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
[Route("api/admin/users")]
[Authorize]
public class UsersController : ControllerBase
{
    private readonly AdminDbContext _db;
    private readonly IAuditService _audit;

    public UsersController(AdminDbContext db, IAuditService audit)
    {
        _db = db;
        _audit = audit;
    }

    [HttpGet]
    public async Task<IActionResult> List(string? q, int page = 1, int pageSize = 20)
    {
        var f = this.EnsurePermission(Permissions.UsersRead);
        if (f is not null) return f;

        if (page < 1) page = 1;
        if (pageSize < 1 || pageSize > 100) pageSize = 20;

        var query = _db.Users.AsQueryable();
        if (!string.IsNullOrWhiteSpace(q))
            query = query.Where(u => u.UserName.Contains(q) || u.NickName.Contains(q));

        var total = await query.CountAsync();
        var users = await query
            .OrderByDescending(u => u.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        var ids = users.Select(u => u.Id).ToList();
        var bannedMap = await _db.UserFlags
            .Where(x => x.IsBanned && ids.Contains(x.UserId))
            .ToDictionaryAsync(x => x.UserId, x => x);

        var onlineThreshold = DateTime.UtcNow.AddMinutes(-5);
        var items = users.Select(u => new ChatUserDto(
            u.Id, u.UserName, u.NickName, u.AvatarUrl,
            u.CreatedAt, u.LastSeenAt,
            u.LastSeenAt >= onlineThreshold,
            bannedMap.TryGetValue(u.Id, out var bf) && bf.IsBanned,
            bannedMap.TryGetValue(u.Id, out var bf2) ? bf2.BanReason : null)).ToList();

        return Ok(new PagedResult<ChatUserDto>(items, total, page, pageSize));
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id)
    {
        var f = this.EnsurePermission(Permissions.UsersRead);
        if (f is not null) return f;

        var u = await _db.Users.FindAsync(id);
        if (u is null) return NotFound();
        var flag = await _db.UserFlags.FindAsync(id);
        var onlineThreshold = DateTime.UtcNow.AddMinutes(-5);
        return Ok(new ChatUserDto(u.Id, u.UserName, u.NickName, u.AvatarUrl, u.CreatedAt, u.LastSeenAt,
            u.LastSeenAt >= onlineThreshold, flag?.IsBanned ?? false, flag?.BanReason));
    }

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, UpdateUserRequest req)
    {
        var f = this.EnsurePermission(Permissions.UsersWrite);
        if (f is not null) return f;

        var u = await _db.Users.FindAsync(id);
        if (u is null) return NotFound();
        if (req.NickName is not null) u.NickName = req.NickName;
        if (req.AvatarUrl is not null) u.AvatarUrl = req.AvatarUrl;
        await _db.SaveChangesAsync();
        await _audit.LogAsync("users.update", target: u.UserName, detail: "更新資料");
        return Ok(new { ok = true });
    }

    [HttpPost("{id:guid}/ban")]
    public async Task<IActionResult> Ban(Guid id, BanUserRequest req)
    {
        var f = this.EnsurePermission(Permissions.UsersWrite);
        if (f is not null) return f;

        var u = await _db.Users.FindAsync(id);
        if (u is null) return NotFound();
        var flag = await _db.UserFlags.FindAsync(id);
        if (flag is null)
        {
            flag = new UserFlag { UserId = id };
            _db.UserFlags.Add(flag);
        }
        flag.IsBanned = req.Banned;
        flag.BanReason = req.Banned ? req.Reason : null;
        flag.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        await _audit.LogAsync(req.Banned ? "users.ban" : "users.unban", target: u.UserName, detail: req.Reason);
        return Ok(new { ok = true, banned = req.Banned });
    }
}
