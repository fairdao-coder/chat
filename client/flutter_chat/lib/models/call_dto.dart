import 'enums.dart';

/// Incoming call pushed by server to callee.
class IncomingCallDto {
  final String sessionId;
  final String callerId;
  final String callerName;
  final String? callerAvatar;
  final CallType type;

  IncomingCallDto({
    required this.sessionId,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
    required this.type,
  });

  factory IncomingCallDto.fromJson(Map<String, dynamic> j) => IncomingCallDto(
        sessionId: (j['sessionId'] ?? j['id'] ?? '').toString(),
        callerId: (j['callerId'] ?? '').toString(),
        callerName: (j['callerName'] ?? '').toString(),
        callerAvatar: j['callerAvatar']?.toString(),
        type: callTypeFromJson(j['type']?.toString()),
      );
}

/// Call accepted notification sent to both peers.
class CallAcceptedDto {
  final String sessionId;
  final String callerId;
  final String calleeId;
  final CallType type;

  CallAcceptedDto({
    required this.sessionId,
    required this.callerId,
    required this.calleeId,
    required this.type,
  });

  factory CallAcceptedDto.fromJson(Map<String, dynamic> j) => CallAcceptedDto(
        sessionId: (j['sessionId'] ?? '').toString(),
        callerId: (j['callerId'] ?? '').toString(),
        calleeId: (j['calleeId'] ?? '').toString(),
        type: callTypeFromJson(j['type']?.toString()),
      );
}

/// Call ended / rejected notification.
class CallEndedDto {
  final String sessionId;
  final CallEndReason reason;

  CallEndedDto({
    required this.sessionId,
    required this.reason,
  });

  factory CallEndedDto.fromJson(Map<String, dynamic> j) => CallEndedDto(
        sessionId: (j['sessionId'] ?? '').toString(),
        reason: callEndReasonFromJson(j['reason']?.toString()),
      );
}

/// WebRTC SDP payload.
class CallSdpDto {
  final String sessionId;
  final String sdp;

  CallSdpDto({required this.sessionId, required this.sdp});

  factory CallSdpDto.fromJson(Map<String, dynamic> j) => CallSdpDto(
        sessionId: (j['sessionId'] ?? '').toString(),
        sdp: (j['sdp'] ?? '').toString(),
      );
}

/// WebRTC ICE candidate payload.
class CallIceCandidateDto {
  final String sessionId;
  final String candidate;

  CallIceCandidateDto({required this.sessionId, required this.candidate});

  factory CallIceCandidateDto.fromJson(Map<String, dynamic> j) =>
      CallIceCandidateDto(
        sessionId: (j['sessionId'] ?? '').toString(),
        candidate: (j['candidate'] ?? '').toString(),
      );
}
