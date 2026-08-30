namespace AdminServer.Entities;

/// <summary>與 ChatServer 共享 Groups 表（統計用）。</summary>
public class Group
{
    public Guid Id { get; set; }
    public string Name { get; set; } = default!;
    public Guid OwnerId { get; set; }
    public string? AvatarUrl { get; set; }
    public DateTime CreatedAt { get; set; }
}
