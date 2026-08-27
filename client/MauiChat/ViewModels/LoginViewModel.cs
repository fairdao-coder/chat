using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MauiChat.Services;
using MauiChat.Views;
using Microsoft.Maui.Controls;

namespace MauiChat.ViewModels;

public partial class LoginViewModel : ObservableObject
{
    private readonly AuthService _auth;
    private readonly ChatHubClient _hub;

    [ObservableProperty] private string _userName = string.Empty;
    [ObservableProperty] private string _password = string.Empty;
    [ObservableProperty] private string _nickName = string.Empty;
    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private bool _isError;
    [ObservableProperty] private string _errorMessage = string.Empty;

    public LoginViewModel(AuthService auth, ChatHubClient hub)
    {
        _auth = auth;
        _hub = hub;
    }

    [RelayCommand]
    private async Task LoginAsync()
    {
        if (IsBusy) return;
        IsBusy = true; IsError = false;
        try
        {
            var result = await _auth.LoginAsync(UserName.Trim(), Password);
            await _hub.ConnectAsync(result.Token);
            Application.Current!.MainPage = new AppShell();
        }
        catch (Exception ex)
        {
            IsError = true;
            ErrorMessage = ex.Message;
        }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task RegisterAsync()
    {
        if (IsBusy) return;
        IsBusy = true; IsError = false;
        try
        {
            var result = await _auth.RegisterAsync(UserName.Trim(), Password, NickName.Trim());
            await _hub.ConnectAsync(result.Token);
            Application.Current!.MainPage = new AppShell();
        }
        catch (Exception ex)
        {
            IsError = true;
            ErrorMessage = ex.Message;
        }
        finally { IsBusy = false; }
    }
}
