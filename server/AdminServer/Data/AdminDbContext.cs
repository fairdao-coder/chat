using AdminServer.Entities;
using Microsoft.EntityFrameworkCore;

namespace AdminServer.Data;

public class AdminDbContext : DbContext
{
    public AdminDbContext(DbContextOptions<AdminDbContext> options) : base(options) { }

    // ---- 複用聊天庫中的表（與 ChatServer 共享同一數據庫，DbSet 名稱決定表名，需與 ChatServer 一致）----
    // 注意：所有表（含聊天表）統一由 AdminServer 負責建表，ChatServer 僅使用不建表。
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
        // 所有表（含聊天表）均由 AdminServer 負責建表，不再 ExcludeFromMigrations。
        b.Entity<AppUser>().HasKey(u => u.Id);
        b.Entity<Message>().HasKey(m => m.Id);
        b.Entity<Group>().HasKey(g => g.Id);
        b.Entity<Friendship>().HasKey(f => f.Id);
        b.Entity<GroupMember>().HasKey(gm => gm.Id);
        b.Entity<DiscoverColumn>().HasKey(c => c.Id);

        b.Entity<AdminUser>().HasIndex(u => u.UserName).IsUnique();
        b.Entity<AdminUser>()
            .HasOne(u => u.Role).WithMany(r => r.Users)
            .HasForeignKey(u => u.RoleId).OnDelete(DeleteBehavior.Restrict);

        b.Entity<AuditLog>().HasIndex(a => a.At);
        b.Entity<UserFlag>().HasKey(f => f.UserId);
        b.Entity<SystemSettings>().HasKey(s => s.Id);
    }
}
