using System.Security.Cryptography;

namespace Chat.Shared.Services;

public interface IPasswordHasher
{
    string HashPassword(string password);
    bool Verify(string hash, string password);
}

/// <summary>
/// PBKDF2-SHA256 口令散列，格式為 "<base64 salt>.<base64 hash>"。
/// ChatServer 與 AdminServer 共用同一實現，保證跨端散列可互相校驗。
/// </summary>
public class PasswordHasher : IPasswordHasher
{
    private const int Iterations = 100_000;
    private const int SaltSize = 16;
    private const int HashSize = 32;

    public string HashPassword(string password)
    {
        var salt = RandomNumberGenerator.GetBytes(SaltSize);
        var hash = Rfc2898DeriveBytes.Pbkdf2(password, salt, Iterations, HashAlgorithmName.SHA256, HashSize);
        return $"{Convert.ToBase64String(salt)}.{Convert.ToBase64String(hash)}";
    }

    public bool Verify(string hash, string password)
    {
        var parts = hash.Split('.');
        if (parts.Length != 2) return false;
        try
        {
            var salt = Convert.FromBase64String(parts[0]);
            var expected = Convert.FromBase64String(parts[1]);
            var actual = Rfc2898DeriveBytes.Pbkdf2(password, salt, Iterations, HashAlgorithmName.SHA256, HashSize);
            if (actual.Length != expected.Length) return false;
            // 定時安全的比較，避免通過響應時間側信道逐字節爆破散列。
            return CryptographicOperations.FixedTimeEquals(actual, expected);
        }
        catch
        {
            return false;
        }
    }
}
