using AdminServer.Authorization;
using AdminServer.Data;
using AdminServer.DTOs;
using AdminServer.Entities;
using Chat.Shared.Entities;
using AdminServer.Services;
using Chat.Shared.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AdminServer.Controllers;

[ApiController]
[Route("api/admin/accounts")]
[Authorize]
public class AdminAccountsController : ControllerBase
{
    private readonly AdminDbContext _db;
    private readonly IPasswordHasher _hasher;
    private readonly IAuditService _audit;

    public AdminAccountsController(AdminDbContext db, IPasswordHasher hasher, IAuditService audit)
    {
        _db = db;
        _hasher = hasher;
        _audit = audit;
    }

    [HttpGet]
    public async Task<IActionResult> List()
    {
        var f = this.EnsurePermission(Permissions.AdminsRead);
        if (f is not null) return f;

        var list = await _db.AdminUsers
            .AsNoTracking()
            .Include(a => a.Role)
            .Select(a => new AdminUserDto(a.Id, a.UserName, a.DisplayName, a.Role!.Name, a.IsActive, a.CreatedAt, a.LastLoginAt))
            .ToListAsync();
        return Ok(list);
    }

    [HttpPost]
    public async Task<IActionResult> Create(CreateAdminRequest req)
    {
        var f = this.EnsurePermission(Permissions.AdminsWrite);
        if (f is not null) return f;

        if (await _db.AdminUsers.AsNoTracking().AnyAsync(a => a.UserName == req.UserName))
            return Conflict("管理員賬號已存在");

        var role = await _db.AdminRoles.FindAsync(req.RoleId);
        if (role is null) return BadRequest("角色不存在");

        var admin = new AdminUser
        {
            UserName = req.UserName,
            DisplayName = req.DisplayName,
            PasswordHash = _hasher.HashPassword(req.Password),
            RoleId = req.RoleId
        };
        _db.AdminUsers.Add(admin);
        await _db.SaveChangesAsync();
        await _audit.LogAsync("accounts.create", target: admin.UserName);
        return Ok(new AdminUserDto(admin.Id, admin.UserName, admin.DisplayName, role.Name, admin.IsActive, admin.CreatedAt, admin.LastLoginAt));
    }

    [HttpPost("{id:guid}/toggle")]
    public async Task<IActionResult> Toggle(Guid id, bool active)
    {
        var f = this.EnsurePermission(Permissions.AdminsWrite);
        if (f is not null) return f;

        var a = await _db.AdminUsers.FindAsync(id);
        if (a is null) return NotFound();
        a.IsActive = active;
        await _db.SaveChangesAsync();
        await _audit.LogAsync("accounts.toggle", target: a.UserName, detail: active ? "啟用" : "停用");
        return Ok(new { ok = true, active });
    }
}
