/// Conversation ID generation — mirrors server/ChatServer/ConversationKeys.cs.
/// Clients can compute these locally to match incoming SignalR messages.
///
/// Private: p_{guidA}_{guidB}  (two ids sorted ascending, string order)
/// Group:   g_{groupId}
String privateConversationId(String a, String b) {
  final sorted = [a, b]..sort();
  return 'p_${sorted[0]}_${sorted[1]}';
}

String groupConversationId(String groupId) => 'g_$groupId';
