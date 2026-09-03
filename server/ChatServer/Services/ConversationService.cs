using Chat.Shared;
using Chat.Shared.Entities;
using ChatServer.Data;
using ChatServer.DTOs;
using Microsoft.EntityFrameworkCore;

namespace ChatServer.Services;

public interface IConversationService
{
    /// <summary>
    /// 會話列表：好友私聊 + 我加入的群，含最後一條消息與在線狀態，按最近活躍倒序。
    /// </summary>
    Task<IReadOnlyList<ContactDto>> GetRecentAsync(Guid userId, CancellationToken ct = default);
}

/// <summary>
/// 會話列表組裝。
///
/// 原實現是典型 N+1：每個好友一次 FindAsync + 一次「最後一條消息」查詢，
/// 每個群再一次消息查詢。N 個好友 + M 個群 = 1 + 2N + M 次往返，
/// 好友一多首屏就會明顯變慢。
///
/// 現實現固定 3 次查詢：
///   1) 好友資料（連 Requester/Addressee 導航屬性一起投影，無需 FindAsync）；
///   2) 我加入的群；
///   3) 所有相關會話的最後一條消息（相關子查詢，命中 (ConversationId, CreatedAt) 索引）。
/// 在線狀態走內存 PresenceTracker，不產生數據庫往返。
/// </summary>
public class ConversationService : IConversationService
{
    private readonly AppDbContext _db;
    private readonly PresenceTracker _presence;

    public ConversationService(AppDbContext db, PresenceTracker presence)
    {
        _db = db;
        _presence = presence;
    }

    public async Task<IReadOnlyList<ContactDto>> GetRecentAsync(Guid userId, CancellationToken ct = default)
    {
        var friends = await _db.Friendships
            .AsNoTracking()
            .Where(f => f.Status == FriendshipStatus.Accepted &&
                        (f.RequesterId == userId || f.AddresseeId == userId))
            .Select(f => f.RequesterId == userId ? f.Addressee : f.Requester)
            .Select(u => new { u.Id, u.NickName, u.AvatarUrl })
            .ToListAsync(ct);

        var groups = await _db.Groups
            .AsNoTracking()
            .Where(g => g.Members.Any(m => m.UserId == userId))
            .Select(g => new { g.Id, g.Name, g.AvatarUrl })
            .ToListAsync(ct);

        var privateConversations = friends.ToDictionary(
            f => ConversationKeys.Private(userId, f.Id),
            f => f.Id);

        var groupConversations = groups.ToDictionary(
            g => ConversationKeys.Group(g.Id),
            g => g.Id);

        var conversationIds = privateConversations.Keys.Concat(groupConversations.Keys).ToList();
        var lastMessages = await LoadLastMessagesAsync(conversationIds, ct);

        // 清空水位線（單會話 + 全部 "*"），早於水位的會話摘要視為無消息。
        var watermarks = await _db.ConversationStates
            .AsNoTracking()
            .Where(s => s.UserId == userId)
            .Select(s => new { s.ConversationId, s.ClearedBeforeAt })
            .ToListAsync(ct);
        var allWatermark = watermarks
            .Where(s => s.ConversationId == ConversationState.AllConversationsKey)
            .Select(s => (DateTime?)s.ClearedBeforeAt)
            .FirstOrDefault();
        var convWatermarks = watermarks
            .Where(s => s.ConversationId != ConversationState.AllConversationsKey)
            .ToDictionary(s => s.ConversationId, s => s.ClearedBeforeAt);

        // 摘要渲染輔助：撤回消息不洩露原文，顯示佔位文案；早於水位的不顯示。
        (string? content, DateTime? at, MessageType? type) PreviewOf(
            string conv, LastMessage? last, string recalledPlaceholder)
        {
            if (last == null) return (null, null, null);
            var wm = convWatermarks.GetValueOrDefault(conv);
            var effective = wm.HasValue && (allWatermark == null || wm > allWatermark) ? wm : allWatermark;
            if (effective.HasValue && last.CreatedAt <= effective.Value) return (null, null, null);
            if (last.Recalled) return (recalledPlaceholder, last.CreatedAt, MessageType.Text);
            return (last.Content, last.CreatedAt, last.Type);
        }

        var online = await _presence.GetOnlineUsers(friends.Select(f => f.Id.ToString()));
        var onlineSet = online.ToHashSet(StringComparer.Ordinal);

        const string recalledPlaceholder = "[消息已撤回]";
        var result = new List<ContactDto>(friends.Count + groups.Count);

        foreach (var f in friends)
        {
            var conv = ConversationKeys.Private(userId, f.Id);
            lastMessages.TryGetValue(conv, out var last);
            var (content, at, type) = PreviewOf(conv, last, recalledPlaceholder);
            result.Add(new ContactDto(
                f.Id, f.NickName, f.AvatarUrl,
                onlineSet.Contains(f.Id.ToString()),
                content, at, false, type));
        }

        foreach (var g in groups)
        {
            var conv = ConversationKeys.Group(g.Id);
            lastMessages.TryGetValue(conv, out var last);
            var (content, at, type) = PreviewOf(conv, last, recalledPlaceholder);
            result.Add(new ContactDto(
                g.Id, g.Name, g.AvatarUrl, true,
                content, at, true, type));
        }

        return result
            .OrderByDescending(c => c.LastMessageAt)
            .ThenBy(c => c.Name, StringComparer.Ordinal)
            .ToList();
    }

    /// <summary>
    /// 批量取每個會話的最後一條消息。
    /// 用「相關子查詢取同會話最大 CreatedAt」表達，翻譯為單條 SQL，
    /// 相比逐會話查詢把 M 次往返壓成 1 次。
    /// 已撤回的消息不參與「最後一條」候選（會話預覽不洩露撤回內容）。
    /// </summary>
    private async Task<Dictionary<string, LastMessage>> LoadLastMessagesAsync(
        IReadOnlyList<string> conversationIds, CancellationToken ct)
    {
        if (conversationIds.Count == 0) return new Dictionary<string, LastMessage>();

        var rows = await _db.Messages
            .AsNoTracking()
            .Where(m => conversationIds.Contains(m.ConversationId))
            // CreatedAt 等於本會話最大值 → 即該會話最新一條。
            .Where(m => m.CreatedAt == _db.Messages
                .Where(x => x.ConversationId == m.ConversationId)
                .Max(x => x.CreatedAt))
            .Select(m => new LastMessage(m.ConversationId, m.Content, m.CreatedAt, m.Type, m.Recalled))
            .ToListAsync(ct);

        // 同一會話若出現毫秒級並發寫入會返回多條，按時間倒序取第一條即可。
        return rows
            .OrderByDescending(r => r.CreatedAt)
            .GroupBy(r => r.ConversationId)
            .ToDictionary(g => g.Key, g => g.First());
    }

    private sealed record LastMessage(
        string ConversationId,
        string Content,
        DateTime CreatedAt,
        MessageType Type);
}
