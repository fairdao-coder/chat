using Chat.Shared;
using Chat.Shared.Entities;
using ChatServer.Data;
using ChatServer.DTOs;
using Microsoft.EntityFrameworkCore;

namespace ChatServer.Services;

/// <summary>
/// 消息發送失敗，且失敗原因需要客戶端據此引導用戶操作時拋出。
/// [Code] 為客戶端可解析的穩定錯誤碼（E_FRIEND_REQUIRED 等）。
/// </summary>
public sealed class MessageSendException : Exception
{
    public string Code { get; }

    public MessageSendException(string code, string message) : base(message) => Code = code;

    public string ToWireMessage() => $"{Code}: {Message}";
}

public interface IMessageService
{
    Task<MessageDto> SendPrivateAsync(
        Guid fromId, string toUserId, string content, MessageType type, string? mediaUrl,
        Guid? replyToId = null, CancellationToken ct = default);

    Task<MessageDto> SendGroupAsync(
        Guid fromId, string groupId, string content, MessageType type, string? mediaUrl,
        Guid? replyToId = default, CancellationToken ct = default);

    /// <param name="userId">當前用戶：歷史按其視角過濾（已刪除的消息 + 清空水位線之前的不返回）。</param>
    Task<IReadOnlyList<MessageDto>> GetHistoryAsync(
        string conversationId, DateTime? before, int count, Guid userId, CancellationToken ct = default);

    /// <summary>撤回自己發出的消息（限時）。成功返回廣播所需的會話信息。</summary>
    Task<RecallResult> RecallAsync(Guid userId, Guid messageId, CancellationToken ct = default);

    /// <summary>刪除（僅自己不再顯示）一條消息。</summary>
    Task HideAsync(Guid userId, Guid messageId, CancellationToken ct = default);

    /// <summary>清空單個會話的聊天記錄（僅自己的視角，水位線之前的不再顯示）。</summary>
    Task ClearConversationAsync(Guid userId, string conversationId, CancellationToken ct = default);

    /// <summary>清除所有會話的聊天記錄（僅自己的視角）。</summary>
    Task ClearAllAsync(Guid userId, CancellationToken ct = default);
}

/// <summary>撤回成功後的廣播信息：Hub 據此選擇私聊對端或群頻道推送。</summary>
public sealed record RecallResult(MessageDto Dto, bool IsGroup, string? PeerUserId);

/// <summary>
/// 消息落庫與校驗。
///
/// 此前 ChatHub 與 MessagesController 各自實現了一套「校驗好友 → 落庫 → 映射」，
/// 邏輯分散且錯誤碼不一致。統一到這裡後，SignalR 與 REST 兩條通道行為完全一致。
/// </summary>
public class MessageService : IMessageService
{
    /// <summary>單次拉取歷史消息的最大條數，防止客戶端傳超大 count 拖垮數據庫。</summary>
    private const int MaxHistoryCount = 100;

    /// <summary>撤回時限：發出後 2 分鐘內可撤回（微信慣例）。</summary>
    private static readonly TimeSpan RecallWindow = TimeSpan.FromMinutes(2);

    private readonly AppDbContext _db;
    private readonly IMessageMapper _mapper;

    public MessageService(AppDbContext db, IMessageMapper mapper)
    {
        _db = db;
        _mapper = mapper;
    }

    public async Task<MessageDto> SendPrivateAsync(
        Guid fromId, string toUserId, string content, MessageType type, string? mediaUrl,
        Guid? replyToId = null, CancellationToken ct = default)
    {
        if (!Guid.TryParse(toUserId, out var toId) || toId == Guid.Empty)
            throw new MessageSendException("E_BAD_TARGET", "收件人 ID 格式不正確");

        var toUser = await _db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == toId, ct);
        if (toUser == null)
            throw new MessageSendException("E_TARGET_NOT_FOUND", "對方用戶不存在");

