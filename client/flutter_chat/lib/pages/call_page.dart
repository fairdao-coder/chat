import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../models/enums.dart';
import '../providers/call_provider.dart';
import '../widgets/app_avatar.dart';

class CallPage extends ConsumerStatefulWidget {
  const CallPage({super.key});

  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

class _CallPageState extends ConsumerState<CallPage> {
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    final notifier = ref.read(callProvider.notifier);
    final localStream = notifier.localStream;
    final remoteStream = notifier.remoteStream;

    if (localStream != null) {
      _localRenderer = RTCVideoRenderer();
      await _localRenderer!.initialize();
      _localRenderer!.srcObject = localStream;
    }

    _remoteRenderer = RTCVideoRenderer();
    await _remoteRenderer!.initialize();
    _remoteRenderer!.srcObject = remoteStream.value;

    remoteStream.addListener(_onRemoteStreamChanged);
    setState(() {});
  }

  void _onRemoteStreamChanged() {
    if (!mounted) return;
    final stream = ref.read(callProvider.notifier).remoteStream.value;
    _remoteRenderer?.srcObject = stream;
    setState(() {});
  }

  @override
  void dispose() {
    final notifier = ref.read(callProvider.notifier);
    notifier.remoteStream.removeListener(_onRemoteStreamChanged);
    _localRenderer?.dispose();
    _remoteRenderer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(callProvider);

    if (call == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.canPop()) context.pop();
      });
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackground(call),
            _buildOverlay(call),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(ActiveCall call) {
    if (call.type == CallType.video && _remoteRenderer != null) {
      return RTCVideoView(
        _remoteRenderer!,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    }
    return Container(color: Colors.black87);
  }

  Widget _buildOverlay(ActiveCall call) {
    return Column(
      children: [
        const SizedBox(height: 40),
        _buildPeerInfo(call),
        const Spacer(),
        if (call.type == CallType.video && _localRenderer != null)
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 120,
                  height: 160,
                  child: RTCVideoView(
                    _localRenderer!,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    mirror: true,
                  ),
                ),
              ),
            ),
          ),
        const Spacer(),
        _buildStatusText(call),
        const SizedBox(height: 32),
        _buildControls(call),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildPeerInfo(ActiveCall call) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppAvatar(imageUrl: call.peerAvatar, name: call.peerName, size: 96),
        const SizedBox(height: 16),
        Text(
          call.peerName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusText(ActiveCall call) {
    String text;
    if (call.state == CallState.calling && call.isCaller) {
      text = '正在呼叫…';
    } else if (call.state == CallState.calling && !call.isCaller) {
      text = '来电';
    } else if (call.state == CallState.connecting) {
      text = '正在连接…';
    } else if (call.state == CallState.connected) {
      text = '通话中';
    } else {
      text = '通话结束';
    }
    return Text(
      text,
      style: const TextStyle(color: Colors.white70, fontSize: 16),
    );
  }

  Widget _buildControls(ActiveCall call) {
    final notifier = ref.read(callProvider.notifier);

    if (call.state == CallState.calling && !call.isCaller) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _roundButton(
            icon: Icons.call_end,
            color: Colors.red,
            onTap: () => notifier.rejectCall(),
          ),
          const SizedBox(width: 48),
          _roundButton(
            icon: Icons.call,
            color: AppColors.brand,
            onTap: () => notifier.acceptCall(),
          ),
        ],
      );
    }

    return _roundButton(
      icon: Icons.call_end,
      color: Colors.red,
      onTap: () => notifier.endCall(),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 72,
          height: 72,
          child: Icon(icon, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}
