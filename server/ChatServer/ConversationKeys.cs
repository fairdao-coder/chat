using System;

namespace ChatServer;

/// <summary>
/// 会话 ID 生成规则（客户端可本地推算，用于去重/历史拼接）。
/// 私聊: p_{guidA}_{guidB}（两 ID 按字符串升序）
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
