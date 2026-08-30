class FriendRequestDto {
  final String id;
  final String userId;
  final String userName;
  final String nickName;
  final String? avatarUrl;
  final DateTime createdAt;

  const FriendRequestDto({
    required this.id,
    required this.userId,
    required this.userName,
    required this.nickName,
    this.avatarUrl,
    required this.createdAt,
  });

  factory FriendRequestDto.fromJson(Map<String, dynamic> j) => FriendRequestDto(
        id: j['id'] as String,
        userId: j['userId'] as String,
        userName: (j['userName'] as String?) ?? '',
        nickName: (j['nickName'] as String?) ?? '',
        avatarUrl: j['avatarUrl'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
