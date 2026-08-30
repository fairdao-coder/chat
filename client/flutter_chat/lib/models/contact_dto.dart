class ContactDto {
  final String id;
  final String name;
  final String? avatarUrl;
  final bool isOnline;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final bool isGroup;

  const ContactDto({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.isOnline,
    this.lastMessage,
    this.lastMessageAt,
    required this.isGroup,
  });

  factory ContactDto.fromJson(Map<String, dynamic> j) => ContactDto(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        avatarUrl: j['avatarUrl'] as String?,
        isOnline: j['isOnline'] as bool? ?? false,
        lastMessage: j['lastMessage'] as String?,
        lastMessageAt: j['lastMessageAt'] == null
            ? null
            : DateTime.parse(j['lastMessageAt'] as String),
        isGroup: j['isGroup'] as bool? ?? false,
      );
}