        // 客服帳號（出現在 ServiceAgents 表）免好友關係即可與用戶私聊；其餘私聊必須為好友。
        var isService = await _db.ServiceAgents.AsNoTracking().AnyAsync(s => s.UserId == toId, ct);
        if (!isService)
        {
            var areFriends = await _db.Friendships
                .AsNoTracking()
                .AnyAsync(f => f.Status == FriendshipStatus.Accepted &&
                               ((f.RequesterId == fromId && f.AddresseeId == toId) ||
                                (f.RequesterId == toId && f.AddresseeId == fromId)), ct);
            if (!areFriends)
                throw new MessageSendException("E_FRIEND_REQUIRED", "你們還不是好友，無法發送消息。先添加對方為好友後再聊吧～");
        }

        EnsureNotEmpty(content, mediaUrl);

        var msg = new Message
        {
            ConversationId = ConversationKeys.Private(fromId, toId),
            SenderId = fromId,
            ChatType = ChatType.Private,
            Content = content ?? string.Empty,
            Type = type,
            MediaUrl = mediaUrl
        };

        await ValidateReplyAsync(msg, replyToId, ct);
        return await PersistAsync(msg, ct);
    }

    public async Task<MessageDto> SendGroupAsync(
        Guid fromId, string groupId, string content, MessageType type, string? mediaUrl,
        Guid? replyToId = default, CancellationToken ct = default)
    {
        if (!Guid.TryParse(groupId, out var gid) || gid == Guid.Empty)
            throw new MessageSendException("E_BAD_TARGET", "群 ID 格式不正確");

        // 一次查詢同時判定「群是否存在」與「我是否成員」，避免兩次往返。
        var group = await _db.Groups
            .AsNoTracking()
            .Where(g => g.Id == gid)
            .Select(g => new { g.Id, IsMember = g.Members.Any(m => m.UserId == fromId) })
            .FirstOrDefaultAsync(ct);

        if (group is null)
            throw new MessageSendException("E_TARGET_NOT_FOUND", "群不存在");

        if (!group.IsMember)
            throw new MessageSendException("E_FRIEND_REQUIRED", "你不在該群，無法發送消息");

        EnsureNotEmpty(content, mediaUrl);

        var msg = new Message
        {
            ConversationId = ConversationKeys.Group(gid),
            SenderId = fromId,
            ChatType = ChatType.Group,
            Content = content ?? string.Empty,
            Type = type,
            MediaUrl = mediaUrl
        };

        await ValidateReplyAsync(msg, replyToId, ct);
        return await PersistAsync(msg, ct);
    }

    public async Task<IReadOnlyList<MessageDto>> GetHistoryAsync(
        string conversationId, DateTime? before, int count, Guid userId, CancellationToken ct = default)
    {
        // 歷史消息按時間倒序取最新 count 條，再翻正為正序返回，客戶端從舊到新渲染。
        var take = Math.Clamp(count, 1, MaxHistoryCount);

        var query = _db.Messages.AsNoTracking().Where(m => m.ConversationId == conversationId);
        if (before.HasValue) query = query.Where(m => m.CreatedAt < before.Value);

        // 「清空聊天記錄」水位線：單會話水位與全部會話水位取較新者，
        // 晚於水位的消息才對該用戶可見。
        var watermark = await GetClearWatermarkAsync(userId, conversationId, ct);
        if (watermark.HasValue)
            query = query.Where(m => m.CreatedAt > watermark.Value);

        // 「刪除」過濾：自己隱藏過的消息不再返回（其他會話參與者不受影響）。
        query = query.Where(m =>
            !_db.MessageHides.Any(h => h.UserId == userId && h.MessageId == m.Id));

        var messages = await query
            .OrderByDescending(m => m.CreatedAt)
            .Take(take)
            .ToListAsync(ct);

        messages.Reverse();
        return await _mapper.MapAsync(messages, ct);
    }

    public async Task<RecallResult> RecallAsync(Guid userId, Guid messageId, CancellationToken ct = default)
    {
        var msg = await _db.Messages.FirstOrDefaultAsync(m => m.Id == messageId, ct);
        if (msg == null)
            throw new MessageSendException("E_TARGET_NOT_FOUND", "消息不存在或已被刪除");

        // 只有發送者能撤回自己的消息。
        if (msg.SenderId != userId)
            throw new MessageSendException("E_FORBIDDEN", "只能撤回自己發送的消息");

        if (msg.Recalled)
        {
            // 冪等：重複撤回直接按已撤回返回（客戶端刷新視圖）。
            return await BuildRecallResultAsync(msg, ct);
        }

        if (DateTime.UtcNow - msg.CreatedAt > RecallWindow)
            throw new MessageSendException("E_RECALL_TIMEOUT", "超過時限，無法撤回");

        msg.Recalled = true;
        msg.RecalledAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);
        return await BuildRecallResultAsync(msg, ct);
    }

    public async Task HideAsync(Guid userId, Guid messageId, CancellationToken ct = default)
    {
        var exists = await _db.Messages.AsNoTracking().AnyAsync(m => m.Id == messageId, ct);
        if (!exists)
            throw new MessageSendException("E_TARGET_NOT_FOUND", "消息不存在或已被刪除");

        var already = await _db.MessageHides
            .AnyAsync(h => h.UserId == userId && h.MessageId == messageId, ct);
        if (already) return;

        _db.MessageHides.Add(new MessageHide { UserId = userId, MessageId = messageId });
        await _db.SaveChangesAsync(ct);
    }

    public async Task ClearConversationAsync(Guid userId, string conversationId, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(conversationId))
            throw new MessageSendException("E_BAD_TARGET", "會話標識無效");

        var state = await _db.ConversationStates
            .FirstOrDefaultAsync(s => s.UserId == userId && s.ConversationId == conversationId, ct);
        if (state != null)
        {
            state.ClearedBeforeAt = DateTime.UtcNow;
        }
        else
        {
            _db.ConversationStates.Add(new ConversationState
            {
                UserId = userId,
                ConversationId = conversationId,
                ClearedBeforeAt = DateTime.UtcNow,
            });
        }
        await _db.SaveChangesAsync(ct);
    }

    public async Task ClearAllAsync(Guid userId, CancellationToken ct = default)
    {
        await ClearConversationAsync(userId, ConversationState.AllConversationsKey, ct);
    }

    /// <summary>取單會話的生效水位線：max(單會話水位, 全部會話水位)。</summary>
    private async Task<DateTime?> GetClearWatermarkAsync(Guid userId, string conversationId, CancellationToken ct)
    {
        var stamps = await _db.ConversationStates
            .AsNoTracking()
            .Where(s => s.UserId == userId &&
                        (s.ConversationId == conversationId ||
                         s.ConversationId == ConversationState.AllConversationsKey))
            .Select(s => s.ClearedBeforeAt)
            .ToListAsync(ct);
        return stamps.Count == 0 ? null : stamps.Max();
    }

    private async Task<RecallResult> BuildRecallResultAsync(Message msg, CancellationToken ct)
    {
        var dto = await _mapper.MapAsync(msg, ct);
        string? peer = null;
        if (msg.ChatType == ChatType.Private)
        {
            // 私聊會話 Id 形如 private_{idA}_{idB}（大 Id 在前），解析出對端用戶。
            peer = ConversationKeys.TryParsePeer(msg.ConversationId, msg.SenderId, out var p) ? p.ToString() : null;
        }
        return new RecallResult(dto, msg.ChatType == ChatType.Group, peer);
    }

    /// <summary>引用校驗：原消息必須存在且與新消息同會話。</summary>
    private async Task ValidateReplyAsync(Message msg, Guid? replyToId, CancellationToken ct)
    {
        if (replyToId == null || replyToId.Value == Guid.Empty) return;

        var reply = await _db.Messages.AsNoTracking()
            .Where(m => m.Id == replyToId.Value)
            .Select(m => new { m.ConversationId })
            .FirstOrDefaultAsync(ct);
        if (reply == null || reply.ConversationId != msg.ConversationId)
            throw new MessageSendException("E_BAD_TARGET", "引用的消息不存在");
        msg.ReplyToId = replyToId;
    }

    private async Task<MessageDto> PersistAsync(Message msg, CancellationToken ct)
    {
        _db.Messages.Add(msg);
        await _db.SaveChangesAsync(ct);
        return await _mapper.MapAsync(msg, ct);
    }

    private static void EnsureNotEmpty(string? content, string? mediaUrl)
    {
        if (string.IsNullOrWhiteSpace(content) && string.IsNullOrWhiteSpace(mediaUrl))
            throw new MessageSendException("E_EMPTY", "不能發送空消息");
    }
}
