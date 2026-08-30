namespace AdminServer.Entities;

/// <summary>
/// 与 ChatServer 共享聊天库中的 Users 表（只读/轻量管理用）。
/// 表名、列名必须与 ChatServer.AppUser 完全一致，避免 EnsureCreated 误建新表。
/// </summary>
public class AppUser
{
    public Guid Id { get; set; }
    public string UserName { get; set; } = default!;
    public string NickName { get; set; } = default!;
    public string? AvatarUrl { get; set; }
    public string? PasswordHash { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime LastSeenAt { get; set; }
}
