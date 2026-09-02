namespace Chat.Shared;

/// <summary>
/// 會話 ID 生成規則（客戶端可本地推算，用於去重/歷史拼接）。
/// 私聊: p_{guidA}_{guidB}（兩 ID 按字符串升序）
/// 群聊: g_{groupId}
/// </summary>
public static class ConversationKeys
{
    public static string Private(Guid a, Guid b)
    {
        var (x, y) = a.CompareTo(b) < 0 ? (a, b) : (b, a);
        return $"p_{x}_{y}";
    }

    public static string Group(Guid groupId) => $"g_{groupId}";
}
