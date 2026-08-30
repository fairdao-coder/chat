using System.Security.Cryptography;

namespace AdminServer.Services;

public interface IPasswordHasher
{
    string HashPassword(string password);
    bool Verify(string hash, string password);
}

/// <summary>與 ChatServer 一致的 PBKDF2 實現（salt.hash Base64）。</summary>
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
            var diff = 0;
            for (var i = 0; i < actual.Length; i++)
                diff |= actual[i] ^ expected[i];
            return diff == 0;
        }
        catch
        {
            return false;
        }
    }
}
