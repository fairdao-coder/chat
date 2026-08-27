using ChatServer.Data;
using ChatServer.DTOs;
using ChatServer.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ChatServer.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class GroupsController : ApiControllerBase
{
    private readonly AppDbContext _db;
    public GroupsController(AppDbContext db) => _db = db;

    [HttpPost]
    public async Task<IActionResult> Create(CreateGroupRequest req)
    {
        if (string.IsNullOrWhiteSpace(req.Name))
            return BadRequest("群名称不能为空");

        var group = new Group { Name = req.Name, OwnerId = UserId };
        group.Members.Add(new GroupMember { UserId = UserId, Role = GroupMemberRole.Owner });
        foreach (var m in req.MemberIds.Distinct())
            if (m != UserId)
                group.Members.Add(new GroupMember { UserId = m });

        _db.Groups.Add(group);
        await _db.SaveChangesAsync();
        return Ok(ToDto(group));
    }

    [HttpGet]
    public async Task<IActionResult> MyGroups()
    {
        var list = await _db.Groups
            .Where(g => g.Members.Any(m => m.UserId == UserId))
            .Select(g => new GroupDto(g.Id, g.Name, g.AvatarUrl, g.Members.Count, g.CreatedAt))
            .ToListAsync();
        return Ok(list);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> Get(Guid id)
    {
        var g = await _db.Groups
            .Include(x => x.Members)
            .FirstOrDefaultAsync(x => x.Id == id && x.Members.Any(m => m.UserId == UserId));
        if (g == null) return NotFound();
        return Ok(ToDto(g));
    }

    private static GroupDto ToDto(Group g) =>
        new(g.Id, g.Name, g.AvatarUrl, g.Members.Count, g.CreatedAt);
}
