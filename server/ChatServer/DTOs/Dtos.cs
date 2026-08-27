using ChatServer.Entities;

namespace ChatServer.DTOs;

public record RegisterRequest(string UserName, string Password, string? NickName);

public record LoginRequest(string UserName, string Password);

public record AuthResult(string Token, UserDto User);

public record UserDto(
    Guid Id,
    string UserName,
    string NickName,
    string? AvatarUrl,
    bool IsOnline,
    DateTime LastSeenAt);

public record MessageDto(
    Guid Id,
    string ConversationId,
    Guid SenderId,
    string SenderName,
    string? SenderAvatar,
    ChatType ChatType,
    string Content,
    MessageType Type,
    string? MediaUrl,
    DateTime CreatedAt);

public record CreateGroupRequest(string Name, List<Guid> MemberIds);

public record GroupDto(
    Guid Id,
    string Name,
    string? AvatarUrl,
    int MemberCount,
    DateTime CreatedAt);

public record FriendRequestDto(
    Guid Id,
    Guid UserId,
    string UserName,
    string NickName,
    string? AvatarUrl,
    DateTime CreatedAt);

public record ContactDto(
    Guid Id,
    string Name,
    string? AvatarUrl,
    bool IsOnline,
    string? LastMessage,
    DateTime? LastMessageAt,
    bool IsGroup);

public record FileUploadResult(string Url, string ContentType, long Size);
