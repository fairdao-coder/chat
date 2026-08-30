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
            return Unauthorized("用户名或密码错误");

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

    private static string[] ParsePerms(string? raw) =>
        (raw ?? string.Empty).Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

    private static AdminUserDto ToDto(AdminUser a) =>
        new(a.Id, a.UserName, a.DisplayName, a.Role?.Name ?? "None", a.IsActive, a.CreatedAt, a.LastLoginAt);
}
