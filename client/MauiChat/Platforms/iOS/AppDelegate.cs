using Foundation;
using Microsoft.Maui;
using UIKit;

namespace MauiChat;

[Register("AppDelegate")]
public class AppDelegate : MauiUIApplicationDelegate
{
    protected override MauiApp CreateMauiApp() => MauiProgram.CreateMauiApp();
}
