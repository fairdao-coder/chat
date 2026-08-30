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

        // 把连接加入其所在的所有群频道
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

    // 注意：参数全部显式声明，不带默认值。
    // - 写默认值（MessageType.Text / null）会让 SignalR 参数绑定器在按元数匹配时
    //   派生出"1/2/3/4 元"多个重载分支，与客户端"params object?[] args"四参数实际形态
    //   偶发不匹配，导致 "InvalidDataException: Error binding arguments"。
    // - 客户端永远传齐 4 个参数，所以去掉默认值不会影响调用语义。
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
                throw new HubException("E_BAD_TARGET: 收件人 ID 格式不正确");

            // 对方必须存在
            var targetExists = await _db.Users.AnyAsync(u => u.Id == toId);
            if (!targetExists)
                throw new HubException("E_TARGET_NOT_FOUND: 对方用户不存在");

            // 私聊必须为好友（前端按 E_FRIEND_REQUIRED 错误码提供"加好友"操作）
            var areFriends = await _db.Friendships.AnyAsync(f =>
                f.Status == FriendshipStatus.Accepted &&
                ((f.RequesterId == fromId && f.AddresseeId == toId) ||
                 (f.RequesterId == toId && f.AddresseeId == fromId)));
            if (!areFriends)
                throw new HubException("E_FRIEND_REQUIRED: 你们还不是好友，无法发送消息。先添加对方为好友后再聊吧～");

            if (string.IsNullOrWhiteSpace(content) && string.IsNullOrWhiteSpace(mediaUrl))
                throw new HubException("E_EMPTY: 不能发送空消息");

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
            // 数据库/网络等意外故障：转为友好且客户端可解析的 HubException，
            // 避免客户端收到 "Failed to invoke '...' due to an error on the server." 这类通用英文。
            throw new HubException("E_SERVER: 服务暂时不可用（网络或数据库异常），请稍后重试");
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
                throw new HubException("E_BAD_TARGET: 群 ID 格式不正确");

            var groupExists = await _db.Groups.AnyAsync(g => g.Id == gid);
            if (!groupExists)
                throw new HubException("E_TARGET_NOT_FOUND: 群不存在");

            var isMember = await _db.GroupMembers.AnyAsync(m => m.GroupId == gid && m.UserId == fromId);
            if (!isMember)
                throw new HubException("E_FRIEND_REQUIRED: 你不在该群，无法发送消息");

            if (string.IsNullOrWhiteSpace(content) && string.IsNullOrWhiteSpace(mediaUrl))
                throw new HubException("E_EMPTY: 不能发送空消息");

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
            // 数据库/网络等意外故障：转为友好且客户端可解析的 HubException，
            // 避免客户端收到 "Failed to invoke '...' due to an error on the server." 这类通用英文。
            throw new HubException("E_SERVER: 服务暂时不可用（网络或数据库异常），请稍后重试");
        }
    }

    public async Task JoinGroup(string groupId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, "group_" + groupId);
    }

    public async Task LeaveGroup(string groupId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, "group_" + groupId);
    }

    // ===================== 语音 / 视频通话信令（WebRTC P2P 中继） =====================
    // 单实例内存态：开发环境足够。多实例横向扩展时需换成共享存储（Redis / DB）。
    private static readonly ConcurrentDictionary<string, CallSession> _calls = new();
    private static readonly ConcurrentDictionary<string, string> _busy = new(); // userId -> callId

    /// <summary>
    /// 发起呼叫。callId 由客户端生成（两端共用，作为本次通话的关联键）。
    /// 服务端仅做信令中继 + 忙线检测，不接触媒体流。
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
            throw new HubException("E_BAD_TARGET: 收件人 ID 格式不正确");
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
        // 把主叫昵称一起下发给被叫，避免被叫端再查联系人。
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
