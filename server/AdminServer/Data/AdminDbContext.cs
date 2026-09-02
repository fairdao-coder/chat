using AdminServer.Entities;
using Chat.Shared.Entities;
using Microsoft.EntityFrameworkCore;

namespace AdminServer.Data;

public class AdminDbContext : DbContext
{
    public AdminDbContext(DbContextOptions<AdminDbContext> options) : base(options) { }

    // ---- 複用聊天庫中的表（與 ChatServer 共享同一數據庫，DbSet 名稱決定表名，需與 ChatServer 一致）----
    // 注意：所有表（含聊天表）統一由 AdminServer 負責建表，ChatServer 僅使用不建表。
    // 因此這裡的索引配置即為物理 schema；ChatServer 側的對等配置僅供其查詢計劃參考。
    public DbSet<AppUser> Users => Set<AppUser>();
    public DbSet<Message> Messages => Set<Message>();
    public DbSet<Group> Groups => Set<Group>();
    public DbSet<Friendship> Friendships => Set<Friendship>();
    public DbSet<GroupMember> GroupMembers => Set<GroupMember>();

    // ---- 後臺管理自有表 ----
    public DbSet<AdminUser> AdminUsers => Set<AdminUser>();
    public DbSet<AdminRole> AdminRoles => Set<AdminRole>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();
    public DbSet<UserFlag> UserFlags => Set<UserFlag>();
    public DbSet<DiscoverColumn> DiscoverColumns => Set<DiscoverColumn>();
    public DbSet<SystemSettings> SystemSettings => Set<SystemSettings>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        // ---- 聊天庫共享表 ----
        b.Entity<AppUser>(e =>
        {
            e.HasKey(u => u.Id);
            e.HasIndex(u => u.UserName).IsUnique();
            // 後臺用戶列表按註冊時間倒序分頁，索引消除排序。
            e.HasIndex(u => u.CreatedAt);
            // 「近 5 分鐘活躍」在線統計。
            e.HasIndex(u => u.LastSeenAt);
        });

        b.Entity<Message>(e =>
        {
            e.HasKey(m => m.Id);
            e.HasIndex(m => new { m.ConversationId, m.CreatedAt });
            e.HasIndex(m => m.SenderId);
            // 儀表盤按時間窗口統計消息量。
            e.HasIndex(m => m.CreatedAt);
        });

        b.Entity<Group>(e =>
        {
            e.HasKey(g => g.Id);
            e.HasIndex(g => g.OwnerId);
        });

        b.Entity<Friendship>(e =>
        {
            e.HasKey(f => f.Id);
            e.HasIndex(f => new { f.RequesterId, f.AddresseeId }).IsUnique();
            e.HasIndex(f => f.RequesterId);
            e.HasIndex(f => f.AddresseeId);
            e.HasIndex(f => f.Status);
        });

        b.Entity<GroupMember>(e =>
        {
            e.HasKey(gm => gm.Id);
            e.HasIndex(gm => new { gm.GroupId, gm.UserId }).IsUnique();
            e.HasIndex(gm => gm.UserId);
        });

        b.Entity<DiscoverColumn>(e =>
        {
            e.HasKey(c => c.Id);
            e.HasIndex(c => c.Sort);
            e.HasIndex(c => new { c.Enabled, c.Pinned });
        });

        b.Entity<SystemSettings>(e => e.HasKey(s => s.Id));

        // ---- 後臺自有表 ----
        b.Entity<AdminUser>(e =>
        {
            e.HasIndex(u => u.UserName).IsUnique();
            e.HasOne(u => u.Role).WithMany(r => r.Users)
                .HasForeignKey(u => u.RoleId).OnDelete(DeleteBehavior.Restrict);
        });

        b.Entity<AuditLog>(e =>
        {
            e.HasIndex(a => a.At);
            // 審計日誌按操作類型篩查。
            e.HasIndex(a => a.Action);
        });

        b.Entity<UserFlag>(e =>
        {
            e.HasKey(f => f.UserId);
            // 用戶列表需要快速篩出封禁用戶。
            e.HasIndex(f => f.IsBanned);
        });
    }
}
