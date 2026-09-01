import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

import '../config/app_colors.dart';
import '../config/constants.dart';
import '../utils/file_pick.dart';
import '../utils/format.dart';
import '../models/enums.dart';
import '../models/feature_settings.dart';
import '../models/message_dto.dart';
import '../providers/auth_provider.dart';
import '../providers/call_provider.dart';
import '../providers/features_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/core_providers.dart';
import '../providers/presence_provider.dart';
import '../providers/typing_provider.dart';
import '../utils/url.dart';
import '../utils/record_bytes.dart';
import '../l10n/app_localizations.dart';
import 'image_viewer_page.dart';

class ChatPage extends ConsumerStatefulWidget {
  final ChatTarget target;
  final String? title;
  const ChatPage({
    super.key,
    required this.target,
    this.title,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _recorder = AudioRecorder();
  bool _uploading = false;
  bool _recording = false;
  int _recordSeconds = 0;
  int _lastLen = 0;
  Timer? _recordTimer;
  String? _recordPath; // native 錄音文件路徑（web 用 stop() 返回值）

  // ---- 正在輸入狀態上報 ----
  Timer? _typingStopTimer;
  bool _typingActive = false;

  @override
  void initState() {
    super.initState();
    // 進頁面時立刻拉一次服務端在線快照，避免首個輪詢週期前的空窗期。
    unawaited(ref.read(presenceProvider.notifier).refresh());
    _ctrl.addListener(_onTextChanged);
  }

  /// 輸入框內容變化時上報「正在輸入」；清空則立即上報「停止輸入」。
  void _onTextChanged() {
    if (widget.target.isGroup) return; // 羣聊暫不支援
    if (_ctrl.text.isEmpty) {
      _stopTyping();
    } else {
      _notifyTyping();
    }
  }

  /// 上報正在輸入，並重置 2 秒停止定時器（避免每敲一個字都發一次）。
  void _notifyTyping() {
    if (!_typingActive) {
      _typingActive = true;
      unawaited(ref.read(hubProvider).sendTyping(widget.target.id, true));
    }
    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(seconds: 2), _stopTyping);
  }

  void _stopTyping() {
    _typingStopTimer?.cancel();
    if (_typingActive) {
      _typingActive = false;
      unawaited(ref.read(hubProvider).sendTyping(widget.target.id, false));
    }
  }

  @override
  void dispose() {
    _stopTyping();
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _scroll.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  /// 安全取本地化字符串：組件卸載後回退到 key，避免訪問已 deactivate 的 context。
  String _lt(String key) {
    if (!mounted) return key;
    try {
      return context.tr(key);
    } catch (_) {
      return key;
    }
  }

  /// 通話時展示給對方的暱稱（來自會話標題；缺失時回退到通用文案）。
  String _peerName() =>
      widget.title ?? (widget.target.isGroup ? _lt('群聊') : _lt('私聊'));

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  }

  Future<void> _sendText() async {
    final text = _ctrl.text;
    if (text.trim().isEmpty) return;
    final err =
        await ref.read(chatProvider(widget.target).notifier).sendText(text);
    if (err == null) {
      _stopTyping(); // 消息已發出，對方不應再看到「正在輸入」
      _ctrl.clear();
    } else {
      _handleHubError(err);
    }
  }

  Future<void> _pickImage() async {
    try {
      developer.log('opening image picker', name: 'chat');
      final picked = await pickImageFile();
      if (picked == null) {
        // 用戶主動取消 = 合法的"什麼都沒發生"。這裡顯式記一行日誌，幫助開發者
        // 區分"用戶取消了"與"picker 靜默失敗"，而不是讓用戶盯著一個毫無反饋的 UI。
        developer.log('image picker returned null (cancelled or silent)',
            name: 'chat');
        return;
      }
      developer.log(
          'picked image name=${picked.name} bytes=${picked.bytes.length}',
          name: 'chat');
      await _uploadAndSend(
        bytes: picked.bytes,
        path: null,
        name: picked.name,
        kind: MessageType.image,
      );
    } catch (e, st) {
      developer.log('image pick error', name: 'chat', error: e, stackTrace: st);
      _toast('${_lt('选择图片失败')}: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      developer.log('opening file picker', name: 'chat');
      final picked = await pickAnyFile();
      if (picked == null) {
        developer.log('file picker returned null (cancelled or silent)',
            name: 'chat');
        return;
      }
      developer.log(
          'picked file name=${picked.name} bytes=${picked.bytes.length}',
          name: 'chat');
      await _uploadAndSend(
        bytes: picked.bytes,
        path: null,
        name: picked.name,
        kind: MessageType.file,
      );
    } catch (e, st) {
      developer.log('file pick error', name: 'chat', error: e, stackTrace: st);
      _toast('${_lt('选择文件失败')}: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        _toast(_lt('麦克风权限被拒绝'));
        return;
      }
      _recordTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordSeconds = 0;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
      if (kIsWeb) {
        // Web 上 record 仍需一個 path 作為錄音標識（內部生成 blob URL）。
        await _recorder.start(const RecordConfig(),
            path: 'voice_${DateTime.now().millisecondsSinceEpoch}');
      } else {
        final path = nativeTempVoicePath();
        await _recorder.start(const RecordConfig(), path: path);
        _recordPath = path;
      }
    } catch (e, st) {
      developer.log('start recording error',
          name: 'chat', error: e, stackTrace: st);
      _recordTimer?.cancel();
      if (mounted) setState(() => _recording = false);
      _toast('${_lt('录音失败')}: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_recording) return;
    _recordTimer?.cancel();
    String? path;
    try {
      path = await _recorder.stop();
    } catch (e, st) {
      developer.log('stop recording error',
          name: 'chat', error: e, stackTrace: st);
      if (mounted) setState(() => _recording = false);
      _toast('${_lt('录音失败')}: $e');
      return;
    }
    final finalPath = kIsWeb ? path : _recordPath;
    if (mounted) setState(() => _recording = false);
    if (finalPath == null || finalPath.isEmpty) {
      _toast(_lt('录音失败'));
      return;
    }
    // 太短（<1s）直接忽略，避免產生空語音。
    if (_recordSeconds < 1) return;
    try {
      developer.log('reading recording bytes path=$finalPath', name: 'chat');
      final bytes = await readRecordingBytes(finalPath);
      await _uploadAndSend(
        bytes: bytes,
        path: null,
        name: 'voice_${DateTime.now().microsecondsSinceEpoch}.m4a',
        kind: MessageType.voice,
        durationSec: _recordSeconds,
      );
    } catch (e, st) {
      developer.log('voice upload error',
          name: 'chat', error: e, stackTrace: st);
      _toast('${_lt('语音消息')}: $e');
    }
  }

  /// 取消錄音：停止並丟棄當前錄音，不發送任何消息。
  Future<void> _cancelRecording() async {
    if (!_recording) return;
    _recordTimer?.cancel();
    try {
      await _recorder.stop();
    } catch (e, st) {
      developer.log('cancel recording stop error',
          name: 'chat', error: e, stackTrace: st);
    }
    final path = kIsWeb
        ? null
        : (_recordPath != null && _recordPath!.isNotEmpty
            ? _recordPath!
            : null);
    _recordPath = null;
    if (mounted) setState(() => _recording = false);
    // 清理臨時錄音文件，避免殘留。
    try {
      if (path != null) await File(path).delete();
    } catch (_) {
      // ignore cleanup errors
    }
  }

  Future<void> _uploadAndSend({
    Uint8List? bytes,
    String? path,
    String? name,
    required MessageType kind,
    int? durationSec,
  }) async {
    if ((bytes == null || bytes.isEmpty) && (path == null || path.isEmpty)) {
      _toast(_lt('文件内容读取失败，请重试'));
      return;
    }
    setState(() => _uploading = true);
    try {
      developer.log(
          'POST /api/files/upload name=$name kind=${messageTypeToJson(kind)}',
          name: 'chat');
      final api = ref.read(apiProvider);
      final up = await api.uploadFile(
        filePath: path,
        bytes: bytes,
        filename: name,
      );
      developer.log(
          'uploaded url=${up.url} ct=${up.contentType} size=${up.size}',
          name: 'chat');
      final notifier = ref.read(chatProvider(widget.target).notifier);
      final err = kind == MessageType.voice
          ? await notifier.sendVoice(up.url, durationSec ?? 0)
          : await notifier.sendMedia(up.url, messageTypeToJson(kind));
      if (err != null) {
        developer.log('send returned err=$err', name: 'chat');
        _handleHubError(err);
      } else {
        developer.log('send ok', name: 'chat');
      }
    } catch (e, st) {
      developer.log('upload error', name: 'chat', error: e, stackTrace: st);
      _toast('${_lt('上传失败')}: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _handleHubError(String raw) {
    final (code, message) = parseHubError(raw);
    if (code == ErrorCodes.friendRequired) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(_lt('还不是好友')),
          content: Text(message),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: Text(_lt('稍后'))),
            FilledButton(
                onPressed: () {
                  Navigator.pop(c);
                  context.push('/add-friend');
                },
                child: Text(_lt('去添加好友'))),
          ],
        ),
      );
    } else {
      _toast(message);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, webOnlyWindowName: '_blank');
    } else {
      _toast('${_lt('无法打开')}: $url');
    }
  }

