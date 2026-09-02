using Chat.Shared.Entities;
using ChatServer.Data;
using ChatServer.DTOs;
using ChatServer.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace ChatServer.Hubs;

/// <summary>
/// SignalR 實時通道。
///
/// 職責邊界：本類只做「鑑權 → 轉發」。
/// 消息校驗/落庫在 <see cref="IMessageService"/>，通話狀態在 <see cref="ICallCoordinator"/>，
/// 在線狀態在 <see cref="PresenceTracker"/>。
/// Hub 不再直接碰 DbContext 的寫操作，避免協議層與持久層耦在一起。
/// </summary>
[Authorize]
public class ChatHub : Hub
{
    private const string ServerErrorMessage = "E_SERVER: 服務暫時不可用（網絡或數據庫異常），請稍後重試";

    private readonly AppDbContext _db;
    private readonly PresenceTracker _presence;
    private readonly IMessageService _messages;
    private readonly ICallCoordinator _calls;
    private readonly ILogger<ChatHub> _logger;

    public ChatHub(
        AppDbContext db,
        PresenceTracker presence,
        IMessageService messages,
        ICallCoordinator calls,
        ILogger<ChatHub> logger)
    {
        _db = db;
        _presence = presence;
        _messages = messages;
        _calls = calls;
        _logger = logger;
    }

    private string UserId => Context.UserIdentifier!;

    private static string GroupChannel(Guid groupId) => $"group_{groupId}";

    public override async Task OnConnectedAsync()
    {
        var userId = UserId;
        await _presence.UserConnected(userId, Context.ConnectionId);

        // 把連接加入其所在的所有群頻道，群消息才能推達。
        var groupIds = await _db.GroupMembers
            .AsNoTracking()
            .Where(m => m.UserId == Guid.Parse(userId))
            .Select(m => m.GroupId)
            .ToListAsync();

        foreach (var gid in groupIds)
            await Groups.AddToGroupAsync(Context.ConnectionId, GroupChannel(gid));

        await Clients.Others.SendAsync("UserOnline", userId);
        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? ex)
    {
        var userId = UserId;

        // 通話途中掉線：通知對端掛斷，否則對端 UI 會一直停在通話中。
        if (_calls.CleanupUser(userId) > 0)
            await Clients.Others.SendAsync("OnPeerDisconnected", userId);

        var stillOnline = await _presence.UserDisconnected(userId, Context.ConnectionId);
        if (!stillOnline)
            await Clients.Others.SendAsync("UserOffline", userId);

        if (ex != null)
            _logger.LogWarning(ex, "SignalR 連接異常斷開 userId={UserId}", userId);

        await base.OnDisconnectedAsync(ex);
    }

    // 注意：參數全部顯式聲明，不帶默認值。
    // - type 用 string 接收再解析，避免 SignalR 參數綁定器對 MessageType 枚舉的
    //   依賴（signalr_netcore 客戶端按位置序列化，'Text' 並不總能被識別為枚舉，
    //   從而觸發 "Error binding arguments"）。任何無法識別的值都回落為 Text。
    public async Task SendPrivateMessage(
        string toUserId,
        string content,
        string type,
        string? mediaUrl)
    {
        if (!Guid.TryParse(UserId, out var fromId))
            throw new HubException("E_BAD_TARGET: 身份無效，請重新登錄");

        var msgType = ParseType(type);

        try
        {
            var dto = await _messages.SendPrivateAsync(fromId, toUserId, content, msgType, mediaUrl);
            await Clients.User(toUserId).SendAsync("ReceiveMessage", dto);
            await Clients.Caller.SendAsync("ReceiveMessage", dto);
        }
        catch (MessageSendException ex)
        {
            // 業務校驗失敗：錯誤碼前綴（E_FRIEND_REQUIRED 等）是客戶端引導用戶的依據，必須原樣透傳。
            throw new HubException(ex.ToWireMessage());
        }
        catch (Exception ex)
        {
            // 數據庫/網絡等意外故障：轉為友好且客戶端可解析的 HubException，
            // 避免客戶端收到 "Failed to invoke '...' due to an error on the server." 這類通用英文。
            _logger.LogError(ex, "SendPrivateMessage 失敗 from={From} to={To}", fromId, toUserId);
            throw new HubException(ServerErrorMessage);
        }
    }

