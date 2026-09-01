using ChatServer.Data;
using ChatServer.DTOs;
using ChatServer.Entities;
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
    public async Task<IActionResult> Get()
    {
        var s = await _db.SystemSettings.FindAsync(SystemSettings.SingletonId);
        if (s is null)
        {
            return Ok(new FeatureSettingsDto(true, true, true, true, true));
        }
        return Ok(new FeatureSettingsDto(
            s.ShowOnlineStatus, s.EnableVoiceCall, s.EnableVideoCall,
            s.AllowFile, s.AllowVoice));
    }
}
