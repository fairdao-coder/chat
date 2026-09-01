using System.Security.Claims;
using System.Text;
using ChatServer.Data;
using ChatServer.Hubs;
using ChatServer.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.FileProviders;
using Microsoft.IdentityModel.Tokens;
using System.Text.Json.Serialization;

var builder = WebApplication.CreateBuilder(args);

// ---- EF Core + PostgreSQL ----
var connectionString = builder.Configuration.GetConnectionString("Default")
    ?? Environment.GetEnvironmentVariable("CONNECTIONSTRINGS__DEFAULT")
    ?? "Host=localhost;Port=5432;Database=chatdb;Username=postgres;Password=postgres";
builder.Services.AddDbContext<AppDbContext>(o => o.UseNpgsql(connectionString));

// ---- JWT ----
var jwtSection = builder.Configuration.GetSection("Jwt");
var jwtKey = jwtSection["Key"] ?? "ThisIsADevelopmentSecretKeyPleaseChangeIt123!";
var jwtIssuer = jwtSection["Issuer"] ?? "ChatServer";
var jwtAudience = jwtSection["Audience"] ?? "ChatClient";

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtIssuer,
            ValidAudience = jwtAudience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey))
        };
        // SignalR over WebSocket 通過 ?access_token= 傳遞 JWT
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                var accessToken = context.Request.Query["access_token"];
                if (!string.IsNullOrEmpty(accessToken) &&
                    context.Request.Path.StartsWithSegments("/hubs/chat"))
                {
                    context.Token = accessToken;
                }
                return Task.CompletedTask;
            }
        };
    });

// ---- 業務服務 ----
builder.Services.AddSingleton<PresenceTracker>();
builder.Services.AddScoped<IPasswordHasher, PasswordHasher>();
builder.Services.AddScoped<ITokenService, TokenService>();
builder.Services.AddScoped<IFileStore, FileStore>();

// ---- CORS ----
// 開發期用 SetIsOriginAllowed 反射任意來源（含 Flutter run 的臨時端口如 30003、127.0.0.1 等），
// 避免每次換端口都要改白名單。生產環境請通過 Cors:Origins 顯式配置來源。
// 注意：AllowCredentials 不能和 AllowAnyOrigin() 同用，但可以和 SetIsOriginAllowed(始終 true) 同用
// （後者會把請求 Origin 反射回 Access-Control-Allow-Origin，等價於動態允許）。
builder.Services.AddCors(o => o.AddPolicy("allow", p =>
{
    // 支持多種配置形態：
    //   1) JSON 陣列（appsettings.json："Cors": { "Origins": ["http://a", "http://b"] }）
    //   2) 逗號/空白分隔字串（環境變數 Cors__Origins=http://a,http://b）
    // 直接 Get<string[]>() 在字串情況下會按 JSON 解析失敗而回傳 null，故這裡手動分割。
    var raw = builder.Configuration["Cors:Origins"];
    string[]? origins = null;
    if (!string.IsNullOrWhiteSpace(raw))
    {
        origins = raw.Split([',', ';', ' ', '\t', '\n', '\r'],
                StringSplitOptions.RemoveEmptyEntries)
            .Select(s => s.Trim())
            .Where(s => s.Length > 0)
            .ToArray();
    }
    if (origins == null || origins.Length == 0)
        // 默認允許常見前端開發來源：Vite(5173)、CRA(3000)，以及 Flutter Web 默認端口(8080/8081)。
        // 瀏覽器裡 127.0.0.1 與 localhost 被視為不同源，需分別列出。
        // 原生 Windows/Android/iOS 客戶端不受 CORS 限制；此列表僅用於瀏覽器端 fetch + SignalR WebSocket。
        // 真機調試可用 appsettings.json 的 Cors:Origins 覆蓋（如 "http://192.168.x.x:8080"）。
        origins = new[] {
            "http://localhost:5173", "http://localhost:3000",
            "http://localhost:8080", "http://localhost:8081",
            "http://127.0.0.1:8080", "http://127.0.0.1:8081",
            "http://127.0.0.1:3000", "http://127.0.0.1:30003",
            "http://localhost:30003"
        };
    p.AllowAnyHeader()
     .AllowAnyMethod()
     .AllowCredentials()
     .WithOrigins(origins);
    if (builder.Environment.IsDevelopment())
        p.SetIsOriginAllowed(_ => true);
}));

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
builder.Services.AddSignalR(o =>
{
    o.EnableDetailedErrors = true;
})
.AddJsonProtocol(o => o.PayloadSerializerOptions.Converters.Add(new JsonStringEnumConverter()));

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

string dir = Path.Combine(app.Environment.ContentRootPath, "uploads");
if (!Directory.Exists(dir))
{
    Directory.CreateDirectory(dir);
}
// CORS 必須在靜態文件之前註冊：否則 /files 下的圖片會被 StaticFiles 短路返回，
// CORS 中間件永遠沒機會寫入 Access-Control-Allow-Origin 頭
// （Flutter Web 用 CanvasKit 渲染，圖片必須 CORS-clean 才能繪到 canvas）。
app.UseCors("allow");

// 上傳的媒體文件靜態訪問
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(
        Path.Combine(app.Environment.ContentRootPath, "uploads")),
    RequestPath = "/files"
});

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHub<ChatHub>("/hubs/chat");
app.MapHealthChecks("/health");

// 資料庫與表統一由 AdminServer 負責建立；ChatServer 僅連接並使用已存在的 chatdb。
// 若啟動時資料庫或表不存在，請先啟動 AdminServer 執行 EnsureCreated 建表。

app.Run();
