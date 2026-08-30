import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../data/signalr_client.dart';
import '../models/call_signal.dart';
import '../providers/core_providers.dart';

/// 當前通話階段。
enum CallStatus { idle, outgoing, incoming, connecting, connected }

/// 通話 UI 狀態。
class CallState {
  final CallStatus status;
  final String? callId;
  final String? peerId;
  final String? peerName;
  final String callType; // 'voice' | 'video'
  final bool isCaller;
  final bool muted;
  final bool cameraOff;
  final int durationSec;
  final String? endedReason; // 對方已拒絕 / 對方忙線 / 對方無應答 / 通話結束 ...

  const CallState({
    this.status = CallStatus.idle,
    this.callId,
    this.peerId,
    this.peerName,
    this.callType = 'voice',
    this.isCaller = false,
    this.muted = false,
    this.cameraOff = false,
    this.durationSec = 0,
    this.endedReason,
  });

  CallState copyWith({
    CallStatus? status,
    String? callId,
    String? peerId,
    String? peerName,
    String? callType,
    bool? isCaller,
    bool? muted,
    bool? cameraOff,
    int? durationSec,
    String? endedReason,
  }) =>
      CallState(
        status: status ?? this.status,
        callId: callId ?? this.callId,
        peerId: peerId ?? this.peerId,
        peerName: peerName ?? this.peerName,
        callType: callType ?? this.callType,
        isCaller: isCaller ?? this.isCaller,
        muted: muted ?? this.muted,
        cameraOff: cameraOff ?? this.cameraOff,
        durationSec: durationSec ?? this.durationSec,
        endedReason: endedReason ?? this.endedReason,
      );
}

final callProvider =
    StateNotifierProvider<CallController, CallState>((ref) {
  return CallController(ref.read(hubProvider));
});

/// 管理一次 WebRTC 語音/視頻通話：本地/遠端媒體流、PeerConnection、與 SignalR 的信令交換。
///
/// 設計為單例（非 family）：全局只有一個活躍通話，來電由頂層 [CallOverlay] 統一呈現。
class CallController extends StateNotifier<CallState> {
  final ChatHubClient _hub;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  bool _renderersReady = false;

  StreamSubscription<CallInvite>? _subInvite;
  StreamSubscription<String>? _subAccepted;
  StreamSubscription<(String, String)>? _subRejected;
  StreamSubscription<(String, String)>? _subOffer;
  StreamSubscription<(String, String)>? _subAnswer;
  StreamSubscription<(String, String)>? _subIce;
  StreamSubscription<String>? _subHangUp;
  Timer? _noAnswerTimer;
  Timer? _durationTimer;

  CallController(this._hub) : super(const CallState()) {
    _init();
  }

  Future<void> _init() async {
    await _ensureRenderers();
    _subInvite = _hub.onIncomingCall.listen(_onIncoming);
    _subAccepted = _hub.onCallAccepted.listen(_onAccepted);
    _subRejected = _hub.onCallRejected.listen(_onRejected);
    _subOffer = _hub.onOffer.listen(_onOffer);
    _subAnswer = _hub.onAnswer.listen(_onAnswer);
    _subIce = _hub.onIceCandidate.listen(_onIce);
    _subHangUp = _hub.onHangUp.listen(_onHangUp);
  }

  Future<void> _ensureRenderers() async {
    if (!_renderersReady) {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
      _renderersReady = true;
    }
  }

  Future<MediaStream> _getUserMedia(String callType) {
    final constraints = {
      'audio': true,
      'video': callType == 'video'
          ? {'facingMode': 'user', 'width': 1280, 'height': 720}
          : false,
    };
    return navigator.mediaDevices.getUserMedia(constraints);
  }

  String _newCallId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${(DateTime.now().microsecond % 9000 + 1000)}';

  // ---------------- 主叫 ----------------

  Future<void> startCall(String peerId, String peerName, String callType) async {
    if (state.status != CallStatus.idle) return;
    await _ensureRenderers();
    final callId = _newCallId();
    state = state.copyWith(
      status: CallStatus.outgoing,
      callId: callId,
      peerId: peerId,
      peerName: peerName,
      callType: callType,
      isCaller: true,
      durationSec: 0,
      endedReason: null,
    );
    try {
      _localStream = await _getUserMedia(callType);
      localRenderer.srcObject = _localStream;
    } catch (e) {
      _cleanup();
      state = state.copyWith(status: CallStatus.idle, endedReason: '無法訪問麥克風或攝像頭');
      return;
    }
    try {
      await _hub.inviteCall(callId, peerId, callType);
    } catch (e) {
      _cleanup();
      state = state.copyWith(status: CallStatus.idle, endedReason: '呼叫失敗');
      return;
    }
    // 無應答超時：30s 內對方未接聽則自動掛斷。
    _noAnswerTimer = Timer(const Duration(seconds: 30), () {
      if (state.status == CallStatus.outgoing) {
        hangUp();
      }
    });
  }

  // ---------------- 被叫 ----------------

  void _onIncoming(CallInvite inv) {
    if (state.status != CallStatus.idle) {
      // 已在通話中，直接拒掉新來電（忙線）。
      _hub.rejectCall(inv.callId).catchError((_) {});
      return;
    }
    state = state.copyWith(
      status: CallStatus.incoming,
      callId: inv.callId,
      peerId: inv.callerId,
      peerName: inv.callerName,
      callType: inv.callType,
      isCaller: false,
    );
  }

