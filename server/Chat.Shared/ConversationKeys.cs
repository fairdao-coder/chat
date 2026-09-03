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

    /// <summary>
    /// 從私聊會話 Id 解析出「對方」的用戶 Id。
    /// 形如 p_{idA}_{idB}（兩 Id 字符串升序），已知其中一方 [selfId] 時取另一方。
    /// 解析失敗（非私聊格式 / 不含 selfId）返回 false。
    /// </summary>
    public static bool TryParsePeer(string conversationId, Guid selfId, out Guid peer)
    {
        peer = Guid.Empty;
        if (string.IsNullOrEmpty(conversationId) || conversationId[0] != 'p') return false;

        var parts = conversationId.Split('_');
        if (parts.Length != 3) return false;

        if (!Guid.TryParse(parts[1], out var a) || !Guid.TryParse(parts[2], out var b))
            return false;

        if (a == selfId && b != selfId) { peer = b; return true; }
        if (b == selfId && a != selfId) { peer = a; return true; }
        return false;
    }
}
