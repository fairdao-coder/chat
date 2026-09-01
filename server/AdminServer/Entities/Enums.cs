using System.Text.Json.Serialization;

namespace AdminServer.Entities;

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
