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
/// 消息校驗/落庫在 <see cref="IMessageService"/>，
/// 在線狀態在 <see cref="PresenceTracker"/>。
/// Hub 不再直接碰 DbContext 的寫操作，避免協議層與持久層耦在一起。
/// </summary>
[Authorize]
public class ChatHub : Hub
{
    private const string ServerErrorMessage = "E_SERVER: 服務暫時不可用（網絡或數據庫異常），請稍後重試";

    private readonly AppDbContext _db;
    private readonly PresenceTracker _presence;
    private readonly CallTracker _callTracker;
    private readonly IMessageService _messages;
    private readonly ILogger<ChatHub> _logger;

    public ChatHub(
        AppDbContext db,
        PresenceTracker presence,
        CallTracker callTracker,
        IMessageService messages,
        ILogger<ChatHub> logger)
    {
        _db = db;
        _presence = presence;
        _callTracker = callTracker;
        _messages = messages;
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

        var stillOnline = await _presence.UserDisconnected(userId, Context.ConnectionId);
        if (!stillOnline)
        {
            await Clients.Others.SendAsync("UserOffline", userId);

            // 用戶完全離線：結束其正在參與的通話，並通知對方。
            if (Guid.TryParse(userId, out var uid))
            {
                var session = _callTracker.EndByUser(uid, CallEndReason.Offline);
                if (session != null)
                {
                    var otherId = session.CallerId == uid ? session.CalleeId : session.CallerId;
                    await Clients.User(otherId.ToString()).SendAsync(
                        "CallEnded",
                        new CallEndedDto(session.Id, CallEndReason.Offline));
                }
            }
        }

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
        string? mediaUrl,
        string? replyToId)
    {
        if (!Guid.TryParse(UserId, out var fromId))
            throw new HubException("E_BAD_TARGET: 身份無效，請重新登錄");

        var msgType = ParseType(type);
        var reply = ParseGuidOrNull(replyToId);

        try
        {
            var dto = await _messages.SendPrivateAsync(fromId, toUserId, content, msgType, mediaUrl, reply);
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
        string? mediaUrl,
        string? replyToId)
    {
        if (!Guid.TryParse(UserId, out var fromId))
            throw new HubException("E_BAD_TARGET: 身份無效，請重新登錄");
        if (!Guid.TryParse(groupId, out var gid))
            throw new HubException("E_BAD_TARGET: 群 ID 格式不正確");

        var msgType = ParseType(type);
        var reply = ParseGuidOrNull(replyToId);

        try
        {
            var dto = await _messages.SendGroupAsync(fromId, groupId, content, msgType, mediaUrl, reply);
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

    // ===================== 消息撤回 =====================
    /// <summary>
    /// 撤回自己發出的消息（限時 2 分鐘）。成功後服務端廣播 MessageRecalled：
    /// 私聊推送給對端與自己，群聊推送給整個群頻道，各端據此把對應氣泡替換為「已撤回」。
    /// </summary>
    public async Task RecallMessage(string messageId)
    {
        if (!Guid.TryParse(UserId, out var fromId))
            throw new HubException("E_BAD_TARGET: 身份無效，請重新登錄");
        var mid = ParseGuidOrNull(messageId)
            ?? throw new HubException("E_BAD_TARGET: 消息 ID 格式不正確");

        try
        {
            var result = await _messages.RecallAsync(fromId, mid);

            if (result.IsGroup && Guid.TryParse(result.Dto.ConversationId[2..], out var gid))
            {
                await Clients.Group(GroupChannel(gid))
                    .SendAsync("MessageRecalled", result.Dto);
            }
            else if (result.PeerUserId != null)
            {
                await Clients.User(result.PeerUserId).SendAsync("MessageRecalled", result.Dto);
                await Clients.Caller.SendAsync("MessageRecalled", result.Dto);
            }
            else
            {
                await Clients.Caller.SendAsync("MessageRecalled", result.Dto);
            }
        }
        catch (MessageSendException ex)
        {
            throw new HubException(ex.ToWireMessage());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "RecallMessage 失敗 from={From} message={MessageId}", fromId, messageId);
            throw new HubException(ServerErrorMessage);
        }
    }

    /// <summary>空串 / null / 非 GUID 一律返回 null，保持 Hub 參數綁定寬容。</summary>
    private static Guid? ParseGuidOrNull(string? raw) =>
        Guid.TryParse(raw, out var g) && g != Guid.Empty ? g : null;

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

    private static CallType ParseCallType(string? type)
    {
        if (string.IsNullOrWhiteSpace(type)) return CallType.Voice;
        return Enum.TryParse<CallType>(type, ignoreCase: true, out var t)
            ? t
            : CallType.Voice;
    }

    // ===================== 语音/视频通话信令 =====================

    /// <summary>
    /// 发起私聊通话。成功时返回 sessionId，并通过 IncomingCall 推送给被叫。
    /// 失败时抛出 HubException（E_BAD_TARGET / E_TARGET_OFFLINE / E_BUSY）。
    /// </summary>
    public async Task<string> CallUser(string toUserId, string type)
    {
        if (!Guid.TryParse(UserId, out var callerId))
            throw new HubException("E_BAD_TARGET: 身份無效，請重新登錄");
        if (!Guid.TryParse(toUserId, out var calleeId))
            throw new HubException("E_BAD_TARGET: 對方 ID 格式不正確");
        if (callerId == calleeId)
            throw new HubException("E_BAD_TARGET: 不能呼叫自己");

        var callType = ParseCallType(type);

        try
        {
            var calleeOnline = await _presence.IsOnline(toUserId);
            if (!calleeOnline)
                throw new HubException("E_TARGET_OFFLINE: 對方不在線");

            var session = _callTracker.StartCall(callerId, calleeId, callType);
            if (session == null)
                throw new HubException("E_BUSY: 對方忙線或您正在通話中");

            var caller = await _db.Users
                .AsNoTracking()
                .FirstOrDefaultAsync(u => u.Id == callerId);

            await Clients.User(toUserId).SendAsync(
                "IncomingCall",
                new IncomingCallDto(
                    session.Id,
                    callerId,
                    caller?.NickName ?? string.Empty,
                    caller?.AvatarUrl,
                    callType));

            return session.Id.ToString();
        }
        catch (HubException)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "CallUser 失敗 caller={Caller} callee={Callee}", callerId, calleeId);
            throw new HubException(ServerErrorMessage);
        }
    }

