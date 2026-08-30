using AdminServer.Entities;
using Microsoft.EntityFrameworkCore;

namespace AdminServer.Data;

public class AdminDbContext : DbContext
{
    public AdminDbContext(DbContextOptions<AdminDbContext> options) : base(options) { }

    // ---- 复用聊天库中的表（与 ChatServer 共享同一数据库，DbSet 名称决定表名，需与 ChatServer 一致）----
    public DbSet<AppUser> Users => Set<AppUser>();
    public DbSet<Message> Messages => Set<Message>();
    public DbSet<Group> Groups => Set<Group>();
    public DbSet<Friendship> Friendships => Set<Friendship>();

    // ---- 后台管理自有表 ----
    public DbSet<AdminUser> AdminUsers => Set<AdminUser>();
    public DbSet<AdminRole> AdminRoles => Set<AdminRole>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();
    public DbSet<UserFlag> UserFlags => Set<UserFlag>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        // 聊天表仅声明键，列定义由 ChatServer 的 EnsureCreated 负责，这里不重复配置以免漂移。
        b.Entity<AppUser>().HasKey(u => u.Id);
        b.Entity<Message>().HasKey(m => m.Id);
        b.Entity<Group>().HasKey(g => g.Id);
        b.Entity<Friendship>().HasKey(f => f.Id);

        b.Entity<AdminUser>().HasIndex(u => u.UserName).IsUnique();
        b.Entity<AdminUser>()
            .HasOne(u => u.Role).WithMany(r => r.Users)
            .HasForeignKey(u => u.RoleId).OnDelete(DeleteBehavior.Restrict);

        b.Entity<AuditLog>().HasIndex(a => a.At);
        b.Entity<UserFlag>().HasKey(f => f.UserId);
    }
}
