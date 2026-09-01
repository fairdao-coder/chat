using AdminServer.Data;
using AdminServer.DTOs;
using AdminServer.Entities;
using AdminServer.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace AdminServer.Controllers;

[ApiController]
[Route("api/admin/auth")]
public class AdminAuthController : ControllerBase
{
    private readonly AdminDbContext _db;
    private readonly IPasswordHasher _hasher;
    private readonly IAdminTokenService _token;
    private readonly IAuditService _audit;

    public AdminAuthController(AdminDbContext db, IPasswordHasher hasher, IAdminTokenService token, IAuditService audit)
    {
        _db = db;
        _hasher = hasher;
        _token = token;
        _audit = audit;
    }

    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<IActionResult> Login(AdminLoginRequest req)
    {
        var admin = await _db.AdminUsers
            .Include(a => a.Role)
            .FirstOrDefaultAsync(a => a.UserName == req.UserName);

        if (admin is null || !admin.IsActive || !_hasher.Verify(admin.PasswordHash, req.Password))
            return Unauthorized("用戶名或密碼錯誤");

        admin.LastLoginAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        var perms = ParsePerms(admin.Role?.Permissions);
        var token = _token.CreateToken(admin, admin.Role?.Name ?? "None", perms);
        await _audit.LogAsync("auth.login", target: admin.UserName);

        return Ok(new AdminLoginResult(token, ToDto(admin), perms));
    }

    [HttpGet("me")]
    [Authorize]
    public async Task<IActionResult> Me()
    {
        var id = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var admin = await _db.AdminUsers.Include(a => a.Role).FirstOrDefaultAsync(a => a.Id == id);
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
    public async Task<IActionResult> ChangePassword(AdminChangePasswordRequest req)
    {
        if (string.IsNullOrWhiteSpace(req.NewPassword) || req.NewPassword.Length < 6)
            return BadRequest("新密碼長度至少 6 位");

        var id = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var admin = await _db.AdminUsers.FirstOrDefaultAsync(a => a.Id == id);
        if (admin is null) return Unauthorized();

        if (!_hasher.Verify(admin.PasswordHash, req.OldPassword))
            return BadRequest("舊密碼錯誤");

        admin.PasswordHash = _hasher.HashPassword(req.NewPassword);
        await _db.SaveChangesAsync();
        await _audit.LogAsync("auth.change_password", target: admin.UserName);
        return Ok();
    }

    private static string[] ParsePerms(string? raw) =>
        (raw ?? string.Empty).Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

    private static AdminUserDto ToDto(AdminUser a) =>
        new(a.Id, a.UserName, a.DisplayName, a.Role?.Name ?? "None", a.IsActive, a.CreatedAt, a.LastLoginAt);
}
