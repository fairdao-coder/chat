namespace Chat.Shared.Entities;

/// <summary>
/// 聊天系統終端用戶。表由 AdminServer 建表，ChatServer 與 AdminServer 共享同一張 Users 表，
/// 因此字段定義必須兩端一致——這正是抽取到共享類庫的原因。
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
