namespace MauiChat.Models;

/// <summary>Matches server <c>FileUploadResult</c>: url, contentType, size.</summary>
public class FileUploadResult
{
    public string Url { get; set; } = string.Empty;
    public string ContentType { get; set; } = string.Empty;
    public long Size { get; set; }
}
