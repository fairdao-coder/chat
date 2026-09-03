using Chat.Shared.Entities;
using ChatServer.Data;
using ChatServer.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ChatServer.Controllers;

/// <summary>
/// 客戶端功能開關。公開接口，App 啟動時拉取；配置由管理後臺寫入。
/// 配置行缺失時（如庫為空）返回全開的默認值，保證客戶端可用。
/// </summary>
[ApiController]
[Route("api/features")]
public class FeaturesController : ControllerBase
{
    private readonly AppDbContext _db;

    public FeaturesController(AppDbContext db) => _db = db;

    [HttpGet]
    [AllowAnonymous]
    public async Task<IActionResult> Get(CancellationToken ct = default)
    {
        var s = await _db.SystemSettings
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == SystemSettings.SingletonId, ct);

        if (s is null)
            return Ok(new FeatureSettingsDto(new ChatFeatureConfig().ToJson()));

        return Ok(new FeatureSettingsDto(s.ChatConfig, s.OtherConfig));
    }
}
