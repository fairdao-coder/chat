namespace AdminServer.Entities;

/// <summary>與 ChatServer 共享 Friendships 表（統計用，由 AdminServer 負責建表）。</summary>
public class Friendship
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid RequesterId { get; set; }
    public AppUser Requester { get; set; } = default!;
    public Guid AddresseeId { get; set; }
    public AppUser Addressee { get; set; } = default!;
    public FriendshipStatus Status { get; set; } = FriendshipStatus.Pending;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
