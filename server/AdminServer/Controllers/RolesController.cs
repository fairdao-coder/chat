using AdminServer.Authorization;
using AdminServer.Data;
using AdminServer.DTOs;
using AdminServer.Entities;
using AdminServer.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AdminServer.Controllers;

[ApiController]
[Route("api/admin/roles")]
[Authorize]
public class RolesController : ControllerBase
{
    private readonly AdminDbContext _db;
    private readonly IAuditService _audit;

    public RolesController(AdminDbContext db, IAuditService audit)
    {
        _db = db;
        _audit = audit;
    }

    [HttpGet]
    public async Task<IActionResult> List()
    {
        var f = this.EnsurePermission(Permissions.RolesRead);
        if (f is not null) return f;

        var roles = await _db.AdminRoles
            .Select(r => new RoleDto(r.Id, r.Name, r.Permissions, r.Description))
            .ToListAsync();
        return Ok(roles);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id)
    {
        var f = this.EnsurePermission(Permissions.RolesRead);
        if (f is not null) return f;

        var r = await _db.AdminRoles.FindAsync(id);
        if (r is null) return NotFound();
        return Ok(new RoleDto(r.Id, r.Name, r.Permissions, r.Description));
    }

    [HttpPost]
    public async Task<IActionResult> Create(CreateRoleRequest req)
    {
        var f = this.EnsurePermission(Permissions.RolesWrite);
        if (f is not null) return f;

        if (await _db.AdminRoles.AnyAsync(r => r.Name == req.Name))
            return Conflict("角色名已存在");

        var role = new AdminRole { Name = req.Name, Permissions = req.Permissions, Description = req.Description };
        _db.AdminRoles.Add(role);
        await _db.SaveChangesAsync();
        await _audit.LogAsync("roles.create", target: role.Name);
        return Ok(new RoleDto(role.Id, role.Name, role.Permissions, role.Description));
    }

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, UpdateRoleRequest req)
    {
        var f = this.EnsurePermission(Permissions.RolesWrite);
        if (f is not null) return f;

        var r = await _db.AdminRoles.FindAsync(id);
        if (r is null) return NotFound();
        r.Name = req.Name;
        r.Permissions = req.Permissions;
        r.Description = req.Description;
        await _db.SaveChangesAsync();
        await _audit.LogAsync("roles.update", target: r.Name);
        return Ok(new RoleDto(r.Id, r.Name, r.Permissions, r.Description));
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var f = this.EnsurePermission(Permissions.RolesWrite);
        if (f is not null) return f;

        var r = await _db.AdminRoles.FindAsync(id);
        if (r is null) return NotFound();
        if (await _db.AdminUsers.AnyAsync(a => a.RoleId == id))
            return BadRequest("仍有管理員使用該角色，無法刪除");
        _db.AdminRoles.Remove(r);
        await _db.SaveChangesAsync();
        await _audit.LogAsync("roles.delete", target: r.Name);
        return Ok(new { ok = true });
    }
}
