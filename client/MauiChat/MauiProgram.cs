using MauiChat.Config;
using MauiChat.Services;
using MauiChat.ViewModels;
using MauiChat.Views;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Maui;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Hosting;

namespace MauiChat;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        // Apply any persisted API base override (set via Preferences).
        AppConfig.Load();

        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>();

        // Register push-style routes once for the whole app lifetime.
        Routing.RegisterRoute("chat", typeof(ChatPage));
        Routing.RegisterRoute("addfriend", typeof(AddFriendPage));
        Routing.RegisterRoute("creategroup", typeof(CreateGroupPage));

        // ---- Services (singletons so the SignalR hub is app-wide) ----
        builder.Services.AddSingleton(new HttpClient());
        builder.Services.AddSingleton<ApiClient>();
        builder.Services.AddSingleton<AuthService>();
        builder.Services.AddSingleton<ChatHubClient>();

        // ---- ViewModels ----
        builder.Services.AddTransient<LoginViewModel>();
        builder.Services.AddTransient<ContactsViewModel>();
        builder.Services.AddTransient<ChatViewModel>();
        builder.Services.AddTransient<AddFriendViewModel>();
        builder.Services.AddTransient<CreateGroupViewModel>();

        // ---- Pages ----
        builder.Services.AddTransient<LoginPage>();
        builder.Services.AddTransient<ContactsPage>();
        builder.Services.AddTransient<ChatPage>();
        builder.Services.AddTransient<AddFriendPage>();
        builder.Services.AddTransient<CreateGroupPage>();

        var app = builder.Build();

        // Expose the DI container to pages/viewmodels (App.Services).
        App.Services = app.Services;

        return app;
    }
}
