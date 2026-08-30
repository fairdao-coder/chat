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
public class ConversationsController : ApiControllerBase
{
    private readonly AppDbContext _db;
    private readonly PresenceTracker _presence;

    public ConversationsController(AppDbContext db, PresenceTracker presence)
    {
        _db = db;
        _presence = presence;
    }

    [HttpGet]
    public async Task<IActionResult> Recent()
    {
        var result = new List<ContactDto>();

        var friendIds = await _db.Friendships
            .Where(f => f.Status == FriendshipStatus.Accepted &&
                        (f.RequesterId == UserId || f.AddresseeId == UserId))
            .Select(f => f.RequesterId == UserId ? f.AddresseeId : f.RequesterId)
            .ToListAsync();

        foreach (var fid in friendIds)
        {
            var u = await _db.Users.FindAsync(fid);
            if (u == null) continue;
            var conv = ConversationKeys.Private(UserId, fid);
            var last = await _db.Messages
                .Where(m => m.ConversationId == conv)
                .OrderByDescending(m => m.CreatedAt)
                .FirstOrDefaultAsync();
            result.Add(new ContactDto(
                fid, u.NickName, u.AvatarUrl,
                await _presence.IsOnline(fid.ToString()),
                last?.Content, last?.CreatedAt, false, last?.Type));
        }

        var groups = await _db.Groups
            .Where(g => g.Members.Any(m => m.UserId == UserId))
            .Select(g => new { g.Id, g.Name, g.AvatarUrl })
            .ToListAsync();

        foreach (var g in groups)
        {
            var conv = ConversationKeys.Group(g.Id);
            var last = await _db.Messages
                .Where(m => m.ConversationId == conv)
                .OrderByDescending(m => m.CreatedAt)
                .FirstOrDefaultAsync();
            result.Add(new ContactDto(
                g.Id, g.Name, g.AvatarUrl, true,
                last?.Content, last?.CreatedAt, true, last?.Type));
        }

        result = result.OrderByDescending(c => c.LastMessageAt).ToList();
        return Ok(result);
    }
}
