using ChatServer.Data;
using ChatServer.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Hosting;

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
    public async Task<IActionResult> List(CancellationToken ct = default)
    {
        try
        {
            return Ok(await Query(ct).ToListAsync(ct));
        }
        catch (Exception ex)
        {
            // 開發/測試期把具體異常返回給前端，方便定位 500；生產仍走 UseExceptionHandler。
            if (HttpContext.RequestServices.GetService<IHostEnvironment>()?.IsDevelopment() ?? false)
            {
                return Problem(
                    title: "Discover query failed",
                    detail: ex.ToString(),
                    statusCode: StatusCodes.Status500InternalServerError);
            }
            throw;
        }
    }

    /// <summary>
    /// 底部固定導航欄目（Pinned=true 且啟用）。客戶端據此動態渲染底部 Tab。
    /// </summary>
    [HttpGet("pinned")]
    [AllowAnonymous]
    public async Task<IActionResult> Pinned(CancellationToken ct = default)
    {
        try
        {
            return Ok(await Query(ct, onlyPinned: true).ToListAsync(ct));
        }
        catch (Exception ex)
        {
            if (HttpContext.RequestServices.GetService<IHostEnvironment>()?.IsDevelopment() ?? false)
            {
                return Problem(
                    title: "Discover pinned query failed",
                    detail: ex.ToString(),
                    statusCode: StatusCodes.Status500InternalServerError);
            }
            throw;
        }
    }

    /// <summary>
    /// 輕量變更信號：僅返回「默認欄目 Id」與「固定欄目簽名」。
    /// 客戶端緩存上次結果，對比兩者是否變化；僅當默認欄目或固定欄目
    /// 發生變化時才重新拉取整個固定欄目列表，以提高性能。
    /// signature = 固定欄目 Id 按 sort 排序後以 '|' 拼接。
    /// </summary>
    [HttpGet("pinned-meta")]
    [AllowAnonymous]
    public async Task<IActionResult> PinnedMeta(CancellationToken ct = default)
    {
        try
        {
            var settings = await _db.SystemSettings.FirstOrDefaultAsync(ct);
            var pinnedIds = await _db.DiscoverColumns
                .AsNoTracking()
                .Where(c => c.Enabled && c.Pinned)
                .OrderBy(c => c.Sort)
                .ThenBy(c => c.CreatedAt)
                .Select(c => c.Id)
                .ToListAsync(ct);
            var signature = string.Join("|", pinnedIds);
            return Ok(new PinnedMetaDto(
                DefaultColumnId: settings?.Other.DefaultColumnId, Signature: signature));
        }
        catch (Exception ex)
        {
            if (HttpContext.RequestServices.GetService<IHostEnvironment>()?.IsDevelopment() ?? false)
            {
                return Problem(
                    title: "Discover pinned-meta query failed",
                    detail: ex.ToString(),
                    statusCode: StatusCodes.Status500InternalServerError);
            }
            throw;
        }
    }

    private IQueryable<DiscoverColumnDto> Query(CancellationToken ct, bool onlyPinned = false)
    {
        var q = _db.DiscoverColumns
            .AsNoTracking()
            .Where(c => c.Enabled);

        if (onlyPinned)
            q = q.Where(c => c.Pinned);

        return q
            .OrderBy(c => c.Sort)
            .ThenBy(c => c.CreatedAt)
            .Select(c => new DiscoverColumnDto(c.Id, c.Title, c.Icon, c.Kind, c.Content, c.Sort, c.Pinned, c.TitleI18n));
    }
}

/// <summary>
/// 固定欄目變更信號：客戶端據此判斷是否需要重新拉取整個固定欄目列表。
/// </summary>
public record PinnedMetaDto(string? DefaultColumnId, string Signature);
