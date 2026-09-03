using System.ComponentModel.DataAnnotations;

namespace Chat.Shared.Entities;

/// <summary>
/// 按用戶隱藏的單條消息（「刪除」語義：僅自己不再顯示，對方不受影響）。
/// 歷史查詢按 (UserId, MessageId) 過濾。
/// </summary>
public class MessageHide
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>執行刪除的用戶。</summary>
    public Guid UserId { get; set; }

    /// <summary>被隱藏的消息。</summary>
    public Guid MessageId { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// 用戶級會話狀態：清空聊天記錄的水位線。
/// 歷史查詢只返回 CreatedAt &gt; ClearedBeforeAt 的消息，實現「僅清空自己視角」。
/// </summary>
public class ConversationState
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>所屬用戶。</summary>
    public Guid UserId { get; set; }

    /// <summary>
    /// 會話標識（ConversationKeys 產物）。
    /// 特殊值 <see cref="AllConversationsKey"/> 表示「全部會話」（一鍵清除所有聊天記錄）。
    /// </summary>
    public string ConversationId { get; set; } = default!;

    /// <summary>清空時間（水位線）：只顯示晚於該時刻的消息。</summary>
    public DateTime ClearedBeforeAt { get; set; } = DateTime.UtcNow;

    /// <summary>「全部會話」的保留鍵。</summary>
    public const string AllConversationsKey = "*";
}
