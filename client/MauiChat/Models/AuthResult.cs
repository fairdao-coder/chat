namespace MauiChat.Models;

/// <summary>Matches server <c>AuthResult</c>: token, user.</summary>
public class AuthResult
{
    public string Token { get; set; } = string.Empty;
    public UserDto User { get; set; } = new();
}
