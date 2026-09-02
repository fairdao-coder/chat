using Chat.Shared.Entities;
using ChatServer.Data;
using ChatServer.DTOs;
using Microsoft.EntityFrameworkCore;

namespace ChatServer.Services;

public interface IMessageMapper
{
    Task<IReadOnlyList<MessageDto>> MapAsync(IReadOnlyList<Message> messages, CancellationToken ct = default);

    Task<MessageDto> MapAsync(Message message, CancellationToken ct = default);
}

/// <summary>
/// Message → MessageDto 映射。
///
/// 原實現對每條消息逐條 FindAsync 查發送者，拉取 N 條歷史就是 N+1 次往返。
/// 這裡改為「收集 SenderId → 一次批量查詢」，無論多少條消息都只多 1 次查詢。
/// </summary>
public class MessageMapper : IMessageMapper
{
    private readonly AppDbContext _db;

    public MessageMapper(AppDbContext db) => _db = db;

    public async Task<IReadOnlyList<MessageDto>> MapAsync(IReadOnlyList<Message> messages, CancellationToken ct = default)
    {
        if (messages.Count == 0) return Array.Empty<MessageDto>();

        var senderIds = messages.Select(m => m.SenderId).Distinct().ToList();
        var senders = await LoadSendersAsync(senderIds, ct);

        return messages.Select(m => ToDto(m, senders)).ToList();
    }

    public async Task<MessageDto> MapAsync(Message message, CancellationToken ct = default)
    {
        var senders = await LoadSendersAsync([message.SenderId], ct);
        return ToDto(message, senders);
    }

    private async Task<Dictionary<Guid, (string NickName, string? AvatarUrl)>> LoadSendersAsync(
        IReadOnlyList<Guid> senderIds, CancellationToken ct)
    {
        if (senderIds.Count == 0) return new Dictionary<Guid, (string, string?)>();

        return await _db.Users
            .AsNoTracking()
            .Where(u => senderIds.Contains(u.Id))
            .Select(u => new { u.Id, u.NickName, u.AvatarUrl })
            .ToDictionaryAsync(u => u.Id, u => (u.NickName, u.AvatarUrl), ct);
    }

    private static MessageDto ToDto(
        Message m,
        IReadOnlyDictionary<Guid, (string NickName, string? AvatarUrl)> senders)
    {
        var sender = senders.GetValueOrDefault(m.SenderId);
        return new MessageDto(
            m.Id, m.ConversationId, m.SenderId,
            sender.NickName ?? "?",
            sender.AvatarUrl,
            m.ChatType, m.Content, m.Type, m.MediaUrl, m.CreatedAt);
    }
}
