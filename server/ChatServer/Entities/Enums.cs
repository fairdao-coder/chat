using System.Text.Json.Serialization;

namespace ChatServer.Entities;

// [JsonConverter] 注解保证：无论走 AddJsonProtocol 的全局选项还是属性级反射，
// "Text"/"Image"/"File" 这类字符串都能可靠地与 enum 互转，避免客户端默认值与
// 服务端枚举不匹配时报告 "Error binding arguments"。
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
