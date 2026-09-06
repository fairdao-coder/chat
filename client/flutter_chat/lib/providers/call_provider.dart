import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';

import '../config/constants.dart';
import '../data/signalr_client.dart';
import '../l10n/app_localizations.dart';
import '../models/call_dto.dart';
import '../models/enums.dart';
import '../models/feature_settings.dart';
import '../router.dart';
import '../services/webrtc_service.dart';
import 'auth_provider.dart';
import 'core_providers.dart';
import 'features_provider.dart';

/// Current active call (or incoming/outgoing request).
class ActiveCall {
  final String sessionId;
  final String peerId;
  final String peerName;
  final String? peerAvatar;
  final CallType type;
  final bool isCaller;
  final CallState state;
  final String? error;
  final DateTime? connectedAt;

  const ActiveCall({
    required this.sessionId,
    required this.peerId,
    required this.peerName,
    this.peerAvatar,
    required this.type,
    required this.isCaller,
    this.state = CallState.calling,
    this.error,
    this.connectedAt,
  });

  ActiveCall copyWith({
    String? sessionId,
    String? peerId,
    String? peerName,
    String? peerAvatar,
    CallType? type,
    bool? isCaller,
    CallState? state,
    String? error,
    DateTime? connectedAt,
    bool clearError = false,
  }) =>
      ActiveCall(
        sessionId: sessionId ?? this.sessionId,
        peerId: peerId ?? this.peerId,
        peerName: peerName ?? this.peerName,
        peerAvatar: peerAvatar ?? this.peerAvatar,
        type: type ?? this.type,
        isCaller: isCaller ?? this.isCaller,
        state: state ?? this.state,
        error: clearError ? null : (error ?? this.error),
        connectedAt: connectedAt ?? this.connectedAt,
      );
}

final callProvider = StateNotifierProvider<CallNotifier, ActiveCall?>((ref) {
  return CallNotifier(ref);
});

class CallNotifier extends StateNotifier<ActiveCall?> {
  final Ref _ref;
  final _webrtc = WebRtcService();
  StreamSubscription? _incomingSub;
  StreamSubscription? _acceptedSub;
  StreamSubscription? _endedSub;
  StreamSubscription? _offerSub;
  StreamSubscription? _answerSub;
  StreamSubscription? _iceSub;

  CallNotifier(this._ref) : super(null) {
    _listen();
  }

  ChatHubClient get _hub => _ref.read(hubProvider);
  MediaStream? get localStream => _webrtc.localStream;
  ValueNotifier<MediaStream?> get remoteStream => _webrtc.remoteStream;

  void _listen() {
    _incomingSub = _hub.onIncomingCall.listen(_onIncomingCall);
    _acceptedSub = _hub.onCallAccepted.listen(_onCallAccepted);
    _endedSub = _hub.onCallEnded.listen(_onCallEnded);
    _offerSub = _hub.onReceiveOffer.listen(_onReceiveOffer);
    _answerSub = _hub.onReceiveAnswer.listen(_onReceiveAnswer);
    _iceSub = _hub.onReceiveIceCandidate.listen(_onReceiveIceCandidate);
  }

  /// Caller starts a new call.
  Future<bool> startCall(
    String toUserId, {
    required CallType type,
    required String peerName,
    String? peerAvatar,
  }) async {
    if (state != null) return false;

    try {
      final sessionId = await _hub.callUser(toUserId, callTypeToJson(type));
      if (sessionId == null || sessionId.isEmpty) {
        _showError('呼叫失败');
        return false;
      }

      final ok = await _prepareLocalStream(type);
      if (!ok) {
        await _hub.endCall(sessionId);
        _showError('无法访问麦克风或摄像头');
        return false;
      }

      state = ActiveCall(
        sessionId: sessionId,
        peerId: toUserId,
        peerName: peerName,
        peerAvatar: peerAvatar,
        type: type,
        isCaller: true,
        state: CallState.calling,
      );

      _openCallPage();
      return true;
    } catch (e, st) {
      developer.log('startCall error', name: 'call', error: e, stackTrace: st);
      _showError('呼叫失败');
      return false;
    }
  }

  /// Callee accepts an incoming call.
  Future<bool> acceptCall() async {
    final current = state;
    if (current == null || current.isCaller || current.state != CallState.calling) {
      return false;
    }

    try {
      await _hub.acceptCall(current.sessionId);
      state = current.copyWith(state: CallState.connecting);
      return true;
    } catch (e, st) {
      developer.log('acceptCall error', name: 'call', error: e, stackTrace: st);
      _showError('连接失败');
      return false;
    }
  }

  /// Callee rejects an incoming call.
  Future<void> rejectCall() async {
    final current = state;
    if (current == null || current.isCaller) return;
    try {
      await _hub.rejectCall(current.sessionId);
    } catch (e, st) {
      developer.log('rejectCall error', name: 'call', error: e, stackTrace: st);
    } finally {
      await _cleanup();
    }
  }

  /// Either side hangs up.
  Future<void> endCall() async {
    final current = state;
    if (current == null) return;
    try {
      await _hub.endCall(current.sessionId);
    } catch (e, st) {
      developer.log('endCall error', name: 'call', error: e, stackTrace: st);
    } finally {
      await _cleanup();
    }
  }

