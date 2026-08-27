using MauiChat.Models;
using MauiChat.ViewModels;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Maui.Controls;

namespace MauiChat.Views;

public partial class ContactsPage : ContentPage
{
    private readonly ContactsViewModel _vm;

    public ContactsPage()
    {
        InitializeComponent();
        _vm = App.Services.GetRequiredService<ContactsViewModel>();
        BindingContext = _vm;
    }

    protected override async void OnAppearing()
    {
        base.OnAppearing();
        await _vm.LoadAsync();
    }

    private void OnContactTapped(object sender, ItemTappedEventArgs e)
    {
        if (e.TappedItem is ContactDto contact && _vm.OpenChatCommand.CanExecute(contact))
            _vm.OpenChatCommand.Execute(contact);
    }
}
