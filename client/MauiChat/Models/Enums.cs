using System.Text.Json.Serialization;

namespace MauiChat.Models;

/// <summary>Chat scope. Serialized as "Private" / "Group" to match the server.</summary>
[JsonConverter(typeof(JsonStringEnumConverter))]
public enum ChatType
{
    Private,
    Group
}

/// <summary>Message kind. Serialized as "Text" / "Image" / "File" to match the server.</summary>
[JsonConverter(typeof(JsonStringEnumConverter))]
public enum MessageType
{
    Text,
    Image,
    File
}
