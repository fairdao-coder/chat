using Chat.Shared.Entities;
using ChatServer.Data;
using Microsoft.EntityFrameworkCore;

namespace ChatServer.Services;

public interface IFriendshipService
{
    /// <summary>已建立好友關係的用戶 ID（請求發出或接收方均可）。</summary>
    Task<IReadOnlyList<Guid>> GetFriendIdsAsync(Guid userId, CancellationToken ct = default);

    /// <summary>雙向好友關係判定（任一方發起、對方接受即成立）。</summary>
    Task<bool> AreFriendsAsync(Guid a, Guid b, CancellationToken ct = default);
}

public class FriendshipService : IFriendshipService
{
    private readonly AppDbContext _db;

    public FriendshipService(AppDbContext db) => _db = db;

    public async Task<IReadOnlyList<Guid>> GetFriendIdsAsync(Guid userId, CancellationToken ct = default) =>
        await _db.Friendships
            .AsNoTracking()
            .Where(f => f.Status == FriendshipStatus.Accepted &&
                        (f.RequesterId == userId || f.AddresseeId == userId))
            .Select(f => f.RequesterId == userId ? f.AddresseeId : f.RequesterId)
            .ToListAsync(ct);

    public Task<bool> AreFriendsAsync(Guid a, Guid b, CancellationToken ct = default) =>
        _db.Friendships
            .AsNoTracking()
            .AnyAsync(f => f.Status == FriendshipStatus.Accepted &&
                           ((f.RequesterId == a && f.AddresseeId == b) ||
                            (f.RequesterId == b && f.AddresseeId == a)), ct);
}