  /// 是否需要在兩條消息之間插入時間分隔（相差 >5 分鐘或跨天）。
  bool _needTimeDivider(MessageDto? prev, MessageDto cur) {
    if (prev == null) return true;
    if (prev.createdAt.year != cur.createdAt.year ||
        prev.createdAt.month != cur.createdAt.month ||
        prev.createdAt.day != cur.createdAt.day) {
      return true;
    }
    return cur.createdAt.difference(prev.createdAt).inMinutes > 5;
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider(widget.target));
    final myId = ref.watch(authProvider).user?.id;
    final msgs = chat.messages;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // 在線狀態以 presence（實時事件 + 服務端輪詢快照）為唯一數據源。
    final peerOnline = ref.watch(presenceProvider).contains(widget.target.id);
    // 對方正在輸入（4 秒無新事件自動過期）。
    final peerTyping = ref.watch(typingProvider).contains(widget.target.id);
    // 系統功能開關：加載中/失敗時回退到全開。
    final features = ref.watch(featuresProvider).maybeWhen(
          data: (f) => f,
          orElse: () => FeatureSettings.allEnabled(),
        );

    if (msgs.length > _lastLen) {
      _lastLen = msgs.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    final title =
        widget.title ?? (widget.target.isGroup ? _lt('群聊') : _lt('私聊'));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            if (!widget.target.isGroup)
              _PeerStatus(
                online: peerOnline,
                typing: peerTyping,
                // 後臺可關閉在線狀態展示；「正在輸入」不受其影響。
                showOnline: features.showOnlineStatus,
                onlineLabel: _lt('在线'),
                offlineLabel: _lt('离线'),
                typingLabel: _lt('正在输入...'),
              ),
          ],
        ),
        actions: widget.target.isGroup
            ? null
            : [
                // 通話入口受後臺功能開關控制。
                if (features.enableVoiceCall)
                  IconButton(
                    onPressed: () => ref
                        .read(callProvider.notifier)
                        .startCall(widget.target.id, _peerName(), 'voice'),
                    icon: const Icon(Icons.call_rounded),
                    tooltip: context.tr('语音通话'),
                  ),
                if (features.enableVideoCall)
                  IconButton(
                    onPressed: () => ref
                        .read(callProvider.notifier)
                        .startCall(widget.target.id, _peerName(), 'video'),
                    icon: const Icon(Icons.videocam_rounded),
                    tooltip: context.tr('视频通话'),
                  ),
              ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chat.loading && msgs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    itemCount: msgs.length,
                    itemBuilder: (c, i) {
                      final m = msgs[i];
                      final widgets = <Widget>[];
                      if (_needTimeDivider(i > 0 ? msgs[i - 1] : null, m)) {
                        final dayLabel = formatDayLabel(m.createdAt);
                        final timeLabel = formatMsgTime(m.createdAt);
                        widgets.add(_TimeDivider(
                          label: dayLabel == '今天' || dayLabel == '昨天'
                              ? '$dayLabel $timeLabel'
                              : '$dayLabel $timeLabel',
                        ));
                      }
                      widgets.add(_Bubble(
                        m: m,
                        isMe: m.senderId == myId,
                        onOpenUrl: _openUrl,
                        dark: dark,
                      ));
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: widgets,
                      );
                    },
                  ),
          ),
          if (chat.error != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                chat.error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ),
          _InputBar(
            onSend: _sendText,
            onImage: _pickImage,
            onFile: _pickFile,
            uploading: _uploading,
            recording: _recording,
            recordSeconds: _recordSeconds,
            onRecordStart: _startRecording,
            onRecordStop: _stopRecording,
            onRecordCancel: _cancelRecording,
            controller: _ctrl,
            allowFile: features.allowFile,
            allowVoice: features.allowVoice,
          ),
        ],
      ),
    );
  }
}

