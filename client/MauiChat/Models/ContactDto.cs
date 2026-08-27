using CommunityToolkit.Mvvm.ComponentModel;

namespace MauiChat.Models;

/// <summary>
/// Matches server <c>ContactDto</c>:
/// id, name, avatarUrl, isOnline, lastMessage, lastMessageAt, isGroup.
///
/// <see cref="Id"/> is a string so it can hold either a friend's user-id
/// (Guid) for a private chat, or a group-id for a group chat.
///
/// Implemented as <see cref="ObservableObject"/> because <see cref="IsOnline"/>
/// is updated in-place from live SignalR presence events.
/// </summary>
public partial class ContactDto : ObservableObject
{
    [ObservableProperty] private string _id = string.Empty;
    [ObservableProperty] private string _name = string.Empty;
    [ObservableProperty] private string? _avatarUrl;
    [ObservableProperty] private bool _isOnline;
    [ObservableProperty] private string? _lastMessage;
    [ObservableProperty] private DateTime? _lastMessageAt;
    [ObservableProperty] private bool _isGroup;
}
