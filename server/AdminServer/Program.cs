using System.Text;
using AdminServer.Data;
using AdminServer.Entities;
using AdminServer.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// ---- EF Core + PostgreSQL（與 ChatServer 共享同一數據庫 chatdb）----
var connectionString = builder.Configuration.GetConnectionString("Default")
    ?? Environment.GetEnvironmentVariable("CONNECTIONSTRINGS__DEFAULT")
    ?? "Host=localhost;Port=5432;Database=chatdb;Username=postgres;Password=postgres";
builder.Services.AddDbContext<AdminDbContext>(o => o.UseNpgsql(connectionString));

// ---- JWT（後臺管理專用，獨立於聊天端）----
var jwtSection = builder.Configuration.GetSection("Jwt");
var jwtKey = jwtSection["Key"] ?? "AdminServerDevelopmentSecretKeyChangeMe1234567890";
var jwtIssuer = jwtSection["Issuer"] ?? "AdminServer";
var jwtAudience = jwtSection["Audience"] ?? "AdminClient";

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
    });

builder.Services.AddAuthorization();

// ---- 業務服務 ----
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<IPasswordHasher, PasswordHasher>();
builder.Services.AddScoped<IAdminTokenService, AdminTokenService>();
builder.Services.AddScoped<IAuditService, AuditService>();

// ---- CORS（與 ChatServer 一致；生產請通過 Cors:Origins 顯式配置）----
builder.Services.AddCors(o => o.AddPolicy("allow", p =>
{
    // 支持 JSON 陣列與逗號/空白分隔字串兩種形態（與 ChatServer 一致）。
    // 環境變數請用雙底線命名：Cors__Origins=https://a.com,https://b.com
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
    if(origins == null || origins.Length == 0)
        origins = new[]
        {
            "http://localhost"
        };
    p.AllowAnyHeader().AllowAnyMethod().AllowCredentials().WithOrigins(origins);
       Console.WriteLine($"CORS origins: {origins.Length} = {string.Join(", ", origins)} ");
    // 生產環境也允許任意來源回顯（公開登錄/聊天 API），確保預檢通過。
    p.SetIsOriginAllowed(_ => true);
}));

builder.Services.AddControllers()
    .AddJsonOptions(o => o.JsonSerializerOptions.Converters.Add(new System.Text.Json.Serialization.JsonStringEnumConverter()));

// ---- 健康檢查：/health 返回數據庫連通性，用於運維探活與監控 ----
builder.Services.AddHealthChecks()
    .AddDbContextCheck<AdminDbContext>();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors("allow");
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapHealthChecks("/health");

// 自動建庫建表（含聊天表與後臺表，已存在則跳過、不動數據）+ 種子默認角色與管理員
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AdminDbContext>();
    db.Database.EnsureCreated();
    await SeedAsync(db, builder.Configuration);
}

app.Run();

static async Task SeedAsync(AdminDbContext db, IConfiguration config)
{
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
        db.SystemSettings.Add(new SystemSettings
        {
            Id = SystemSettings.SingletonId,
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
        if (!existingTitles.Contains(title))
        {
            db.DiscoverColumns.Add(new DiscoverColumn
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
    }
    foreach (var (title, icon, kind, content, sort) in defaultColumns)
    {
        if (!existingTitles.Contains(title))
        {
            db.DiscoverColumns.Add(new DiscoverColumn
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
    }

    await db.SaveChangesAsync();
}
