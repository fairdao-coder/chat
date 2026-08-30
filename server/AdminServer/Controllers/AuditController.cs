using AdminServer.Authorization;
using AdminServer.Data;
using AdminServer.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AdminServer.Controllers;

[ApiController]
[Route("api/admin/audit")]
[Authorize]
public class AuditController : ControllerBase
{
    private readonly AdminDbContext _db;

    public AuditController(AdminDbContext db) => _db = db;

    [HttpGet]
    public async Task<IActionResult> List(string? q, int page = 1, int pageSize = 30)
    {
        var f = this.EnsurePermission(Permissions.AuditRead);
        if (f is not null) return f;

        if (page < 1) page = 1;
        if (pageSize < 1 || pageSize > 100) pageSize = 30;

        var query = _db.AuditLogs.AsQueryable();
        if (!string.IsNullOrWhiteSpace(q))
            query = query.Where(a => a.Action.Contains(q) || a.AdminUserName.Contains(q));

        var total = await query.CountAsync();
        var items = await query
            .OrderByDescending(a => a.At)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(a => new AuditLogDto(a.Id, a.AdminUserName, a.Action, a.Target, a.Detail, a.At, a.Ip))
            .ToListAsync();

        return Ok(new PagedResult<AuditLogDto>(items, total, page, pageSize));
    }
}
