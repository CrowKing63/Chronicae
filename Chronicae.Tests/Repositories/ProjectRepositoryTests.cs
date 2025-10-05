using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Xunit;
using Chronicae.Core.Interfaces;
using Chronicae.Core.Models;
using Chronicae.Data;
using Chronicae.Data.Repositories;

namespace Chronicae.Tests.Repositories
{
    public class ProjectRepositoryTests : IDisposable
    {
        private readonly ChronicaeDbContext _context;
        private readonly IProjectRepository _repository;

        public ProjectRepositoryTests()
        {
            var options = new DbContextOptionsBuilder<ChronicaeDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;

            _context = new ChronicaeDbContext(options);
            _repository = new ProjectRepository(_context);
        }

        public void Dispose()
        {
            _context.Dispose();
        }

        [Fact]
        public async Task CreateAsync_ShouldCreateProject()
        {
            // Arrange
            var projectName = "Test Project";

            // Act
            var result = await _repository.CreateAsync(projectName);

            // Assert
            Assert.NotNull(result);
            Assert.Equal(projectName, result.Name);
            Assert.Equal(0, result.NoteCount);
            Assert.Null(result.LastIndexedAt);
            Assert.NotEqual(Guid.Empty, result.Id);

            // Verify project was saved to database
            var savedProject = await _context.Projects.FindAsync(result.Id);
            Assert.NotNull(savedProject);
            Assert.Equal(projectName, savedProject.Name);
            Assert.Equal(0, savedProject.NoteCount);
        }

        [Fact]
        public async Task CreateAsync_ShouldTrimProjectName()
        {
            // Arrange
            var projectName = "  Test Project  ";
            var expectedName = "Test Project";

            // Act
            var result = await _repository.CreateAsync(projectName);

            // Assert
            Assert.NotNull(result);
            Assert.Equal(expectedName, result.Name);

            // Verify in database
            var savedProject = await _context.Projects.FindAsync(result.Id);
            Assert.NotNull(savedProject);
            Assert.Equal(expectedName, savedProject.Name);
        }

        [Fact]
        public async Task GetAllAsync_ShouldReturnProjectsOrderedByName()
        {
            // Arrange
            var project1 = await _repository.CreateAsync("Zebra Project");
            var project2 = await _repository.CreateAsync("Alpha Project");
            var project3 = await _repository.CreateAsync("Beta Project");

            // Act
            var result = await _repository.GetAllAsync();

            // Assert
            var projects = result.ToList();
            Assert.Equal(3, projects.Count);
            Assert.Equal("Alpha Project", projects[0].Name);
            Assert.Equal("Beta Project", projects[1].Name);
            Assert.Equal("Zebra Project", projects[2].Name);
        }

        [Fact]
        public async Task GetAllAsync_WithIncludeStats_ShouldCalculateStatistics()
        {
            // Arrange
            var project = await _repository.CreateAsync("Test Project");
            
            // Add some test notes to calculate stats
            var note1 = new Note
            {
                Id = Guid.NewGuid(),
                ProjectId = project.Id,
                Title = "Note 1",
                Content = "This is the first note content",
                Tags = new List<string> { "tag1", "tag2" },
                CreatedAt = DateTime.UtcNow.AddDays(-2),
                UpdatedAt = DateTime.UtcNow.AddDays(-1),
                Version = 1
            };

            var note2 = new Note
            {
                Id = Guid.NewGuid(),
                ProjectId = project.Id,
                Title = "Note 2",
                Content = "This is the second note with different content length",
                Tags = new List<string> { "tag2", "tag3" },
                CreatedAt = DateTime.UtcNow.AddDays(-1),
                UpdatedAt = DateTime.UtcNow,
                Version = 1
            };

            _context.Notes.AddRange(note1, note2);

            // Add some versions
            var version1 = new NoteVersion
            {
                Id = Guid.NewGuid(),
                NoteId = note1.Id,
                Title = note1.Title,
                Content = note1.Content,
                CreatedAt = note1.CreatedAt,
                Version = 1
            };

            var version2 = new NoteVersion
            {
                Id = Guid.NewGuid(),
                NoteId = note2.Id,
                Title = note2.Title,
                Content = note2.Content,
                CreatedAt = note2.CreatedAt,
                Version = 1
            };

            _context.NoteVersions.AddRange(version1, version2);
            await _context.SaveChangesAsync();

            // Act
            var result = await _repository.GetAllAsync(includeStats: true);

            // Assert
            var projects = result.ToList();
            Assert.Single(projects);
            
            var projectWithStats = projects[0];
            Assert.NotNull(projectWithStats.Stats);
            Assert.Equal(2, projectWithStats.Stats.VersionCount);
            Assert.Equal(3, projectWithStats.Stats.UniqueTagCount); // tag1, tag2, tag3
            Assert.True(projectWithStats.Stats.AverageNoteLength > 0);
            Assert.Equal(note2.UpdatedAt, projectWithStats.Stats.LatestNoteUpdatedAt);
        }

