using MauiChat.ViewModels;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Maui.Controls;

namespace MauiChat.Views;

public partial class ChatPage : ContentPage
{
    private readonly ChatViewModel _vm;
    private bool _loaded;

    public ChatPage()
    {
        InitializeComponent();
        _vm = App.Services.GetRequiredService<ChatViewModel>();
        BindingContext = _vm;
    }

    // Shell query parameters (set before OnAppearing).
    [QueryProperty(nameof(ContactId), "contactId")]
    [QueryProperty(nameof(IsGroup), "isGroup")]
    [QueryProperty(nameof(ContactName), "name")]
    public string ContactId { get; set; } = string.Empty;
    public bool IsGroup { get; set; }
    public string ContactName { get; set; } = string.Empty;

    protected override async void OnAppearing()
    {
        base.OnAppearing();
        if (!_loaded)
        {
            _loaded = true;
            await _vm.InitializeAsync(ContactId, IsGroup, Uri.UnescapeDataString(ContactName));
        }
    }
}
