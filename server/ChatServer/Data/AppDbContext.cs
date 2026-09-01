using ChatServer.Entities;
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
        b.Entity<AppUser>().HasIndex(u => u.UserName).IsUnique();

        b.Entity<Friendship>()
            .HasIndex(f => new { f.RequesterId, f.AddresseeId })
            .IsUnique();

        b.Entity<GroupMember>()
            .HasIndex(m => new { m.GroupId, m.UserId })
            .IsUnique();

        b.Entity<Message>()
            .HasIndex(m => new { m.ConversationId, m.CreatedAt });

        b.Entity<Friendship>()
            .HasOne(f => f.Requester).WithMany().HasForeignKey(f => f.RequesterId)
            .OnDelete(DeleteBehavior.NoAction);
        b.Entity<Friendship>()
            .HasOne(f => f.Addressee).WithMany().HasForeignKey(f => f.AddresseeId)
            .OnDelete(DeleteBehavior.NoAction);

        b.Entity<Group>()
            .HasOne(g => g.Owner).WithMany().HasForeignKey(g => g.OwnerId)
            .OnDelete(DeleteBehavior.NoAction);

        b.Entity<GroupMember>()
            .HasOne(m => m.Group).WithMany(g => g.Members).HasForeignKey(m => m.GroupId)
            .OnDelete(DeleteBehavior.Cascade);
        b.Entity<GroupMember>()
            .HasOne(m => m.User).WithMany().HasForeignKey(m => m.UserId)
            .OnDelete(DeleteBehavior.NoAction);

        b.Entity<Message>()
            .HasOne(m => m.Sender).WithMany().HasForeignKey(m => m.SenderId)
            .OnDelete(DeleteBehavior.NoAction);

        b.Entity<DiscoverColumn>().HasIndex(c => c.Sort);

        b.Entity<SystemSettings>().HasKey(s => s.Id);
    }
}