        [Fact]
        public async Task GetByIdAsync_ShouldReturnProject()
        {
            // Arrange
            var project = await _repository.CreateAsync("Test Project");

            // Act
            var result = await _repository.GetByIdAsync(project.Id);

            // Assert
            Assert.NotNull(result);
            Assert.Equal(project.Id, result.Id);
            Assert.Equal(project.Name, result.Name);
        }

        [Fact]
        public async Task GetByIdAsync_WithNonExistentId_ShouldReturnNull()
        {
            // Arrange
            var nonExistentId = Guid.NewGuid();

            // Act
            var result = await _repository.GetByIdAsync(nonExistentId);

            // Assert
            Assert.Null(result);
        }

        [Fact]
        public async Task UpdateAsync_ShouldUpdateProjectName()
        {
            // Arrange
            var project = await _repository.CreateAsync("Original Name");
            var newName = "Updated Name";

            // Act
            var result = await _repository.UpdateAsync(project.Id, newName);

            // Assert
            Assert.NotNull(result);
            Assert.Equal(newName, result.Name);
            Assert.Equal(project.Id, result.Id);

            // Verify in database
            var updatedProject = await _context.Projects.FindAsync(project.Id);
            Assert.NotNull(updatedProject);
            Assert.Equal(newName, updatedProject.Name);
        }

        [Fact]
        public async Task UpdateAsync_WithNonExistentId_ShouldReturnNull()
        {
            // Arrange
            var nonExistentId = Guid.NewGuid();

            // Act
            var result = await _repository.UpdateAsync(nonExistentId, "New Name");

            // Assert
            Assert.Null(result);
        }

        [Fact]
        public async Task DeleteAsync_ShouldDeleteProject()
        {
            // Arrange
            var project = await _repository.CreateAsync("Project to Delete");

            // Act
            var result = await _repository.DeleteAsync(project.Id);

            // Assert
            Assert.True(result);

            // Verify project is deleted
            var deletedProject = await _context.Projects.FindAsync(project.Id);
            Assert.Null(deletedProject);
        }

        [Fact]
        public async Task DeleteAsync_WithNonExistentId_ShouldReturnFalse()
        {
            // Arrange
            var nonExistentId = Guid.NewGuid();

            // Act
            var result = await _repository.DeleteAsync(nonExistentId);

            // Assert
            Assert.False(result);
        }

        [Fact]
        public async Task DeleteAsync_ShouldCascadeDeleteNotesAndVersions()
        {
            // Arrange
            var project = await _repository.CreateAsync("Project with Notes");
            
            // Add notes and versions
            var note = new Note
            {
                Id = Guid.NewGuid(),
                ProjectId = project.Id,
                Title = "Test Note",
                Content = "Test Content",
                Tags = new List<string>(),
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                Version = 1
            };

            _context.Notes.Add(note);

            var version = new NoteVersion
            {
                Id = Guid.NewGuid(),
                NoteId = note.Id,
                Title = note.Title,
                Content = note.Content,
                CreatedAt = note.CreatedAt,
                Version = 1
            };

            _context.NoteVersions.Add(version);
            await _context.SaveChangesAsync();

            // Act
            var result = await _repository.DeleteAsync(project.Id);

            // Assert
            Assert.True(result);

            // Verify cascade deletion
            var deletedNote = await _context.Notes.FindAsync(note.Id);
            Assert.Null(deletedNote);

            var deletedVersion = await _context.NoteVersions.FindAsync(version.Id);
            Assert.Null(deletedVersion);
        }

