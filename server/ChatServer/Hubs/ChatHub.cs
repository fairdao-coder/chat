using System.Collections.Concurrent;
using ChatServer.Data;
using ChatServer.DTOs;
using ChatServer.Entities;
using ChatServer.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace ChatServer.Hubs;

[Authorize]
public class ChatHub : Hub
{
    private readonly AppDbContext _db;
    private readonly PresenceTracker _presence;

    public ChatHub(AppDbContext db, PresenceTracker presence)
    {
        _db = db;
        _presence = presence;
    }

    public override async Task OnConnectedAsync()
    {
        var userId = Context.UserIdentifier!;
        await _presence.UserConnected(userId, Context.ConnectionId);

        // 把連接加入其所在的所有群頻道
        var groupIds = await _db.GroupMembers
            .Where(m => m.UserId == Guid.Parse(userId))
            .Select(m => m.GroupId)
            .ToListAsync();
        foreach (var gid in groupIds)
            await Groups.AddToGroupAsync(Context.ConnectionId, "group_" + gid);

        await Clients.Others.SendAsync("UserOnline", userId);
        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? ex)
    {
        var userId = Context.UserIdentifier!;
        var stillOnline = await _presence.UserDisconnected(userId, Context.ConnectionId);
        if (!stillOnline)
            await Clients.Others.SendAsync("UserOffline", userId);
        await base.OnDisconnectedAsync(ex);
    }

    // 注意：參數全部顯式聲明，不帶默認值。
    // - 寫默認值（MessageType.Text / null）會讓 SignalR 參數綁定器在按元數匹配時
    //   派生出"1/2/3/4 元"多個重載分支，與客戶端"params object?[] args"四參數實際形態
    //   偶發不匹配，導致 "InvalidDataException: Error binding arguments"。
    // - 客戶端永遠傳齊 4 個參數，所以去掉默認值不會影響調用語義。
    public async Task SendPrivateMessage(
        string toUserId,
        string content,
        MessageType type,
        string? mediaUrl)
    {
        try
        {
            var fromId = Guid.Parse(Context.UserIdentifier!);
            if (!Guid.TryParse(toUserId, out var toId))
                throw new HubException("E_BAD_TARGET: 收件人 ID 格式不正確");

            // 對方必須存在
            var targetExists = await _db.Users.AnyAsync(u => u.Id == toId);
            if (!targetExists)
                throw new HubException("E_TARGET_NOT_FOUND: 對方用戶不存在");

            // 私聊必須為好友（前端按 E_FRIEND_REQUIRED 錯誤碼提供"加好友"操作）
            var areFriends = await _db.Friendships.AnyAsync(f =>
                f.Status == FriendshipStatus.Accepted &&
                ((f.RequesterId == fromId && f.AddresseeId == toId) ||
                 (f.RequesterId == toId && f.AddresseeId == fromId)));
            if (!areFriends)
                throw new HubException("E_FRIEND_REQUIRED: 你們還不是好友，無法發送消息。先添加對方為好友後再聊吧～");

            if (string.IsNullOrWhiteSpace(content) && string.IsNullOrWhiteSpace(mediaUrl))
                throw new HubException("E_EMPTY: 不能發送空消息");

            var msg = new Message
            {
                ConversationId = ConversationKeys.Private(fromId, toId),
                SenderId = fromId,
                ChatType = ChatType.Private,
                Content = content ?? string.Empty,
                Type = type,
                MediaUrl = mediaUrl
            };
            _db.Messages.Add(msg);
            await _db.SaveChangesAsync();

            var dto = await MapAsync(msg);
            await Clients.User(toUserId).SendAsync("ReceiveMessage", dto);
            await Clients.Caller.SendAsync("ReceiveMessage", dto);
        }
        catch (HubException) { throw; }
        catch (Exception)
        {
            // 數據庫/網絡等意外故障：轉為友好且客戶端可解析的 HubException，
            // 避免客戶端收到 "Failed to invoke '...' due to an error on the server." 這類通用英文。
            throw new HubException("E_SERVER: 服務暫時不可用（網絡或數據庫異常），請稍後重試");
        }
    }

    public async Task SendGroupMessage(
        string groupId,
        string content,
        MessageType type,
        string? mediaUrl)
    {
        try
        {
            var fromId = Guid.Parse(Context.UserIdentifier!);
            if (!Guid.TryParse(groupId, out var gid))
                throw new HubException("E_BAD_TARGET: 群 ID 格式不正確");

            var groupExists = await _db.Groups.AnyAsync(g => g.Id == gid);
            if (!groupExists)
                throw new HubException("E_TARGET_NOT_FOUND: 群不存在");

            var isMember = await _db.GroupMembers.AnyAsync(m => m.GroupId == gid && m.UserId == fromId);
            if (!isMember)
                throw new HubException("E_FRIEND_REQUIRED: 你不在該群，無法發送消息");

            if (string.IsNullOrWhiteSpace(content) && string.IsNullOrWhiteSpace(mediaUrl))
                throw new HubException("E_EMPTY: 不能發送空消息");

            var msg = new Message
            {
                ConversationId = ConversationKeys.Group(gid),
                SenderId = fromId,
                ChatType = ChatType.Group,
                Content = content ?? string.Empty,
                Type = type,
                MediaUrl = mediaUrl
            };
            _db.Messages.Add(msg);
            await _db.SaveChangesAsync();

            var dto = await MapAsync(msg);
            await Clients.Group("group_" + gid).SendAsync("ReceiveMessage", dto);
        }
        catch (HubException) { throw; }
        catch (Exception)
        {
            // 數據庫/網絡等意外故障：轉為友好且客戶端可解析的 HubException，
            // 避免客戶端收到 "Failed to invoke '...' due to an error on the server." 這類通用英文。
            throw new HubException("E_SERVER: 服務暫時不可用（網絡或數據庫異常），請稍後重試");
        }
    }