  void _onIncomingCall(IncomingCallDto dto) {
    if (state != null) {
      // Already busy: reject silently.
      _hub.rejectCall(dto.sessionId);
      return;
    }
    state = ActiveCall(
      sessionId: dto.sessionId,
      peerId: dto.callerId,
      peerName: dto.callerName,
      peerAvatar: dto.callerAvatar,
      type: dto.type,
      isCaller: false,
      state: CallState.calling,
    );
    _openCallPage();
  }

  Future<void> _onCallAccepted(CallAcceptedDto dto) async {
    final current = state;
    if (current == null || current.sessionId != dto.sessionId.toString()) return;

    if (!_webrtc.hasLocalStream) {
      await _prepareLocalStream(current.type);
    }

    state = current.copyWith(state: CallState.connecting);
    await _createPeerConnection();

    if (current.isCaller) {
      final offer = await _webrtc.createOffer();
      if (offer != null) {
        await _hub.sendOffer(current.sessionId, offer.sdp!);
      }
    }
  }

  Future<void> _onReceiveOffer(CallSdpDto dto) async {
    final current = state;
    if (current == null || current.isCaller) return;
    if (current.sessionId != dto.sessionId.toString()) return;

    final ok = await _webrtc.setRemoteDescription(
        RTCSessionDescription(dto.sdp, 'offer'));
    if (!ok) return;

    final answer = await _webrtc.createAnswer();
    if (answer != null) {
      await _hub.sendAnswer(current.sessionId, answer.sdp!);
      state = current.copyWith(state: CallState.connected, connectedAt: DateTime.now());
    }
  }

  Future<void> _onReceiveAnswer(CallSdpDto dto) async {
    final current = state;
    if (current == null || !current.isCaller) return;
    if (current.sessionId != dto.sessionId.toString()) return;

    final ok = await _webrtc.setRemoteDescription(
        RTCSessionDescription(dto.sdp, 'answer'));
    if (ok) {
      state = current.copyWith(state: CallState.connected, connectedAt: DateTime.now());
    }
  }

  Future<void> _onReceiveIceCandidate(CallIceCandidateDto dto) async {
    final current = state;
    if (current == null || current.sessionId != dto.sessionId.toString()) return;

    try {
      final c = jsonDecode(dto.candidate) as Map<String, dynamic>;
      await _webrtc.addIceCandidate(RTCIceCandidate(
        c['candidate'] as String?,
        c['sdpMid'] as String?,
        c['sdpMLineIndex'] as int?,
      ));
    } catch (e, st) {
      developer.log('ICE parse error', name: 'call', error: e, stackTrace: st);
    }
  }

  Future<void> _onCallEnded(CallEndedDto dto) async {
    final current = state;
    if (current == null || current.sessionId != dto.sessionId.toString()) return;
    _showError(callEndReasonKey(dto.reason));
    await _cleanup();
  }

  Future<bool> _prepareLocalStream(CallType type) async {
    final stream = await _webrtc.openLocalStream(video: type == CallType.video);
    return stream != null;
  }

  Future<void> _createPeerConnection() async {
    final features = _ref.read(featuresProvider);
    final ice = await _iceServers(features);
    final pc = await _webrtc.createPeerConnection(ice);
    if (pc == null) return;

    _webrtc.onIceCandidate((candidate) async {
      final current = state;
      if (current == null) return;
      final payload = jsonEncode({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
      await _hub.sendIceCandidate(current.sessionId, payload);
    });
  }

  Future<Map<String, dynamic>> _iceServers(AsyncValue<FeatureSettings> features) async {
    final defaultServers = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
    };

    final rtConfig = features.valueOrNull?.rtConfig;
    if (rtConfig == null || rtConfig.isEmpty) return defaultServers;

    try {
      final parsed = jsonDecode(rtConfig) as Map<String, dynamic>;
      if (parsed.containsKey('iceServers')) return parsed;
      return {'iceServers': parsed['stun'] ?? defaultServers['iceServers']};
    } catch (_) {
      return defaultServers;
    }
  }

  void _openCallPage() {
    final ctx = _rootContext;
    if (ctx == null || !ctx.mounted) return;
    ctx.push('/call');
  }

  void _showError(String key) {
    final ctx = _rootContext;
    if (ctx == null || !ctx.mounted) return;
    final msg = _safeTranslate(ctx, key);
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _safeTranslate(BuildContext ctx, String key) {
    try {
      return ctx.tr(key);
    } catch (_) {
      return key;
    }
  }

  BuildContext? get _rootContext {
    try {
      return rootNavigatorKey.currentContext;
    } catch (_) {
      return null;
    }
  }

  Future<void> _cleanup() async {
    await _webrtc.dispose();
    if (mounted) state = null;
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _acceptedSub?.cancel();
    _endedSub?.cancel();
    _offerSub?.cancel();
    _answerSub?.cancel();
    _iceSub?.cancel();
    _webrtc.dispose();
    super.dispose();
  }
}
