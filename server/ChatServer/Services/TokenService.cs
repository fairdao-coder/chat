using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Chat.Shared.Entities;
using Chat.Shared.Security;
using Microsoft.IdentityModel.Tokens;

namespace ChatServer.Services;

public interface ITokenService
{
    string CreateToken(AppUser user);
}

public class TokenService : ITokenService
{
    private readonly JwtSettings _settings;

    public TokenService(JwtSettings settings) => _settings = settings;

    public string CreateToken(AppUser user)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_settings.Key));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new Claim(ClaimTypes.Name, user.UserName),
            new Claim("nick", user.NickName)
        };

        var token = new JwtSecurityToken(
            issuer: _settings.Issuer,
            audience: _settings.Audience,
            claims: claims,
            expires: DateTime.UtcNow.AddDays(_settings.ExpiryDays),
            signingCredentials: creds);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
