using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MauiChat.Models;
using MauiChat.Services;
using Microsoft.Maui.Controls;

namespace MauiChat.ViewModels;

public partial class CreateGroupViewModel : ObservableObject
{
    private readonly ApiClient _api;

    [ObservableProperty] private string _groupName = string.Empty;
    [ObservableProperty] private bool _isBusy;

    public ObservableCollection<SelectableUser> Friends { get; } = new();

    public CreateGroupViewModel(ApiClient api) => _api = api;

    [RelayCommand]
    public async Task LoadAsync()
    {
        try
        {
            var list = await _api.GetFriendsAsync();
            Friends.Clear();
            foreach (var f in list)
                Friends.Add(new SelectableUser { User = f });
        }
        catch (Exception ex)
        {
            await Shell.Current.DisplayAlert("Error", ex.Message, "OK");
        }
    }

    [RelayCommand]
    private void Toggle(SelectableUser item)
        => item.IsSelected = !item.IsSelected;

    [RelayCommand]
    private async Task CreateAsync()
    {
        if (string.IsNullOrWhiteSpace(GroupName))
        {
            await Shell.Current.DisplayAlert("Name required", "Please enter a group name.", "OK");
            return;
        }

        var memberIds = Friends.Where(f => f.IsSelected).Select(f => f.User.Id).ToList();
        if (memberIds.Count == 0)
        {
            await Shell.Current.DisplayAlert("Members required", "Select at least one friend.", "OK");
            return;
        }

        IsBusy = true;
        try
        {
            await _api.CreateGroupAsync(GroupName.Trim(), memberIds);
            await Shell.Current.DisplayAlert("Created", "Group created.", "OK");
            await Shell.Current.GoToAsync(".."); // back to contacts
        }
        catch (Exception ex)
        {
            await Shell.Current.DisplayAlert("Error", ex.Message, "OK");
        }
        finally { IsBusy = false; }
    }
}
