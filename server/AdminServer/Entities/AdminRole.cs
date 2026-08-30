namespace AdminServer.Entities;

/// <summary>
/// 后台角色。Permissions 为逗号分隔的权限点字符串，如 "users.read,users.write"。
/// 超级管理员使用 "*" 表示全部权限。
/// </summary>
public class AdminRole
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = default!;
    public string Permissions { get; set; } = default!;
    public string? Description { get; set; }
    public List<AdminUser> Users { get; set; } = new();
}
