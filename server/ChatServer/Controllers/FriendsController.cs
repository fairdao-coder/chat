using ChatServer.Data;
using ChatServer.DTOs;
using ChatServer.Entities;
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
    public async Task<IActionResult> SendRequest([FromBody] Guid friendId)
    {
        if (friendId == UserId) return BadRequest("不能添加自己為好友");
        if (!await _db.Users.AnyAsync(u => u.Id == friendId)) return NotFound("用戶不存在");
        if (await _db.Friendships.AnyAsync(f => f.RequesterId == UserId && f.AddresseeId == friendId))
            return Conflict("請求已存在");
        var fs = new Friendship
        {
            RequesterId = UserId,
            AddresseeId = friendId,
            Status = FriendshipStatus.Pending
        };
        _db.Friendships.Add(fs);
        await _db.SaveChangesAsync();

        // 实时通知被邀请方，使其无需重启 App 即可在好友请求里看到新邀请。
        var requester = await _db.Users
            .Where(u => u.Id == UserId)
            .Select(u => new FriendRequestDto(fs.Id, u.Id, u.UserName, u.NickName, u.AvatarUrl, fs.CreatedAt))
            .FirstAsync();
        await _hub.Clients.User(friendId.ToString())
            .SendAsync("ReceiveFriendRequest", requester);

        return Ok();
    }

    [HttpGet("requests")]
    public async Task<IActionResult> Requests()
    {
        var list = await _db.Friendships
            .Where(f => f.AddresseeId == UserId && f.Status == FriendshipStatus.Pending)
            .Select(f => new FriendRequestDto(
                f.Id, f.Requester.Id, f.Requester.UserName, f.Requester.NickName, f.Requester.AvatarUrl, f.CreatedAt))
            .ToListAsync();
        return Ok(list);
    }

    [HttpPost("accept")]
    public async Task<IActionResult> Accept([FromBody] Guid friendId)
    {
        var fr = await _db.Friendships.FirstOrDefaultAsync(f =>
            f.AddresseeId == UserId && f.RequesterId == friendId && f.Status == FriendshipStatus.Pending);
        if (fr == null) return NotFound("請求不存在");
        fr.Status = FriendshipStatus.Accepted;
        await _db.SaveChangesAsync();
        return Ok();
    }

    [HttpGet]
    public async Task<IActionResult> List()
    {
        var list = await _db.Friendships
            .Where(f => f.Status == FriendshipStatus.Accepted &&
                        (f.RequesterId == UserId || f.AddresseeId == UserId))
            .Select(f => f.RequesterId == UserId ? f.Addressee : f.Requester)
            .Select(u => new UserDto(u.Id, u.UserName, u.NickName, u.AvatarUrl, false, u.LastSeenAt))
            .ToListAsync();
        return Ok(list);
    }

    [HttpDelete("{friendId}")]
    public async Task<IActionResult> Remove(Guid friendId)
    {
        var fr = await _db.Friendships.FirstOrDefaultAsync(f =>
            (f.RequesterId == UserId && f.AddresseeId == friendId) ||
            (f.AddresseeId == UserId && f.RequesterId == friendId));
        if (fr == null) return NotFound();
        _db.Friendships.Remove(fr);
        await _db.SaveChangesAsync();
        return NoContent();
    }
}
