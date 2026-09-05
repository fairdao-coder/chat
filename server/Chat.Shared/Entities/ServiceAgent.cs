namespace Chat.Shared.Entities;

/// <summary>
/// 客服帳號表。客服本質仍是普通聊天用戶（AppUser），
/// 僅當其 Id 出現在 ServiceAgents 表時才被視為客服——用戶於「聯繫客服」時可免好友關係直接與其私聊。
/// 與 Users 表完全分離，避免污染通用用戶表結構；移除客服只需刪除此表記錄，用戶本體與歷史會話得以保留。
/// </summary>
public class ServiceAgent
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }

    /// <summary>成為客服的時間，用於後臺列表排序與審計。</summary>
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>對應的聊天用戶（僅供查詢導航，不參與級聯刪除）。</summary>
    public AppUser? User { get; set; }
}
