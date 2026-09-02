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
        CancellationToken ct = default);

    Task<MessageDto> SendGroupAsync(
        Guid fromId, string groupId, string content, MessageType type, string? mediaUrl,
        CancellationToken ct = default);

    Task<IReadOnlyList<MessageDto>> GetHistoryAsync(
        string conversationId, DateTime? before, int count, CancellationToken ct = default);
}

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

    private readonly AppDbContext _db;
    private readonly IMessageMapper _mapper;

    public MessageService(AppDbContext db, IMessageMapper mapper)
    {
        _db = db;
        _mapper = mapper;
    }

    public async Task<MessageDto> SendPrivateAsync(
        Guid fromId, string toUserId, string content, MessageType type, string? mediaUrl,
        CancellationToken ct = default)
    {
        if (!Guid.TryParse(toUserId, out var toId) || toId == Guid.Empty)
            throw new MessageSendException("E_BAD_TARGET", "收件人 ID 格式不正確");

        var targetExists = await _db.Users.AsNoTracking().AnyAsync(u => u.Id == toId, ct);
        if (!targetExists)
            throw new MessageSendException("E_TARGET_NOT_FOUND", "對方用戶不存在");

        // 私聊必須為好友（前端按 E_FRIEND_REQUIRED 提供「加好友」操作）。
        var areFriends = await _db.Friendships
            .AsNoTracking()
            .AnyAsync(f => f.Status == FriendshipStatus.Accepted &&
                           ((f.RequesterId == fromId && f.AddresseeId == toId) ||
                            (f.RequesterId == toId && f.AddresseeId == fromId)), ct);
        if (!areFriends)
            throw new MessageSendException("E_FRIEND_REQUIRED", "你們還不是好友，無法發送消息。先添加對方為好友後再聊吧～");

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

        return await PersistAsync(msg, ct);
    }

    public async Task<MessageDto> SendGroupAsync(
        Guid fromId, string groupId, string content, MessageType type, string? mediaUrl,
        CancellationToken ct = default)
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

        return await PersistAsync(msg, ct);
    }

    public async Task<IReadOnlyList<MessageDto>> GetHistoryAsync(
        string conversationId, DateTime? before, int count, CancellationToken ct = default)
    {
        // 歷史消息按時間倒序取最新 count 條，再翻正為正序返回，客戶端從舊到新渲染。
        var take = Math.Clamp(count, 1, MaxHistoryCount);

        var query = _db.Messages.AsNoTracking().Where(m => m.ConversationId == conversationId);
        if (before.HasValue) query = query.Where(m => m.CreatedAt < before.Value);

        var messages = await query
            .OrderByDescending(m => m.CreatedAt)
            .Take(take)
            .ToListAsync(ct);

        messages.Reverse();
        return await _mapper.MapAsync(messages, ct);
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
