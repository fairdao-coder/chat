using Chat.Shared.Security;
using ChatServer.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace ChatServer.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class FilesController : ApiControllerBase
{
    private readonly IFileStore _store;
    private readonly IConfiguration _config;

    public FilesController(IFileStore store, IConfiguration config)
    {
        _store = store;
        _config = config;
    }

    /// <summary>
    /// 上傳圖片 / 文件。
    /// RequestSizeLimit 讓超限請求在讀完 body 之前就被框架截斷，
    /// 避免白白消耗帶寬與內存；具體類型還會在 FileStore 中做二次校驗。
    /// </summary>
    [HttpPost("upload")]
    [EnableRateLimiting(RateLimitPolicies.Upload)]
    [RequestSizeLimit((int)(UploadSafety.DefaultMaxBytes))]
    [RequestFormLimits(MultipartBodyLengthLimit = UploadSafety.DefaultMaxBytes)]
    public async Task<IActionResult> Upload(IFormFile file, CancellationToken ct = default)
    {
        if (file == null || file.Length == 0)
            return BadRequest("未選擇文件");

        try
        {
            var result = await _store.SaveAsync(file, ct);
            return Ok(result);
        }
        catch (UploadRejectedException ex)
        {
            return BadRequest(ex.Message);
        }
    }
}
