using System.Collections.Concurrent;
using Chat.Shared.Entities;

namespace ChatServer.Services;

/// <summary>
/// 記憶體通話會話追蹤（單實例）。
/// 負責維護「誰正在通話中」、會話狀態與結束原因。
/// </summary>
public class CallTracker
{
    private readonly ConcurrentDictionary<Guid, CallSession> _sessions = new();
    private readonly ConcurrentDictionary<Guid, Guid> _userSession = new();

    /// <summary>
    /// 發起一通新通話。若主叫或被叫已經在通話中，則返回 null（忙線）。
    /// </summary>
    public CallSession? StartCall(Guid callerId, Guid calleeId, CallType type)
    {
        var session = new CallSession
        {
            Id = Guid.NewGuid(),
            CallerId = callerId,
            CalleeId = calleeId,
            Type = type,
            State = CallState.Calling,
            CreatedAt = DateTime.UtcNow
        };

        if (!_userSession.TryAdd(callerId, session.Id))
            return null;

        if (!_userSession.TryAdd(calleeId, session.Id))
        {
            _userSession.TryRemove(callerId, out _);
            return null;
        }

        _sessions[session.Id] = session;
        return session;
    }

    /// <summary>被叫接受通話。</summary>
    public bool Accept(Guid sessionId, Guid calleeId)
    {
        if (!_sessions.TryGetValue(sessionId, out var session))
            return false;

        if (session.CalleeId != calleeId || session.State != CallState.Calling)
            return false;

        session.State = CallState.Connecting;
        session.AcceptedAt = DateTime.UtcNow;
        return true;
    }

    /// <summary>拒絕來電。</summary>
    public bool Reject(Guid sessionId, Guid calleeId)
    {
        if (!_sessions.TryGetValue(sessionId, out var session))
            return false;

        if (session.CalleeId != calleeId || session.State != CallState.Calling)
            return false;

        return End(sessionId, CallEndReason.Declined);
    }

    /// <summary>結束通話（主叫或被叫掛斷、斷線等）。</summary>
    public bool End(Guid sessionId, CallEndReason reason)
    {
        if (!_sessions.TryGetValue(sessionId, out var session))
            return false;

        if (session.State == CallState.Ended)
            return false;

        session.State = CallState.Ended;
        session.EndedAt = DateTime.UtcNow;
        session.EndReason = reason;

        _userSession.TryRemove(session.CallerId, out _);
        _userSession.TryRemove(session.CalleeId, out _);
        return true;
    }

    /// <summary>讓某一方進入 Connected 狀態（收到 answer 後）。</summary>
    public bool MarkConnected(Guid sessionId)
    {
        if (!_sessions.TryGetValue(sessionId, out var session))
            return false;

        if (session.State != CallState.Connecting)
            return false;

        session.State = CallState.Connected;
        return true;
    }

    public bool TryGetSession(Guid sessionId, out CallSession? session)
        => _sessions.TryGetValue(sessionId, out session);

    public CallSession? GetSessionByUser(Guid userId)
        => _userSession.TryGetValue(userId, out var sid) && _sessions.TryGetValue(sid, out var s)
            ? s
            : null;

    /// <summary>結束某用戶當前關聯的通話（用於斷線清理）。</summary>
    public CallSession? EndByUser(Guid userId, CallEndReason reason)
    {
        if (!_userSession.TryGetValue(userId, out var sid))
            return null;

        if (!_sessions.TryGetValue(sid, out var session))
            return null;

        End(sid, reason);
        return session;
    }
}

public class CallSession
{
    public Guid Id { get; set; }
    public Guid CallerId { get; set; }
    public Guid CalleeId { get; set; }
    public CallType Type { get; set; }
    public CallState State { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? AcceptedAt { get; set; }
    public DateTime? EndedAt { get; set; }
    public CallEndReason? EndReason { get; set; }
}