    /// <summary>被叫接受通话，通知双方 CallAccepted。</summary>
    public async Task AcceptCall(string sessionId)
    {
        if (!Guid.TryParse(UserId, out var userId))
            throw new HubException("E_BAD_TARGET: 身份無效，請重新登錄");
        if (!Guid.TryParse(sessionId, out var sid))
            throw new HubException("E_BAD_TARGET: 會話 ID 格式不正確");

        try
        {
            if (!_callTracker.TryGetSession(sid, out var session) || session == null)
                throw new HubException("E_TARGET_NOT_FOUND: 通話已結束或不存在");

            if (!session.CalleeId.Equals(userId))
                throw new HubException("E_BAD_TARGET: 無權操作該通話");

            if (!_callTracker.Accept(sid, userId))
                throw new HubException("E_SERVER: 接受通話失敗");

            var accepted = new CallAcceptedDto(sid, session.CallerId, session.CalleeId, session.Type);
            await Clients.User(session.CallerId.ToString()).SendAsync("CallAccepted", accepted);
            await Clients.User(session.CalleeId.ToString()).SendAsync("CallAccepted", accepted);
        }
        catch (HubException)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "AcceptCall 失敗 user={User} session={Session}", userId, sessionId);
            throw new HubException(ServerErrorMessage);
        }
    }

    /// <summary>被叫拒绝通话。</summary>
    public async Task RejectCall(string sessionId)
    {
        if (!Guid.TryParse(UserId, out var userId))
            throw new HubException("E_BAD_TARGET: 身份無效，請重新登錄");
        if (!Guid.TryParse(sessionId, out var sid))
            throw new HubException("E_BAD_TARGET: 會話 ID 格式不正確");

        try
        {
            if (!_callTracker.TryGetSession(sid, out var session) || session == null)
                return;

            if (!session.CalleeId.Equals(userId))
                throw new HubException("E_BAD_TARGET: 無權操作該通話");

            if (_callTracker.Reject(sid, userId))
            {
                await Clients.User(session.CallerId.ToString()).SendAsync(
                    "CallEnded",
                    new CallEndedDto(sid, CallEndReason.Declined));
            }
        }
        catch (HubException)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "RejectCall 失敗 user={User} session={Session}", userId, sessionId);
            throw new HubException(ServerErrorMessage);
        }
    }

    /// <summary>任意一方挂断通话。</summary>
    public async Task EndCall(string sessionId)
    {
        if (!Guid.TryParse(UserId, out var userId))
            throw new HubException("E_BAD_TARGET: 身份無效，請重新登錄");
        if (!Guid.TryParse(sessionId, out var sid))
            throw new HubException("E_BAD_TARGET: 會話 ID 格式不正確");

        try
        {
            if (!_callTracker.TryGetSession(sid, out var session) || session == null)
                return;

            if (!session.CallerId.Equals(userId) && !session.CalleeId.Equals(userId))
                throw new HubException("E_BAD_TARGET: 無權操作該通話");

            if (_callTracker.End(sid, CallEndReason.HangUp))
            {
                var otherId = session.CallerId.Equals(userId) ? session.CalleeId : session.CallerId;
                await Clients.User(otherId.ToString()).SendAsync(
                    "CallEnded",
                    new CallEndedDto(sid, CallEndReason.HangUp));
            }
        }
        catch (HubException)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "EndCall 失敗 user={User} session={Session}", userId, sessionId);
            throw new HubException(ServerErrorMessage);
        }
    }

    /// <summary>转发 WebRTC offer（主叫 -> 被叫）。</summary>
    public async Task SendOffer(string sessionId, string sdp)
    {
        await ForwardSdp(sessionId, sdp, "ReceiveOffer");
    }

    /// <summary>转发 WebRTC answer（被叫 -> 主叫）。</summary>
    public async Task SendAnswer(string sessionId, string sdp)
    {
        var ok = await ForwardSdp(sessionId, sdp, "ReceiveAnswer");
        if (ok && Guid.TryParse(sessionId, out var sid))
            _callTracker.MarkConnected(sid);
    }

    /// <summary>转发 ICE candidate。</summary>
    public async Task SendIceCandidate(string sessionId, string candidate)
    {
        await ForwardSdp(sessionId, candidate, "ReceiveIceCandidate");
    }

    private async Task<bool> ForwardSdp(string sessionId, string payload, string eventName)
    {
        if (!Guid.TryParse(UserId, out var userId))
            return false;
        if (!Guid.TryParse(sessionId, out var sid))
            return false;
        if (string.IsNullOrWhiteSpace(payload))
            return false;

        if (!_callTracker.TryGetSession(sid, out var session) || session == null)
            return false;

        if (!session.CallerId.Equals(userId) && !session.CalleeId.Equals(userId))
            return false;

        var otherId = session.CallerId.Equals(userId) ? session.CalleeId : session.CallerId;

        if (eventName == "ReceiveIceCandidate")
        {
            await Clients.User(otherId.ToString()).SendAsync(
                eventName,
                new CallIceCandidateDto(sid, payload));
        }
        else
        {
            await Clients.User(otherId.ToString()).SendAsync(
                eventName,
                new CallSdpDto(sid, payload));
        }

        return true;
    }

}
