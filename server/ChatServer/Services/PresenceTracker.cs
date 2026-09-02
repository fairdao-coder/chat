using System.Collections.Concurrent;

namespace ChatServer.Services;

/// <summary>
/// 內存在線狀態追蹤（單實例可用；多實例需改為 Redis/SignalR backplane）。
///
/// 一個用戶可能有多條連接（多標籤頁 / 多設備），只有最後一條斷開才算離線。
/// </summary>
public class PresenceTracker
{
    private readonly ConcurrentDictionary<string, HashSet<string>> _connections = new();
    private readonly object _lock = new();

    public int OnlineUserCount
    {
        get { lock (_lock) return _connections.Count; }
    }

    public Task UserConnected(string userId, string connectionId)
    {
        lock (_lock)
        {
            if (!_connections.TryGetValue(userId, out var set))
            {
                set = new HashSet<string>();
                _connections[userId] = set;
            }
            set.Add(connectionId);
        }
        return Task.CompletedTask;
    }

    public Task<bool> UserDisconnected(string userId, string connectionId)
    {
        bool stillOnline;
        lock (_lock)
        {
            if (_connections.TryGetValue(userId, out var set))
            {
                set.Remove(connectionId);
                stillOnline = set.Count > 0;
                if (!stillOnline)
                    _connections.TryRemove(userId, out _);
            }
            else
            {
                stillOnline = false;
            }
        }
        return Task.FromResult(stillOnline);
    }

    public Task<bool> IsOnline(string userId)
    {
        bool online;
        lock (_lock)
            online = _connections.ContainsKey(userId);
        return Task.FromResult(online);
    }

    /// <summary>
    /// 從候選集合中篩出在線用戶。
    ///
    /// 原實現遍歷整張在線表再判斷是否命中候選集合，複雜度 O(在線用戶數)；
    /// 改為按候選集合查表，複雜度 O(候選數)，在線用戶多時差異明顯。
    /// </summary>
    public Task<IReadOnlyList<string>> GetOnlineUsers(IEnumerable<string> userIds)
    {
        List<string> result = new();
        lock (_lock)
        {
            foreach (var id in userIds)
                if (_connections.ContainsKey(id))
                    result.Add(id);
        }
        return Task.FromResult((IReadOnlyList<string>)result);
    }
}
