using ChatServer.Data;
using ChatServer.DTOs;
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
    public UsersController(AppDbContext db) => _db = db;

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
}
