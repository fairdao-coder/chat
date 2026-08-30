namespace AdminServer.Entities;

/// <summary>与 ChatServer 共享 Groups 表（统计用）。</summary>
public class Group
{
    public Guid Id { get; set; }
    public string Name { get; set; } = default!;
    public Guid OwnerId { get; set; }
    public string? AvatarUrl { get; set; }
    public DateTime CreatedAt { get; set; }
}