/// 標題欄下方的狀態行：在線 / 離線 / 正在輸入。
class _PeerStatus extends StatelessWidget {
  final bool online;
  final bool typing;

  /// 後臺是否開啟在線狀態展示；關閉且非輸入中時整行隱藏。
  final bool showOnline;
  final String onlineLabel;
  final String offlineLabel;
  final String typingLabel;

  const _PeerStatus({
    required this.online,
    required this.typing,
    required this.showOnline,
    required this.onlineLabel,
    required this.offlineLabel,
    required this.typingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // 正在輸入比在線狀態更即時有用，優先展示（且不受在線狀態開關影響）。
    if (typing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _TypingDots(),
          const SizedBox(width: 6),
          Text(
            typingLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: AppColors.online,
            ),
          ),
        ],
      );
    }

    // 後臺關閉在線狀態展示時，非輸入狀態下整行隱藏。
    if (!showOnline) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(
            color: online ? AppColors.online : AppColors.offline,
            shape: BoxShape.circle,
          ),
        ),
        Text(
          online ? onlineLabel : offlineLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
            color: online ? AppColors.online : cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 「正在輸入」的三點跳動動畫。
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 8,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (i) {
              // 三個點依次錯開相位，形成波浪跳動。
              final phase = (_c.value - i * 0.15).clamp(0.0, 1.0);
              final scale =
                  0.6 + 0.4 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.online,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _TimeDivider extends StatelessWidget {
  final String label;
  const _TimeDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: cs.onSurfaceVariant.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final MessageDto m;
  final bool isMe;
  final void Function(String) onOpenUrl;
  final bool dark;
  const _Bubble({
    required this.m,
    required this.isMe,
    required this.onOpenUrl,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textColor = isMe
        ? Colors.white
        : (dark ? AppColors.bubbleTextPeerDark : AppColors.bubbleTextPeerLight);

    // 圖片消息：圓角縮略圖（自身即氣泡）
    if (m.type == MessageType.image && m.mediaUrl != null) {
      final url = resolveUrl(m.mediaUrl);
      return Column(
        crossAxisAlignment: align,
        children: [
          if (!isMe && m.senderName.isNotEmpty) _senderName(context),
          GestureDetector(
            onTap: () => openImageViewer(context, url),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 200,
                maxHeight: 280,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (c, _) => AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      color: dark
                          ? AppColors.darkSurfaceVariant
                          : const Color(0xFFEDF4F2),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  errorWidget: (c, _, __) => AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      color: dark
                          ? AppColors.darkSurfaceVariant
                          : const Color(0xFFEDF4F2),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.broken_image_outlined),
                            const SizedBox(height: 4),
                            Text(context.tr('加载失败·点击打开'),
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      );
    }

    // 語音消息：播放 / 暫停 + 進度條 + 時長
    if (m.type == MessageType.voice && m.mediaUrl != null) {
      final dur = int.tryParse(m.content) ?? 0;
      final body = _VoiceBubble(
        url: resolveUrl(m.mediaUrl!),
        seconds: dur,
        isMe: isMe,
        textColor: textColor,
        dark: dark,
      );
      return _wrap(context, body, align, textColor);
    }

    Widget body;
    if (m.type == MessageType.file && m.mediaUrl != null) {
      final url = resolveUrl(m.mediaUrl);
      final name = m.mediaUrl!.split('/').last;
      body = GestureDetector(
        onTap: () => onOpenUrl(url),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_outlined, color: textColor, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                style: TextStyle(
                  color: textColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      body = Text(m.content, style: TextStyle(color: textColor, fontSize: 15));
    }

    return _wrap(context, body, align, textColor);
  }

  Widget _wrap(BuildContext context, Widget body, CrossAxisAlignment align,
      Color textColor) {
    final isMe = this.isMe;
    final radius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(5),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(5),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          );

    return Column(
      crossAxisAlignment: align,
      children: [
        if (!isMe && m.senderName.isNotEmpty) _senderName(context),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          decoration: BoxDecoration(
            gradient: isMe ? AppColors.bubbleMine : null,
            color: isMe
                ? null
                : (dark ? AppColors.bubblePeerDark : AppColors.bubblePeerLight),
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: isMe
                    ? AppColors.brand.withValues(alpha: 0.28)
                    : Colors.black.withValues(alpha: dark ? 0.25 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: body,
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _senderName(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 3),
        child: Text(
          m.senderName,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}

/// 語音氣泡：播放 / 暫停按鈕 + 進度條 + 時長。
class _VoiceBubble extends StatefulWidget {
  final String url;
  final int seconds;
  final bool isMe;
  final Color textColor;
  final bool dark;
  const _VoiceBubble({
    required this.url,
    required this.seconds,
    required this.isMe,
    required this.textColor,
    required this.dark,
  });

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _pos = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPositionChanged.listen((d) {
      if (mounted) setState(() => _pos = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_playing) {
        await _player.pause();
        if (mounted) setState(() => _playing = false);
      } else {
        await _player.setSource(UrlSource(widget.url));
        await _player.resume();
        if (mounted) setState(() => _playing = true);
      }
    } catch (_) {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.seconds > 0 ? widget.seconds : 1;
    final progress = (_pos.inSeconds.clamp(0, total) / total).clamp(0.0, 1.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _toggle,
          icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          color: widget.textColor,
          iconSize: 28,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 4,
              decoration: BoxDecoration(
                color: widget.textColor.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.textColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text('${widget.seconds}″',
                style: TextStyle(color: widget.textColor, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onImage;
  final VoidCallback onFile;
  final bool uploading;
  final bool recording;
  final int recordSeconds;
  final VoidCallback? onRecordStart;
  final VoidCallback? onRecordStop;
  final VoidCallback? onRecordCancel;

  /// 是否允許發送文件（含圖片），由後臺開關控制。
  final bool allowFile;

  /// 是否允許發送語音消息，由後臺開關控制。
  final bool allowVoice;
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onImage,
    required this.onFile,
    required this.uploading,
    this.recording = false,
    this.recordSeconds = 0,
    this.onRecordStart,
    this.onRecordStop,
    this.onRecordCancel,
    this.allowFile = true,
    this.allowVoice = true,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar>
    with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  late FocusNode _focus;

  /// 錄音狀態動畫：紅點呼吸 + 波形律動。
  late AnimationController _pulse;
  var _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _hasText = _controller.text.trim().isNotEmpty;
    _controller.addListener(_onTextChanged);
    _focus = FocusNode();
    _focus.addListener(_onFocusChanged);
    _pulse =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _InputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      _controller = widget.controller;
      _controller.addListener(_onTextChanged);
      _hasText = _controller.text.trim().isNotEmpty;
    }
    if (widget.recording) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      if (_pulse.isAnimating) _pulse.stop();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final v = _controller.text.trim().isNotEmpty;
    if (v != _hasText) setState(() => _hasText = v);
  }

  void _insertEmoji(String emoji) {
    final text = _controller.text;
    final sel = _controller.selection;
    final newText = text.replaceRange(sel.start, sel.end, emoji);
    final newSel = TextSelection.collapsed(offset: sel.start + emoji.length);
    _controller.value = TextEditingValue(text: newText, selection: newSel);
  }

  void _showPlusSheet() {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: dark ? cs.surface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('更多'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ActionItem(
                      icon: Icons.image_outlined,
                      label: context.tr('图片'),
                      color: const Color(0xFF3B82F6),
                      onTap: () {
                        Navigator.of(c).pop();
                        widget.onImage();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionItem(
                      icon: Icons.attach_file_outlined,
                      label: context.tr('文件'),
                      color: const Color(0xFFF59E0B),
                      onTap: () {
                        Navigator.of(c).pop();
                        widget.onFile();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmojiSheet() {
    const emojis = [
      '😀',
      '😂',
      '🥰',
      '😘',
      '😭',
      '😡',
      '👍',
      '👎',
      '🙏',
      '🎉',
      '❤️',
      '💔',
      '🔥',
      '👋',
      '🤔',
      '😎',
      '😅',
      '😊',
      '🥳',
      '🤮',
      '👀',
      '✨',
      '🎁',
      '🎄',
      '🌹',
      '☀️',
      '🌙',
      '⭐',
      '🍎',
      '🍺',
      '🍰',
      '🎂',
      '🍜',
      '🍕',
      '🍔',
      '⚽',
      '🏀',
      '🏸',
      '🎮',
      '🎵',
    ];
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: dark ? cs.surface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SizedBox(
          height: 316,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    Text(
                      context.tr('常用表情'),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    // 退格：支持 emoji 代理對，點選後面板保持打開，可連續輸入。
                    IconButton(
                      tooltip: context.tr('删除'),
                      icon: const Icon(Icons.backspace_outlined, size: 20),
                      onPressed: _backspace,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: emojis.length,
                  itemBuilder: (c, i) => InkWell(
                    onTap: () => _insertEmoji(emojis[i]),
                    borderRadius: BorderRadius.circular(10),
                    child: Center(
                      child:
                          Text(emojis[i], style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 刪除光標前的一個字符（正確處理 emoji 代理對）。
  void _backspace() {
    final text = _controller.text;
    if (text.isEmpty) return;
    final sel = _controller.selection;
    final end =
        (sel.end >= 0 && sel.end <= text.length) ? sel.end : text.length;
    var start =
        (sel.start >= 0 && sel.start <= text.length) ? sel.start : text.length;
    if (start == end) {
      if (start == 0) return;
      start--;
      // 高位代理項（emoji 佔兩個 code unit），再退一格整體刪除。
      if (start > 0 &&
          text.codeUnitAt(start) >= 0xD800 &&
          text.codeUnitAt(start) <= 0xDBFF) {
        start--;
      }
    }
    final newText = text.replaceRange(start, end, '');
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    // 錄音模式：整條切換為錄音操作面板（取消 / 狀態 / 完成）。
    if (widget.recording) {
      return SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            color: dark ? cs.surface : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.3 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: _buildRecordingRow(cs),
        ),
      );
    }

    final busy = widget.uploading;
    // 上傳中固定顯示發送態（內含進度圈），其餘時刻按有無文本切換 發送/更多。
    final rightChild = widget.uploading
        ? _buildSendButton(context, cs, key: const ValueKey('send'))
        : _hasText
            ? _buildSendButton(context, cs, key: const ValueKey('send'))
            : (widget.allowFile
                ? _IconAction(
                    key: const ValueKey('plus'),
                    icon: Icons.add_circle_outline_rounded,
                    tooltip: context.tr('更多'),
                    onTap: busy ? null : _showPlusSheet,
                  )
                : const SizedBox.shrink(key: ValueKey('none')));

    return SafeArea(
      top: false,
      child: Container(
        // 微信風格淺灰底欄，頂部 0.5 細線分隔，無陰影。
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF121212) : const Color(0xFFF7F7F7),
          border: Border(
            top: BorderSide(
              color: dark ? const Color(0xFF2A2A2A) : const Color(0xFFD9D9D9),
              width: 0.5,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 语音（受後臺「允許發送語音」開關控制）
              if (widget.allowVoice)
                _IconAction(
                  icon: Icons.mic_none_rounded,
                  tooltip: context.tr('语音'),
                  onTap: busy ? null : widget.onRecordStart,
                ),
              // 输入框（白底淺灰邊框，小圓角，高度充足）
              Expanded(child: _buildInputPill(cs, dark)),
              // 表情
              _IconAction(
                icon: Icons.emoji_emotions_outlined,
                tooltip: context.tr('表情'),
                onTap: busy ? null : _showEmojiSheet,
              ),
              // 發送 / 更多（平滑切換）
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: child,
                ),
                child: rightChild,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 微信風格輸入框：白底、淺灰細邊框、小圓角、高度 46，文字/光標垂直居中。
  Widget _buildInputPill(ColorScheme cs, bool dark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      constraints: const BoxConstraints(minHeight: 28, maxHeight: 40),
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: dark ? const Color(0xFF3A3A3A) : const Color(0xFFE5E5E5),
          width: 0.8,
        ),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.send,
        minLines: 1,
        maxLines: 5,
        textAlignVertical: TextAlignVertical.center,
        cursorColor: AppColors.brand,
        style: TextStyle(
          fontSize: 14,
          height: 1.2,
          color: dark ? Colors.white : const Color(0xFF1A1A1A),
        ),
        decoration: InputDecoration(
          hintText: context.tr('输入消息…'),
          hintStyle: TextStyle(
            color: dark ? const Color(0xFF888888) : const Color(0xFFB3B3B3),
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
          isCollapsed: true,
        ),
        onSubmitted: (_) => widget.onSend(),
      ),
    );
  }

  /// 微信風格發送按鈕：有文字時綠色小圓角矩形「發送」，上傳中顯示進度圈。
  Widget _buildSendButton(BuildContext context, ColorScheme cs, {Key? key}) {
    return Material(
      key: key,
      color: AppColors.brand,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: widget.uploading ? null : widget.onSend,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          child: widget.uploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  context.tr('发送'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  /// 錄音面板：呼吸紅點 + 律動波形 + 秒數，左取消 / 右完成。
  Widget _buildRecordingRow(ColorScheme cs) {
    return Row(
      children: [
        TextButton(
          onPressed: widget.onRecordCancel,
          style: TextButton.styleFrom(
            foregroundColor: cs.error,
            minimumSize: const Size(52, 40),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: Text(context.tr('取消'), style: const TextStyle(fontSize: 14)),
        ),
        Expanded(
          child: Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
            ),
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = _pulse.value * 2 * math.pi;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: 0.45 + 0.55 * (0.5 + 0.5 * math.sin(t)),
                      child: const Icon(Icons.fiber_manual_record,
                          color: Colors.red, size: 13),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${context.tr('正在录音')} ${widget.recordSeconds}″',
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 10),
                    for (var i = 0; i < 4; i++)
                      Container(
                        width: 3,
                        height: 6 + 8 * (0.5 + 0.5 * math.sin(t + i * 1.1)),
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        Material(
          color: AppColors.brand,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onRecordStop,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              child: Text(
                context.tr('完成'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 底欄圖標按鈕：28×28 觸控區，與矮輸入框同高對齊。
class _IconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _IconAction({
    required this.icon,
    required this.tooltip,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 22,
              color: onTap == null ? cs.outline : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// 「更多」面板的操作卡片：彩色圓形圖標 + 標籤。
class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
