using AdminServer.Authorization;
using AdminServer.Data;
using AdminServer.DTOs;
using AdminServer.Services;
using Chat.Shared.Entities;
using Chat.Shared.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AdminServer.Controllers;

/// <summary>
/// 客服帳號管理。客服帳號本質是普通聊天用戶，僅當其 Id 出現在 ServiceAgents 表時才被視為客服，
/// 用戶在客戶端「聯繫客服」時可免好友關係直接與其私聊。
/// </summary>
[ApiController]
[Route("api/admin/service-accounts")]
[Authorize]
public class ServiceAccountsController : ControllerBase
{
    private readonly AdminDbContext _db;
    private readonly IPasswordHasher _hasher;
    private readonly IAuditService _audit;

    public ServiceAccountsController(AdminDbContext db, IPasswordHasher hasher, IAuditService audit)
    {
        _db = db;
        _hasher = hasher;
        _audit = audit;
    }

    /// <summary>客服帳號列表（含在線狀態）。</summary>
    [HttpGet]
    public async Task<IActionResult> List(int page = 1, int pageSize = 50)
    {
        var f = this.EnsurePermission(Permissions.UsersRead);
        if (f is not null) return f;

        if (page < 1) page = 1;
        if (pageSize < 1 || pageSize > 200) pageSize = 50;

        var query = _db.ServiceAgents.AsNoTracking()
            .Join(_db.Users, s => s.UserId, u => u.Id,
                (s, u) => new { u.Id, u.UserName, u.NickName, u.AvatarUrl, u.LastSeenAt });
        var total = await query.CountAsync();
        var list = await query
            .OrderBy(u => u.UserName)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(u => new { u.Id, u.UserName, u.NickName, u.AvatarUrl, u.LastSeenAt })
            .ToListAsync();

        var ids = list.Select(x => x.Id).ToList();
        var bannedMap = await _db.UserFlags
            .AsNoTracking().Where(x => x.IsBanned && ids.Contains(x.UserId))
            .ToDictionaryAsync(x => x.UserId, x => x);
        var onlineThreshold = DateTime.UtcNow.AddMinutes(-5);

        var items = list.Select(u =>
        {
            bannedMap.TryGetValue(u.Id, out var flag);
            return new ServiceAccountDto(
                u.Id, u.UserName, u.NickName, u.AvatarUrl,
                u.LastSeenAt >= onlineThreshold, u.LastSeenAt,
                flag?.IsBanned ?? false);
        }).ToList();

        return Ok(new PagedResult<ServiceAccountDto>(items, total, page, pageSize));
    }

    /// <summary>創建客服帳號。用戶名需全網唯一。</summary>
    [HttpPost]
    public async Task<IActionResult> Create(CreateServiceAccountRequest req)
    {
        var f = this.EnsurePermission(Permissions.UsersWrite);
        if (f is not null) return f;

        var userName = (req.UserName ?? "").Trim();
        var nickName = (req.NickName ?? "").Trim();
        var password = (req.Password ?? "").Trim();

        if (userName.Length < 3)
            return BadRequest(new { error = "E_BAD_USERNAME", message = "用戶名至少 3 個字元" });
        if (nickName.Length < 1)
            return BadRequest(new { error = "E_BAD_NICKNAME", message = "請填寫顯示名稱" });
        if (password.Length < 6)
            return BadRequest(new { error = "E_BAD_PASSWORD", message = "密碼至少 6 個字元" });

        if (await _db.Users.AsNoTracking().AnyAsync(u => u.UserName == userName))
            return Conflict(new { error = "E_DUP_USERNAME", message = "用戶名已存在" });

        var user = new AppUser
        {
            UserName = userName,
            NickName = nickName,
            AvatarUrl = req.AvatarUrl,
            PasswordHash = _hasher.HashPassword(password),
        };
        _db.Users.Add(user);
        // 寫入獨立 ServiceAgents 表即標記為客服；用戶本體保持普通用戶，便於日後移除客服時保留歷史。
        _db.ServiceAgents.Add(new ServiceAgent { UserId = user.Id });
        await _db.SaveChangesAsync();
        await _audit.LogAsync("service.create", target: userName, detail: "創建客服帳號");
        return Ok(new ServiceAccountDto(user.Id, user.UserName, user.NickName, user.AvatarUrl, false, user.LastSeenAt, false));
    }

    /// <summary>刪除客服帳號（移除 ServiceAgents 表記錄，用戶本體保留以保留歷史聊天）。</summary>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var f = this.EnsurePermission(Permissions.UsersWrite);
        if (f is not null) return f;

        var u = await _db.Users.FindAsync(id);
        if (u is null) return NotFound();
        // 僅移除 ServiceAgents 表記錄，用戶本體與歷史會話保留。
        var agent = await _db.ServiceAgents.FirstOrDefaultAsync(s => s.UserId == id);
        if (agent is null) return NotFound();
        _db.ServiceAgents.Remove(agent);
        await _db.SaveChangesAsync();
        await _audit.LogAsync("service.delete", target: u.UserName, detail: "移除客服標記（保留用戶本體）");
        return Ok(new { ok = true });
    }
}
