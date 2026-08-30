namespace AdminServer.Entities;

/// <summary>與 ChatServer 共享 Friendships 表（統計用）。</summary>
public class Friendship
{
    public Guid Id { get; set; }
    public Guid RequesterId { get; set; }
    public Guid AddresseeId { get; set; }
    public FriendshipStatus Status { get; set; }
    public DateTime CreatedAt { get; set; }
}
