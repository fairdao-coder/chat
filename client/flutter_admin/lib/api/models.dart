import 'dart:convert';

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

class ServiceAccountDto {
  final String id;
  final String userName;
  final String nickName;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime lastSeenAt;
  final bool isBanned;

  ServiceAccountDto.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        userName = j['userName'],
        nickName = j['nickName'],
        avatarUrl = j['avatarUrl'],
        isOnline = j['isOnline'] ?? false,
        lastSeenAt = DateTime.parse(j['lastSeenAt']),
        isBanned = j['isBanned'] ?? false;
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

/// 系統功能開關（單例配置）。
///
/// 採分類存儲：聊天相關開關放進 [chatConfig]（JSON 字符串），
/// 其他雜項（如默認打開欄目）放進 [otherConfig]（JSON 字符串）。
/// 為兼容界面層，提供強類型的讀寫便捷方法，自動在 JSON 與對象間轉換。
class SystemSettingsDto {
  /// 聊天功能開關 JSON：
  /// {"ShowOnlineStatus":true,"EnableVoiceCall":true,"EnableVideoCall":true,"AllowFile":true,"AllowVoice":true}
  String chatConfig;

  /// 其他配置 JSON：{"DefaultColumnId":"xxx"}；null 表示無。
  String? otherConfig;

  final DateTime? updatedAt;

  SystemSettingsDto({
    required this.chatConfig,
    this.otherConfig,
    this.updatedAt,
  });

  /// 從聊天配置 JSON 解析出強類型開關。
  Map<String, dynamic> get _chat => Map<String, dynamic>.from(
      (jsonDecode(chatConfig) as Map<dynamic, dynamic>?) ?? {});

  bool _chatBool(String key) => _chat[key] as bool? ?? true;

  set _showOnlineStatus(bool v) => _setChat('ShowOnlineStatus', v);
  set _enableVoiceCall(bool v) => _setChat('EnableVoiceCall', v);
  set _enableVideoCall(bool v) => _setChat('EnableVideoCall', v);
  set _allowFile(bool v) => _setChat('AllowFile', v);
  set _allowVoice(bool v) => _setChat('AllowVoice', v);
  set _allowRegister(bool v) => _setChat('AllowRegister', v);

  void _setChat(String key, bool v) {
    final m = _chat;
    m[key] = v;
    chatConfig = jsonEncode(m);
  }

  bool get showOnlineStatus => _chatBool('ShowOnlineStatus');
  bool get enableVoiceCall => _chatBool('EnableVoiceCall');
  bool get enableVideoCall => _chatBool('EnableVideoCall');
  bool get allowFile => _chatBool('AllowFile');
  bool get allowVoice => _chatBool('AllowVoice');
  bool get allowRegister => _chatBool('AllowRegister');

  /// 默認打開的欄目（底部固定 Tab）Id；null 表示未配置。
  String? get defaultColumnId {
    if (otherConfig == null) return null;
    final m = jsonDecode(otherConfig!) as Map<dynamic, dynamic>?;
    return m?['DefaultColumnId'] as String?;
  }

  set defaultColumnId(String? v) {
    final m = <String, dynamic>{};
    if (otherConfig != null) {
      final existing = jsonDecode(otherConfig!) as Map<dynamic, dynamic>?;
      if (existing != null) m.addAll(existing.map((k, val) => MapEntry(k, val)));
    }
    if (v == null) {
      m.remove('DefaultColumnId');
    } else {
      m['DefaultColumnId'] = v;
    }
    otherConfig = m.isEmpty ? null : jsonEncode(m);
  }

  factory SystemSettingsDto.fromJson(Map<String, dynamic> j) =>
      SystemSettingsDto(
        chatConfig: j['chatConfig'] as String? ?? '{}',
        otherConfig: j['otherConfig'] as String?,
        updatedAt:
            j['updatedAt'] == null ? null : DateTime.tryParse(j['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
        'chatConfig': chatConfig,
        'otherConfig': otherConfig,
      };

  SystemSettingsDto copyWith({
    bool? showOnlineStatus,
    bool? enableVoiceCall,
    bool? enableVideoCall,
    bool? allowFile,
    bool? allowVoice,
    bool? allowRegister,
    String? chatConfig,
    String? otherConfig,
    DateTime? updatedAt,
  }) {
    final s = SystemSettingsDto(
      chatConfig: chatConfig ?? this.chatConfig,
      otherConfig: otherConfig ?? this.otherConfig,
      updatedAt: updatedAt ?? this.updatedAt,
    );
    if (showOnlineStatus != null) s._showOnlineStatus = showOnlineStatus;
    if (enableVoiceCall != null) s._enableVoiceCall = enableVoiceCall;
    if (enableVideoCall != null) s._enableVideoCall = enableVideoCall;
    if (allowFile != null) s._allowFile = allowFile;
    if (allowVoice != null) s._allowVoice = allowVoice;
    if (allowRegister != null) s._allowRegister = allowRegister;
    return s;
  }
}

class DiscoverColumnDto {
  final String id;
  /// 默認 / 回退標題。
  final String title;
  /// 多語言譯文 JSON 字符串：{"zh-TW":"遊戲中心","en":"Games"}；null 表示未配置。
  /// 後端字段為 string，故這裡保持原始 JSON 字符串（而非已解碼的 Map）。
  final String? titleI18n;
  final String? icon;
  final String kind;
  final String? content;
  final int sort;
  final bool enabled;
  final bool pinned;
  final DateTime createdAt;

  DiscoverColumnDto({
    required this.id,
    required this.title,
    this.titleI18n,
    this.icon,
    required this.kind,
    this.content,
    required this.sort,
    required this.enabled,
    this.pinned = false,
    required this.createdAt,
  });

  /// 譯文 Map（解析失敗返回空 Map，界面回退到 [title]）。
  Map<String, String> get i18nMap {
    if (titleI18n == null || titleI18n!.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(titleI18n!) as Map<dynamic, dynamic>?;
      if (decoded == null) return {};
      return decoded.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    } catch (_) {
      return {};
    }
  }

  DiscoverColumnDto.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        title = j['title'],
        titleI18n = j['titleI18n'] as String?,
        icon = j['icon'],
        kind = j['kind'] ?? 'link',
        content = j['content'],
        sort = j['sort'] ?? 0,
        enabled = j['enabled'] ?? true,
        pinned = j['pinned'] ?? false,
        createdAt = DateTime.parse(j['createdAt']);

  DiscoverColumnDto copyWith({
    String? id,
    String? title,
    String? titleI18n,
    String? icon,
    String? kind,
    String? content,
    int? sort,
    bool? enabled,
    bool? pinned,
    DateTime? createdAt,
  }) =>
      DiscoverColumnDto(
        id: id ?? this.id,
        title: title ?? this.title,
        titleI18n: titleI18n ?? this.titleI18n,
        icon: icon ?? this.icon,
        kind: kind ?? this.kind,
        content: content ?? this.content,
        sort: sort ?? this.sort,
        enabled: enabled ?? this.enabled,
        pinned: pinned ?? this.pinned,
        createdAt: createdAt ?? this.createdAt,
      );
}
