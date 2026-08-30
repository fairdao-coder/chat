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
      };
}
