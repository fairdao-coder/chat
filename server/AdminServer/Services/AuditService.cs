using AdminServer.Data;
using AdminServer.Entities;
using Chat.Shared.Entities;
using Microsoft.AspNetCore.Http;
using System.Security.Claims;

namespace AdminServer.Services;

public interface IAuditService
{
    Task LogAsync(string action, string? target = null, string? detail = null, ClaimsPrincipal? user = null);
}

public class AuditService : IAuditService
{
    private readonly AdminDbContext _db;
    private readonly IHttpContextAccessor _http;

    public AuditService(AdminDbContext db, IHttpContextAccessor http)
    {
        _db = db;
        _http = http;
    }

    public async Task LogAsync(string action, string? target = null, string? detail = null, ClaimsPrincipal? user = null)
    {
        user ??= _http.HttpContext?.User;
        var userName = user?.Identity?.Name ?? "system";
        var adminId = user?.FindFirstValue(ClaimTypes.NameIdentifier);
        var ip = _http.HttpContext?.Connection.RemoteIpAddress?.ToString();

        _db.AuditLogs.Add(new AuditLog
        {
            AdminUserId = adminId != null && Guid.TryParse(adminId, out var parsed) ? parsed : null,
            AdminUserName = userName,
            Action = action,
            Target = target,
            Detail = detail,
            Ip = ip
        });
        await _db.SaveChangesAsync();
    }
}
