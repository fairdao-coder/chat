using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;

namespace Chat.Shared.Security;

/// <summary>
/// JWT 簽名配置。從 IConfiguration 讀取並做啟動期強校驗——
/// 缺失/過短/仍為佔位值的密鑰在非開發環境直接讓進程啟動失敗，
/// 而不是悄悄退回一個眾所周知的默認值（任何人都能偽造令牌）。
/// </summary>
public sealed class JwtSettings
{
    /// <summary>HS256 要求密鑰不短於 256 bit。</summary>
    private const int MinKeyLength = 32;

    private static readonly string[] PlaceholderMarkers =
        ["CHANGE", "CHANGEME", "PLEASECHANGEIT", "DEVELOPMENTSECRET", "YOUR_"];

    public string Key { get; private init; } = "";
    public string Issuer { get; private init; } = "";
    public string Audience { get; private init; } = "";
    public int ExpiryDays { get; private init; } = 7;

    public static JwtSettings Load(
        IConfiguration configuration,
        IHostEnvironment environment,
        string sectionName = "Jwt",
        string defaultIssuer = "ChatServer",
        string defaultAudience = "ChatClient")
    {
        var section = configuration.GetSection(sectionName);
        var key = section["Key"];
        var issuer = section["Issuer"] ?? defaultIssuer;
        var audience = section["Audience"] ?? defaultAudience;

        var expiryDays = 7;
        if (int.TryParse(section["ExpiryDays"], out var parsed) && parsed > 0)
            expiryDays = parsed;

        if (string.IsNullOrWhiteSpace(key) || IsPlaceholder(key))
        {
            if (environment.IsProduction())
                ThrowInvalid(sectionName, key is null ? "未配置" : "仍為佔位值/開發默認值");

            // 開發環境：保留可預測的默認密鑰，重啟後令牌仍有效，方便聯調。
            key = "ThisIsADevelopmentSecretKeyPleaseChangeIt123!";
        }
        else if (key.Length < MinKeyLength)
        {
            ThrowInvalid(sectionName, $"長度僅 {key.Length} 字符，HS256 至少要求 {MinKeyLength}");
        }

        return new JwtSettings
        {
            Key = key,
            Issuer = issuer,
            Audience = audience,
            ExpiryDays = expiryDays
        };
    }

    private static bool IsPlaceholder(string key)
    {
        var upper = key.ToUpperInvariant();
        foreach (var marker in PlaceholderMarkers)
            if (upper.Contains(marker, StringComparison.Ordinal))
                return true;
        return false;
    }

    private static void ThrowInvalid(string sectionName, string reason) =>
        throw new InvalidOperationException(
            $"JWT 密鑰不可用（{sectionName}:Key，{reason}）。" +
            $"請通過環境變量 {sectionName.ToUpperInvariant()}__KEY 或用戶機密配置一個長度 ≥ {MinKeyLength} 的隨機密鑰，例如：openssl rand -base64 48");
}
