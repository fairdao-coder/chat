using System.Text.Json.Serialization;

namespace Chat.Shared.Entities;

// [JsonConverter] 註解保證：無論走 AddJsonProtocol 的全局選項還是屬性級反射，
// "Text"/"Image"/"File" 這類字符串都能可靠地與 enum 互轉，避免客戶端默認值與
// 服務端枚舉不匹配時報告 "Error binding arguments"。
[JsonConverter(typeof(JsonStringEnumConverter))]
public enum ChatType
{
    Private = 0,
    Group = 1
}

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum MessageType
{
    Text = 0,
    Image = 1,
    File = 2,
    Voice = 3
}

public enum FriendshipStatus
{
    Pending = 0,
    Accepted = 1
}

public enum GroupMemberRole
{
    Member = 0,
    Admin = 1,
    Owner = 2
}

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum CallType
{
    Voice = 0,
    Video = 1
}

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum CallState
{
    Calling = 0,
    Connecting = 1,
    Connected = 2,
    Ended = 3
}

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum CallEndReason
{
    Declined = 0,
    Busy = 1,
    Timeout = 2,
    HangUp = 3,
    Offline = 4,
    Error = 5
}
