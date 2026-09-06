using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using Chat.Shared.Security;
using Chat.Shared.Services;
using ChatServer.Data;
using ChatServer.Hubs;
using ChatServer.Services;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Logging;

var builder = WebApplication.CreateBuilder(args);

// ---- EF Core + PostgreSQL ----
var connectionString = builder.Configuration.GetConnectionString("Default")
    ?? Environment.GetEnvironmentVariable("CONNECTIONSTRINGS__DEFAULT")
    ?? "Host=localhost;Port=5432;Database=chatdb;Username=postgres;Password=postgres";
builder.Services.AddDbContext<AppDbContext>(o => o.UseNpgsql(connectionString));

// ---- JWT（含 SignalR over WebSocket 的 ?access_token= 支持）----
// 生產環境缺少強密鑰時這裡會直接拋異常讓進程啟動失敗，而不是靜默退回默認密鑰。
builder.Services.AddChatAuthentication(
    builder.Configuration, builder.Environment, hubPath: "/hubs/chat");

// ---- CORS（開發回顯任意來源；生產必須顯式配置 Cors:Origins）----
builder.Services.AddChatCors();

// ---- 業務服務 ----
builder.Services.AddSingleton<PresenceTracker>();
builder.Services.AddSingleton<CallTracker>();
builder.Services.AddScoped<IPasswordHasher, PasswordHasher>();
builder.Services.AddScoped<ITokenService, TokenService>();
builder.Services.AddScoped<IFileStore, FileStore>();
builder.Services.AddScoped<IFriendshipService, FriendshipService>();
builder.Services.AddScoped<IMessageMapper, MessageMapper>();
builder.Services.AddScoped<IMessageService, MessageService>();
builder.Services.AddScoped<IConversationService, ConversationService>();

// ---- 限流 ----
// 認證接口是撞庫/暴力破解的主要入口，上傳接口容易被拿來打滿磁盤，二者必須限流。
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    options.AddPolicy(RateLimitPolicies.Auth, context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 20,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0
            }));

    options.AddPolicy(RateLimitPolicies.Upload, context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 30,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0
            }));
});

builder.Services.AddControllers()
    .AddJsonOptions(o => o.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));

// ---- 健康檢查：/health 返回數據庫連通性，用於運維探活與監控 ----
builder.Services.AddHealthChecks()
    .AddDbContextCheck<AppDbContext>();

// SignalR 服務註冊（修復：防止 MapHub 拋出 "Unable to find the required services"）
// 啟用字符串枚舉反序列化，使客戶端可直接以 "Text"/"Image"/"File" 傳遞 MessageType
// 始終開啟 EnableDetailedErrors：Hub 僅會拋出帶 "E_*: ..." 錯誤碼的 HubException
// （即 E_FRIEND_REQUIRED / E_TARGET_NOT_FOUND / E_BAD_TARGET / E_EMPTY），
// 這些都是面向客戶端的用戶提示，不含敏感信息；關閉的話客戶端只能看到
// "Failed to invoke '{method}' due to an error on the server." 這種通用英文，
// 前端按錯誤碼前綴做的「添加好友」等操作式對話框就不會觸發。
builder.Services.AddSignalR(o => o.EnableDetailedErrors = true)
    .AddJsonProtocol(o => o.PayloadSerializerOptions.Converters.Add(new JsonStringEnumConverter()));

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// 未捕獲異常統一轉為 RFC7807 ProblemDetails，避免把堆棧直接回給客戶端。
builder.Services.AddProblemDetails();

// 結構化請求日誌：只記錄方法/路徑/狀態碼/耗時，不記錄 body（含令牌與隱私內容）。
builder.Services.AddHttpLogging(o =>
{
    o.LoggingFields = Microsoft.AspNetCore.HttpLogging.HttpLoggingFields.RequestMethod
                      | Microsoft.AspNetCore.HttpLogging.HttpLoggingFields.RequestPath
                      | Microsoft.AspNetCore.HttpLogging.HttpLoggingFields.ResponseStatusCode
                      | Microsoft.AspNetCore.HttpLogging.HttpLoggingFields.Duration;
    o.RequestBodyLogLimit = 0;
    o.ResponseBodyLogLimit = 0;
    o.CombineLogs = true;
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseExceptionHandler(errorApp =>
{
    errorApp.Run(async context =>
    {
        var exFeature = context.Features.Get<IExceptionHandlerFeature>();
        var ex = exFeature?.Error;
        if (ex is not null)
        {
            var logger = context.RequestServices.GetService<ILogger<Program>>();
            logger?.LogError(ex,
                "Unhandled exception on {Method} {Path}: {Message}",
                context.Request.Method,
                context.Request.Path,
                ex.Message);
        }
        // 其它邏輯交給內建 ProblemDetails 中間件統一返回 RFC7807。
        context.Response.StatusCode = StatusCodes.Status500InternalServerError;
        await Task.CompletedTask;
    });
});

// 探活請求量極大且無業務信息，排除在請求日誌之外，避免淹沒有效日誌。
app.UseWhen(ctx => !ctx.Request.Path.StartsWithSegments("/health"), b => b.UseHttpLogging());

string dir = Path.Combine(app.Environment.ContentRootPath, "uploads");
if (!Directory.Exists(dir))
{
    Directory.CreateDirectory(dir);
}

// CORS 必須在靜態文件之前註冊：否則 /files 下的圖片會被 StaticFiles 短路返回，
// CORS 中間件永遠沒機會寫入 Access-Control-Allow-Origin 頭
// （Flutter Web 用 CanvasKit 渲染，圖片必須 CORS-clean 才能繪到 canvas）。
app.UseCors(CorsExtensions.PolicyName);

// 上傳的媒體文件靜態訪問
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(
        Path.Combine(app.Environment.ContentRootPath, "uploads")),
    RequestPath = "/files"
});

app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();

app.MapControllers();
app.MapHub<ChatHub>("/hubs/chat");
app.MapHealthChecks("/health");

// 資料庫與表統一由 AdminServer 負責建立；ChatServer 僅連接並使用已存在的 chatdb。
// 若啟動時資料庫或表不存在，請先啟動 AdminServer 執行 EnsureCreated 建表。

app.Run();
