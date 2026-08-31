using ChatServer.Data;
using ChatServer.DTOs;
using ChatServer.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ChatServer.Controllers;

/// <summary>
/// 發現頁欄目。公開接口，App 啟動時拉取；管理後臺的增刪改在 AdminServer。
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class DiscoverController : ControllerBase
{
    private readonly AppDbContext _db;
    public DiscoverController(AppDbContext db) => _db = db;

    [HttpGet]
    [AllowAnonymous]
    public async Task<IActionResult> List()
    {
        var list = await _db.DiscoverColumns
            .Where(c => c.Enabled)
            .OrderBy(c => c.Sort)
            .ThenBy(c => c.CreatedAt)
            .Select(c => new DiscoverColumnDto(c.Id, c.Title, c.Icon, c.Link, c.Sort))
            .ToListAsync();
        return Ok(list);
    }
}