    // ===================== 正在輸入狀態（實時中繼，不持久化） =====================
    /// <summary>
    /// 客戶端輸入時上報，服務端即時轉發給對方。
    /// 停止輸入由客戶端定時器判定後上報 false（避免服務端維護超時狀態）。
    /// </summary>
    public async Task SendTyping(string toUserId, bool isTyping)
    {
        var fromId = Context.UserIdentifier!;
        if (!Guid.TryParse(toUserId, out _)) return;
        if (toUserId == fromId) return;
        await Clients.User(toUserId).SendAsync("OnTyping", fromId, isTyping);
    }

    public async Task JoinGroup(string groupId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, "group_" + groupId);
    }

    public async Task LeaveGroup(string groupId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, "group_" + groupId);
    }

    // ===================== 語音 / 視頻通話信令（WebRTC P2P 中繼） =====================
    // 單實例內存態：開發環境足夠。多實例橫向擴展時需換成共享存儲（Redis / DB）。
    private static readonly ConcurrentDictionary<string, CallSession> _calls = new();
    private static readonly ConcurrentDictionary<string, string> _busy = new(); // userId -> callId

    /// <summary>
    /// 發起呼叫。callId 由客戶端生成（兩端共用，作為本次通話的關聯鍵）。
    /// 服務端僅做信令中繼 + 忙線檢測，不接觸媒體流。
    /// </summary>
    public async Task InviteCall(string callId, string targetUserId, string callType)
    {
        var fromId = Context.UserIdentifier!;
        if (fromId == targetUserId)
        {
            await Clients.Caller.SendAsync("OnCallRejected", callId, "self");
            return;
        }
        if (!Guid.TryParse(targetUserId, out _))
            throw new HubException("E_BAD_TARGET: 收件人 ID 格式不正確");
        if (_busy.ContainsKey(targetUserId))
        {
            await Clients.Caller.SendAsync("OnCallRejected", callId, "busy");
            return;
        }
        var caller = await _db.Users.FindAsync(Guid.Parse(fromId));
        _calls[callId] = new CallSession
        {
            CallId = callId,
            CallerId = fromId,
            CalleeId = targetUserId,
            CallType = callType
        };
        // 把主叫暱稱一起下發給被叫，避免被叫端再查聯繫人。
        await Clients.User(targetUserId)
            .SendAsync("OnIncomingCall", callId, fromId, caller?.NickName ?? "", callType);
    }

    public async Task AcceptCall(string callId)
    {
        if (!_calls.TryGetValue(callId, out var s)) return;
        if (s.CalleeId != Context.UserIdentifier) return;
        _busy[s.CallerId] = callId;
        _busy[s.CalleeId] = callId;
        await Clients.User(s.CallerId).SendAsync("OnCallAccepted", callId);
    }

    public async Task RejectCall(string callId)
    {
        if (_calls.TryGetValue(callId, out var s))
        {
            await Clients.User(s.CallerId).SendAsync("OnCallRejected", callId, "rejected");
            _calls.TryRemove(callId, out _);
            _busy.TryRemove(s.CallerId, out _);
            _busy.TryRemove(s.CalleeId, out _);
        }
    }

    public async Task SendOffer(string callId, string sdp)
    {
        if (!_calls.TryGetValue(callId, out var s)) return;
        var peer = PeerOf(s, Context.UserIdentifier!);
        if (peer != null) await Clients.User(peer).SendAsync("OnOffer", callId, sdp);
    }

    public async Task SendAnswer(string callId, string sdp)
    {
        if (!_calls.TryGetValue(callId, out var s)) return;
        var peer = PeerOf(s, Context.UserIdentifier!);
        if (peer != null) await Clients.User(peer).SendAsync("OnAnswer", callId, sdp);
    }

    public async Task SendIceCandidate(string callId, string candidate)
    {
        if (!_calls.TryGetValue(callId, out var s)) return;
        var peer = PeerOf(s, Context.UserIdentifier!);
        if (peer != null) await Clients.User(peer).SendAsync("OnIceCandidate", callId, candidate);
    }

    public async Task HangUp(string callId)
    {
        if (_calls.TryGetValue(callId, out var s))
        {
            var peer = PeerOf(s, Context.UserIdentifier!);
            if (peer != null) await Clients.User(peer).SendAsync("OnHangUp", callId);
            _calls.TryRemove(callId, out _);
            _busy.TryRemove(s.CallerId, out _);
            _busy.TryRemove(s.CalleeId, out _);
        }
    }

    private static string? PeerOf(CallSession s, string me) =>
        me == s.CallerId ? s.CalleeId : (me == s.CalleeId ? s.CallerId : null);

    private sealed class CallSession
    {
        public string CallId { get; set; } = "";
        public string CallerId { get; set; } = "";
        public string CalleeId { get; set; } = "";
        public string CallType { get; set; } = "";
    }

    private async Task<MessageDto> MapAsync(Message m)
    {
        var sender = await _db.Users.FindAsync(m.SenderId);
        return new MessageDto(
            m.Id, m.ConversationId, m.SenderId,
            sender?.NickName ?? "?",
            sender?.AvatarUrl,
            m.ChatType, m.Content, m.Type, m.MediaUrl, m.CreatedAt);
    }
}
