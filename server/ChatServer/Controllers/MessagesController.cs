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
public class MessagesController : ApiControllerBase
{
    private readonly AppDbContext _db;
    public MessagesController(AppDbContext db) => _db = db;

    [HttpGet("private/{friendId}")]
    public async Task<IActionResult> PrivateHistory(Guid friendId, [FromQuery] DateTime? before = null, [FromQuery] int count = 30)
    {
        var conv = ConversationKeys.Private(UserId, friendId);
        var q = _db.Messages.Where(m => m.ConversationId == conv);
        if (before.HasValue) q = q.Where(m => m.CreatedAt < before.Value);
        var msgs = await q.OrderByDescending(m => m.CreatedAt).Take(count).OrderBy(m => m.CreatedAt).ToListAsync();
        return Ok(await MapAsync(msgs));
    }

    [HttpGet("group/{groupId}")]
    public async Task<IActionResult> GroupHistory(Guid groupId, [FromQuery] DateTime? before = null, [FromQuery] int count = 30)
    {
        var conv = ConversationKeys.Group(groupId);
        var q = _db.Messages.Where(m => m.ConversationId == conv);
        if (before.HasValue) q = q.Where(m => m.CreatedAt < before.Value);
        var msgs = await q.OrderByDescending(m => m.CreatedAt).Take(count).OrderBy(m => m.CreatedAt).ToListAsync();
        return Ok(await MapAsync(msgs));
    }

    private async Task<List<MessageDto>> MapAsync(List<Message> msgs)
    {
        var dtos = new List<MessageDto>();
        foreach (var m in msgs)
        {
            var s = await _db.Users.FindAsync(m.SenderId);
            dtos.Add(new MessageDto(m.Id, m.ConversationId, m.SenderId, s?.NickName ?? "?",
                s?.AvatarUrl, m.ChatType, m.Content, m.Type, m.MediaUrl, m.CreatedAt));
        }
        return dtos;
    }
}
