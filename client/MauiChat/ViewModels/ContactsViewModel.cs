using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MauiChat.Models;
using MauiChat.Services;
using MauiChat.Views;
using Microsoft.Maui;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.Controls;

namespace MauiChat.ViewModels;

public partial class ContactsViewModel : ObservableObject
{
    private readonly ApiClient _api;
    private readonly ChatHubClient _hub;
    private readonly AuthService _auth;

    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private UserDto? _currentUser;

    public ObservableCollection<ContactDto> Contacts { get; } = new();

    public ContactsViewModel(ApiClient api, ChatHubClient hub, AuthService auth)
    {
        _api = api;
        _hub = hub;
        _auth = auth;

        // Keep online status in sync with live SignalR presence events.
        _hub.UserOnline += OnUserOnline;
        _hub.UserOffline += OnUserOffline;
    }

    private void OnUserOnline(string userId)
        => ApplyPresence(userId, true);

    private void OnUserOffline(string userId)
        => ApplyPresence(userId, false);

    private void ApplyPresence(string userId, bool online)
    {
        // Only private contacts have a user-id; groups have no presence.
        MainThread.BeginInvokeOnMainThread(() =>
        {
            var c = Contacts.FirstOrDefault(x => !x.IsGroup && x.Id == userId);
            if (c is not null) c.IsOnline = online;
        });
    }

    [RelayCommand]
    public async Task LoadAsync()
    {
        if (IsBusy) return;
        IsBusy = true;
        try
        {
            CurrentUser = await _auth.GetUserAsync();
            var list = await _api.GetConversationsAsync();
            Contacts.Clear();
            foreach (var c in list)
                Contacts.Add(c);
        }
        catch (Exception ex)
        {
            await Shell.Current.DisplayAlert("Error", ex.Message, "OK");
        }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task OpenChatAsync(ContactDto contact)
    {
        var name = Uri.EscapeDataString(contact.Name);
        await Shell.Current.GoToAsync($"chat?contactId={contact.Id}&isGroup={contact.IsGroup}&name={name}");
    }

    [RelayCommand]
    private async Task GoAddFriendAsync()
        => await Shell.Current.GoToAsync("addfriend");

    [RelayCommand]
    private async Task GoCreateGroupAsync()
        => await Shell.Current.GoToAsync("creategroup");

    [RelayCommand]
    private async Task LogoutAsync()
    {
        await _hub.DisconnectAsync();
        await _auth.LogoutAsync();
        Application.Current!.MainPage = new NavigationPage(new LoginPage());
    }
}
