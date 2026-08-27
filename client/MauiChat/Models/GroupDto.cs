namespace MauiChat.Models;

/// <summary>Matches server <c>GroupDto</c>: id, name, avatarUrl, memberCount, createdAt.</summary>
public class GroupDto
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? AvatarUrl { get; set; }
    public int MemberCount { get; set; }
    public DateTime CreatedAt { get; set; }
}
