import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../l10n/app_localizations.dart';
import '../providers/call_provider.dart';

/// 全局通话覆盖层。挂在 MaterialApp.builder 里，通话状态非 idle 时浮在路由之上。
class CallOverlay extends ConsumerStatefulWidget {
  const CallOverlay({super.key});

  @override
  ConsumerState<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends ConsumerState<CallOverlay> {
  CallStatus _prev = CallStatus.idle;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(callProvider);

    // 通话刚结束（idle 且带原因）：弹一个 toast 提示。
    if (_prev != CallStatus.idle &&
        s.status == CallStatus.idle &&
        s.endedReason != null &&
        mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(context.tr(s.endedReason!))));
      });
    }
    _prev = s.status;

    if (s.status == CallStatus.idle) return const SizedBox.shrink();
    return _CallScreen(state: s);
  }
}

class _CallScreen extends ConsumerWidget {
  final CallState state;
  const _CallScreen({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(callProvider.notifier);
    if (state.status == CallStatus.incoming) {
      return Positioned.fill(
        child: Material(
          color: Colors.black54,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _IncomingSheet(state: state, ctrl: ctrl),
          ),
        ),
      );
    }
    if (state.status == CallStatus.outgoing) {
      return Positioned.fill(
        child: Material(
          color: Colors.black87,
          child: Center(child: _OutgoingCard(state: state, ctrl: ctrl)),
        ),
      );
    }
    // connecting / connected
    return Positioned.fill(child: _ActiveCall(state: state, ctrl: ctrl));
  }
}

class _IncomingSheet extends StatelessWidget {
  final CallState state;
  final CallController ctrl;
  const _IncomingSheet({required this.state, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isVideo = state.callType == 'video';
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(context.tr('来电'),
                style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(state.peerName?.isNotEmpty == true ? state.peerName! : '?',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(isVideo ? context.tr('视频通话') : context.tr('语音通话'),
                style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: 'reject',
                  backgroundColor: Colors.red,
                  onPressed: ctrl.reject,
                  child: const Icon(Icons.call_end_rounded),
                ),
                FloatingActionButton(
                  heroTag: 'accept',
                  backgroundColor: Colors.green,
                  onPressed: ctrl.accept,
                  child: Icon(isVideo ? Icons.videocam_rounded : Icons.call_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OutgoingCard extends StatelessWidget {
  final CallState state;
  final CallController ctrl;
  const _OutgoingCard({required this.state, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: Colors.white),
        const SizedBox(height: 20),
        Text(context.tr('正在呼叫…'),
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 4),
        Text(state.peerName ?? '',
            style: const TextStyle(color: Colors.white70, fontSize: 20)),
        const SizedBox(height: 28),
        FloatingActionButton(
          backgroundColor: Colors.red,
          onPressed: ctrl.hangUp,
          child: const Icon(Icons.call_end_rounded),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: ctrl.hangUp,
          child: Text(context.tr('取消'), style: const TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}

class _ActiveCall extends StatelessWidget {
  final CallState state;
  final CallController ctrl;
  const _ActiveCall({required this.state, required this.ctrl});

  String _fmt(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = state.callType == 'video';
    final avatarLetter =
        (state.peerName?.isNotEmpty == true ? state.peerName![0] : '?').toUpperCase();

    return Material(
      color: Colors.black,
      child: Stack(
        children: [
          // 远端画面 / 语音头像
          if (isVideo)
            Positioned.fill(
              child: state.status == CallStatus.connected
                  ? RTCVideoView(ctrl.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                  : const Center(child: CircularProgressIndicator(color: Colors.white)),
            )
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 56, child: Text(avatarLetter, style: const TextStyle(fontSize: 44))),
                  const SizedBox(height: 16),
                  Text(state.peerName ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 22)),
                ],
              ),
            ),

          // 本地小窗（视频通话）
          if (isVideo)
            Positioned(
              top: 40,
              right: 16,
              width: 110,
              height: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: state.cameraOff
                    ? Container(
                        color: Colors.grey.shade800,
                        child: const Center(child: Icon(Icons.videocam_off, color: Colors.white70)),
                      )
                    : RTCVideoView(ctrl.localRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
              ),
            ),

          // 顶部状态条
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: Colors.black45,
                child: Column(
                  children: [
                    Text(isVideo ? context.tr('视频通话') : context.tr('语音通话'),
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(
                      state.status == CallStatus.connected
                          ? _fmt(state.durationSec)
                          : context.tr('正在连接…'),
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 底部控制条
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                color: Colors.black45,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RoundBtn(
                      icon: state.muted ? Icons.mic_off : Icons.mic,
                      label: context.tr('静音'),
                      active: state.muted,
                      onTap: ctrl.toggleMute,
                    ),
                    if (isVideo)
                      _RoundBtn(
                        icon: Icons.flip_camera_android,
                        label: context.tr('翻转'),
                        onTap: ctrl.switchCamera,
                      ),
                    _RoundBtn(
                      icon: Icons.call_end_rounded,
                      label: context.tr('挂断'),
                      danger: true,
                      onTap: ctrl.hangUp,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool danger;
  final VoidCallback onTap;
  const _RoundBtn({
    required this.icon,
    required this.label,
    this.active = false,
    this.danger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? Colors.red
        : (active ? Colors.white : Colors.white70);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: label,
          backgroundColor: danger
              ? Colors.red
              : (active ? Colors.white24 : Colors.white12),
          onPressed: onTap,
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
