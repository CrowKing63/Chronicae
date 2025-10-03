using Chronicae.Server.Windows.Data;
using Chronicae.Server.Windows.Models;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;

namespace Chronicae.Server.Windows.Tests;

public class ApiTests
{
    private ChronicaeDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<ChronicaeDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString()) // Unique database for each test
            .Options;

        var context = new ChronicaeDbContext(options);
        context.Database.EnsureCreated();
        return context;
    }

    [Fact]
    public async Task GetStatus_ReturnsCorrectData()
    {
        // Arrange
        using var context = CreateDbContext();
        
        // Add test data
        var project = new Project
        {
            Id = "test-project-id",
            Name = "Test Project",
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
            NoteCount = 2,
            VectorStatus = new VectorStatus { LastIndexedAt = DateTimeOffset.MinValue, PendingJobs = 0 }
        };
        context.Projects.Add(project);
        
        var note = new Note
        {
            Id = "test-note-id",
            ProjectId = "test-project-id",
            Title = "Test Note",
            Tags = new List<string> { "test", "sample" },
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
            Excerpt = "This is a test note",
            Content = "Full content of the test note",
            Version = 1
        };
        context.Notes.Add(note);
        
        var versionSnapshot = new VersionSnapshot
        {
            Id = "test-version-id",
            NoteId = "test-note-id", 
            Content = "Full content of the test note",
            CreatedAt = DateTimeOffset.UtcNow,
            VersionNumber = 1
        };
        context.VersionSnapshots.Add(versionSnapshot);
        
        await context.SaveChangesAsync();

        // Act - Simulate the GetStatus logic
        var uptime = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var projectsCount = await context.Projects.CountAsync();
        var notesCount = await context.Notes.CountAsync();
        var versionsCount = await context.VersionSnapshots.CountAsync();
        
        var recentProject = await context.Projects
            .OrderByDescending(p => p.UpdatedAt)
            .Select(p => p.Id)
            .FirstOrDefaultAsync();
        
        var status = new SystemStatus(uptime, recentProject, projectsCount, notesCount, versionsCount);

        // Assert
        Assert.Equal(1, status.Projects);
        Assert.Equal(1, status.NotesIndexed);
        Assert.Equal(1, status.VersionsStored);
        Assert.Equal("test-project-id", status.CurrentProjectId);
        Assert.True(status.Uptime > 0);
    }

    [Fact]
    public async Task DeleteNote_WithPurgeVersions_RemovesVersions()
    {
        // Arrange
        using var context = CreateDbContext();
        
        var note = new Note
        {
            Id = "test-note-id",
            ProjectId = "test-project-id",
            Title = "Test Note",
            Tags = new List<string> { "test" },
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
            Excerpt = "Test",
            Content = "Test content",
            Version = 1
        };
        context.Notes.Add(note);
        
        var version1 = new VersionSnapshot
        {
            Id = "version-1",
            NoteId = "test-note-id",
            Content = "Content version 1",
            CreatedAt = DateTimeOffset.UtcNow,
            VersionNumber = 1
        };
        context.VersionSnapshots.Add(version1);
        
        var version2 = new VersionSnapshot
        {
            Id = "version-2", 
            NoteId = "test-note-id",
            Content = "Content version 2",
            CreatedAt = DateTimeOffset.UtcNow,
            VersionNumber = 2
        };
        context.VersionSnapshots.Add(version2);
        
        await context.SaveChangesAsync();
        
        // Verify initial state
        Assert.Equal(1, await context.Notes.CountAsync());
        Assert.Equal(2, await context.VersionSnapshots.CountAsync());

        // Act: Simulate the delete logic with purgeVersions=true
        var noteToDelete = await context.Notes.FindAsync("test-note-id");
        if (noteToDelete != null)
        {
            // If purgeVersions is true, also delete associated version snapshots
            var versionSnapshots = await context.VersionSnapshots
                .Where(vs => vs.NoteId == "test-note-id")
                .ToListAsync();
            context.VersionSnapshots.RemoveRange(versionSnapshots);

            context.Notes.Remove(noteToDelete);
            await context.SaveChangesAsync();
        }

        // Assert
        Assert.Equal(0, await context.Notes.CountAsync());
        Assert.Equal(0, await context.VersionSnapshots.CountAsync());
    }

    [Fact]
    public async Task DeleteNote_WithoutPurgeVersions_KeepsVersions()
    {
        // Arrange
        using var context = CreateDbContext();
        
        var note = new Note
        {
            Id = "test-note-id",
            ProjectId = "test-project-id",
            Title = "Test Note",
            Tags = new List<string> { "test" },
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
            Excerpt = "Test",
            Content = "Test content",
            Version = 1
        };
        context.Notes.Add(note);
        
        var version1 = new VersionSnapshot
        {
            Id = "version-1",
            NoteId = "test-note-id",
            Content = "Content version 1",
            CreatedAt = DateTimeOffset.UtcNow,
            VersionNumber = 1
        };
        context.VersionSnapshots.Add(version1);
        
        await context.SaveChangesAsync();
        
        // Verify initial state
        Assert.Equal(1, await context.Notes.CountAsync());
        Assert.Equal(1, await context.VersionSnapshots.CountAsync());

        // Act: Simulate the delete logic with purgeVersions=false (default)
        var noteToDelete = await context.Notes.FindAsync("test-note-id");
        if (noteToDelete != null)
        {
            // Do NOT remove version snapshots when purgeVersions is false
            context.Notes.Remove(noteToDelete);
            await context.SaveChangesAsync();
        }

        // Assert - note is deleted but versions remain
        Assert.Equal(0, await context.Notes.CountAsync());
        Assert.Equal(1, await context.VersionSnapshots.CountAsync());
    }
}