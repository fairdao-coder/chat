using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using AdminServer.Entities;
using Chat.Shared.Security;
using Microsoft.IdentityModel.Tokens;

namespace AdminServer.Services;

public interface IAdminTokenService
{
    string CreateToken(AdminUser admin, string roleName, string[] permissions);
}

public class AdminTokenService : IAdminTokenService
{
    /// <summary>後臺令牌有效期短於聊天端：8 小時，降低令牌洩露後的可用窗口。</summary>
    private const int ExpiryHours = 8;

    private readonly JwtSettings _settings;

    public AdminTokenService(JwtSettings settings) => _settings = settings;

    public string CreateToken(AdminUser admin, string roleName, string[] permissions)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_settings.Key));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, admin.Id.ToString()),
            new(ClaimTypes.Name, admin.UserName),
            new("display", admin.DisplayName),
            new(ClaimTypes.Role, roleName)
        };
        claims.AddRange(permissions.Select(p => new Claim("perm", p)));

        var token = new JwtSecurityToken(
            issuer: _settings.Issuer,
            audience: _settings.Audience,
            claims: claims,
            expires: DateTime.UtcNow.AddHours(ExpiryHours),
            signingCredentials: creds);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
