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
public class MessagesController : ApiControllerBase
{
    private readonly AppDbContext _db;
    private readonly IHubContext<ChatHub> _hub;
    public MessagesController(AppDbContext db, IHubContext<ChatHub> hub)
    {
        _db = db;
        _hub = hub;
    }

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

    /// <summary>
    /// 发送一条私聊文本消息（REST 兜底通道，供“接受好友后自动问候”等场景使用，
    /// 无需依赖 SignalR 连接）。会校验双方为好友，并实时推送给对方与发送者。
    /// body: { "to": "<userId>", "content": "..." }
    /// </summary>
    [HttpPost("private")]
    public async Task<IActionResult> SendPrivate([FromBody] SendPrivateRequest req)
    {
        if (string.IsNullOrWhiteSpace(req.Content))
            return BadRequest("消息内容不能为空");

        var toId = Guid.Parse(req.To);
        var areFriends = await _db.Friendships.AnyAsync(f =>
            f.Status == FriendshipStatus.Accepted &&
            ((f.RequesterId == UserId && f.AddresseeId == toId) ||
             (f.RequesterId == toId && f.AddresseeId == UserId)));
        if (!areFriends)
            return BadRequest("E_FRIEND_REQUIRED: 你们还不是好友，无法发送消息");

        var msg = new Message
        {
            ConversationId = ConversationKeys.Private(UserId, toId),
            SenderId = UserId,
            ChatType = ChatType.Private,
            Content = req.Content,
            Type = MessageType.Text,
        };
        _db.Messages.Add(msg);
        await _db.SaveChangesAsync();

        var dto = await MapAsync(new List<Message> { msg });
        await _hub.Clients.User(req.To).SendAsync("ReceiveMessage", dto);
        await _hub.Clients.User(UserId.ToString()).SendAsync("ReceiveMessage", dto);
        return Ok(dto);
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
