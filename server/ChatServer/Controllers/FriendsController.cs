using Chat.Shared.Entities;
using ChatServer.Data;
using ChatServer.DTOs;
using ChatServer.Hubs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace ChatServer.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class FriendsController : ApiControllerBase
{
    private readonly AppDbContext _db;
    private readonly IHubContext<ChatHub> _hub;

    public FriendsController(AppDbContext db, IHubContext<ChatHub> hub)
    {
        _db = db;
        _hub = hub;
    }

    [HttpPost("request")]
    public async Task<IActionResult> SendRequest([FromBody] Guid friendId, CancellationToken ct = default)
    {
        if (friendId == Guid.Empty) return BadRequest("無效的用戶 ID");
        if (friendId == UserId) return BadRequest("不能添加自己為好友");
        if (!await _db.Users.AsNoTracking().AnyAsync(u => u.Id == friendId, ct)) return NotFound("用戶不存在");

        var exists = await _db.Friendships
            .AsNoTracking()
            .AnyAsync(f => f.RequesterId == UserId && f.AddresseeId == friendId, ct);
        if (exists) return Conflict("請求已存在");

        // 對方此前已向自己發過請求：直接接受，避免出現兩條方向相反的記錄。
        var pending = await _db.Friendships.FirstOrDefaultAsync(
            f => f.RequesterId == friendId && f.AddresseeId == UserId, ct);
        if (pending != null)
        {
            pending.Status = FriendshipStatus.Accepted;
            await _db.SaveChangesAsync(ct);
            return Ok();
        }

        var fs = new Friendship
        {
            RequesterId = UserId,
            AddresseeId = friendId,
            Status = FriendshipStatus.Pending
        };
        _db.Friendships.Add(fs);

        // 實時通知被邀請方，使其無需重啟 App 即可在好友請求裡看到新邀請。
        var requester = await _db.Users
            .AsNoTracking()
            .Where(u => u.Id == UserId)
            .Select(u => new { u.Id, u.UserName, u.NickName, u.AvatarUrl })
            .FirstAsync(ct);

        await _db.SaveChangesAsync(ct);

        await _hub.Clients.User(friendId.ToString()).SendAsync(
            "ReceiveFriendRequest",
            new FriendRequestDto(fs.Id, requester.Id, requester.UserName, requester.NickName,
                requester.AvatarUrl, fs.CreatedAt),
            ct);

        return Ok();
    }

    [HttpGet("requests")]
    public async Task<IActionResult> Requests(CancellationToken ct = default)
    {
        var list = await _db.Friendships
            .AsNoTracking()
            .Where(f => f.AddresseeId == UserId && f.Status == FriendshipStatus.Pending)
            .Select(f => new FriendRequestDto(
                f.Id, f.Requester.Id, f.Requester.UserName, f.Requester.NickName, f.Requester.AvatarUrl, f.CreatedAt))
            .ToListAsync(ct);
        return Ok(list);
    }

    [HttpPost("accept")]
    public async Task<IActionResult> Accept([FromBody] Guid friendId, CancellationToken ct = default)
    {
        var fr = await _db.Friendships.FirstOrDefaultAsync(f =>
            f.AddresseeId == UserId && f.RequesterId == friendId && f.Status == FriendshipStatus.Pending, ct);
        if (fr == null) return NotFound("請求不存在");
        fr.Status = FriendshipStatus.Accepted;
        await _db.SaveChangesAsync(ct);
        return Ok();
    }

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct = default)
    {
        var list = await _db.Friendships
            .AsNoTracking()
            .Where(f => f.Status == FriendshipStatus.Accepted &&
                        (f.RequesterId == UserId || f.AddresseeId == UserId))
            .Select(f => f.RequesterId == UserId ? f.Addressee : f.Requester)
            .Select(u => new UserDto(u.Id, u.UserName, u.NickName, u.AvatarUrl, false, u.LastSeenAt))
            .ToListAsync(ct);
        return Ok(list);
    }

    [HttpDelete("{friendId}")]
    public async Task<IActionResult> Remove(Guid friendId, CancellationToken ct = default)
    {
        var fr = await _db.Friendships.FirstOrDefaultAsync(f =>
            (f.RequesterId == UserId && f.AddresseeId == friendId) ||
            (f.AddresseeId == UserId && f.RequesterId == friendId), ct);
        if (fr == null) return NotFound();
        _db.Friendships.Remove(fr);
        await _db.SaveChangesAsync(ct);
        return NoContent();
    }
}
