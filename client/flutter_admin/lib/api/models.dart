class AdminUserDto {
  final String id;
  final String userName;
  final String displayName;
  final String roleName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  AdminUserDto.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        userName = j['userName'],
        displayName = j['displayName'],
        roleName = j['roleName'],
        isActive = j['isActive'],
        createdAt = DateTime.parse(j['createdAt']),
        lastLoginAt = j['lastLoginAt'] == null ? null : DateTime.parse(j['lastLoginAt']);
}

class RoleDto {
  final String id;
  final String name;
  final String permissions;
  final String? description;

  RoleDto.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'],
        permissions = j['permissions'] ?? '',
        description = j['description'];

  List<String> get perms =>
      permissions.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}

class AuditLogDto {
  final String id;
  final String adminUserName;
  final String action;
  final String? target;
  final String? detail;
  final DateTime at;
  final String? ip;

  AuditLogDto.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        adminUserName = j['adminUserName'],
        action = j['action'],
        target = j['target'],
        detail = j['detail'],
        at = DateTime.parse(j['at']),
        ip = j['ip'];
}

class DailyCount {
  final DateTime date;
  final int count;
  DailyCount.fromJson(Map<String, dynamic> j)
      : date = DateTime.parse(j['date']),
        count = j['count'];
}

class DashboardStats {
  final int totalUsers;
  final int totalMessages;
  final int totalGroups;
  final int totalFriendships;
  final int bannedUsers;
  final int onlineUsers;
  final int messagesToday;
  final int newUsersToday;
  final int newUsersLast7Days;
  final List<DailyCount> signups;
  final List<DailyCount> messages;

  DashboardStats.fromJson(Map<String, dynamic> j)
      : totalUsers = j['totalUsers'],
        totalMessages = j['totalMessages'],
        totalGroups = j['totalGroups'],
        totalFriendships = j['totalFriendships'],
        bannedUsers = j['bannedUsers'],
        onlineUsers = j['onlineUsers'],
        messagesToday = j['messagesToday'],
        newUsersToday = j['newUsersToday'],
        newUsersLast7Days = j['newUsersLast7Days'],
        signups = (j['signupsLast14Days'] as List).map((e) => DailyCount.fromJson(e)).toList(),
        messages = (j['messagesLast14Days'] as List).map((e) => DailyCount.fromJson(e)).toList();
}

class ChatUserDto {
  final String id;
  final String userName;
  final String nickName;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  final bool isOnline;
  final bool isBanned;
  final String? banReason;

  ChatUserDto.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        userName = j['userName'],
        nickName = j['nickName'],
        avatarUrl = j['avatarUrl'],
        createdAt = DateTime.parse(j['createdAt']),
        lastSeenAt = DateTime.parse(j['lastSeenAt']),
        isOnline = j['isOnline'],
        isBanned = j['isBanned'],
        banReason = j['banReason'];
}

class PagedResult<T> {
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  PagedResult(this.items, this.total, this.page, this.pageSize);

  int get totalPages => (total / pageSize).ceil();
}

class DiscoverColumnDto {
  final String id;
  final String title;
  final String? icon;
  final String? link;
  final int sort;
  final bool enabled;
  final DateTime createdAt;

  DiscoverColumnDto.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        title = j['title'],
        icon = j['icon'],
        link = j['link'],
        sort = j['sort'] ?? 0,
        enabled = j['enabled'] ?? true,
        createdAt = DateTime.parse(j['createdAt']);
}
