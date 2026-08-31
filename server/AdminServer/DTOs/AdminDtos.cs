using AdminServer.Entities;

namespace AdminServer.DTOs;

public record AdminLoginRequest(string UserName, string Password);
public record AdminLoginResult(string Token, AdminUserDto Admin, string[] Permissions);
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

public record CreateRoleRequest(string Name, string Permissions, string? Description);
public record UpdateRoleRequest(string Name, string Permissions, string? Description);

public record CreateAdminRequest(string UserName, string DisplayName, string Password, Guid RoleId);

public record DiscoverColumnDto(
    Guid Id, string Title, string? Icon, string? Link, int Sort, bool Enabled, DateTime CreatedAt);

public record UpsertDiscoverColumnRequest(string Title, string? Icon, string? Link, int Sort, bool Enabled);
