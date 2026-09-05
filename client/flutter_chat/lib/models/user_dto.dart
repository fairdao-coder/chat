class UserDto {
  final String id;
  final String userName;
  final String nickName;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime? lastSeenAt;
  /// 是否為客服帳號（可免好友關係直接私聊）。
  final bool isService;

  const UserDto({
    required this.id,
    required this.userName,
    required this.nickName,
    this.avatarUrl,
    this.isOnline = false,
    this.lastSeenAt,
    this.isService = false,
  });

  factory UserDto.fromJson(Map<String, dynamic> j) => UserDto(
        id: j['id'] as String,
        userName: j['userName'] as String,
        nickName: (j['nickName'] as String?) ?? (j['userName'] as String),
        avatarUrl: j['avatarUrl'] as String?,
        isOnline: j['isOnline'] as bool? ?? false,
        lastSeenAt: j['lastSeenAt'] == null
            ? null
            : DateTime.parse(j['lastSeenAt'] as String),
        isService: j['isService'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userName': userName,
        'nickName': nickName,
        'avatarUrl': avatarUrl,
        'isOnline': isOnline,
        'isService': isService,
        'lastSeenAt': lastSeenAt?.toIso8601String(),
      };

  UserDto copyWith({
    String? id,
    String? userName,
    String? nickName,
    String? avatarUrl,
    bool? isOnline,
    DateTime? lastSeenAt,
    bool? isService,
  }) =>
      UserDto(
        id: id ?? this.id,
        userName: userName ?? this.userName,
        nickName: nickName ?? this.nickName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isOnline: isOnline ?? this.isOnline,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        isService: isService ?? this.isService,
      );
}
