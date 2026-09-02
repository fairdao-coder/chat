using ChatServer.DTOs;
using ChatServer.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ChatServer.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ConversationsController : ApiControllerBase
{
    private readonly IConversationService _conversations;

    public ConversationsController(IConversationService conversations) => _conversations = conversations;

    [HttpGet]
    public async Task<IActionResult> Recent(CancellationToken ct)
    {
        var result = await _conversations.GetRecentAsync(UserId, ct);
        return Ok(result);
    }
}
