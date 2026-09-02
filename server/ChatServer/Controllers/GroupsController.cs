using Chat.Shared.Entities;
using ChatServer.Data;
using ChatServer.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ChatServer.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class GroupsController : ApiControllerBase
{
    /// <summary>單個群的人數上限。</summary>
    private const int MaxMembers = 500;

    private readonly AppDbContext _db;

    public GroupsController(AppDbContext db) => _db = db;

    [HttpPost]
    public async Task<IActionResult> Create(CreateGroupRequest req, CancellationToken ct = default)
    {
        if (req == null || string.IsNullOrWhiteSpace(req.Name))
            return BadRequest("群名稱不能為空");

        var memberIds = (req.MemberIds ?? [])
            .Where(id => id != Guid.Empty && id != UserId)
            .Distinct()
            .Take(MaxMembers - 1)
            .ToList();

        var group = new Group { Name = req.Name.Trim(), OwnerId = UserId };
        group.Members.Add(new GroupMember { UserId = UserId, Role = GroupMemberRole.Owner });

        foreach (var m in memberIds)
            group.Members.Add(new GroupMember { UserId = m });

        _db.Groups.Add(group);
        await _db.SaveChangesAsync(ct);
        return Ok(ToDto(group));
    }

    [HttpGet]
    public async Task<IActionResult> MyGroups(CancellationToken ct = default)
    {
        var list = await _db.Groups
            .AsNoTracking()
            .Where(g => g.Members.Any(m => m.UserId == UserId))
            .OrderByDescending(g => g.CreatedAt)
            .Select(g => new GroupDto(g.Id, g.Name, g.AvatarUrl, g.Members.Count, g.CreatedAt))
            .ToListAsync(ct);
        return Ok(list);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct = default)
    {
        var g = await _db.Groups
            .AsNoTracking()
            .Where(x => x.Id == id && x.Members.Any(m => m.UserId == UserId))
            .Select(x => new GroupDto(x.Id, x.Name, x.AvatarUrl, x.Members.Count, x.CreatedAt))
            .FirstOrDefaultAsync(ct);

        if (g == null) return NotFound();
        return Ok(g);
    }

    private static GroupDto ToDto(Group g) =>
        new(g.Id, g.Name, g.AvatarUrl, g.Members.Count, g.CreatedAt);
}
