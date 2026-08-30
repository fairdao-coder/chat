namespace AdminServer.Entities;

/// <summary>与 ChatServer 共享 Friendships 表（统计用）。</summary>
public class Friendship
{
    public Guid Id { get; set; }
    public Guid RequesterId { get; set; }
    public Guid AddresseeId { get; set; }
    public FriendshipStatus Status { get; set; }
    public DateTime CreatedAt { get; set; }
}
