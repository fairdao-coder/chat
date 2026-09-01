using System.Collections.Generic;

namespace AdminServer.Entities;

/// <summary>與 ChatServer 共享 Groups 表（統計用，由 AdminServer 負責建表）。</summary>
public class Group
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = default!;
    public Guid OwnerId { get; set; }
    public AppUser Owner { get; set; } = default!;
    public string? AvatarUrl { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public List<GroupMember> Members { get; set; } = new();
}
