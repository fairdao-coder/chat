/// 来电邀请载荷（服务端 OnIncomingCall 下发）。
class CallInvite {
  final String callId;
  final String callerId;
  final String callerName;
  final String callType; // 'voice' | 'video'

  const CallInvite(this.callId, this.callerId, this.callerName, this.callType);
}
