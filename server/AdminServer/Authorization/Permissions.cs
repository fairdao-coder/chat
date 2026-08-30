using Microsoft.AspNetCore.Mvc;

namespace AdminServer.Authorization;

/// <summary>
/// 後臺管理權限點常量。Token 中以 "perm" claim 攜帶，值為逗號分隔的權限列表。
/// 超級管理員角色權限為 "*"，在 EnsurePermission 中作為通配放行。
/// </summary>
public static class Permissions
{
    public const string DashboardView = "dashboard.view";
    public const string UsersRead = "users.read";
    public const string UsersWrite = "users.write";
    public const string RolesRead = "roles.read";
    public const string RolesWrite = "roles.write";
    public const string AuditRead = "audit.read";
    public const string AdminsRead = "admins.read";
    public const string AdminsWrite = "admins.write";
}

public static class PermissionHelper
{
    /// <summary>
    /// 校驗當前管理員是否擁有其中任意一個權限；擁有則返回 null，否則返回 403 ForbidResult。
    /// </summary>
    public static IActionResult? EnsurePermission(this ControllerBase c, params string[] perms)
    {
        var user = c.User;
        if (user.HasClaim("perm", "*"))
            return null;
        var has = perms.Any(p => user.HasClaim("perm", p));
        return has ? null : c.Forbid();
    }
}
