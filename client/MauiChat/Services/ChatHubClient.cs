using System.Text.Json;
using System.Text.Json.Serialization;
using MauiChat.Config;
using MauiChat.Models;
using Microsoft.AspNetCore.SignalR.Client;

namespace MauiChat.Services;

/// <summary>
/// Singleton wrapper around the SignalR <c>/hubs/chat</c> connection.
///
/// - Authenticates with the JWT via <c>AccessTokenProvider</c> (the hub
///   reads it as the <c>access_token</c> query parameter on handshake).
/// - Exposes typed invoke methods matching ARCHITECTURE.md.
/// - Surfaces server events (<c>ReceiveMessage</c>, <c>UserOnline</c>,
///   <c>UserOffline</c>) as C# events so any ViewModel can subscribe.
/// </summary>
public class ChatHubClient
{
    private HubConnection? _connection;
    private string? _token;

    public event Action<MessageDto>? ReceiveMessage;
    public event Action<string>? UserOnline;
    public event Action<string>? UserOffline;
    public event Action? Connected;
    public event Action<Exception?>? Disconnected;

    public HubConnectionState State => _connection?.State ?? HubConnectionState.Disconnected;

    public async Task ConnectAsync(string token)
    {
        _token = token;

        if (_connection is not null)
        {
            // Already built: if dropped, restart with the (possibly new) token.
            if (_connection.State == HubConnectionState.Disconnected)
                await _connection.StartAsync();
            return;
        }

        _connection = new HubConnectionBuilder()
            .WithUrl(AppConfig.HubUrl, options =>
                options.AccessTokenProvider = () => Task.FromResult<string?>(_token))
            .AddJsonProtocol(options =>
            {
                options.PayloadSerializerOptions.PropertyNameCaseInsensitive = true;
                options.PayloadSerializerOptions.Converters.Add(new JsonStringEnumConverter());
            })
            .WithAutomaticReconnect()
            .Build();

        _connection.On<MessageDto>("ReceiveMessage", m => ReceiveMessage?.Invoke(m));
        _connection.On<string>("UserOnline", id => UserOnline?.Invoke(id));
        _connection.On<string>("UserOffline", id => UserOffline?.Invoke(id));
        _connection.Reconnected += _ => { Connected?.Invoke(); return Task.CompletedTask; };
        _connection.Closed += ex => { Disconnected?.Invoke(ex); return Task.CompletedTask; };

        await _connection.StartAsync();
        Connected?.Invoke();
    }

    public async Task DisconnectAsync()
    {
        if (_connection is not null)
        {
            await _connection.StopAsync();
            await _connection.DisposeAsync();
            _connection = null;
        }
    }

    // ---- Client -> Server invokes (method names/order per ARCHITECTURE.md) ----

    public Task SendPrivateMessageAsync(string toUserId, string content, MessageType type, string? mediaUrl = null)
        => Invoke("SendPrivateMessage", toUserId, content, type.ToString(), mediaUrl);

    public Task SendGroupMessageAsync(string groupId, string content, MessageType type, string? mediaUrl = null)
        => Invoke("SendGroupMessage", groupId, content, type.ToString(), mediaUrl);

    public Task JoinGroupAsync(string groupId)
        => Invoke("JoinGroup", groupId);

    public Task LeaveGroupAsync(string groupId)
        => Invoke("LeaveGroup", groupId);

    private Task Invoke(string method, params object?[] args)
    {
        if (_connection is null)
            throw new InvalidOperationException("Hub is not connected. Call ConnectAsync first.");
        return _connection.InvokeAsync(method, args);
    }
}
