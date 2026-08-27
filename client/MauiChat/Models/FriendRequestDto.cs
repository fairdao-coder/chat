namespace MauiChat.Models;

/// <summary>
/// Shape of an incoming friend request from <c>GET /api/friends/requests</c>.
///
/// NOTE: ARCHITECTURE.md does not fully specify this payload. We assume the
/// server returns each request with an id, the requester's id and display
/// name, and a timestamp. Adjust the fields here if the server differs.
/// The accept endpoint (<c>POST /api/friends/accept</c>) only needs the
/// requester's Guid, which we map from <see cref="RequesterId"/>.
/// </summary>
public class FriendRequestDto
{
    public Guid Id { get; set; }
    public Guid RequesterId { get; set; }
    public string RequesterName { get; set; } = string.Empty;
    public DateTime RequestedAt { get; set; }
}