    public async Task SendGroupMessage(
        string groupId,
        string content,
        string type,
        string? mediaUrl)
    {
        if (!Guid.TryParse(UserId, out var fromId))
            throw new HubException("E_BAD_TARGET: 身份無效，請重新登錄");
        if (!Guid.TryParse(groupId, out var gid))
            throw new HubException("E_BAD_TARGET: 群 ID 格式不正確");

        var msgType = ParseType(type);

        try
        {
            var dto = await _messages.SendGroupAsync(fromId, groupId, content, msgType, mediaUrl);
            await Clients.Group(GroupChannel(gid)).SendAsync("ReceiveMessage", dto);
        }
        catch (MessageSendException ex)
        {
            throw new HubException(ex.ToWireMessage());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "SendGroupMessage 失敗 from={From} group={Group}", fromId, groupId);
            throw new HubException(ServerErrorMessage);
        }
    }

    // ===================== 正在輸入狀態（實時中繼，不持久化） =====================
    /// <summary>
    /// 客戶端輸入時上報，服務端即時轉發給對方。
    /// 停止輸入由客戶端定時器判定後上報 false（避免服務端維護超時狀態）。
    /// </summary>
    public async Task SendTyping(string toUserId, bool isTyping)
    {
        if (!Guid.TryParse(toUserId, out _)) return;
        if (toUserId == UserId) return;
        await Clients.User(toUserId).SendAsync("OnTyping", UserId, isTyping);
    }

    public async Task JoinGroup(string groupId)
    {
        if (!Guid.TryParse(groupId, out var gid)) return;

        // 加入前校驗成員身份，防止任意用戶訂閱他人群組的消息流。
        if (!Guid.TryParse(UserId, out var userId)) return;
        var isMember = await _db.GroupMembers
            .AsNoTracking()
            .AnyAsync(m => m.GroupId == gid && m.UserId == userId);
        if (!isMember) return;

        await Groups.AddToGroupAsync(Context.ConnectionId, GroupChannel(gid));
    }

    public async Task LeaveGroup(string groupId)
    {
        if (!Guid.TryParse(groupId, out var gid)) return;
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, GroupChannel(gid));
    }

    /// <summary>
    /// 將客戶端傳來的 type 字符串解析為 MessageType。
    /// 無法識別（含大小寫差異、空值）時回落為 Text，避免綁定失敗。
    /// </summary>
    private static MessageType ParseType(string? type)
    {
        if (string.IsNullOrWhiteSpace(type)) return MessageType.Text;
        return Enum.TryParse<MessageType>(type, ignoreCase: true, out var t)
            ? t
            : MessageType.Text;
    }

    // ===================== 語音 / 視頻通話信令（WebRTC P2P 中繼） =====================

    /// <summary>
    /// 發起呼叫。callId 由客戶端生成（兩端共用，作為本次通話的關聯鍵）。
    /// 服務端僅做信令中繼 + 忙線檢測，不接觸媒體流。
    /// </summary>
    public async Task InviteCall(string callId, string targetUserId, string callType)
    {
        var fromId = UserId;
        if (fromId == targetUserId)
        {
            await Clients.Caller.SendAsync("OnCallRejected", callId, "self");
            return;
        }
        if (!Guid.TryParse(targetUserId, out _))
            throw new HubException("E_BAD_TARGET: 收件人 ID 格式不正確");

        var session = new CallSession(callId, fromId, targetUserId, callType);
        if (!_calls.TryInvite(session))
        {
            await Clients.Caller.SendAsync("OnCallRejected", callId, "busy");
            return;
        }

        // 把主叫暱稱一起下發給被叫，避免被叫端再查聯繫人。
        var nick = await _db.Users
            .AsNoTracking()
            .Where(u => u.Id == Guid.Parse(fromId))
            .Select(u => u.NickName)
            .FirstOrDefaultAsync();

        await Clients.User(targetUserId)
            .SendAsync("OnIncomingCall", callId, fromId, nick ?? "", callType);
    }

    public async Task AcceptCall(string callId)
    {
        if (!_calls.TryAccept(callId, UserId, out var session) || session == null) return;
        await Clients.User(session.CallerId).SendAsync("OnCallAccepted", callId);
    }

    public async Task RejectCall(string callId)
    {
        if (!_calls.TryEnd(callId, out var session) || session == null) return;
        await Clients.User(session.CallerId).SendAsync("OnCallRejected", callId, "rejected");
    }

    public Task SendOffer(string callId, string sdp) => RelayAsync(callId, "OnOffer", callId, sdp);

    public Task SendAnswer(string callId, string sdp) => RelayAsync(callId, "OnAnswer", callId, sdp);

    public Task SendIceCandidate(string callId, string candidate) =>
        RelayAsync(callId, "OnIceCandidate", callId, candidate);

    public async Task HangUp(string callId)
    {
        if (!_calls.TryEnd(callId, out var session) || session == null) return;
        await Clients.User(session.PeerOf(UserId) ?? session.CallerId).SendAsync("OnHangUp", callId);
    }

    /// <summary>把信令轉發給通話對端；呼叫者不在會話中時靜默丟棄。</summary>
    private async Task RelayAsync(string callId, string method, params object?[] args)
    {
        var session = _calls.Get(callId);
        if (session == null) return;

        var peer = session.PeerOf(UserId);
        if (peer == null) return;

        await Clients.User(peer).SendAsync(method, args);
    }
}
