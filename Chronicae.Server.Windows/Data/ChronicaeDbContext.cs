using Chronicae.Server.Windows.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;

namespace Chronicae.Server.Windows.Data;

public class ChronicaeDbContext : DbContext
{
    public ChronicaeDbContext(DbContextOptions<ChronicaeDbContext> options) : base(options)
    {
    }

    public DbSet<Project> Projects { get; set; }
    public DbSet<Note> Notes { get; set; }
    public DbSet<VersionSnapshot> VersionSnapshots { get; set; } // Added DbSet for VersionSnapshot

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Project>()
            .OwnsOne(p => p.VectorStatus);

        // 인덱스 추가
        modelBuilder.Entity<Project>()
            .HasIndex(p => p.Id)
            .IsUnique();

        modelBuilder.Entity<Note>()
            .HasIndex(n => n.ProjectId);  // 프로젝트별 노트 검색 최적화
        
        modelBuilder.Entity<Note>()
            .HasIndex(n => n.Id)
            .IsUnique();

        modelBuilder.Entity<VersionSnapshot>()
            .HasIndex(vs => vs.NoteId);  // 노트별 버전 검색 최적화
        
        modelBuilder.Entity<VersionSnapshot>()
            .HasIndex(vs => new { vs.NoteId, vs.VersionNumber })
            .IsUnique();  // 노트 ID와 버전 번호 조합의 고유성 보장

        var stringListComparer = new ValueComparer<List<string>>(
            (c1, c2) => (c1 == null && c2 == null) || (c1 != null && c2 != null && c1.SequenceEqual(c2)),
            c => c.Aggregate(0, (a, v) => HashCode.Combine(a, v.GetHashCode())),
            c => c.ToList());

        modelBuilder.Entity<Note>().Property(n => n.Tags).HasConversion(
            v => string.Join(',', v),
            v => v.Split(',', StringSplitOptions.RemoveEmptyEntries).ToList())
            .Metadata.SetValueComparer(stringListComparer);
    }
}