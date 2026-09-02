import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/message_dto.dart';
import 'auth_provider.dart';
import 'core_providers.dart';

/// 一条需要在屏幕顶部闪现的「來自其他會話」的消息通知。
class IncomingMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final ChatType chatType;
  final String preview;
  final DateTime createdAt;

  const IncomingMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.chatType,
    required this.preview,
    required this.createdAt,
  });

  /// 點按後跳轉用的路由參數：群聊用 groupId，私聊用對方（sender）id。
  String get targetId => chatType == ChatType.group ? conversationId.substring(2) : senderId;
  bool get isGroup => chatType == ChatType.group;
}

/// 当前用户正在查看的会话 id。ChatPage 进入时写入、离开时清空；
/// 该会话收到的消息不弹横幅（已在聊天界面内可见）。
final activeConversationProvider = StateProvider<String?>((_) => null);

/// 待显示的通知队列（顶部横幅按此列表渲染）。
final messageNotificationsProvider =
    StateNotifierProvider<MessageNotifications, List<IncomingMessage>>(
        (_) => MessageNotifications());

class MessageNotifications extends StateNotifier<List<IncomingMessage>> {
  MessageNotifications() : super(const []);

  void push(IncomingMessage m) {
    // 同一条消息可能因断线重连被服务端重发，按 id 去重。
    if (state.any((x) => x.id == m.id)) return;
    state = [...state, m];
  }

  void remove(String id) => state = state.where((x) => x.id != id).toList();

  void clear() => state = const [];
}

/// 副作用 provider：订阅 SignalR 的 [ChatHubClient.onMessage]，按规则将「需要提醒」
/// 的消息推入 [messageNotificationsProvider]。在应用入口处 watch 一次即可常驻。
///
/// 过滤规则：
///  - 自己发出的消息不提醒（乐观气泡已在当前会话显示）；
///  - 当前正在查看的会话（[activeConversationProvider]）收到的消息不提醒；
///  - 其余任意会话（含其它私聊、群聊）的消息，在屏幕顶部闪现横幅。
///
/// 与 [friendRequestPushProvider] 同理：本 provider 只为副作用而存在，不产出状态。
/// 回调内仅用 [Ref.read] 取当前值（不在依赖失效窗口调用会触发重建的 ref 函数），
/// 因此可安全读取登录态与会话焦点，规避 Riverpod 生命周期竞态。
final messageNotificationControllerProvider = Provider<void>((ref) {
  final hub = ref.watch(hubProvider);
  final notifications = ref.read(messageNotificationsProvider.notifier);

  final sub = hub.onMessage.listen((MessageDto m) {
    final myId = ref.read(authProvider).user?.id;
    // 自己发的（乐观回显 / 自己其它設備）不提醒。
    if (myId != null && m.senderId == myId) return;

    final active = ref.read(activeConversationProvider);
    // 当前正在聊的会话不提醒（已在界面内可见）。
    if (active != null && m.conversationId == active) return;

    final preview = _previewOf(m);
    notifications.push(IncomingMessage(
      id: m.id,
      conversationId: m.conversationId,
      senderId: m.senderId,
      senderName: m.senderName,
      senderAvatar: m.senderAvatar,
      chatType: m.chatType,
      preview: preview,
      createdAt: m.createdAt,
    ));
  });

  ref.keepAlive();
  ref.onDispose(sub.cancel);
});

/// 把不同類型的消息转成横幅上的一行预览文本。
String _previewOf(MessageDto m) {
  switch (m.type) {
    case MessageType.image:
      return '[图片]';
    case MessageType.voice:
      return '[语音]';
    case MessageType.file:
      return '[文件]';
    default:
      return m.content.isEmpty ? '[消息]' : m.content;
  }
}
