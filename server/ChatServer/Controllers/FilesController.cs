using ChatServer.DTOs;
using ChatServer.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ChatServer.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class FilesController : ApiControllerBase
{
    private readonly IFileStore _store;
    public FilesController(IFileStore store) => _store = store;

    [HttpPost("upload")]
    public async Task<IActionResult> Upload(IFormFile file)
    {
        if (file == null || file.Length == 0)
            return BadRequest("未选择文件");
        var (url, size, ct) = await _store.SaveAsync(file);
        return Ok(new FileUploadResult(url, ct, size));
    }
}
