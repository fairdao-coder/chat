using ChatServer.DTOs;
using ChatServer.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using ChatServer.Hubs;

namespace ChatServer.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class MessagesController : ApiControllerBase
{
    private readonly IMessageService _messages;
    private readonly IHubContext<ChatHub> _hub;

    public MessagesController(IMessageService messages, IHubContext<ChatHub> hub)
    {
        _messages = messages;
        _hub = hub;
    }

    [HttpGet("private/{friendId}")]
    public async Task<IActionResult> PrivateHistory(
        Guid friendId,
        [FromQuery] DateTime? before = null,
        [FromQuery] int count = 30,
        CancellationToken ct = default)
    {
        var conversationId = ConversationIdForFriend(friendId);
        var msgs = await _messages.GetHistoryAsync(conversationId, before, count, UserId, ct);
        return Ok(msgs);
    }

    [HttpGet("group/{groupId}")]
    public async Task<IActionResult> GroupHistory(
        Guid groupId,
        [FromQuery] DateTime? before = null,
        [FromQuery] int count = 30,
        CancellationToken ct = default)
    {
        var msgs = await _messages.GetHistoryAsync(
            Chat.Shared.ConversationKeys.Group(groupId), before, count, UserId, ct);
        return Ok(msgs);
    }

    /// <summary>
    /// 刪除一條消息（僅自己不再顯示，對方不受影響）。冪等。
    /// </summary>
    [HttpPost("hide/{messageId}")]
    public async Task<IActionResult> Hide(Guid messageId, CancellationToken ct = default)
    {
        try
        {
            await _messages.HideAsync(UserId, messageId, ct);
            return Ok();
        }
        catch (MessageSendException ex)
        {
            return BadRequest(ex.ToWireMessage());
        }
    }

    /// <summary>清空單個會話的聊天記錄（僅自己的視角）。</summary>
    [HttpPost("clear/{conversationId}")]
    public async Task<IActionResult> Clear(string conversationId, CancellationToken ct = default)
    {
        try
        {
            await _messages.ClearConversationAsync(UserId, Uri.UnescapeDataString(conversationId), ct);
            return Ok();
        }
        catch (MessageSendException ex)
        {
            return BadRequest(ex.ToWireMessage());
        }
    }

    /// <summary>清除所有會話的聊天記錄（僅自己的視角）。</summary>
    [HttpPost("clear-all")]
    public async Task<IActionResult> ClearAll(CancellationToken ct = default)
    {
        await _messages.ClearAllAsync(UserId, ct);
        return Ok();
    }

    /// <summary>
    /// 发送一条私聊文本消息（REST 兜底通道，供“接受好友后自动问候”等场景使用，
    /// 无需依赖 SignalR 连接）。校验与 SignalR 通道共用 <see cref="IMessageService"/>，
    /// 保证两条通道行为一致，并实时推送给对方与发送者。
    /// body: { "to": "&lt;userId&gt;", "content": "..." }
    /// </summary>
    [HttpPost("private")]
    public async Task<IActionResult> SendPrivate([FromBody] SendPrivateRequest req, CancellationToken ct = default)
    {
        if (req == null || string.IsNullOrWhiteSpace(req.To))
            return BadRequest("缺少收件人");
        if (string.IsNullOrWhiteSpace(req.Content))
            return BadRequest("消息内容不能为空");

        try
        {
            var dto = await _messages.SendPrivateAsync(
                UserId, req.To, req.Content, Chat.Shared.Entities.MessageType.Text, null, replyToId: null, ct: ct);

            // 與 SignalR 通道保持一致的推送負載：這裡是單條 DTO，Hub 推送的也是單條。
            await _hub.Clients.User(req.To).SendAsync("ReceiveMessage", dto, ct);
            await _hub.Clients.User(UserId.ToString()).SendAsync("ReceiveMessage", dto, ct);
            return Ok(dto);
        }
        catch (MessageSendException ex)
        {
            // 保持與 SignalR 通道一致的錯誤碼前綴，客戶端可復用同一套提示邏輯。
            return BadRequest(ex.ToWireMessage());
        }
    }

    private string ConversationIdForFriend(Guid friendId) =>
        Chat.Shared.ConversationKeys.Private(UserId, friendId);
}
