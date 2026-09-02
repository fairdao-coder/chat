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

// CORS 中間件必須在 UseRouting 之後、UseAuthentication/UseAuthorization 之前，
// 這樣預檢請求能正確寫入 Access-Control-Allow-* 頭。
app.UseRouting();
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

    // 底部固定導航欄目（信息/通訊錄/發現/我）：首次部署時自動插入並固定到底部，已存在同名則跳過（冪等）。
    // Kind = "tab" 表示客戶端底部 Tab，Content 標識跳轉目標（chat / contacts / discover / me）。
    // 排序：信息/通訊錄置頂（大負值），發現/我置底（大正值），與微信習慣一致。
    var pinnedTabs = new[]
    {
        ("信息", "💬", "tab", "chat", -9999),
        ("通訊錄", "👤", "tab", "contacts", -8888),
        ("發現", "🧭", "tab", "discover", 8888),
        ("我", "🙂", "tab", "me", 9999),
    };
    // 發現頁默認欄目：首次部署時自動插入，已存在同名欄目則跳過（冪等）。
    var defaultColumns = new[]
    {
        ("新增好友", "🤝", "action", "addFriend", 0),
        ("好友邀請", "📩", "action", "friendRequests", 1),
        ("建立群組", "👥", "action", "createGroup", 2),
        ("掃一掃", "📷", "action", "scan", 3),
    };

    var existingTitles = await db.DiscoverColumns.Select(c => c.Title).ToListAsync();

    foreach (var (title, icon, kind, content, sort) in pinnedTabs)
    {
        if (existingTitles.Contains(title)) continue;

        db.DiscoverColumns.Add(new Chat.Shared.Entities.DiscoverColumn
        {
            Title = title,
            Icon = icon,
            Kind = kind,
            Content = content,
            Sort = sort,
            Enabled = true,
            Pinned = true,
            CreatedAt = DateTime.UtcNow,
        });
    }

    foreach (var (title, icon, kind, content, sort) in defaultColumns)
    {
        if (existingTitles.Contains(title)) continue;

        db.DiscoverColumns.Add(new Chat.Shared.Entities.DiscoverColumn
        {
            Title = title,
            Icon = icon,
            Kind = kind,
            Content = content,
            Sort = sort,
            Enabled = true,
            CreatedAt = DateTime.UtcNow,
        });
    }

    await db.SaveChangesAsync();
}
