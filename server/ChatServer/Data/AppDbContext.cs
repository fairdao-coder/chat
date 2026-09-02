using Chat.Shared.Entities;
using Microsoft.EntityFrameworkCore;

namespace ChatServer.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<AppUser> Users => Set<AppUser>();
    public DbSet<Friendship> Friendships => Set<Friendship>();
    public DbSet<Group> Groups => Set<Group>();
    public DbSet<GroupMember> GroupMembers => Set<GroupMember>();
    public DbSet<Message> Messages => Set<Message>();
    public DbSet<DiscoverColumn> DiscoverColumns => Set<DiscoverColumn>();
    // 只讀：表由 AdminServer 建立，ChatServer 僅查詢功能開關。
    public DbSet<SystemSettings> SystemSettings => Set<SystemSettings>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<AppUser>(e =>
        {
            e.HasIndex(u => u.UserName).IsUnique();
        });

        b.Entity<Friendship>(e =>
        {
            // 複合唯一索引保證「同一對用戶只發一次好友請求」。
            e.HasIndex(f => new { f.RequesterId, f.AddresseeId }).IsUnique();
            // 列表類查詢按「我發起的」或「我收到的」單邊過濾，複合索引的左前綴用不上，
            // 故兩列各建一個獨立索引。
            e.HasIndex(f => f.RequesterId);
            e.HasIndex(f => f.AddresseeId);
            e.HasIndex(f => f.Status);

            e.HasOne(f => f.Requester).WithMany().HasForeignKey(f => f.RequesterId)
                .OnDelete(DeleteBehavior.NoAction);
            e.HasOne(f => f.Addressee).WithMany().HasForeignKey(f => f.AddresseeId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        b.Entity<Group>(e =>
        {
            e.HasOne(g => g.Owner).WithMany().HasForeignKey(g => g.OwnerId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        b.Entity<GroupMember>(e =>
        {
            e.HasIndex(m => new { m.GroupId, m.UserId }).IsUnique();
            // 「我加入的群」按 UserId 過濾，複合索引左前綴是 GroupId，用不上。
            e.HasIndex(m => m.UserId);

            e.HasOne(m => m.Group).WithMany(g => g.Members).HasForeignKey(m => m.GroupId)
                .OnDelete(DeleteBehavior.Cascade);
            e.HasOne(m => m.User).WithMany().HasForeignKey(m => m.UserId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        b.Entity<Message>(e =>
        {
            // 會話歷史主查詢：WHERE ConversationId = ? ORDER BY CreatedAt DESC LIMIT n
            // 恰好命中此索引，無需額外排序。
            e.HasIndex(m => new { m.ConversationId, m.CreatedAt });
            // 統計與「某用戶發過的消息」類查詢。
            e.HasIndex(m => m.SenderId);
            e.HasIndex(m => m.CreatedAt);

            e.HasOne(m => m.Sender).WithMany().HasForeignKey(m => m.SenderId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        b.Entity<DiscoverColumn>(e =>
        {
            // 發現頁按 Sort 排序後返回，索引消除排序開銷。
            e.HasIndex(c => c.Sort);
            e.HasIndex(c => new { c.Enabled, c.Pinned });
        });

        b.Entity<SystemSettings>(e =>
        {
            e.HasKey(s => s.Id);
        });
    }
}
