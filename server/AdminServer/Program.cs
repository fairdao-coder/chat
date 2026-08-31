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
    var origins = builder.Configuration.GetSection("Cors:Origins").Get<string[]>();
    if (origins == null || origins.Length == 0)
        origins = new[]
        {
            "http://localhost:5173", "http://localhost:3000",
            "http://localhost:8080", "http://127.0.0.1:8080",
            "http://localhost:30003", "http://127.0.0.1:30003"
        };
    p.AllowAnyHeader().AllowAnyMethod().AllowCredentials().WithOrigins(origins);
    if (builder.Environment.IsDevelopment())
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

// 自動建庫（僅新增後臺管理表）+ 種子默認角色與管理員
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AdminDbContext>();
    db.Database.Migrate();
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
            Permissions = "dashboard.view,users.read,users.write,roles.read,audit.read,admins.read",
            Description = "管理員"
        };
        var viewer = new AdminRole { Name = "Viewer", Permissions = "dashboard.view,users.read,roles.read,audit.read", Description = "只讀訪客" };
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
}
