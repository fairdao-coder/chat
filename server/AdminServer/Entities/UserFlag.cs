namespace AdminServer.Entities;

/// <summary>
/// 聊天用戶的管理標記（封禁等），以聊天用戶 Id 為主鍵，避免改動 ChatServer 的 Users 表結構。
/// </summary>
public class UserFlag
{
    public Guid UserId { get; set; }
    public bool IsBanned { get; set; }
    public string? BanReason { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public Guid? UpdatedById { get; set; }
}
