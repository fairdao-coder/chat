using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Microsoft.AspNetCore.Cors.Infrastructure;

namespace Chat.Shared.Security;

/// <summary>
/// 統一的 CORS 策略。
///
/// 關鍵安全約束：AllowCredentials() 與「回顯任意 Origin」不能同時存在於生產環境，
/// 否則任意站點都能帶上用戶憑證訪問本站接口（等同關閉同源策略）。
/// 因此：
///   - 顯式配置了 Cors:Origins → 只放行白名單；
///   - 未配置且為開發環境 → 回顯任意 Origin（Flutter Web 端口隨機，聯調必需）；
///   - 未配置且非開發環境 → 不放行任何跨源來源，並記錄嚴重告警。
/// </summary>
public static class CorsExtensions
{
    public const string PolicyName = "allow";

    public static readonly string[] DevelopmentOrigins =
    [
        "http://localhost:5173", "http://localhost:3000",
        "http://localhost:8080", "http://localhost:8081",
        "http://127.0.0.1:8080", "http://127.0.0.1:8081",
        "http://127.0.0.1:3000", "http://127.0.0.1:30003",
        "http://localhost:30003"
    ];

    public static IServiceCollection AddChatCors(this IServiceCollection services)
    {
        services.AddCors();
        services.AddTransient<IConfigureOptions<CorsOptions>, ChatCorsSetup>();
        return services;
    }

    /// <summary>
    /// 透過 IConfigureOptions 延遲到容器可用時再構造策略，
    /// 避免在註冊階段調用 BuildServiceProvider（會產生重複容器與 ASP0000 告警）。
    /// </summary>
    private sealed class ChatCorsSetup : IConfigureOptions<CorsOptions>
    {
        private readonly IConfiguration _configuration;
        private readonly IHostEnvironment _environment;
        private readonly ILogger<ChatCorsSetup> _logger;

        public ChatCorsSetup(IConfiguration configuration, IHostEnvironment environment, ILogger<ChatCorsSetup> logger)
        {
            _configuration = configuration;
            _environment = environment;
            _logger = logger;
        }

        public void Configure(CorsOptions options)
        {
            var origins = ParseOrigins(_configuration["Cors:Origins"]);

            options.AddPolicy(PolicyName, policy =>
            {
                if (origins.Length > 0)
                {
                    policy.WithOrigins(origins).AllowAnyHeader().AllowAnyMethod().AllowCredentials();
                    return;
                }

                if (_environment.IsDevelopment())
                {
                    // 開發期回顯 Origin：Flutter Web 每次 run 端口都可能變，逐個加白名單不現實。
                    policy.SetIsOriginAllowed(_ => true)
                          .AllowAnyHeader()
                          .AllowAnyMethod()
                          .AllowCredentials();
                    return;
                }

                // 生產環境未配置白名單：最安全退化為「不允許任何跨源請求」。
                _logger.LogCritical(
                    "生產環境未配置 Cors:Origins，已禁用所有跨源請求。" +
                    "請通過環境變量 Cors__Origins=https://a.com,https://b.com 顯式配置。");
            });
        }

        /// <summary>
        /// 支持兩種配置形態：JSON 陣列（appsettings.json）與逗號分隔字串（環境變量）。
        /// 直接 Get&lt;string[]&gt;() 在字串形態下會因 JSON 解析失敗返回 null，故手動分割。
        /// </summary>
        private static string[] ParseOrigins(string? raw)
        {
            if (string.IsNullOrWhiteSpace(raw)) return [];

            return raw.Split([',', ';', ' ', '\t', '\n', '\r'], StringSplitOptions.RemoveEmptyEntries)
                .Select(s => s.Trim())
                .Where(s => s.Length > 0)
                .ToArray();
        }
    }
}
