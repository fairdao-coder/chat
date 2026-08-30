using ChatServer.Data;
using ChatServer.DTOs;
using ChatServer.Entities;
using ChatServer.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ChatServer.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class UsersController : ApiControllerBase
{
    private readonly AppDbContext _db;
    private readonly PresenceTracker _presence;

    public UsersController(AppDbContext db, PresenceTracker presence)
    {
        _db = db;
        _presence = presence;
    }

    [HttpGet("search")]
    public async Task<IActionResult> Search([FromQuery] string q = "")
    {
        var list = await _db.Users
            .Where(u => u.Id != UserId && (u.UserName.Contains(q) || u.NickName.Contains(q)))
            .Take(20)
            .Select(u => new UserDto(u.Id, u.UserName, u.NickName, u.AvatarUrl, false, u.LastSeenAt))
            .ToListAsync();
        return Ok(list);
    }

    [HttpGet("me")]
    public async Task<IActionResult> Me()
    {
        var u = await _db.Users.FindAsync(UserId);
        if (u == null) return NotFound();
        return Ok(new UserDto(u.Id, u.UserName, u.NickName, u.AvatarUrl, true, u.LastSeenAt));
    }

    /// <summary>
    /// 當前在線用戶 ID 列表。
    /// SignalR 的 UserOnline / UserOffline 是"盡力而為"的推送（重連窗口期可能丟失），
    /// 客戶端用一個輕量輪詢兜底，保證在線狀態最終一致。
    /// </summary>
    [HttpGet("online")]
    public async Task<IActionResult> Online()
    {
        var friends = await _db.Friendships
            .Where(f => f.Status == FriendshipStatus.Accepted &&
                        (f.RequesterId == UserId || f.AddresseeId == UserId))
            .Select(f => f.RequesterId == UserId ? f.AddresseeId : f.RequesterId)
            .ToListAsync();

        var online = await _presence.GetOnlineUsers(friends.Select(x => x.ToString()));
        return Ok(online);
    }
}
