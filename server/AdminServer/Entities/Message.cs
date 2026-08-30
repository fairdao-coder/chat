namespace AdminServer.Entities;

/// <summary>与 ChatServer 共享 Messages 表（统计用）。</summary>
public class Message
{
    public Guid Id { get; set; }
    public string ConversationId { get; set; } = default!;
    public Guid SenderId { get; set; }
    public ChatType ChatType { get; set; }
    public string Content { get; set; } = string.Empty;
    public MessageType Type { get; set; }
    public string? MediaUrl { get; set; }
    public DateTime CreatedAt { get; set; }
    public bool IsRead { get; set; }
}
