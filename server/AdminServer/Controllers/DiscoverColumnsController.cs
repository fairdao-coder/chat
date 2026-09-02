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
[Route("api/admin/discover")]
[Authorize]
public class DiscoverColumnsController : ControllerBase
{
    private readonly AdminDbContext _db;
    private readonly IAuditService _audit;

    public DiscoverColumnsController(AdminDbContext db, IAuditService audit)
    {
        _db = db;
        _audit = audit;
    }

    [HttpGet]
    public async Task<IActionResult> List()
    {
        var f = this.EnsurePermission(Permissions.DiscoverRead);
        if (f is not null) return f;

        var items = await _db.DiscoverColumns
            .AsNoTracking()
            .OrderBy(c => c.Sort)
            .ThenBy(c => c.CreatedAt)
            .Select(c => new DiscoverColumnDto(c.Id, c.Title, c.Icon, c.Kind, c.Content, c.Sort, c.Enabled, c.Pinned, c.CreatedAt))
            .ToListAsync();
        return Ok(items);
    }

    [HttpPost]
    public async Task<IActionResult> Create(UpsertDiscoverColumnRequest req)
    {
        var f = this.EnsurePermission(Permissions.DiscoverWrite);
        if (f is not null) return f;

        if (string.IsNullOrWhiteSpace(req.Title))
            return BadRequest("欄目標題不能為空");

        var col = new DiscoverColumn
        {
            Id = Guid.NewGuid(),
            Title = req.Title,
            Icon = req.Icon,
            Kind = req.Kind ?? "link",
            Content = req.Content,
            Sort = req.Sort,
            Enabled = req.Enabled,
            Pinned = req.Pinned,
            CreatedAt = DateTime.UtcNow,
        };
        _db.DiscoverColumns.Add(col);
        await _db.SaveChangesAsync();
        await _audit.LogAsync("discover.create", target: col.Title, detail: col.Content);
        return Ok(new DiscoverColumnDto(col.Id, col.Title, col.Icon, col.Kind, col.Content, col.Sort, col.Enabled, col.Pinned, col.CreatedAt));
    }

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, UpsertDiscoverColumnRequest req)
    {
        var f = this.EnsurePermission(Permissions.DiscoverWrite);
        if (f is not null) return f;

        var col = await _db.DiscoverColumns.FindAsync(id);
        if (col is null) return NotFound();

        if (string.IsNullOrWhiteSpace(req.Title))
            return BadRequest("欄目標題不能為空");

        col.Title = req.Title;
        col.Icon = req.Icon;
        col.Kind = req.Kind ?? "link";
        col.Content = req.Content;
        col.Sort = req.Sort;
        col.Enabled = req.Enabled;
        col.Pinned = req.Pinned;
        await _db.SaveChangesAsync();
        await _audit.LogAsync("discover.update", target: col.Title, detail: col.Content);
        return Ok(new DiscoverColumnDto(col.Id, col.Title, col.Icon, col.Kind, col.Content, col.Sort, col.Enabled, col.Pinned, col.CreatedAt));
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var f = this.EnsurePermission(Permissions.DiscoverWrite);
        if (f is not null) return f;

        var col = await _db.DiscoverColumns.FindAsync(id);
        if (col is null) return NotFound();

        _db.DiscoverColumns.Remove(col);
        await _db.SaveChangesAsync();
        await _audit.LogAsync("discover.delete", target: col.Title);
        return Ok(new { ok = true });
    }
}
