using MauiChat.Models;
using MauiChat.ViewModels;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Maui.Controls;

namespace MauiChat.Views;

public partial class CreateGroupPage : ContentPage
{
    private readonly CreateGroupViewModel _vm;

    public CreateGroupPage()
    {
        InitializeComponent();
        _vm = App.Services.GetRequiredService<CreateGroupViewModel>();
        BindingContext = _vm;
    }

    protected override async void OnAppearing()
    {
        base.OnAppearing();
        await _vm.LoadAsync();
    }

    private void OnFriendTapped(object sender, ItemTappedEventArgs e)
    {
        if (e.TappedItem is SelectableUser item && _vm.ToggleCommand.CanExecute(item))
            _vm.ToggleCommand.Execute(item);
    }
}
