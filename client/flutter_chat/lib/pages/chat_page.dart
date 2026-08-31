import 'dart:async';
import 'dart:developer' as developer;

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
import '../models/message_dto.dart';
import '../providers/auth_provider.dart';
import '../providers/call_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/core_providers.dart';
import '../providers/presence_provider.dart';
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

  @override
  void initState() {
    super.initState();
    // 進頁面時立刻拉一次服務端在線快照，避免首個輪詢週期前的空窗期。
    unawaited(ref.read(presenceProvider.notifier).refresh());
  }

  @override
  void dispose() {
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
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // 在線狀態以 presence（實時事件 + 服務端輪詢快照）為唯一數據源。
    final peerOnline = ref.watch(presenceProvider).contains(widget.target.id);

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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                      color: peerOnline ? AppColors.online : AppColors.offline,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(
                    peerOnline ? _lt('在线') : _lt('离线'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color:
                          peerOnline ? AppColors.online : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
          ],
        ),
        actions: widget.target.isGroup
            ? null
            : [
                IconButton(
                  onPressed: () => ref
                      .read(callProvider.notifier)
                      .startCall(widget.target.id, _peerName(), 'voice'),
                  icon: const Icon(Icons.call_rounded),
                  tooltip: context.tr('语音通话'),
                ),
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
            controller: _ctrl,
          ),
        ],
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: url,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
                placeholder: (c, _) => Container(
                  width: 200,
                  height: 200,
                  color: dark
                      ? AppColors.darkSurfaceVariant
                      : const Color(0xFFEDF4F2),
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (c, _, __) => Container(
                  width: 200,
                  height: 200,
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

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onImage;
  final VoidCallback onFile;
  final bool uploading;
  final bool recording;
  final int recordSeconds;
  final VoidCallback? onRecordStart;
  final VoidCallback? onRecordStop;
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
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final busy = uploading || recording;
    final inputBg = dark ? cs.surfaceContainerHighest : const Color(0xFFF5F5F5);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: dark ? cs.surface : Colors.white,
          border: Border(
            top: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: busy ? null : onImage,
              icon: Icon(Icons.image_outlined, color: cs.onSurfaceVariant),
              tooltip: context.tr('图片'),
              style: IconButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
            ),
            IconButton(
              onPressed: busy ? null : onFile,
              icon: Icon(Icons.attach_file_outlined, color: cs.onSurfaceVariant),
              tooltip: context.tr('文件'),
              style: IconButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                constraints: const BoxConstraints(
                  minHeight: 44,
                  maxHeight: 140,
                ),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: recording
                    ? Row(
                        children: [
                          const Icon(Icons.fiber_manual_record,
                              color: Colors.red, size: 12),
                          const SizedBox(width: 8),
                          Text('${context.tr('正在录音')} $recordSeconds″',
                              style: TextStyle(color: cs.onSurfaceVariant)),
                        ],
                      )
                    : TextField(
                        controller: controller,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.send,
                        minLines: 1,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: context.tr('输入消息…'),
                          hintStyle: TextStyle(
                              color: cs.onSurfaceVariant
                                  .withValues(alpha: 0.6)),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                          isDense: true,
                        ),
                        onSubmitted: (_) => onSend(),
                      ),
              ),
            ),
            IconButton(
              onPressed: recording ? onRecordStop : onRecordStart,
              icon: recording
                  ? const Icon(Icons.stop_circle_rounded, color: Colors.red)
                  : Icon(Icons.mic_none_rounded, color: cs.onSurfaceVariant),
              tooltip: recording ? context.tr('正在录音') : context.tr('语音'),
              style: IconButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
            ),
            if (!recording)
              uploading
                  ? const SizedBox(
                      width: 44,
                      height: 44,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  : Material(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: onSend,
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          child: const Icon(Icons.send_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    ),
          ],
        ),
      ),
    );
  }
}
