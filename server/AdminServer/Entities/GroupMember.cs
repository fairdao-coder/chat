namespace AdminServer.Entities;

/// <summary>與 ChatServer 共享 GroupMembers 表（由 AdminServer 負責建表）。</summary>
public class GroupMember
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid GroupId { get; set; }
    public Group Group { get; set; } = default!;
    public Guid UserId { get; set; }
    public AppUser User { get; set; } = default!;
    public GroupMemberRole Role { get; set; } = GroupMemberRole.Member;
    public DateTime JoinedAt { get; set; } = DateTime.UtcNow;
}
