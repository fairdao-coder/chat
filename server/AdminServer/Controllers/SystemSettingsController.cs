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

/// <summary>
/// 全系統功能開關（單例配置）。管理後臺讀寫，聊天客戶端經 ChatServer 公開接口讀取。
/// </summary>
[ApiController]
[Route("api/admin/settings")]
[Authorize]
public class SystemSettingsController : ControllerBase
{
    private readonly AdminDbContext _db;
    private readonly IAuditService _audit;

    public SystemSettingsController(AdminDbContext db, IAuditService audit)
    {
        _db = db;
        _audit = audit;
    }

    [HttpGet]
    public async Task<IActionResult> Get()
    {
        var f = this.EnsurePermission(Permissions.SettingsRead);
        if (f is not null) return f;

        var s = await GetOrCreateAsync();
        return Ok(ToDto(s));
    }

    [HttpPut]
    public async Task<IActionResult> Update(UpdateSystemSettingsRequest req)
    {
        var f = this.EnsurePermission(Permissions.SettingsWrite);
        if (f is not null) return f;

        var s = await GetOrCreateAsync();
        s.ChatConfig = req.ChatConfig;
        s.OtherConfig = req.OtherConfig;
        s.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        await _audit.LogAsync(
            "settings.update",
            target: "system",
            detail: $"chatConfig={s.ChatConfig},otherConfig={s.OtherConfig}");

        return Ok(ToDto(s));
    }

    /// <summary>
    /// 讀取單例配置；首次訪問時按默認值（全開）創建。
    /// 兼顧「表已建但尚未寫入種子」的歷史庫。
    /// </summary>
    private async Task<SystemSettings> GetOrCreateAsync()
    {
        var s = await _db.SystemSettings.FindAsync(SystemSettings.SingletonId);
        if (s is not null) return s;

        s = new SystemSettings { Id = SystemSettings.SingletonId };
        _db.SystemSettings.Add(s);
        await _db.SaveChangesAsync();
        return s;
    }

    private static SystemSettingsDto ToDto(SystemSettings s) =>
        new(s.ChatConfig, s.OtherConfig, s.UpdatedAt);
}
