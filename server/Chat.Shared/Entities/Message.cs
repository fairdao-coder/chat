namespace Chat.Shared.Entities;

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

    /// <summary>
    /// 是否已被發送者撤回。撤回後消息記錄保留（引用它的消息可顯示「原消息已撤回」），
    /// 但正文不再下發。
    /// </summary>
    public bool Recalled { get; set; }

    /// <summary>撤回時間；null 表示未撤回。</summary>
    public DateTime? RecalledAt { get; set; }

    /// <summary>
    /// 引用（回覆）的原消息 Id；null 表示普通消息。
    /// 引用目標必須與本消息同屬一個會話（服務端校驗）。
    /// </summary>
    public Guid? ReplyToId { get; set; }
}
