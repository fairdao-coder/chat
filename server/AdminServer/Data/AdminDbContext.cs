using AdminServer.Entities;
using Microsoft.EntityFrameworkCore;

namespace AdminServer.Data;

public class AdminDbContext : DbContext
{
    public AdminDbContext(DbContextOptions<AdminDbContext> options) : base(options) { }

    // ---- 複用聊天庫中的表（與 ChatServer 共享同一數據庫，DbSet 名稱決定表名，需與 ChatServer 一致）----
    public DbSet<AppUser> Users => Set<AppUser>();
    public DbSet<Message> Messages => Set<Message>();
    public DbSet<Group> Groups => Set<Group>();
    public DbSet<Friendship> Friendships => Set<Friendship>();

    // ---- 後臺管理自有表 ----
    public DbSet<AdminUser> AdminUsers => Set<AdminUser>();
    public DbSet<AdminRole> AdminRoles => Set<AdminRole>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();
    public DbSet<UserFlag> UserFlags => Set<UserFlag>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        // 聊天表僅聲明鍵，列定義由 ChatServer 負責，這裡只讀/查詢不遷移，避免覆蓋 ChatServer 的表結構。
        b.Entity<AppUser>().HasKey(u => u.Id);
        b.Entity<Message>().HasKey(m => m.Id);
        b.Entity<Group>().HasKey(g => g.Id);
        b.Entity<Friendship>().HasKey(f => f.Id);
        b.Entity<AppUser>().ToTable("Users", t => t.ExcludeFromMigrations());
        b.Entity<Message>().ToTable("Messages", t => t.ExcludeFromMigrations());
        b.Entity<Group>().ToTable("Groups", t => t.ExcludeFromMigrations());
        b.Entity<Friendship>().ToTable("Friendships", t => t.ExcludeFromMigrations());

        b.Entity<AdminUser>().HasIndex(u => u.UserName).IsUnique();
        b.Entity<AdminUser>()
            .HasOne(u => u.Role).WithMany(r => r.Users)
            .HasForeignKey(u => u.RoleId).OnDelete(DeleteBehavior.Restrict);

        b.Entity<AuditLog>().HasIndex(a => a.At);
        b.Entity<UserFlag>().HasKey(f => f.UserId);
    }
}
