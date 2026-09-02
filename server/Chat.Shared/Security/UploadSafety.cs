using System.Security.Cryptography;

namespace Chat.Shared.Security;

/// <summary>
/// 上傳文件安全校驗。
///
/// 解決三類問題：
///   1. 任意擴展名：攻擊者可上傳 .html/.svg 並通過 /files 靜態目錄執行 XSS；
///   2. 擴展名與真實類型不符：靠 Content-Type 頭不可信（客戶端可控），故做魔數嗅探；
///   3. 路徑穿越 / 無大小上限：磁盤被打滿或寫到預期目錄之外。
///
/// 存儲名一律由服務端生成（隨機 GUID + 白名單擴展名），永不採用客戶端文件名。
/// </summary>
public static class UploadSafety
{
    /// <summary>單文件默認上限 20 MB。</summary>
    public const long DefaultMaxBytes = 20 * 1024 * 1024;

    /// <summary>
    /// 允許的擴展名白名單。刻意不含 .svg（可被瀏覽器當作文檔執行內聯腳本）
    /// 與 .html/.js 等可直接執行後綴。
    /// </summary>
    public static readonly IReadOnlyDictionary<string, byte[][]> Allowed = new Dictionary<string, byte[][]>(StringComparer.OrdinalIgnoreCase)
    {
        // 圖片
        [".png"] = [[0x89, 0x50, 0x4E, 0x47]],
        [".jpg"] = [[0xFF, 0xD8, 0xFF]],
        [".jpeg"] = [[0xFF, 0xD8, 0xFF]],
        [".gif"] = [[0x47, 0x49, 0x46, 0x38]],
        [".webp"] = [[0x52, 0x49, 0x46, 0x46]], // "RIFF"，容器類，僅做寬鬆校驗
        [".bmp"] = [[0x42, 0x4D]],
        // 音頻
        [".mp3"] = [[0x49, 0x44, 0x33], [0xFF, 0xFB], [0xFF, 0xF3], [0xFF, 0xF2]],
        [".wav"] = [[0x52, 0x49, 0x46, 0x46]],
        [".ogg"] = [[0x4F, 0x67, 0x67, 0x53]],
        [".m4a"] = [[0x66, 0x74, 0x79, 0x70]],
        [".aac"] = [[0xFF, 0xF1], [0xFF, 0xF9]],
        // 視頻
        [".mp4"] = [[0x66, 0x74, 0x79, 0x70]],
        [".webm"] = [[0x1A, 0x45, 0xDF, 0xA3]],
        // 文檔與歸檔
        [".pdf"] = [[0x25, 0x50, 0x44, 0x46]],
        [".zip"] = [[0x50, 0x4B, 0x03, 0x04], [0x50, 0x4B, 0x05, 0x06]],
        [".doc"] = [[0xD0, 0xCF, 0x11, 0xE0]],
        [".docx"] = [[0x50, 0x4B, 0x03, 0x04]],
        [".xls"] = [[0xD0, 0xCF, 0x11, 0xE0]],
        [".xlsx"] = [[0x50, 0x4B, 0x03, 0x04]],
        [".ppt"] = [[0xD0, 0xCF, 0x11, 0xE0]],
        [".pptx"] = [[0x50, 0x4B, 0x03, 0x04]],
    };

    /// <summary>純文本類：無可靠魔數，只做擴展名白名單校驗。</summary>
    public static readonly string[] TextualExtensions =
        [".txt", ".csv", ".json", ".md", ".log"];

    public static bool IsAllowedExtension(string extension) =>
        Allowed.ContainsKey(extension) || TextualExtensions.Contains(extension, StringComparer.OrdinalIgnoreCase);

    /// <summary>
    /// 生成服務端文件名。擴展名必須在白名單內，名字本身隨機，杜絕路徑穿越與雙擴展名攻擊。
    /// </summary>
    public static bool TryBuildStorageName(string? originalFileName, out string storageName, out string extension)
    {
        storageName = "";
        extension = "";

        if (string.IsNullOrWhiteSpace(originalFileName)) return false;

        var ext = Path.GetExtension(originalFileName);
        if (string.IsNullOrEmpty(ext) || !IsAllowedExtension(ext)) return false;

        extension = ext.ToLowerInvariant();
        storageName = $"{Guid.NewGuid():N}{extension}";
        return true;
    }

    /// <summary>
    /// 魔數嗅探。對無魔數定義的文本類擴展名直接放行（其風險已被擴展名白名單覆蓋）。
    /// </summary>
    public static bool ContentMatches(ReadOnlySpan<byte> head, string extension)
    {
        if (!Allowed.TryGetValue(extension, out var signatures)) return true;

        foreach (var sig in signatures)
        {
            if (head.Length >= sig.Length && head[..sig.Length].SequenceEqual(sig))
                return true;
        }
        return false;
    }

    /// <summary>
    /// 讀取文件頭並校驗魔數。僅讀取前 16 字節，避免為校驗而緩衝整個文件。
    /// </summary>
    public static async Task<bool> SniffAsync(Stream stream, string extension, CancellationToken ct = default)
    {
        if (!Allowed.TryGetValue(extension, out var signatures)) return true;

        var maxLen = signatures.Max(s => s.Length);
        var buffer = new byte[maxLen];
        var read = await stream.ReadAtLeastAsync(buffer, maxLen, throwOnEndOfStream: false, ct);
        if (read == 0) return false;

        stream.Position = 0;
        return ContentMatches(buffer.AsSpan(0, read), extension);
    }

    /// <summary>
    /// 擴展名 → MIME 映射。客戶端上報的 Content-Type 不可信（完全由客戶端控制），
    /// 落盤時一律以本表為準，避免把 text/html 之類的類型回寫進靜態服務響應頭。
    /// </summary>
    public static readonly IReadOnlyDictionary<string, string> MimeTypes =
        new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            [".png"] = "image/png",
            [".jpg"] = "image/jpeg",
            [".jpeg"] = "image/jpeg",
            [".gif"] = "image/gif",
            [".webp"] = "image/webp",
            [".bmp"] = "image/bmp",
            [".mp3"] = "audio/mpeg",
            [".wav"] = "audio/wav",
            [".ogg"] = "audio/ogg",
            [".m4a"] = "audio/mp4",
            [".aac"] = "audio/aac",
            [".mp4"] = "video/mp4",
            [".webm"] = "video/webm",
            [".pdf"] = "application/pdf",
            [".zip"] = "application/zip",
            [".doc"] = "application/msword",
            [".docx"] = "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            [".xls"] = "application/vnd.ms-excel",
            [".xlsx"] = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            [".ppt"] = "application/vnd.ms-powerpoint",
            [".pptx"] = "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            [".txt"] = "text/plain",
            [".csv"] = "text/csv",
            [".json"] = "application/json",
            [".md"] = "text/markdown",
            [".log"] = "text/plain",
        };

    public static string MimeFor(string extension) =>
        MimeTypes.TryGetValue(extension, out var mime) ? mime : "application/octet-stream";

    /// <summary>生成隨機文件名（用於無原始文件名的場景）。</summary>
    public static string RandomName(string extension) =>
        $"{RandomNumberGenerator.GetHexString(16)}{extension}";
}
