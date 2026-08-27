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

    public async Task SendPrivateMessage(
        string toUserId,
        string content,
        MessageType type = MessageType.Text,
        string? mediaUrl = null)
    {
        var fromId = Guid.Parse(Context.UserIdentifier!);
        var toId = Guid.Parse(toUserId);

        var areFriends = await _db.Friendships.AnyAsync(f =>
            f.Status == FriendshipStatus.Accepted &&
            ((f.RequesterId == fromId && f.AddresseeId == toId) ||
             (f.RequesterId == toId && f.AddresseeId == fromId)));
        if (!areFriends)
            throw new HubException("你们还不是好友，无法发送消息");

        var msg = new Message
        {
            ConversationId = ConversationKeys.Private(fromId, toId),
            SenderId = fromId,
            ChatType = ChatType.Private,
            Content = content,
            Type = type,
            MediaUrl = mediaUrl
        };
        _db.Messages.Add(msg);
        await _db.SaveChangesAsync();

        var dto = await MapAsync(msg);
        await Clients.User(toUserId).SendAsync("ReceiveMessage", dto);
        await Clients.Caller.SendAsync("ReceiveMessage", dto);
    }

    public async Task SendGroupMessage(
        string groupId,
        string content,
        MessageType type = MessageType.Text,
        string? mediaUrl = null)
    {
        var fromId = Guid.Parse(Context.UserIdentifier!);
        var gid = Guid.Parse(groupId);

        var isMember = await _db.GroupMembers.AnyAsync(m => m.GroupId == gid && m.UserId == fromId);
        if (!isMember)
            throw new HubException("你不在该群，无法发送消息");

        var msg = new Message
        {
            ConversationId = ConversationKeys.Group(gid),
            SenderId = fromId,
            ChatType = ChatType.Group,
            Content = content,
            Type = type,
            MediaUrl = mediaUrl
        };
        _db.Messages.Add(msg);
        await _db.SaveChangesAsync();

        var dto = await MapAsync(msg);
        await Clients.Group("group_" + gid).SendAsync("ReceiveMessage", dto);
    }

    public async Task JoinGroup(string groupId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, "group_" + groupId);
    }

    public async Task LeaveGroup(string groupId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, "group_" + groupId);
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
