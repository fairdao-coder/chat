using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;

namespace ChatServer.Services;

public interface IFileStore
{
    Task<(string Url, long Size, string ContentType)> SaveAsync(IFormFile file);
}

public class FileStore : IFileStore
{
    private readonly IWebHostEnvironment _env;

    public FileStore(IWebHostEnvironment env) => _env = env;

    public async Task<(string Url, long Size, string ContentType)> SaveAsync(IFormFile file)
    {
        var root = Path.Combine(_env.ContentRootPath, "uploads");
        Directory.CreateDirectory(root);

        var ext = Path.GetExtension(file.FileName);
        var name = $"{Guid.NewGuid()}{ext}";
        var path = Path.Combine(root, name);

        await using var fs = new FileStream(path, FileMode.Create);
        await file.CopyToAsync(fs);

        var contentType = file.ContentType;
        if (string.IsNullOrWhiteSpace(contentType))
            contentType = "application/octet-stream";

        return ($"/files/{name}", file.Length, contentType);
    }
}
