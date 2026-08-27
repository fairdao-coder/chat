namespace MauiChat.Models;

/// <summary>Matches server <c>UserDto</c>: id, userName, nickName, avatarUrl, isOnline, lastSeenAt.</summary>
public class UserDto
{
    public Guid Id { get; set; }
    public string UserName { get; set; } = string.Empty;
    public string NickName { get; set; } = string.Empty;
    public string? AvatarUrl { get; set; }
    public bool IsOnline { get; set; }
    public DateTime? LastSeenAt { get; set; }
}
