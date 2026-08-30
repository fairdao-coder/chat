class GroupDto {
  final String id;
  final String name;
  final String? avatarUrl;
  final int memberCount;
  final DateTime createdAt;

  const GroupDto({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.memberCount,
    required this.createdAt,
  });

  factory GroupDto.fromJson(Map<String, dynamic> j) => GroupDto(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        avatarUrl: j['avatarUrl'] as String?,
        memberCount: (j['memberCount'] as int?) ?? 0,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarUrl': avatarUrl,
        'memberCount': memberCount,
        'createdAt': createdAt.toIso8601String(),
      };
}
