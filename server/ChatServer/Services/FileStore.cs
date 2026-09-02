using Chat.Shared.Security;
using ChatServer.DTOs;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace ChatServer.Services;

/// <summary>上傳被拒絕（類型/大小/內容不符）。[Message] 可直接展示給用戶。</summary>
public sealed class UploadRejectedException : Exception
{
    public UploadRejectedException(string message) : base(message) { }
}

public interface IFileStore
{
    Task<FileUploadResult> SaveAsync(IFormFile file, CancellationToken ct = default);
}

public class FileStore : IFileStore
{
    private readonly IWebHostEnvironment _env;
    private readonly IConfiguration _config;
    private readonly ILogger<FileStore> _logger;

    public FileStore(IWebHostEnvironment env, IConfiguration config, ILogger<FileStore> logger)
    {
        _env = env;
        _config = config;
        _logger = logger;
    }

    public async Task<FileUploadResult> SaveAsync(IFormFile file, CancellationToken ct = default)
    {
        var maxBytes = _config.GetValue<long?>("Uploads:MaxBytes") ?? UploadSafety.DefaultMaxBytes;

        if (file.Length == 0)
            throw new UploadRejectedException("文件為空");

        if (file.Length > maxBytes)
            throw new UploadRejectedException($"文件超過 {maxBytes / 1024 / 1024} MB 上限");

        // 存儲名由服務端生成：隨機 GUID + 白名單擴展名，
        // 既杜絕路徑穿越，也杜絕 "a.jpg.html" 這類雙擴展名欺騙。
        if (!UploadSafety.TryBuildStorageName(file.FileName, out var storageName, out var extension))
            throw new UploadRejectedException($"不支持的文件類型：{Path.GetExtension(file.FileName)}");

        await using var input = file.OpenReadStream();

        // Content-Type 頭由客戶端控制，不可信；用魔數嗅探判斷真實類型。
        if (!await UploadSafety.SniffAsync(input, extension, ct))
            throw new UploadRejectedException("文件內容與擴展名不符，已拒絕保存");

        var root = Path.Combine(_env.ContentRootPath, "uploads");
        Directory.CreateDirectory(root);

        var path = Path.Combine(root, storageName);
        input.Position = 0;
        await using (var fs = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None,
                         bufferSize: 81920, useAsync: true))
        {
            await input.CopyToAsync(fs, ct);
        }

        _logger.LogInformation("上傳成功 name={Name} size={Size} ext={Ext}", storageName, file.Length, extension);

        return new FileUploadResult($"/files/{storageName}", UploadSafety.MimeFor(extension), file.Length);
    }
}
