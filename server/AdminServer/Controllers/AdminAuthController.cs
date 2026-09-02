using AdminServer.Data;
using AdminServer.DTOs;
using AdminServer.Entities;
using AdminServer.Services;
using Chat.Shared.Security;
using Chat.Shared.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace AdminServer.Controllers;

[ApiController]
[Route("api/admin/auth")]
public class AdminAuthController : ControllerBase
{
    private const int MinPasswordLength = 6;
    private const int MaxPasswordLength = 128;

    private readonly AdminDbContext _db;
    private readonly IPasswordHasher _hasher;
    private readonly IAdminTokenService _token;
    private readonly IAuditService _audit;
    private readonly ILogger<AdminAuthController> _logger;

    public AdminAuthController(
        AdminDbContext db,
        IPasswordHasher hasher,
        IAdminTokenService token,
        IAuditService audit,
        ILogger<AdminAuthController> logger)
    {
        _db = db;
        _hasher = hasher;
        _token = token;
        _audit = audit;
        _logger = logger;
    }

    [HttpPost("login")]
    [AllowAnonymous]
    [EnableRateLimiting(RateLimitPolicies.Auth)]
    public async Task<IActionResult> Login(AdminLoginRequest req, CancellationToken ct = default)
    {
        if (req == null || string.IsNullOrWhiteSpace(req.UserName) || string.IsNullOrEmpty(req.Password))
            return BadRequest("用戶名與密碼不能為空");

        var userName = req.UserName.Trim();
        var admin = await _db.AdminUsers
            .Include(a => a.Role)
            .FirstOrDefaultAsync(a => a.UserName == userName, ct);

        // 賬號不存在時也走一次同等開銷的散列比對，消除「賬號是否存在」的時序側信道。
        var passwordOk = admin != null
            ? _hasher.Verify(admin.PasswordHash, req.Password)
            : _hasher.Verify(DummyHash, req.Password);

        if (admin is null || !admin.IsActive || !passwordOk)
        {
            _logger.LogWarning("後臺登錄失敗 userName={UserName}", userName);
            return Unauthorized("用戶名或密碼錯誤");
        }

        admin.LastLoginAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        var perms = ParsePerms(admin.Role?.Permissions);
        var token = _token.CreateToken(admin, admin.Role?.Name ?? "None", perms);
        await _audit.LogAsync("auth.login", target: admin.UserName);

        return Ok(new AdminLoginResult(token, ToDto(admin), perms));
    }

    [HttpGet("me")]
    [Authorize]
    public async Task<IActionResult> Me(CancellationToken ct = default)
    {
        if (!TryGetAdminId(out var id)) return Unauthorized("令牌無效，請重新登錄");

        var admin = await _db.AdminUsers
            .AsNoTracking()
            .Include(a => a.Role)
            .FirstOrDefaultAsync(a => a.Id == id, ct);
        if (admin is null) return Unauthorized();

        var perms = ParsePerms(admin.Role?.Permissions);
        return Ok(new AdminLoginResult("", ToDto(admin), perms));
    }

    /// <summary>
    /// 當前登錄管理員自助修改密碼：需舊密碼驗證，成功後記錄審計日誌。
    /// 不要求特定權限點——任何管理員都可以修改自己的密碼。
    /// </summary>
    [HttpPost("change-password")]
    [Authorize]
    [EnableRateLimiting(RateLimitPolicies.Auth)]
    public async Task<IActionResult> ChangePassword(AdminChangePasswordRequest req, CancellationToken ct = default)
    {
        if (req == null) return BadRequest("請求體為空");
        if (!ValidatePassword(req.NewPassword, out var error)) return BadRequest(error);
        if (!TryGetAdminId(out var id)) return Unauthorized("令牌無效，請重新登錄");

        var admin = await _db.AdminUsers.FirstOrDefaultAsync(a => a.Id == id, ct);
        if (admin is null) return Unauthorized();

        if (!_hasher.Verify(admin.PasswordHash, req.OldPassword))
            return BadRequest("舊密碼錯誤");

        admin.PasswordHash = _hasher.HashPassword(req.NewPassword);
        await _db.SaveChangesAsync(ct);
        await _audit.LogAsync("auth.change_password", target: admin.UserName);
        return Ok();
    }

    private bool TryGetAdminId(out Guid id)
    {
        id = Guid.Empty;
        var raw = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return raw != null && Guid.TryParse(raw, out id);
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
            error = $"新密碼長度至少 {MinPasswordLength} 位";
            return false;
        }
        if (password.Length > MaxPasswordLength)
        {
            error = $"新密碼長度不能超過 {MaxPasswordLength} 位";
            return false;
        }
        error = "";
        return true;
    }

    /// <summary>用於賬號不存在時做等值開銷比對的常量散列。</summary>
    private static readonly string DummyHash =
        new PasswordHasher().HashPassword("dummy-password-for-timing-equalization");

    private static string[] ParsePerms(string? raw) =>
        (raw ?? string.Empty).Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

    private static AdminUserDto ToDto(AdminUser a) =>
        new(a.Id, a.UserName, a.DisplayName, a.Role?.Name ?? "None", a.IsActive, a.CreatedAt, a.LastLoginAt);
}
