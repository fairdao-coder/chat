namespace AdminServer.Entities;

/// <summary>后台管理员账号（AdminServer 自有表）。</summary>
public class AdminUser
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string UserName { get; set; } = default!;
    public string DisplayName { get; set; } = default!;
    public string PasswordHash { get; set; } = default!;
    public Guid RoleId { get; set; }
    public AdminRole? Role { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? LastLoginAt { get; set; }
}
