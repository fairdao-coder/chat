using System.Text.Json;
using MauiChat.Config;
using MauiChat.Models;
using Microsoft.Maui.Storage;

namespace MauiChat.Services;

/// <summary>
/// Login / register plus persistence of the JWT and current user in
/// <see cref="SecureStorage"/>. The token is also what the SignalR hub
/// uses (via <see cref="ChatHubClient"/>).
/// </summary>
public class AuthService
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    private readonly ApiClient _api;

    public AuthService(ApiClient api) => _api = api;

    public async Task<AuthResult> LoginAsync(string userName, string password)
    {
        var result = await _api.LoginAsync(userName, password);
        await PersistAsync(result);
        return result;
    }

    public async Task<AuthResult> RegisterAsync(string userName, string password, string nickName)
    {
        var result = await _api.RegisterAsync(userName, password, nickName);
        await PersistAsync(result);
        return result;
    }

    private async Task PersistAsync(AuthResult result)
    {
        await SecureStorage.Default.SetAsync(AuthKeys.TokenKey, result.Token);
        await SecureStorage.Default.SetAsync(AuthKeys.UserKey, JsonSerializer.Serialize(result.User, JsonOptions));
    }

    public async Task<string?> GetTokenAsync()
        => await SecureStorage.Default.GetAsync(AuthKeys.TokenKey);

    public async Task<UserDto?> GetUserAsync()
    {
        var json = await SecureStorage.Default.GetAsync(AuthKeys.UserKey);
        return string.IsNullOrEmpty(json) ? null : JsonSerializer.Deserialize<UserDto>(json, JsonOptions);
    }

    public async Task LogoutAsync()
    {
        SecureStorage.Default.Remove(AuthKeys.TokenKey);
        SecureStorage.Default.Remove(AuthKeys.UserKey);
    }

    /// <summary>True if a token is currently stored.</summary>
    public async Task<bool> IsAuthenticatedAsync()
        => !string.IsNullOrEmpty(await GetTokenAsync());
}
