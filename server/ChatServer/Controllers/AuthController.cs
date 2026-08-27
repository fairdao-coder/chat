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
public class AuthController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly IPasswordHasher _hasher;
    private readonly ITokenService _token;

    public AuthController(AppDbContext db, IPasswordHasher hasher, ITokenService token)
    {
        _db = db;
        _hasher = hasher;
        _token = token;
    }

    [HttpPost("register")]
    [AllowAnonymous]
    public async Task<IActionResult> Register(RegisterRequest req)
    {
        if (await _db.Users.AnyAsync(u => u.UserName == req.UserName))
            return Conflict("用户名已存在");

        var user = new AppUser
        {
            UserName = req.UserName,
            NickName = req.NickName ?? req.UserName,
            PasswordHash = _hasher.HashPassword(req.Password)
        };
        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        return Ok(new AuthResult(_token.CreateToken(user), ToUserDto(user, true)));
    }

    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<IActionResult> Login(LoginRequest req)
    {
        var user = await _db.Users.FirstOrDefaultAsync(u => u.UserName == req.UserName);
        if (user == null || !_hasher.Verify(user.PasswordHash, req.Password))
            return Unauthorized("用户名或密码错误");

        user.LastSeenAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return Ok(new AuthResult(_token.CreateToken(user), ToUserDto(user, true)));
    }

    private static UserDto ToUserDto(AppUser u, bool online) =>
        new(u.Id, u.UserName, u.NickName, u.AvatarUrl, online, u.LastSeenAt);
}
