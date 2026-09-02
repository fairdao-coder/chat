using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.IdentityModel.Tokens;

namespace Chat.Shared.Security;

/// <summary>
/// ChatServer 與 AdminServer 共用的 JWT 鑑權註冊邏輯。
/// 兩個服務此前各維護一份幾乎相同的配置（差異僅在 SignalR 的 access_token 讀取），
/// 統一到此處避免日後只改一端導致行為分叉。
/// </summary>
public static class AuthenticationExtensions
{
    /// <param name="hubPath">
    /// SignalR Hub 路徑。非空時允許通過查詢串 ?access_token= 傳遞令牌
    /// （瀏覽器 WebSocket 無法自定義 Header，這是唯一可行方式）。
    /// </param>
    public static IServiceCollection AddChatAuthentication(
        this IServiceCollection services,
        IConfiguration configuration,
        IHostEnvironment environment,
        string sectionName = "Jwt",
        string defaultIssuer = "ChatServer",
        string defaultAudience = "ChatClient",
        string? hubPath = null)
    {
        var settings = JwtSettings.Load(configuration, environment, sectionName, defaultIssuer, defaultAudience);

        services.AddSingleton(settings);

        services
            .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidateAudience = true,
                    ValidateLifetime = true,
                    ValidateIssuerSigningKey = true,
                    ValidIssuer = settings.Issuer,
                    ValidAudience = settings.Audience,
                    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(settings.Key)),
                    // 令牌自帶的 nbf/exp 與服務端時鐘可能秒級漂移，給 30s 容忍窗口。
                    ClockSkew = TimeSpan.FromSeconds(30)
                };

                if (string.IsNullOrEmpty(hubPath)) return;

                options.Events = new JwtBearerEvents
                {
                    OnMessageReceived = context =>
                    {
                        var accessToken = context.Request.Query["access_token"];
                        if (!string.IsNullOrEmpty(accessToken) &&
                            context.Request.Path.StartsWithSegments(hubPath))
                        {
                            context.Token = accessToken;
                        }
                        return Task.CompletedTask;
                    }
                };
            });

        services.AddAuthorization();
        return services;
    }
}
