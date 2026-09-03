using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using AdminServer.Data;
using AdminServer.Entities;
using AdminServer.Services;
using Chat.Shared.Entities;
using Chat.Shared.Security;
using Chat.Shared.Services;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// ---- EF Core + PostgreSQL（與 ChatServer 共享同一數據庫 chatdb）----
var connectionString = builder.Configuration.GetConnectionString("Default")
    ?? Environment.GetEnvironmentVariable("CONNECTIONSTRINGS__DEFAULT")
    ?? "Host=localhost;Port=5432;Database=chatdb;Username=postgres;Password=postgres";
builder.Services.AddDbContext<AdminDbContext>(o => o.UseNpgsql(connectionString));

// ---- JWT（後臺管理專用，獨立於聊天端；生產缺強密鑰時啟動即失敗）----
builder.Services.AddChatAuthentication(
    builder.Configuration,
    builder.Environment,
    defaultIssuer: "AdminServer",
    defaultAudience: "AdminClient");

// ---- CORS ----
// 原實現在所有環境都 SetIsOriginAllowed(_ => true) 且 AllowCredentials()，
// 等價於允許任意站點攜帶憑證訪問後臺接口。這裡改為生產環境必須顯式配置白名單。
builder.Services.AddChatCors();

// ---- 業務服務 ----
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<IPasswordHasher, PasswordHasher>();
builder.Services.AddScoped<IAdminTokenService, AdminTokenService>();
builder.Services.AddScoped<IAuditService, AuditService>();

// ---- 限流：後臺登錄是橫向提權的首要目標 ----
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
});

builder.Services.AddControllers()
    .AddJsonOptions(o => o.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));

// ---- 健康檢查：/health 返回數據庫連通性，用於運維探活與監控 ----
builder.Services.AddHealthChecks()
    .AddDbContextCheck<AdminDbContext>();
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

app.UseExceptionHandler();
app.UseWhen(ctx => !ctx.Request.Path.StartsWithSegments("/health"), b => b.UseHttpLogging());

app.UseCors(CorsExtensions.PolicyName);
app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();

app.MapControllers();
app.MapHealthChecks("/health");

// 自動建表（已存在則跳過、不動數據）+ 種子默認角色與管理員
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AdminDbContext>();
    db.Database.EnsureCreated();
    // 舊庫結構遷移（分類 JSON 存儲），冪等；新庫自動跳過。
    await DatabaseMigrator.MigrateSystemSettingsAsync(
        db, scope.ServiceProvider.GetRequiredService<ILoggerFactory>().CreateLogger("AdminServer.Migrate"));
    await DatabaseMigrator.MigrateDiscoverColumnsAsync(
        db, scope.ServiceProvider.GetRequiredService<ILoggerFactory>().CreateLogger("AdminServer.Migrate"));
    await SeedAsync(db, builder.Configuration, scope.ServiceProvider.GetRequiredService<ILoggerFactory>());
}

app.Run();

static async Task SeedAsync(AdminDbContext db, IConfiguration config, ILoggerFactory loggerFactory)
{
    var logger = loggerFactory.CreateLogger("AdminServer.Seed");

    if (!await db.AdminRoles.AnyAsync())
    {
        var super = new AdminRole { Name = "SuperAdmin", Permissions = "*", Description = "超級管理員，擁有全部權限" };
        var admin = new AdminRole
        {
            Name = "Admin",
            Permissions = "dashboard.view,users.read,users.write,roles.read,audit.read,admins.read,settings.read,settings.write",
            Description = "管理員"
        };
        var viewer = new AdminRole { Name = "Viewer", Permissions = "dashboard.view,users.read,roles.read,audit.read,settings.read", Description = "只讀訪客" };
        db.AdminRoles.AddRange(super, admin, viewer);
        await db.SaveChangesAsync();
    }

    if (!await db.AdminUsers.AnyAsync())
    {
        var super = await db.AdminRoles.FirstAsync(r => r.Name == "SuperAdmin");
        var seed = config.GetSection("SeedAdmin");
        var userName = seed["UserName"] ?? "admin";
        var password = seed["Password"] ?? "admin123";
        var hasher = new PasswordHasher();

        db.AdminUsers.Add(new AdminUser
        {
            UserName = userName,
            DisplayName = "超級管理員",
            PasswordHash = hasher.HashPassword(password),
            RoleId = super.Id
        });
        await db.SaveChangesAsync();

        if (password == "admin123")
            logger.LogWarning(
                "已使用默認種子密碼創建超級管理員 {UserName}，請立即通過環境變量 SeedAdmin__Password 修改。", userName);
    }

    // 舊庫已存在角色：補充後續新增的 settings 權限（冪等，按前綴判斷避免重複追加）。
    foreach (var (name, extra) in new[]
             {
                 ("Admin", ",settings.read,settings.write"),
                 ("Viewer", ",settings.read"),
             })
    {
        var role = await db.AdminRoles.FirstOrDefaultAsync(r => r.Name == name);
        if (role != null && !role.Permissions.Contains("settings."))
        {
            role.Permissions += extra;
        }
    }

    // 功能開關單例行：缺失時按默認值（全開）創建，避免客戶端首次拉取落空。
    if (!await db.SystemSettings.AnyAsync())
    {
        db.SystemSettings.Add(new Chat.Shared.Entities.SystemSettings
        {
            Id = Chat.Shared.Entities.SystemSettings.SingletonId,
            UpdatedAt = DateTime.UtcNow
        });
    }

    // 系統自帶欄目（內置導航 + 發現頁默認入口）連同四語譯文一併寫入（冪等）。
    await DiscoverColumnSeeder.SeedAsync(db, logger);

    await db.SaveChangesAsync();
}
