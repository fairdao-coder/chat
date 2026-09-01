namespace AdminServer.Entities;

/// <summary>
/// 與 ChatServer 共享聊天庫中的 Users 表。表結構由 AdminServer 負責建表，
/// 欄位必須與 ChatServer.AppUser 完全一致。
/// </summary>
public class AppUser
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string UserName { get; set; } = default!;
    public string NickName { get; set; } = default!;
    public string PasswordHash { get; set; } = default!;
    public string? AvatarUrl { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime LastSeenAt { get; set; } = DateTime.UtcNow;
}
