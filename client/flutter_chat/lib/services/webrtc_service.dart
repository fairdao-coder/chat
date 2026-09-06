import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Thin wrapper around `flutter_webrtc` for 1-to-1 calls.
class WebRtcService {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  final _remoteStream = ValueNotifier<MediaStream?>(null);
  final _connectionState = ValueNotifier<RTCPeerConnectionState?>(null);

  ValueNotifier<MediaStream?> get remoteStream => _remoteStream;
  ValueNotifier<RTCPeerConnectionState?> get connectionState => _connectionState;

  /// Acquires mic (+ camera if [video] is true). On web this triggers
  /// the browser permission prompt; `localhost` is a secure context.
  MediaStream? get localStream => _localStream;

  bool get hasLocalStream {
    if (_localStream == null) return false;
    return _localStream!.getTracks().any((t) => t.enabled);
  }

  Future<MediaStream?> openLocalStream({required bool video}) async {
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': video
            ? {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
              }
            : false,
      });
      _localStream = stream;
      return stream;
    } catch (e, st) {
      developer.log('getUserMedia error', name: 'webrtc', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> closeLocalStream() async {
    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    _localStream = null;
  }

  /// Creates a peer connection using the provided ICE configuration.
  Future<RTCPeerConnection?> createPeerConnection(Map<String, dynamic> config) async {
    try {
      final pc = await createPeerConnection(config);
      if (pc == null) return null;
      _pc = pc;

      pc.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          _remoteStream.value = event.streams[0];
        }
      };

      pc.onConnectionState = (state) {
        _connectionState.value = state;
      };

      // Forward the local stream tracks to the peer connection.
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await pc.addTrack(track, _localStream!);
        }
      }

      return pc;
    } catch (e, st) {
      developer.log('createPeerConnection error', name: 'webrtc', error: e, stackTrace: st);
      return null;
    }
  }

  Future<RTCSessionDescription?> createOffer() async {
    if (_pc == null) return null;
    try {
      final offer = await _pc!.createOffer({});
      await _pc!.setLocalDescription(offer);
      return offer;
    } catch (e, st) {
      developer.log('createOffer error', name: 'webrtc', error: e, stackTrace: st);
      return null;
    }
  }

  Future<RTCSessionDescription?> createAnswer() async {
    if (_pc == null) return null;
    try {
      final answer = await _pc!.createAnswer({});
      await _pc!.setLocalDescription(answer);
      return answer;
    } catch (e, st) {
      developer.log('createAnswer error', name: 'webrtc', error: e, stackTrace: st);
      return null;
    }
  }

  Future<bool> setRemoteDescription(RTCSessionDescription desc) async {
    if (_pc == null) return false;
    try {
      await _pc!.setRemoteDescription(desc);
      return true;
    } catch (e, st) {
      developer.log('setRemoteDescription error', name: 'webrtc', error: e, stackTrace: st);
      return false;
    }
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    if (_pc == null) return;
    try {
      await _pc!.addCandidate(candidate);
    } catch (e, st) {
      developer.log('addIceCandidate error', name: 'webrtc', error: e, stackTrace: st);
    }
  }

  void onIceCandidate(void Function(RTCIceCandidate candidate) handler) {
    _pc?.onIceCandidate = handler;
  }

  Future<void> dispose() async {
    await closeLocalStream();
    _remoteStream.value = null;
    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;
  }
}
