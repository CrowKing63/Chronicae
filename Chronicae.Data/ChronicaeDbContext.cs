using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using Chronicae.Core.Models;

namespace Chronicae.Data
{
    public class ChronicaeDbContext : DbContext
    {
        public ChronicaeDbContext(DbContextOptions<ChronicaeDbContext> options) : base(options)
        {
        }

        public DbSet<Project> Projects { get; set; }
        public DbSet<Note> Notes { get; set; }
        public DbSet<NoteVersion> NoteVersions { get; set; }
        public DbSet<BackupRecord> BackupRecords { get; set; }
        public DbSet<ExportJob> ExportJobs { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // Configure Project entity
            modelBuilder.Entity<Project>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Name)
                    .IsRequired()
                    .HasMaxLength(500);
                entity.Property(e => e.NoteCount)
                    .HasDefaultValue(0);
                entity.Property(e => e.LastIndexedAt)
                    .HasConversion(
                        v => v.HasValue ? v.Value.ToUniversalTime() : (DateTime?)null,
                        v => v.HasValue ? DateTime.SpecifyKind(v.Value, DateTimeKind.Utc) : (DateTime?)null);

                // Configure relationship with Notes
                entity.HasMany(e => e.Notes)
                    .WithOne(e => e.Project)
                    .HasForeignKey(e => e.ProjectId)
                    .OnDelete(DeleteBehavior.Cascade);

                // Ignore Stats property as it's computed
                entity.Ignore(e => e.Stats);
            });

            // Configure Note entity
            modelBuilder.Entity<Note>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Title)
                    .IsRequired()
                    .HasMaxLength(1000);
                entity.Property(e => e.Content)
                    .IsRequired();
                entity.Property(e => e.Excerpt)
                    .HasMaxLength(500);
                
                // Configure Tags as JSON
                var tagsConverter = new ValueConverter<List<string>, string>(
                    v => JsonSerializer.Serialize(v, (JsonSerializerOptions?)null),
                    v => JsonSerializer.Deserialize<List<string>>(v, (JsonSerializerOptions?)null) ?? new List<string>());
                
                var tagsComparer = new ValueComparer<List<string>>(
                    (c1, c2) => c1!.SequenceEqual(c2!),
                    c => c.Aggregate(0, (a, v) => HashCode.Combine(a, v.GetHashCode())),
                    c => c.ToList());
                
                entity.Property(e => e.Tags)
                    .HasConversion(tagsConverter)
                    .Metadata.SetValueComparer(tagsComparer);

                // Configure date fields to store as UTC
                entity.Property(e => e.CreatedAt)
                    .HasConversion(
                        v => v.ToUniversalTime(),
                        v => DateTime.SpecifyKind(v, DateTimeKind.Utc));
                
                entity.Property(e => e.UpdatedAt)
                    .HasConversion(
                        v => v.ToUniversalTime(),
                        v => DateTime.SpecifyKind(v, DateTimeKind.Utc));

                entity.Property(e => e.Version)
                    .HasDefaultValue(1);

                // Configure indexes
                entity.HasIndex(e => e.UpdatedAt);
                entity.HasIndex(e => e.CreatedAt);
                entity.HasIndex(e => new { e.ProjectId, e.UpdatedAt });
                entity.HasIndex(e => e.Title);

                // Configure relationship with Versions
                entity.HasMany(e => e.Versions)
                    .WithOne(e => e.Note)
                    .HasForeignKey(e => e.NoteId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            // Configure NoteVersion entity
            modelBuilder.Entity<NoteVersion>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Title)
                    .IsRequired()
                    .HasMaxLength(1000);
                entity.Property(e => e.Content)
                    .IsRequired();
                entity.Property(e => e.Excerpt)
                    .HasMaxLength(500);
                
                // Configure date field to store as UTC
                entity.Property(e => e.CreatedAt)
                    .HasConversion(
                        v => v.ToUniversalTime(),
                        v => DateTime.SpecifyKind(v, DateTimeKind.Utc));

                entity.Property(e => e.Version)
                    .IsRequired();

                // Configure indexes
                entity.HasIndex(e => new { e.NoteId, e.CreatedAt });
                entity.HasIndex(e => e.CreatedAt);
            });

            // Configure BackupRecord entity
            modelBuilder.Entity<BackupRecord>(entity =>
            {
                entity.HasKey(e => e.Id);
                
                // Configure date fields to store as UTC
                entity.Property(e => e.StartedAt)
                    .HasConversion(
                        v => v.ToUniversalTime(),
                        v => DateTime.SpecifyKind(v, DateTimeKind.Utc));
                
                entity.Property(e => e.CompletedAt)
                    .HasConversion(
                        v => v.ToUniversalTime(),
                        v => DateTime.SpecifyKind(v, DateTimeKind.Utc));

                entity.Property(e => e.Status)
                    .HasConversion<string>();

                entity.Property(e => e.ArtifactPath)
                    .HasMaxLength(1000);

                // Configure indexes
                entity.HasIndex(e => e.StartedAt);
                entity.HasIndex(e => e.Status);
            });

            // Configure ExportJob entity
            modelBuilder.Entity<ExportJob>(entity =>
            {
                entity.HasKey(e => e.Id);
                
                entity.Property(e => e.Format)
                    .IsRequired()
                    .HasMaxLength(50);
                
                entity.Property(e => e.Status)
                    .IsRequired()
                    .HasMaxLength(50);

                entity.Property(e => e.ArtifactPath)
                    .HasMaxLength(1000);

                entity.Property(e => e.ErrorMessage)
                    .HasMaxLength(2000);

                // Configure date fields to store as UTC
                entity.Property(e => e.CreatedAt)
                    .HasConversion(
                        v => v.ToUniversalTime(),
                        v => DateTime.SpecifyKind(v, DateTimeKind.Utc));
                
                entity.Property(e => e.CompletedAt)
                    .HasConversion(
                        v => v.HasValue ? v.Value.ToUniversalTime() : (DateTime?)null,
                        v => v.HasValue ? DateTime.SpecifyKind(v.Value, DateTimeKind.Utc) : (DateTime?)null);

                // Configure relationships
                entity.HasOne(e => e.Project)
                    .WithMany()
                    .HasForeignKey(e => e.ProjectId)
                    .OnDelete(DeleteBehavior.SetNull);

                entity.HasOne(e => e.Note)
                    .WithMany()
                    .HasForeignKey(e => e.NoteId)
                    .OnDelete(DeleteBehavior.SetNull);

                entity.HasOne(e => e.Version)
                    .WithMany()
                    .HasForeignKey(e => e.VersionId)
                    .OnDelete(DeleteBehavior.SetNull);

                // Configure indexes
                entity.HasIndex(e => e.CreatedAt);
                entity.HasIndex(e => e.Status);
            });
        }
    }
}