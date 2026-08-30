namespace AdminServer.Entities;

/// <summary>
/// 後臺角色。Permissions 為逗號分隔的權限點字符串，如 "users.read,users.write"。
/// 超級管理員使用 "*" 表示全部權限。
/// </summary>
public class AdminRole
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = default!;
    public string Permissions { get; set; } = default!;
    public string? Description { get; set; }
    public List<AdminUser> Users { get; set; } = new();
}
