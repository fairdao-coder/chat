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
        // SignalR over WebSocket 通过 ?access_token= 传递 JWT
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

// ---- 业务服务 ----
builder.Services.AddSingleton<PresenceTracker>();
builder.Services.AddScoped<IPasswordHasher, PasswordHasher>();
builder.Services.AddScoped<ITokenService, TokenService>();
builder.Services.AddScoped<IFileStore, FileStore>();

// ---- CORS ----
// 开发期用 SetIsOriginAllowed 反射任意来源（含 Flutter run 的临时端口如 30003、127.0.0.1 等），
// 避免每次换端口都要改白名单。生产环境请通过 Cors:Origins 显式配置来源。
// 注意：AllowCredentials 不能和 AllowAnyOrigin() 同用，但可以和 SetIsOriginAllowed(始终 true) 同用
// （后者会把请求 Origin 反射回 Access-Control-Allow-Origin，等价于动态允许）。
builder.Services.AddCors(o => o.AddPolicy("allow", p =>
{
    var origins = builder.Configuration.GetSection("Cors:Origins").Get<string[]>();
    if (origins == null || origins.Length == 0)
        // 默认允许常见前端开发来源：Vite(5173)、CRA(3000)，以及 Flutter Web 默认端口(8080/8081)。
        // 浏览器里 127.0.0.1 与 localhost 被视为不同源，需分别列出。
        // 原生 Windows/Android/iOS 客户端不受 CORS 限制；此列表仅用于浏览器端 fetch + SignalR WebSocket。
        // 真机调试可用 appsettings.json 的 Cors:Origins 覆盖（如 "http://192.168.x.x:8080"）。
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
// SignalR 服务注册（修复：防止 MapHub 抛出 "Unable to find the required services"）
// 启用字符串枚举反序列化，使客户端可直接以 "Text"/"Image"/"File" 传递 MessageType
// 始终开启 EnableDetailedErrors：Hub 仅会抛出带 "E_*: ..." 错误码的 HubException
// （即 E_FRIEND_REQUIRED / E_TARGET_NOT_FOUND / E_BAD_TARGET / E_EMPTY），
// 这些都是面向客户端的用户提示，不含敏感信息；关闭的话客户端只能看到
// "Failed to invoke '{method}' due to an error on the server." 这种通用英文，
// 前端按错误码前缀做的「添加好友」等操作式对话框就不会触发。
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
// CORS 必须在静态文件之前注册：否则 /files 下的图片会被 StaticFiles 短路返回，
// CORS 中间件永远没机会写入 Access-Control-Allow-Origin 头
// （Flutter Web 用 CanvasKit 渲染，图片必须 CORS-clean 才能绘到 canvas）。
app.UseCors("allow");

// 上传的媒体文件静态访问
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

// 开发期自动建库（生产请用 EF Migration）
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.EnsureCreated();
}

app.Run();
