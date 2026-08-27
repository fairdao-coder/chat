using ChatServer.Data;
using ChatServer.DTOs;
using ChatServer.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ChatServer.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class FriendsController : ApiControllerBase
{
    private readonly AppDbContext _db;
    public FriendsController(AppDbContext db) => _db = db;

    [HttpPost("request")]
    public async Task<IActionResult> SendRequest([FromBody] Guid friendId)
    {
        if (friendId == UserId) return BadRequest("不能添加自己为好友");
        if (!await _db.Users.AnyAsync(u => u.Id == friendId)) return NotFound("用户不存在");
        if (await _db.Friendships.AnyAsync(f => f.RequesterId == UserId && f.AddresseeId == friendId))
            return Conflict("请求已存在");
        _db.Friendships.Add(new Friendship
        {
            RequesterId = UserId,
            AddresseeId = friendId,
            Status = FriendshipStatus.Pending
        });
        await _db.SaveChangesAsync();
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
        if (fr == null) return NotFound("请求不存在");
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
