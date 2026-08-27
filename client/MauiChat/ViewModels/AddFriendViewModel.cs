using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MauiChat.Models;
using MauiChat.Services;
using Microsoft.Maui.Controls;

namespace MauiChat.ViewModels;

public partial class AddFriendViewModel : ObservableObject
{
    private readonly ApiClient _api;

    [ObservableProperty] private string _searchQuery = string.Empty;
    [ObservableProperty] private bool _isBusy;

    public ObservableCollection<UserDto> SearchResults { get; } = new();
    public ObservableCollection<FriendRequestDto> IncomingRequests { get; } = new();

    public AddFriendViewModel(ApiClient api) => _api = api;

    [RelayCommand]
    private async Task LoadRequestsAsync()
    {
        try
        {
            var requests = await _api.GetFriendRequestsAsync();
            IncomingRequests.Clear();
            foreach (var r in requests)
                IncomingRequests.Add(r);
        }
        catch (Exception ex)
        {
            await Shell.Current.DisplayAlert("Error", ex.Message, "OK");
        }
    }

    [RelayCommand]
    private async Task SearchAsync()
    {
        if (string.IsNullOrWhiteSpace(SearchQuery))
            return;

        IsBusy = true;
        try
        {
            var results = await _api.SearchUsersAsync(SearchQuery.Trim());
            SearchResults.Clear();
            foreach (var u in results)
                SearchResults.Add(u);
        }
        catch (Exception ex)
        {
            await Shell.Current.DisplayAlert("Error", ex.Message, "OK");
        }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task SendRequestAsync(UserDto user)
    {
        try
        {
            await _api.SendFriendRequestAsync(user.Id);
            await Shell.Current.DisplayAlert("Sent", $"Friend request sent to {user.NickName}.", "OK");
        }
        catch (Exception ex)
        {
            await Shell.Current.DisplayAlert("Error", ex.Message, "OK");
        }
    }

    [RelayCommand]
    private async Task AcceptAsync(FriendRequestDto req)
    {
        try
        {
            await _api.AcceptFriendRequestAsync(req.RequesterId);
            IncomingRequests.Remove(req);
            await Shell.Current.DisplayAlert("Accepted", $"You are now friends with {req.RequesterName}.", "OK");
        }
        catch (Exception ex)
        {
            await Shell.Current.DisplayAlert("Error", ex.Message, "OK");
        }
    }
}
