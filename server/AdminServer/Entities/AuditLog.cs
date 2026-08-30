namespace AdminServer.Entities;

/// <summary>管理员操作审计日志（AdminServer 自有表）。</summary>
public class AuditLog
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid? AdminUserId { get; set; }
    public string AdminUserName { get; set; } = "system";
    public string Action { get; set; } = default!;
    public string? Target { get; set; }
    public string? Detail { get; set; }
    public DateTime At { get; set; } = DateTime.UtcNow;
    public string? Ip { get; set; }
}
