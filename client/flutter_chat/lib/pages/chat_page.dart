import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:record/record.dart';

import '../config/app_colors.dart';
import '../config/constants.dart';
import '../utils/file_pick.dart';
import '../utils/format.dart';
import '../utils/conversation_keys.dart';
import '../models/enums.dart';
import '../models/feature_settings.dart';
import '../models/message_dto.dart';
import '../providers/auth_provider.dart';
import '../providers/call_provider.dart';
import '../providers/features_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/core_providers.dart';
import '../providers/notification_provider.dart';
import '../providers/presence_provider.dart';
import '../providers/typing_provider.dart';
import '../utils/record_bytes.dart';
import '../l10n/app_localizations.dart';
import '../widgets/chat/input_bar.dart';
import '../widgets/chat/message_bubble.dart';
import '../widgets/chat/peer_status.dart';
import '../widgets/chat/time_divider.dart';

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
    // 標記「當前正在查看的會話」，使該會話的消息不彈頂部橫幅（已在界面內可見）。
    final myId = ref.read(authProvider).user?.id;
    if (myId != null) {
      final convId = widget.target.isGroup
          ? groupConversationId(widget.target.id)
          : privateConversationId(myId, widget.target.id);
      ref.read(activeConversationProvider.notifier).state = convId;
    }
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
    if (!mounted) return;
    if (!_typingActive) {
      _typingActive = true;
      unawaited(ref.read(hubProvider).sendTyping(widget.target.id, true));
    }
    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(seconds: 2), _stopTyping);
  }

  void _stopTyping() {
    if (!mounted) return;
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
    // 離開會話時清除焦點，恢復對該會話消息的橫幅提醒（若仍為本會話）。
    final myId = ref.read(authProvider).user?.id;
    if (myId != null) {
      final convId = widget.target.isGroup
          ? groupConversationId(widget.target.id)
          : privateConversationId(myId, widget.target.id);
      if (ref.read(activeConversationProvider) == convId) {
        ref.read(activeConversationProvider.notifier).state = null;
      }
    }
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
              PeerStatus(
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
                        // 分隔條不參與滾動重建的重繪，獨立為圖層。
                        widgets.add(RepaintBoundary(
                          child: TimeDivider(
                            label:
                                '${formatDayLabel(m.createdAt)} ${formatMsgTime(m.createdAt)}',
                          ),
                        ));
                      }
                      // 每條消息獨立圖層：新消息插入時只重繪該條，
                      // 不會因兄弟節點重繪而讓整屏氣泡重新光柵化。
                      widgets.add(RepaintBoundary(
                        child: MessageBubble(
                          message: m,
                          isMe: m.senderId == myId,
                          onOpenUrl: _openUrl,
                          dark: dark,
                        ),
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
          ChatInputBar(
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
