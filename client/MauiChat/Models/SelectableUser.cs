using CommunityToolkit.Mvvm.ComponentModel;

namespace MauiChat.Models;

/// <summary>Wrapper used by the "create group" UI to track selection state.</summary>
public partial class SelectableUser : ObservableObject
{
    public UserDto User { get; set; } = new();

    [ObservableProperty]
    private bool _isSelected;
}
