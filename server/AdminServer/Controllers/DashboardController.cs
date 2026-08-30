using AdminServer.Authorization;
using AdminServer.Data;
using AdminServer.DTOs;
using AdminServer.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AdminServer.Controllers;

[ApiController]
[Route("api/admin/dashboard")]
[Authorize]
public class DashboardController : ControllerBase
{
    private readonly AdminDbContext _db;

    public DashboardController(AdminDbContext db) => _db = db;

    [HttpGet("stats")]
    public async Task<IActionResult> Stats()
    {
        var f = this.EnsurePermission(Permissions.DashboardView);
        if (f is not null) return f;

        var now = DateTime.UtcNow;
        var todayStart = now.Date;
        var sevenDaysAgo = now.AddDays(-7);
        var fourteenDaysAgo = now.AddDays(-14);
        var onlineThreshold = now.AddMinutes(-5);

        var totalUsers = await _db.Users.CountAsync();
        var totalMessages = await _db.Messages.CountAsync();
        var totalGroups = await _db.Groups.CountAsync();
        var totalFriends = await _db.Friendships.CountAsync();
        var bannedUsers = await _db.UserFlags.CountAsync(x => x.IsBanned);
        var onlineUsers = await _db.Users.CountAsync(u => u.LastSeenAt >= onlineThreshold);
        var messagesToday = await _db.Messages.CountAsync(m => m.CreatedAt >= todayStart);
        var newUsersToday = await _db.Users.CountAsync(u => u.CreatedAt >= todayStart);
        var newUsers7 = await _db.Users.CountAsync(u => u.CreatedAt >= sevenDaysAgo);

        var signups = await _db.Users
            .Where(u => u.CreatedAt >= fourteenDaysAgo)
            .GroupBy(u => u.CreatedAt.Date)
            .Select(g => new DailyCount(g.Key, g.Count()))
            .ToListAsync();

        var msgs = await _db.Messages
            .Where(m => m.CreatedAt >= fourteenDaysAgo)
            .GroupBy(m => m.CreatedAt.Date)
            .Select(g => new DailyCount(g.Key, g.Count()))
            .ToListAsync();

        var signupMap = signups.ToDictionary(d => d.Date, d => d.Count);
        var msgMap = msgs.ToDictionary(d => d.Date, d => d.Count);
        var signupsFull = new List<DailyCount>();
        var msgsFull = new List<DailyCount>();
        for (var d = fourteenDaysAgo.Date; d <= now.Date; d = d.AddDays(1))
        {
            signupsFull.Add(new DailyCount(d, signupMap.GetValueOrDefault(d, 0)));
            msgsFull.Add(new DailyCount(d, msgMap.GetValueOrDefault(d, 0)));
        }

        return Ok(new DashboardStats(
            totalUsers, totalMessages, totalGroups, totalFriends,
            bannedUsers, onlineUsers, messagesToday, newUsersToday, newUsers7,
            signupsFull, msgsFull));
    }
}
