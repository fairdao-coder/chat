using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using AdminServer.Entities;
using Microsoft.IdentityModel.Tokens;

namespace AdminServer.Services;

public interface IAdminTokenService
{
    string CreateToken(AdminUser admin, string roleName, string[] permissions);
}

public class AdminTokenService : IAdminTokenService
{
    private readonly IConfiguration _config;

    public AdminTokenService(IConfiguration config) => _config = config;

    public string CreateToken(AdminUser admin, string roleName, string[] permissions)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_config["Jwt:Key"]!));
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
            issuer: _config["Jwt:Issuer"],
            audience: _config["Jwt:Audience"],
            claims: claims,
            expires: DateTime.UtcNow.AddHours(8),
            signingCredentials: creds);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
