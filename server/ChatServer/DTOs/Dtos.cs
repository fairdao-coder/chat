using Chat.Shared.Entities;

namespace ChatServer.DTOs;

public record RegisterRequest(string UserName, string Password, string? NickName);

public record LoginRequest(string UserName, string Password);

/// <summary>修改密碼請求（聊天用戶自助）。</summary>
public record ChangePasswordRequest(string OldPassword, string NewPassword);

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

public record SendPrivateRequest(string To, string Content);

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

/// <param name="LastMessageType">
/// 最後一條消息的類型。圖片/文件/語音的 Content 為空，客戶端靠它渲染成
/// "[圖片]" / "[文件]" / "[語音]" 之類的圖標佔位，而不是空白。
/// </param>
public record ContactDto(
    Guid Id,
    string Name,
    string? AvatarUrl,
    bool IsOnline,
    string? LastMessage,
    DateTime? LastMessageAt,
    bool IsGroup,
    MessageType? LastMessageType = null);

public record FileUploadResult(string Url, string ContentType, long Size);

public record DiscoverColumnDto(
    Guid Id,
    string Title,
    string? Icon,
    string Kind,
    string? Content,
    int Sort,
    bool Pinned);

/// <summary>
/// 客戶端功能開關。字段與 AdminServer 的 SystemSettings 一一對應。
/// </summary>
public record FeatureSettingsDto(
    bool ShowOnlineStatus,
    bool EnableVoiceCall,
    bool EnableVideoCall,
    bool AllowFile,
    bool AllowVoice);
