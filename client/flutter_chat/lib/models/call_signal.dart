/// 來電邀請載荷（服務端 OnIncomingCall 下發）。
class CallInvite {
  final String callId;
  final String callerId;
  final String callerName;
  final String callType; // 'voice' | 'video'

  const CallInvite(this.callId, this.callerId, this.callerName, this.callType);
}
