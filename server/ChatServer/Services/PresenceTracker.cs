using System.Collections.Concurrent;

namespace ChatServer.Services;

/// <summary>
/// 內存在線狀態追蹤（單實例可用；多實例需改為 Redis/SignalR backplane）。
/// </summary>
public class PresenceTracker
{
    private readonly ConcurrentDictionary<string, HashSet<string>> _connections = new();
    private readonly object _lock = new();

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

    public Task<IReadOnlyList<string>> GetOnlineUsers(IEnumerable<string> userIds)
    {
        var ids = userIds.Select(x => x.ToString()).ToHashSet();
        var result = new List<string>();
        lock (_lock)
            foreach (var kv in _connections)
                if (ids.Contains(kv.Key))
                    result.Add(kv.Key);
        return Task.FromResult((IReadOnlyList<string>)result);
    }
}
