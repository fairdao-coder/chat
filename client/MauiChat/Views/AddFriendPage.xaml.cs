using MauiChat.Models;
using MauiChat.ViewModels;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Maui.Controls;

namespace MauiChat.Views;

public partial class AddFriendPage : ContentPage
{
    private readonly AddFriendViewModel _vm;

    public AddFriendPage()
    {
        InitializeComponent();
        _vm = App.Services.GetRequiredService<AddFriendViewModel>();
        BindingContext = _vm;
    }

    protected override async void OnAppearing()
    {
        base.OnAppearing();
        await _vm.LoadRequestsAsync();
    }

    private void OnAcceptClicked(object sender, EventArgs e)
    {
        if (((Button)sender).BindingContext is FriendRequestDto req && _vm.AcceptCommand.CanExecute(req))
            _vm.AcceptCommand.Execute(req);
    }

    private void OnSendRequestClicked(object sender, EventArgs e)
    {
        if (((Button)sender).BindingContext is UserDto user && _vm.SendRequestCommand.CanExecute(user))
            _vm.SendRequestCommand.Execute(user);
    }
}