  Future<void> accept() async {
    if (state.status != CallStatus.incoming || state.callId == null) return;
    await _ensureRenderers();
    final callId = state.callId!;
    final callType = state.callType;
    state = state.copyWith(status: CallStatus.connecting);
    try {
      _localStream = await _getUserMedia(callType);
      localRenderer.srcObject = _localStream;
      await _createPeer();
      await _hub.acceptCall(callId);
    } catch (e) {
      _cleanup();
      state = state.copyWith(status: CallStatus.idle, endedReason: '無法訪問麥克風或攝像頭');
    }
  }

  Future<void> reject() async {
    if (state.callId != null) await _hub.rejectCall(state.callId!).catchError((_) {});
    _cleanup();
    state = const CallState();
  }

  // ---------------- PeerConnection ----------------

  Future<void> _createPeer() async {
    _pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
    });
    _pc!.onIceCandidate = (candidate) async {
      if (state.callId != null && mounted) {
        await _hub.sendIceCandidate(state.callId!, jsonEncode(candidate.toMap()));
      }
    };
    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty && mounted) {
        remoteRenderer.srcObject = event.streams[0];
        if (state.status != CallStatus.connected) {
          state = state.copyWith(status: CallStatus.connected);
          _startDuration();
        }
      }
    };
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await _pc!.addTrack(track, _localStream!);
      }
    }
  }

  Future<void> _onAccepted(String callId) async {
    if (state.status != CallStatus.outgoing || state.callId != callId) return;
    _noAnswerTimer?.cancel();
    state = state.copyWith(status: CallStatus.connecting);
    await _createPeer();
    try {
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      await _hub.sendOffer(callId, jsonEncode(offer.toMap()));
    } catch (e) {
      _cleanup();
      state = state.copyWith(status: CallStatus.idle, endedReason: '連接失敗');
    }
  }

  Future<void> _onRejected((String, String) p) async {
    final (callId, reason) = p;
    if (state.callId != callId) return;
    final msg = switch (reason) {
      'busy' => '對方忙線',
      'self' => '不能呼叫自己',
      _ => '對方已拒絕',
    };
    _cleanup();
    state = state.copyWith(status: CallStatus.idle, endedReason: msg);
  }

  Future<void> _onOffer((String, String) p) async {
    final (callId, sdpJson) = p;
    if (state.callId != callId || _pc == null) return;
    try {
      final m = jsonDecode(sdpJson) as Map<String, dynamic>;
      final desc = RTCSessionDescription(m['sdp'] as String?, m['type'] as String?);
      await _pc!.setRemoteDescription(desc);
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      await _hub.sendAnswer(callId, jsonEncode(answer.toMap()));
    } catch (e) {
      _cleanup();
      state = state.copyWith(status: CallStatus.idle, endedReason: '連接失敗');
    }
  }

  Future<void> _onAnswer((String, String) p) async {
    final (callId, sdpJson) = p;
    if (state.callId != callId || _pc == null) return;
    try {
      final m = jsonDecode(sdpJson) as Map<String, dynamic>;
      final desc = RTCSessionDescription(m['sdp'] as String?, m['type'] as String?);
      await _pc!.setRemoteDescription(desc);
    } catch (_) {
      // ignore malformed answer
    }
  }

  Future<void> _onIce((String, String) p) async {
    final (callId, candJson) = p;
    if (state.callId != callId || _pc == null) return;
    try {
      final m = jsonDecode(candJson) as Map<String, dynamic>;
      final cand = RTCIceCandidate(
        m['candidate'] as String?,
        m['sdpMid'] as String?,
        m['sdpMLineIndex'] as int?,
      );
      await _pc!.addCandidate(cand);
    } catch (_) {
      // ignore malformed candidate
    }
  }

  Future<void> _onHangUp(String callId) async {
    if (state.callId != callId) return;
    final wasConnected = state.status == CallStatus.connected;
    _cleanup();
    state = state.copyWith(
      status: CallStatus.idle,
      endedReason: wasConnected ? '通話結束' : '通話已取消',
    );
  }

  void _startDuration() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) state = state.copyWith(durationSec: state.durationSec + 1);
    });
  }

  // ---------------- 控制 ----------------

  Future<void> hangUp() async {
    final wasConnected = state.status == CallStatus.connected;
    if (state.callId != null) await _hub.hangUpCall(state.callId!).catchError((_) {});
    _cleanup();
    state = state.copyWith(
      status: CallStatus.idle,
      endedReason: wasConnected ? '通話結束' : (state.endedReason ?? '通話已取消'),
    );
  }

  void toggleMute() {
    final audio = _localStream?.getAudioTracks() ?? const [];
    if (audio.isEmpty) return;
    final enabled = !audio.first.enabled;
    for (final t in audio) {
      t.enabled = enabled;
    }
    state = state.copyWith(muted: !enabled);
  }

  void toggleCamera() {
    final video = _localStream?.getVideoTracks() ?? const [];
    if (video.isEmpty) return;
    final enabled = !video.first.enabled;
    for (final t in video) {
      t.enabled = enabled;
    }
    state = state.copyWith(cameraOff: !enabled);
  }

  Future<void> switchCamera() async {
    final video = _localStream?.getVideoTracks() ?? const [];
    if (video.isEmpty) return;
    try {
      await Helper.switchCamera(video.first);
    } catch (_) {
      // 部分平臺/桌面不支持切換，忽略
    }
  }

  void _cleanup() {
    _noAnswerTimer?.cancel();
    _durationTimer?.cancel();
    _pc?.close();
    _pc = null;
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream = null;
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
  }

  @override
  void dispose() {
    _subInvite?.cancel();
    _subAccepted?.cancel();
    _subRejected?.cancel();
    _subOffer?.cancel();
    _subAnswer?.cancel();
    _subIce?.cancel();
    _subHangUp?.cancel();
    _cleanup();
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }
}
