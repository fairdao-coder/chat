using System.Collections.Concurrent;

namespace ChatServer.Services;

public sealed record CallSession(string CallId, string CallerId, string CalleeId, string CallType)
{
    public DateTime CreatedAt { get; init; } = DateTime.UtcNow;

    /// <summary>被叫是否已接聽。未接聽的會話會在超時後被回收。</summary>
    public bool Accepted { get; set; }
}

public interface ICallCoordinator
{
    /// <summary>登記一次呼叫。被叫忙線時返回 false。</summary>
    bool TryInvite(CallSession session);

    CallSession? Get(string callId);

    /// <summary>被叫接聽：標記會話已接聽並置雙方忙線。</summary>
    bool TryAccept(string callId, string userId, out CallSession? session);

    /// <summary>結束通話（拒絕/掛斷/超時）：清理會話與忙線標記。</summary>
    bool TryEnd(string callId, out CallSession? session);

    /// <summary>連接斷開時清理該用戶相關的通話狀態，避免留下永久忙線。</summary>
    int CleanupUser(string userId);
}

/// <summary>
/// WebRTC 通話信令的服務端狀態（呼叫會話 + 忙線表）。
///
/// 原先是 ChatHub 裡的兩個 static ConcurrentDictionary：
/// 靜態狀態無法單測、連接斷開時也清理不掉，還讓 Hub 承擔了不屬於它的職責。
/// 改為單例服務後由 Hub 的 OnDisconnectedAsync 顯式清理，
/// 並對「發起後無人接聽」的會話做超時回收，杜絕內存無限增長。
///
/// 單實例內存態：多實例橫向擴展時需換成 Redis 等共享存儲。
/// </summary>
public class CallCoordinator : ICallCoordinator
{
    /// <summary>呼叫發出後無人響應的超時時間。</summary>
    private static readonly TimeSpan InviteTimeout = TimeSpan.FromSeconds(60);

    private readonly ConcurrentDictionary<string, CallSession> _calls = new();
    private readonly ConcurrentDictionary<string, string> _busy = new(); // userId -> callId

    public bool TryInvite(CallSession session)
    {
        PurgeStale();

        // 只對被叫做忙線判定：主叫側是否「同時發起多路呼叫」由客戶端 UI 約束。
        if (_busy.ContainsKey(session.CalleeId)) return false;

        _calls[session.CallId] = session;
        return true;
    }

    public CallSession? Get(string callId) => _calls.GetValueOrDefault(callId);

    public bool TryAccept(string callId, string userId, out CallSession? session)
    {
        session = null;
        if (!_calls.TryGetValue(callId, out var s)) return false;
        if (s.CalleeId != userId) return false;

        s.Accepted = true;
        _busy[s.CallerId] = callId;
        _busy[s.CalleeId] = callId;
        session = s;
        return true;
    }

    public bool TryEnd(string callId, out CallSession? session)
    {
        session = null;
        if (!_calls.TryRemove(callId, out var s)) return false;

        ClearBusy(s.CallerId, callId);
        ClearBusy(s.CalleeId, callId);
        session = s;
        return true;
    }

    public int CleanupUser(string userId)
    {
        _busy.TryRemove(userId, out _);

        var removed = 0;
        foreach (var (callId, session) in _calls)
        {
            if (session.CallerId != userId && session.CalleeId != userId) continue;

            if (_calls.TryRemove(callId, out var s))
            {
                ClearBusy(s.CallerId, callId);
                ClearBusy(s.CalleeId, callId);
                removed++;
            }
        }
        return removed;
    }

    /// <summary>回收長時間無人接聽的會話，防止惡意/異常客戶端把會話表撐爆。</summary>
    private void PurgeStale()
    {
        var cutoff = DateTime.UtcNow - InviteTimeout;
        foreach (var (callId, session) in _calls)
        {
            if (session.Accepted || session.CreatedAt >= cutoff) continue;

            if (_calls.TryRemove(callId, out var s))
            {
                ClearBusy(s.CallerId, callId);
                ClearBusy(s.CalleeId, callId);
            }
        }
    }

    private void ClearBusy(string userId, string callId)
    {
        if (_busy.TryGetValue(userId, out var current) && current == callId)
            _busy.TryRemove(userId, out _);
    }
}

/// <summary>通話會話的對端解析。</summary>
public static class CallSessionExtensions
{
    public static string? PeerOf(this CallSession session, string userId) =>
        userId == session.CallerId ? session.CalleeId
        : userId == session.CalleeId ? session.CallerId
        : null;
}
