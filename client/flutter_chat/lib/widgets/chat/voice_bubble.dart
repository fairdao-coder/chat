import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// 语音气泡：播放 / 暂停按钮 + 进度条 + 时长。
class VoiceBubble extends StatefulWidget {
  final String url;
  final int seconds;
  final bool isMe;
  final Color textColor;

  const VoiceBubble({
    super.key,
    required this.url,
    required this.seconds,
    required this.isMe,
    required this.textColor,
  });

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> {
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _pos = Duration.zero;

  // audioplayers 的 onPositionChanged / onPlayerComplete 是广播流，
  // 只 dispose 播放器而不取消订阅会在长列表里留下悬挂回调（持有已卸载 State）。
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<void>? _doneSub;

  @override
  void initState() {
    super.initState();
    _posSub = _player.onPositionChanged.listen((d) {
      if (mounted) setState(() => _pos = d);
    });
    _doneSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void didUpdateWidget(covariant VoiceBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 列表滚动复用时可能换绑到另一条语音，需重置播放进度，避免显示上一条的进度。
    if (oldWidget.url != widget.url) {
      _pos = Duration.zero;
      _playing = false;
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _doneSub?.cancel();
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
