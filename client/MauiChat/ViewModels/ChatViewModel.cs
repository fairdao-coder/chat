using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MauiChat.Models;
using MauiChat.Services;
using Microsoft.Maui;
using Microsoft.Maui.ApplicationModel;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Media;
using Microsoft.Maui.Storage;

namespace MauiChat.ViewModels;

public partial class ChatViewModel : ObservableObject
{
    private readonly ApiClient _api;
    private readonly ChatHubClient _hub;
    private readonly AuthService _auth;

    private Guid _currentUserId;
    private string _targetId = string.Empty;
    private bool _isGroup;
    private string _conversationId = string.Empty;
    private bool _initialized;

    [ObservableProperty] private string _title = string.Empty;
    [ObservableProperty] private string _draft = string.Empty;
    [ObservableProperty] private bool _isBusy;

    public ObservableCollection<MessageDto> Messages { get; } = new();

    public ChatViewModel(ApiClient api, ChatHubClient hub, AuthService auth)
    {
        _api = api;
        _hub = hub;
        _auth = auth;

        _hub.ReceiveMessage += OnReceiveMessage;
    }

    /// <summary>Called by <see cref="Views.ChatPage"/> once query parameters are set.</summary>
    public async Task InitializeAsync(string contactId, bool isGroup, string name)
    {
        if (_initialized && _conversationId == ComputeConversationId(contactId, isGroup))
            return;

        _initialized = true;
        _targetId = contactId;
        _isGroup = isGroup;
        Title = name;

        var user = await _auth.GetUserAsync();
        _currentUserId = user?.Id ?? Guid.Empty;
        _conversationId = ComputeConversationId(contactId, isGroup);

        Messages.Clear();
        await LoadHistoryAsync();

        // Ensure the hub has joined the group's SignalR channel.
        if (_isGroup)
            await _hub.JoinGroupAsync(_targetId);
    }

    private string ComputeConversationId(string id, bool group)
    {
        if (group)
            return $"g_{id}";

        // Private: p_{guidA}_{guidB} with ids sorted ascending (per ARCHITECTURE.md).
        var ids = new[] { _currentUserId.ToString(), id };
        Array.Sort(ids, StringComparer.Ordinal);
        return "p_" + string.Join("_", ids);
    }

    private async Task LoadHistoryAsync()
    {
        IsBusy = true;
        try
        {
            List<MessageDto> history = _isGroup
                ? await _api.GetGroupHistoryAsync(Guid.Parse(_targetId))
                : await _api.GetPrivateHistoryAsync(Guid.Parse(_targetId));

            foreach (var m in history)
                AppendMessage(m);
        }
        catch (Exception ex)
        {
            await Shell.Current.DisplayAlert("Error", ex.Message, "OK");
        }
        finally { IsBusy = false; }
    }

    private void OnReceiveMessage(MessageDto m)
    {
        // Be robust against the exact server conversation-id format: filter by
        // chat type + participants rather than relying solely on the string id.
        if (_isGroup)
        {
            if (m.ChatType == ChatType.Group && m.ConversationId == _conversationId)
                MainThread.BeginInvokeOnMainThread(() => AppendMessage(m));
        }
        else if (m.ChatType == ChatType.Private)
        {
            var other = Guid.Parse(_targetId);
            if (m.SenderId == _currentUserId || m.SenderId == other)
                MainThread.BeginInvokeOnMainThread(() => AppendMessage(m));
        }
    }

    private void AppendMessage(MessageDto m)
    {
        if (Messages.Any(x => x.Id == m.Id))
            return; // dedupe (server echoes to sender too)

        m.IsMine = m.SenderId == _currentUserId;
        Messages.Add(m);
    }

    [RelayCommand]
    private async Task SendAsync()
    {
        var text = Draft?.Trim();
        if (string.IsNullOrEmpty(text))
            return;

        Draft = string.Empty;

        try
        {
            if (_isGroup)
                await _hub.SendGroupMessageAsync(_targetId, text, MessageType.Text);
            else
                await _hub.SendPrivateMessageAsync(_targetId, text, MessageType.Text);
            // The server echoes ReceiveMessage to the sender; we render on receipt.
        }
        catch (Exception ex)
        {
            await Shell.Current.DisplayAlert("Send failed", ex.Message, "OK");
        }
    }

    [RelayCommand]
    private async Task PickImageAsync()
    {
        try
        {
            var file = await MediaPicker.Default.PickPhotoAsync();
            if (file is not null)
                await UploadAndSendAsync(file, MessageType.Image);
        }
        catch (Exception ex)
        {
            await Shell.Current.DisplayAlert("Pick failed", ex.Message, "OK");
        }
    }

    [RelayCommand]
    private async Task PickFileAsync()
    {
        try
        {
            var file = await FilePicker.Default.PickAsync();
            if (file is not null)
                await UploadAndSendAsync(file, MessageType.File);
        }
        catch (Exception ex)
        {
            await Shell.Current.DisplayAlert("Pick failed", ex.Message, "OK");
        }
    }

    private async Task UploadAndSendAsync(FileResult file, MessageType type)
    {
        try
        {
            await using var stream = await file.OpenReadAsync();
            var upload = await _api.UploadFileAsync(
                stream, file.FileName ?? "file", file.ContentType ?? "application/octet-stream");

            if (_isGroup)
                await _hub.SendGroupMessageAsync(_targetId, file.FileName ?? "", type, upload.Url);
            else
                await _hub.SendPrivateMessageAsync(_targetId, file.FileName ?? "", type, upload.Url);
        }
        catch (Exception ex)
        {
            await Shell.Current.DisplayAlert("Upload failed", ex.Message, "OK");
        }
    }
}
