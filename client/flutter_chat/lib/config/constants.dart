/// Server-side HubException error-code prefixes surfaced by ChatServer.
/// The hub only ever throws HubException with one of these prefixes, so the
/// client can bucket them into friendly, action-oriented dialogs.
class ErrorCodes {
  /// Not friends yet — show an "add friend" action.
  static const String friendRequired = 'E_FRIEND_REQUIRED';

  /// Target user/group does not exist.
  static const String targetNotFound = 'E_TARGET_NOT_FOUND';

  /// Malformed id (guid parse failed).
  static const String badTarget = 'E_BAD_TARGET';

  /// Empty message.
  static const String empty = 'E_EMPTY';

  /// Unexpected server/db/network failure.
  static const String server = 'E_SERVER';
}

/// SignalR hub method and event names (kept in sync with ChatHub.cs).
class HubMethods {
  static const String sendPrivateMessage = 'SendPrivateMessage';
  static const String sendGroupMessage = 'SendGroupMessage';
  static const String joinGroup = 'JoinGroup';
  static const String leaveGroup = 'LeaveGroup';
  // 正在輸入狀態
  static const String sendTyping = 'SendTyping';
  // 消息撤回
  static const String recallMessage = 'RecallMessage';
  // 通话信令
  static const String callUser = 'CallUser';
  static const String acceptCall = 'AcceptCall';
  static const String rejectCall = 'RejectCall';
  static const String endCall = 'EndCall';
  static const String sendOffer = 'SendOffer';
  static const String sendAnswer = 'SendAnswer';
  static const String sendIceCandidate = 'SendIceCandidate';
}

class HubEvents {
  static const String receiveMessage = 'ReceiveMessage';
  static const String userOnline = 'UserOnline';
  static const String userOffline = 'UserOffline';
  static const String receiveFriendRequest = 'ReceiveFriendRequest';
  // 正在輸入狀態
  static const String typing = 'OnTyping';
  // 消息撤回（推送已撤回的完整 MessageDto）
  static const String messageRecalled = 'MessageRecalled';
  // 通话事件
  static const String incomingCall = 'IncomingCall';
  static const String callAccepted = 'CallAccepted';
  static const String callEnded = 'CallEnded';
  static const String receiveOffer = 'ReceiveOffer';
  static const String receiveAnswer = 'ReceiveAnswer';
  static const String receiveIceCandidate = 'ReceiveIceCandidate';
}

/// Strip the "E_XXX: " prefix from a HubException message, returning the
/// user-facing text plus the detected code (or null if it's a plain message).
(String? code, String message) parseHubError(String raw) {
  final idx = raw.indexOf(':');
  if (idx > 0) {
    final maybeCode = raw.substring(0, idx).trim();
    if (maybeCode.startsWith('E_')) {
      return (maybeCode, raw.substring(idx + 1).trim());
    }
  }
  return (null, raw);
}
