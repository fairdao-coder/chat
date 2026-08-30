namespace AdminServer.Entities;

/// <summary>
/// 聊天用户的管理标记（封禁等），以聊天用户 Id 为主键，避免改动 ChatServer 的 Users 表结构。
/// </summary>
public class UserFlag
{
    public Guid UserId { get; set; }
    public bool IsBanned { get; set; }
    public string? BanReason { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public Guid? UpdatedById { get; set; }
}
