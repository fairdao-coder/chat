using MauiChat.ViewModels;
using Microsoft.Extensions.DependencyInjection;

namespace MauiChat.Views;

public partial class LoginPage : ContentPage
{
    public LoginPage()
    {
        InitializeComponent();
        BindingContext = App.Services.GetRequiredService<LoginViewModel>();
    }
}