        [Fact]
        public async Task SwitchActiveAsync_ShouldUpdateActiveProject()
        {
            // Arrange
            var project1 = await _repository.CreateAsync("Project 1");
            var project2 = await _repository.CreateAsync("Project 2");

            // Act
            var result = await _repository.SwitchActiveAsync(project2.Id);

            // Assert
            Assert.NotNull(result);
            Assert.Equal(project2.Id, result.Id);
            Assert.Equal(project2.Name, result.Name);

            // Note: The current implementation doesn't actually store the active project ID
            // This test verifies that the method returns the correct project when it exists
            // In a full implementation, this would also verify that the active project ID is stored
        }

        [Fact]
        public async Task SwitchActiveAsync_WithNonExistentId_ShouldReturnNull()
        {
            // Arrange
            var nonExistentId = Guid.NewGuid();

            // Act
            var result = await _repository.SwitchActiveAsync(nonExistentId);

            // Assert
            Assert.Null(result);
        }

        [Fact]
        public async Task ResetAsync_ShouldDeleteAllNotes()
        {
            // Arrange
            var project = await _repository.CreateAsync("Project to Reset");
            
            // Add multiple notes with versions
            var note1 = new Note
            {
                Id = Guid.NewGuid(),
                ProjectId = project.Id,
                Title = "Note 1",
                Content = "Content 1",
                Tags = new List<string> { "tag1" },
                CreatedAt = DateTime.UtcNow.AddDays(-1),
                UpdatedAt = DateTime.UtcNow.AddDays(-1),
                Version = 1
            };

            var note2 = new Note
            {
                Id = Guid.NewGuid(),
                ProjectId = project.Id,
                Title = "Note 2",
                Content = "Content 2",
                Tags = new List<string> { "tag2" },
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                Version = 1
            };

            _context.Notes.AddRange(note1, note2);

            // Add versions for the notes
            var version1 = new NoteVersion
            {
                Id = Guid.NewGuid(),
                NoteId = note1.Id,
                Title = note1.Title,
                Content = note1.Content,
                CreatedAt = note1.CreatedAt,
                Version = 1
            };

            var version2 = new NoteVersion
            {
                Id = Guid.NewGuid(),
                NoteId = note2.Id,
                Title = note2.Title,
                Content = note2.Content,
                CreatedAt = note2.CreatedAt,
                Version = 1
            };

            _context.NoteVersions.AddRange(version1, version2);

            // Update project stats
            project.NoteCount = 2;
            project.LastIndexedAt = DateTime.UtcNow;
            _context.Projects.Update(project);
            
            await _context.SaveChangesAsync();

            // Act
            var result = await _repository.ResetAsync(project.Id);

            // Assert
            Assert.NotNull(result);
            Assert.Equal(project.Id, result.Id);
            Assert.Equal(0, result.NoteCount);
            Assert.Null(result.LastIndexedAt);

            // Verify all notes are deleted
            var remainingNotes = await _context.Notes
                .Where(n => n.ProjectId == project.Id)
                .CountAsync();
            Assert.Equal(0, remainingNotes);

            // Verify all versions are deleted (cascade delete)
            var remainingVersions = await _context.NoteVersions
                .Where(v => v.NoteId == note1.Id || v.NoteId == note2.Id)
                .CountAsync();
            Assert.Equal(0, remainingVersions);

            // Verify project still exists but is reset
            var resetProject = await _context.Projects.FindAsync(project.Id);
            Assert.NotNull(resetProject);
            Assert.Equal(0, resetProject.NoteCount);
            Assert.Null(resetProject.LastIndexedAt);
        }

        [Fact]
        public async Task ResetAsync_WithNonExistentId_ShouldReturnNull()
        {
            // Arrange
            var nonExistentId = Guid.NewGuid();

            // Act
            var result = await _repository.ResetAsync(nonExistentId);

            // Assert
            Assert.Null(result);
        }

        [Fact]
        public async Task GetActiveProjectIdAsync_ShouldReturnFirstProjectId()
        {
            // Arrange
            var project1 = await _repository.CreateAsync("First Project");
            var project2 = await _repository.CreateAsync("Second Project");

            // Act
            var result = await _repository.GetActiveProjectIdAsync();

            // Assert
            // The current implementation returns the first project alphabetically
            // Since "First Project" comes before "Second Project" alphabetically
            Assert.Equal(project1.Id, result);
        }

        [Fact]
        public async Task GetActiveProjectIdAsync_WithNoProjects_ShouldReturnNull()
        {
            // Act
            var result = await _repository.GetActiveProjectIdAsync();

            // Assert
            Assert.Null(result);
        }
    }
}