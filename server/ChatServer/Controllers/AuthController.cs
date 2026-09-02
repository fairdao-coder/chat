using Chat.Shared.Entities;
using Chat.Shared.Services;
using ChatServer.Data;
using ChatServer.DTOs;
using ChatServer.Services;
using Chat.Shared.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace ChatServer.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private const int MinPasswordLength = 6;
    private const int MaxPasswordLength = 128;

    private readonly AppDbContext _db;
    private readonly IPasswordHasher _hasher;
    private readonly ITokenService _token;
    private readonly ILogger<AuthController> _logger;

    public AuthController(
        AppDbContext db,
        IPasswordHasher hasher,
        ITokenService token,
        ILogger<AuthController> logger)
    {
        _db = db;
        _hasher = hasher;
        _token = token;
        _logger = logger;
    }

    [HttpPost("register")]
    [AllowAnonymous]
    [EnableRateLimiting(RateLimitPolicies.Auth)]
    public async Task<IActionResult> Register(RegisterRequest req, CancellationToken ct = default)
    {
        if (req == null) return BadRequest("請求體為空");

        var userName = (req.UserName ?? "").Trim();
        if (string.IsNullOrEmpty(userName)) return BadRequest("用戶名不能為空");
        if (!ValidatePassword(req.Password, out var passwordError)) return BadRequest(passwordError);

        if (await _db.Users.AsNoTracking().AnyAsync(u => u.UserName == userName, ct))
            return Conflict("用戶名已存在");

        var user = new AppUser
        {
            UserName = userName,
            NickName = string.IsNullOrWhiteSpace(req.NickName) ? userName : req.NickName.Trim(),
            PasswordHash = _hasher.HashPassword(req.Password)
        };
        _db.Users.Add(user);
        await _db.SaveChangesAsync(ct);

        _logger.LogInformation("新用戶註冊 userId={UserId} userName={UserName}", user.Id, userName);
        return Ok(new AuthResult(_token.CreateToken(user), ToUserDto(user)));
    }

    [HttpPost("login")]
    [AllowAnonymous]
    [EnableRateLimiting(RateLimitPolicies.Auth)]
    public async Task<IActionResult> Login(LoginRequest req, CancellationToken ct = default)
    {
        if (req == null || string.IsNullOrWhiteSpace(req.UserName) || string.IsNullOrEmpty(req.Password))
            return BadRequest("用戶名與密碼不能為空");

        var userName = req.UserName.Trim();
        var user = await _db.Users.FirstOrDefaultAsync(u => u.UserName == userName, ct);

        // 用戶不存在時也走一次同等開銷的散列比對，消除「用戶名是否存在」的時序側信道。
        var passwordOk = user != null
            ? _hasher.Verify(user.PasswordHash, req.Password)
            : _hasher.Verify(DummyHash, req.Password);

        if (user == null || !passwordOk)
        {
            _logger.LogWarning("登錄失敗 userName={UserName}", userName);
            return Unauthorized("用戶名或密碼錯誤");
        }

        user.LastSeenAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        return Ok(new AuthResult(_token.CreateToken(user), ToUserDto(user)));
    }

    /// <summary>
    /// 當前登錄用戶修改密碼：需提供舊密碼驗證身份，成功後用新密碼覆蓋。
    /// 舊 JWT 仍然有效（無狀態令牌），用戶無需重新登錄。
    /// </summary>
    [HttpPost("change-password")]
    [Authorize]
    public async Task<IActionResult> ChangePassword(ChangePasswordRequest req, CancellationToken ct = default)
    {
        if (req == null) return BadRequest("請求體為空");
        if (!ValidatePassword(req.NewPassword, out var passwordError)) return BadRequest(passwordError);

        // 令牌中的 NameIdentifier 由簽名保證，理論上必然為有效 GUID；
        // 仍用 TryParse 兜底，避免異常輸入觸發 500 而非 401。
        if (!TryGetUserId(out var userId)) return Unauthorized("令牌無效，請重新登錄");

        var user = await _db.Users.FirstOrDefaultAsync(u => u.Id == userId, ct);
        if (user == null) return Unauthorized("用戶不存在");

        if (!_hasher.Verify(user.PasswordHash, req.OldPassword))
            return BadRequest("舊密碼錯誤");

        user.PasswordHash = _hasher.HashPassword(req.NewPassword);
        await _db.SaveChangesAsync(ct);

        _logger.LogInformation("用戶修改密碼成功 userId={UserId}", userId);
        return Ok();
    }

    private bool TryGetUserId(out Guid userId)
    {
        userId = Guid.Empty;
        var raw = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return raw != null && Guid.TryParse(raw, out userId);
    }

    private static bool ValidatePassword(string? password, out string error)
    {
        if (string.IsNullOrEmpty(password))
        {
            error = "密碼不能為空";
            return false;
        }
        if (password.Length < MinPasswordLength)
        {
            error = $"密碼長度至少 {MinPasswordLength} 位";
            return false;
        }
        if (password.Length > MaxPasswordLength)
        {
            // PBKDF2 迭代 10 萬次，超長密碼會被用來做 CPU 耗盡型 DoS，必須設上限。
            error = $"密碼長度不能超過 {MaxPasswordLength} 位";
            return false;
        }
        error = "";
        return true;
    }

    /// <summary>用於用戶不存在時做等值開銷比對的常量散列。</summary>
    private static readonly string DummyHash =
        new Chat.Shared.Services.PasswordHasher().HashPassword("dummy-password-for-timing-equalization");

    private static UserDto ToUserDto(AppUser u) =>
        new(u.Id, u.UserName, u.NickName, u.AvatarUrl, true, u.LastSeenAt);
}
