import 'enums.dart';

class MessageDto {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final ChatType chatType;
  final String content;
  final MessageType type;
  final String? mediaUrl;
  final DateTime createdAt;

  /// 是否已被發送者撤回：正文不再展示，氣泡顯示「撤回了一條消息」。
  final bool recalled;

  /// 引用（回覆）的原消息 Id；null 表示普通消息。
  final String? replyToId;

  /// 引用原消息的內容摘要（服務端組裝；媒體消息為 [图片] 等佔位，
  /// 原消息已撤回時為 null）。
  final String? replyPreview;

  /// 引用原消息的類型（用於摘要圖標渲染）。
  final MessageType? replyType;

  /// 引用原消息發送者的暱稱。
  final String? replySenderName;

  const MessageDto({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.chatType,
    required this.content,
    required this.type,
    this.mediaUrl,
    required this.createdAt,
    this.recalled = false,
    this.replyToId,
    this.replyPreview,
    this.replyType,
    this.replySenderName,
  });

  factory MessageDto.fromJson(Map<String, dynamic> j) => MessageDto(
        id: j['id'] as String,
        conversationId: j['conversationId'] as String,
        senderId: j['senderId'] as String,
        senderName: (j['senderName'] as String?) ?? '?',
        senderAvatar: j['senderAvatar'] as String?,
        chatType: chatTypeFromJson(j['chatType'] as String?),
        content: (j['content'] as String?) ?? '',
        type: messageTypeFromJson(j['type'] as String?),
        mediaUrl: j['mediaUrl'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        recalled: (j['recalled'] as bool?) ?? false,
        replyToId: j['replyToId'] as String?,
        replyPreview: j['replyPreview'] as String?,
        replyType: j['replyType'] == null
            ? null
            : messageTypeFromJson(j['replyType'] as String),
        replySenderName: j['replySenderName'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'senderId': senderId,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'chatType': chatTypeToJson(chatType),
        'content': content,
        'type': messageTypeToJson(type),
        'mediaUrl': mediaUrl,
        'createdAt': createdAt.toIso8601String(),
        'recalled': recalled,
        'replyToId': replyToId,
        'replyPreview': replyPreview,
        'replyType': replyType == null ? null : messageTypeToJson(replyType!),
        'replySenderName': replySenderName,
      };

  /// 複製並替換部分字段（撤回事件用：標記 recalled 並清空正文）。
  MessageDto copyWith({
    bool? recalled,
    String? Function()? replyPreview,
  }) =>
      MessageDto(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        chatType: chatType,
        content: content,
        type: type,
        mediaUrl: mediaUrl,
        createdAt: createdAt,
        recalled: recalled ?? this.recalled,
        replyToId: replyToId,
        replyPreview:
            replyPreview != null ? replyPreview() : this.replyPreview,
        replyType: replyType,
        replySenderName: replySenderName,
      );
}
