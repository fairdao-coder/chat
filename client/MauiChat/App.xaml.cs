using MauiChat.Services;
using MauiChat.Views;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Maui.Controls;

namespace MauiChat;

public partial class App : Application
{
    /// <summary>DI container, populated in <see cref="MauiProgram.CreateMauiApp"/>.</summary>
    public static IServiceProvider Services { get; set; } = null!;

    public App()
    {
        InitializeComponent();

        // Placeholder until OnStart decides login vs. main shell.
        // (Avoids resolving pages here, before the DI container is ready.)
        MainPage = new ContentPage
        {
            Title = "MauiChat",
            Content = new ActivityIndicator { IsRunning = true, VerticalOptions = LayoutOptions.Center }
        };
    }

    protected override async void OnStart()
    {
        var auth = Services.GetRequiredService<AuthService>();
        var hub = Services.GetRequiredService<ChatHubClient>();

        if (await auth.IsAuthenticatedAsync())
        {
            var token = await auth.GetTokenAsync();
            try
            {
                if (!string.IsNullOrEmpty(token))
                    await hub.ConnectAsync(token);
            }
            catch
            {
                // Offline at launch; the hub will auto-reconnect when reachable.
            }

            MainPage = new AppShell();
        }
        else
        {
            MainPage = new NavigationPage(new LoginPage());
        }
    }
}
