namespace MauiChat.Config;

/// <summary>
/// Central configuration. The API base address MUST match the running
/// ASP.NET Core server from ARCHITECTURE.md.
///
/// Defaults (dev):
///   - Android emulator : http://10.0.2.2:5298   (10.0.2.2 == host loopback)
///   - iOS simulator    : http://localhost:5298
///   - Physical device  : use your dev machine LAN IP, e.g. http://192.168.1.50:5298
///
/// The value can be overridden at runtime via Preferences (see MauiProgram).
/// </summary>
public static class AppConfig
{
    public const string DefaultApiBase = "http://localhost:5298";
    private const string PrefKey = "api_base";

    /// <summary>Resolved API base (with trailing slash trimmed).</summary>
    public static string ApiBase { get; private set; } = DefaultApiBase;

    /// <summary>Absolute SignalR hub URL.</summary>
    public static string HubUrl => ApiBase.TrimEnd('/') + "/hubs/chat";

    /// <summary>Load the overridden base (if any) from Preferences.</summary>
    public static void Load()
    {
        var saved = Microsoft.Maui.Storage.Preferences.Default.Get(PrefKey, string.Empty);
        if (!string.IsNullOrWhiteSpace(saved))
            ApiBase = saved.TrimEnd('/');
    }

    /// <summary>Persist an overridden base (blank resets to default).</summary>
    public static void Set(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            ApiBase = DefaultApiBase;
            Microsoft.Maui.Storage.Preferences.Default.Remove(PrefKey);
        }
        else
        {
            ApiBase = value.TrimEnd('/');
            Microsoft.Maui.Storage.Preferences.Default.Set(PrefKey, ApiBase);
        }
    }
}
