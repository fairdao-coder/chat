using Microsoft.AspNetCore.Mvc;

namespace AdminServer.Authorization;

/// <summary>
/// 后台管理权限点常量。Token 中以 "perm" claim 携带，值为逗号分隔的权限列表。
/// 超级管理员角色权限为 "*"，在 EnsurePermission 中作为通配放行。
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
    /// 校验当前管理员是否拥有其中任意一个权限；拥有则返回 null，否则返回 403 ForbidResult。
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
