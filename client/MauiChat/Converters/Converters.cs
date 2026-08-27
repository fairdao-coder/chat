using System.Globalization;
using MauiChat.Config;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Graphics;

namespace MauiChat.Converters;

/// <summary>
/// Turns a (relative) media URL returned by the server into a full
/// <see cref="ImageSource"/> by prefixing <see cref="AppConfig.ApiBase"/>.
/// Returns null when the value is empty so the bound Image collapses.
/// </summary>
public class MediaSourceConverter : IValueConverter
{
    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is not string s || string.IsNullOrWhiteSpace(s))
            return null;

        var url = s.StartsWith("http", StringComparison.OrdinalIgnoreCase)
            ? s
            : AppConfig.ApiBase.TrimEnd('/') + (s.StartsWith('/') ? s : "/" + s);

        return ImageSource.FromUri(new Uri(url));
    }

    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotSupportedException();
}

/// <summary>True → LayoutOptions.End (own messages, right aligned); False → Start.</summary>
public class BoolToEndConverter : IValueConverter
{
    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is true ? LayoutOptions.End : LayoutOptions.Start;

    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotSupportedException();
}

/// <summary>Online presence indicator: true → green, false → gray.</summary>
public class OnlineColorConverter : IValueConverter
{
    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is true ? Colors.LightGreen : Colors.LightGray;

    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotSupportedException();
}

/// <summary>Chat bubble background: own messages → light blue, others → light gray.</summary>
public class BubbleColorConverter : IValueConverter
{
    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is true ? Colors.LightBlue : Colors.LightGray;

    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotSupportedException();
}

/// <summary>Selection tick: true → "✓", false → empty string.</summary>
public class BoolToCheckConverter : IValueConverter
{
    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is true ? "✓" : string.Empty;

    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotSupportedException();
}
