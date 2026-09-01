using ChatServer.Data;
using ChatServer.DTOs;
using ChatServer.Entities;
using ChatServer.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

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
            return Conflict("用戶名已存在");

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
            return Unauthorized("用戶名或密碼錯誤");

        user.LastSeenAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return Ok(new AuthResult(_token.CreateToken(user), ToUserDto(user, true)));
    }

    /// <summary>
    /// 當前登錄用戶修改密碼：需提供舊密碼驗證身份，成功後用新密碼覆蓋。
    /// 舊 JWT 仍然有效（無狀態令牌），用戶無需重新登錄。
    /// </summary>
    [HttpPost("change-password")]
    [Authorize]
    public async Task<IActionResult> ChangePassword(ChangePasswordRequest req)
    {
        if (string.IsNullOrWhiteSpace(req.NewPassword) || req.NewPassword.Length < 6)
            return BadRequest("新密碼長度至少 6 位");

        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var user = await _db.Users.FirstOrDefaultAsync(u => u.Id == userId);
        if (user == null)
            return Unauthorized("用戶不存在");

        if (!_hasher.Verify(user.PasswordHash, req.OldPassword))
            return BadRequest("舊密碼錯誤");

        user.PasswordHash = _hasher.HashPassword(req.NewPassword);
        await _db.SaveChangesAsync();
        return Ok();
    }

    private static UserDto ToUserDto(AppUser u, bool online) =>
        new(u.Id, u.UserName, u.NickName, u.AvatarUrl, online, u.LastSeenAt);
}
