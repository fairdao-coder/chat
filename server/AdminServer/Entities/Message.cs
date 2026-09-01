namespace AdminServer.Entities;

/// <summary>與 ChatServer 共享 Messages 表（統計用，由 AdminServer 負責建表）。</summary>
public class Message
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string ConversationId { get; set; } = default!;
    public Guid SenderId { get; set; }
    public AppUser Sender { get; set; } = default!;
    public ChatType ChatType { get; set; }
    public string Content { get; set; } = string.Empty;
    public MessageType Type { get; set; } = MessageType.Text;
    public string? MediaUrl { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public bool IsRead { get; set; }
}
