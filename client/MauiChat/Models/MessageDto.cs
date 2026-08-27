namespace MauiChat.Models;

/// <summary>
/// Matches server <c>MessageDto</c>:
/// id, conversationId, senderId, senderName, senderAvatar,
/// chatType ("Private"|"Group"), content, type ("Text"|"Image"|"File"),
/// mediaUrl, createdAt.
/// </summary>
public class MessageDto
{
    public Guid Id { get; set; }
    public string ConversationId { get; set; } = string.Empty;
    public Guid SenderId { get; set; }
    public string SenderName { get; set; } = string.Empty;
    public string? SenderAvatar { get; set; }
    public ChatType ChatType { get; set; }
    public string Content { get; set; } = string.Empty;
    public MessageType Type { get; set; }
    public string? MediaUrl { get; set; }
    public DateTime CreatedAt { get; set; }

    // ---- Client-side helpers (not sent to server) ----

    /// <summary>True when the current user is the sender (used for right-aligned bubbles).</summary>
    public bool IsMine { get; set; }

    public bool IsImage => Type == MessageType.Image;
    public bool IsText => Type == MessageType.Text;
    public bool IsFile => Type == MessageType.File;
}
