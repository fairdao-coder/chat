using Chat.Shared.Entities;
using ChatServer.Data;
using ChatServer.DTOs;
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
    private readonly IFriendshipService _friendships;

    public UsersController(AppDbContext db, PresenceTracker presence, IFriendshipService friendships)
    {
        _db = db;
        _presence = presence;
        _friendships = friendships;
    }

    [HttpGet("search")]
    public async Task<IActionResult> Search([FromQuery] string q = "", CancellationToken ct = default)
    {
        // 空關鍵字在舊實現下等價於「返回任意 20 個用戶」，構成用戶枚舉入口，這裡直接拒絕。
        if (string.IsNullOrWhiteSpace(q))
            return BadRequest("請輸入搜索關鍵字");

        var keyword = q.Trim();
        var list = await _db.Users
            .AsNoTracking()
            .Where(u => u.Id != UserId && (u.UserName.Contains(keyword) || u.NickName.Contains(keyword)))
            .Take(20)
            .Select(u => new UserDto(u.Id, u.UserName, u.NickName, u.AvatarUrl, false, u.LastSeenAt))
            .ToListAsync(ct);
        return Ok(list);
    }

    [HttpGet("me")]
    public async Task<IActionResult> Me(CancellationToken ct = default)
    {
        var u = await _db.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == UserId, ct);
        if (u == null) return NotFound();
        return Ok(new UserDto(u.Id, u.UserName, u.NickName, u.AvatarUrl, true, u.LastSeenAt));
    }

    /// <summary>
    /// 當前用戶的「個人名片」：用於「我的二維碼」與「掃碼添加好友」。
    /// 客戶端將 <see cref="Card"/> 編碼為二維碼；他人掃描後解析出 Id 再發起好友請求。
    /// </summary>
    [HttpGet("me/card")]
    public async Task<IActionResult> MyCard(CancellationToken ct = default)
    {
        var u = await _db.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == UserId, ct);
        if (u == null) return NotFound();
        // 協議格式：fairchat://user/<Id>；掃碼端以此前綴識別「添加好友」類型碼。
        var card = $"fairchat://user/{u.Id}";
        return Ok(new
        {
            card,
            user = new UserDto(u.Id, u.UserName, u.NickName, u.AvatarUrl, true, u.LastSeenAt),
        });
    }

    /// <summary>
    /// 當前在線好友 ID 列表。
    /// SignalR 的 UserOnline / UserOffline 是"盡力而為"的推送（重連窗口期可能丟失），
    /// 客戶端用一個輕量輪詢兜底，保證在線狀態最終一致。
    /// </summary>
    [HttpGet("online")]
    public async Task<IActionResult> Online(CancellationToken ct = default)
    {
        var friendIds = await _friendships.GetFriendIdsAsync(UserId, ct);
        if (friendIds.Count == 0) return Ok(Array.Empty<string>());

        var online = await _presence.GetOnlineUsers(friendIds.Select(x => x.ToString()));
        return Ok(online);
    }
}
