using AdminServer.Entities;
using Chat.Shared.Entities;

namespace AdminServer.DTOs;

public record AdminLoginRequest(string UserName, string Password);
public record AdminLoginResult(string Token, AdminUserDto Admin, string[] Permissions);

/// <summary>管理員自助修改密碼請求。</summary>
public record AdminChangePasswordRequest(string OldPassword, string NewPassword);
public record AdminUserDto(
    Guid Id, string UserName, string DisplayName, string RoleName,
    bool IsActive, DateTime CreatedAt, DateTime? LastLoginAt);

public record RoleDto(Guid Id, string Name, string Permissions, string? Description);

public record AuditLogDto(
    Guid Id, string AdminUserName, string Action, string? Target,
    string? Detail, DateTime At, string? Ip);

public record DashboardStats(
    int TotalUsers, int TotalMessages, int TotalGroups, int TotalFriendships,
    int BannedUsers, int OnlineUsers,
    int MessagesToday, int NewUsersToday, int NewUsersLast7Days,
    List<DailyCount> SignupsLast14Days, List<DailyCount> MessagesLast14Days);

public record DailyCount(DateTime Date, int Count);

public record ChatUserDto(
    Guid Id, string UserName, string NickName, string? AvatarUrl,
    DateTime CreatedAt, DateTime LastSeenAt, bool IsOnline, bool IsBanned, string? BanReason);

public record PagedResult<T>(List<T> Items, int Total, int Page, int PageSize);

public record UpdateUserRequest(string? NickName, string? AvatarUrl);
public record BanUserRequest(bool Banned, string? Reason);

/// <summary>後臺創建客服帳號請求。客服帳號為普通聊天用戶，僅當其 Id 出現在 ServiceAgents 表時才被視為客服。</summary>
public record CreateServiceAccountRequest(
    string UserName, string NickName, string Password, string? AvatarUrl = null);

/// <summary>客服帳號列表項。</summary>
public record ServiceAccountDto(
    Guid Id, string UserName, string NickName, string? AvatarUrl,
    bool IsOnline, DateTime LastSeenAt, bool IsBanned);

public record CreateRoleRequest(string Name, string Permissions, string? Description);
public record UpdateRoleRequest(string Name, string Permissions, string? Description);

public record CreateAdminRequest(string UserName, string DisplayName, string Password, Guid RoleId);

public record DiscoverColumnDto(
    Guid Id, string Title, string? Icon, string Kind, string? Content,
    int Sort, bool Enabled, bool Pinned, DateTime CreatedAt, string? TitleI18n = null);

public record UpsertDiscoverColumnRequest(
    string Title, string? Icon = null, string Kind = "link", string? Content = null,
    int Sort = 0, bool Enabled = true, bool Pinned = false, string? TitleI18n = null);

// ---- 系統功能開關 ----

/// <summary>
/// 全系統功能開關（單例）。客戶端據此控制功能可用性。
/// ChatConfig / OtherConfig 為分類存儲的 JSON 字符串。
/// </summary>
public record SystemSettingsDto(
    string ChatConfig,
    string? OtherConfig,
    string? RtConfig,
    DateTime UpdatedAt);

public record UpdateSystemSettingsRequest(
    string ChatConfig,
    string? OtherConfig,
    string? RtConfig);
