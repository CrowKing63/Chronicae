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
    public class NoteRepositoryTests : IDisposable
    {
        private readonly ChronicaeDbContext _context;
        private readonly INoteRepository _repository;
        private readonly Project _testProject;

        public NoteRepositoryTests()
        {
            var options = new DbContextOptionsBuilder<ChronicaeDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;

            _context = new ChronicaeDbContext(options);
            _repository = new TestNoteRepository(_context);

            // Create a test project
            _testProject = new Project
            {
                Id = Guid.NewGuid(),
                Name = "Test Project",
                NoteCount = 0,
                LastIndexedAt = DateTime.UtcNow
            };

            _context.Projects.Add(_testProject);
            _context.SaveChanges();
        }

        public void Dispose()
        {
            _context.Dispose();
        }

        [Fact]
        public async Task CreateAsync_ShouldCreateNoteWithVersion()
        {
            // Arrange
            var title = "Test Note";
            var content = "This is a test note content that should be long enough to generate an excerpt.";
            var tags = new List<string> { "test", "unit-test" };

            // Act
            var result = await _repository.CreateAsync(_testProject.Id, title, content, tags);

            // Assert
            Assert.NotNull(result);
            Assert.Equal(title, result.Title);
            Assert.Equal(content, result.Content);
            Assert.Equal(tags, result.Tags);
            Assert.Equal(1, result.Version);
            Assert.True(result.CreatedAt <= DateTime.UtcNow);
            Assert.True(result.UpdatedAt <= DateTime.UtcNow);
            Assert.NotNull(result.Excerpt);
            Assert.Equal(_testProject.Id, result.ProjectId);

            // Verify version was created
            var versions = await _context.NoteVersions
                .Where(v => v.NoteId == result.Id)
                .ToListAsync();
            Assert.Single(versions);
            Assert.Equal(1, versions[0].Version);
            Assert.Equal(title, versions[0].Title);
            Assert.Equal(content, versions[0].Content);

            // Verify project note count was updated
            var updatedProject = await _context.Projects.FindAsync(_testProject.Id);
            Assert.NotNull(updatedProject);
            Assert.Equal(1, updatedProject.NoteCount);
        }

        [Fact]
        public async Task CreateAsync_WithNonExistentProject_ShouldReturnNull()
        {
            // Arrange
            var nonExistentProjectId = Guid.NewGuid();
            var title = "Test Note";
            var content = "Test content";
            var tags = new List<string>();

            // Act
            var result = await _repository.CreateAsync(nonExistentProjectId, title, content, tags);

            // Assert
            Assert.Null(result);
        }

        [Fact]
        public async Task UpdateAsync_WithConflict_ShouldReturnConflict()
        {
            // Arrange
            var note = await CreateTestNote("Original Title", "Original content");
            var outdatedVersion = note.Version - 1; // Simulate outdated version

            // Act
            var result = await _repository.UpdateAsync(
                _testProject.Id, 
                note.Id, 
                "Updated Title", 
                "Updated content", 
                new List<string> { "updated" }, 
                NoteUpdateMode.Full, 
                outdatedVersion);

            // Assert
            Assert.IsType<NoteUpdateResult.ConflictResult>(result);
            var conflictResult = (NoteUpdateResult.ConflictResult)result;
            Assert.Equal(note.Id, conflictResult.CurrentNote.Id);
            Assert.Equal(note.Version, conflictResult.CurrentNote.Version);
        }

        [Fact]
        public async Task UpdateAsync_WithValidVersion_ShouldUpdateSuccessfully()
        {
            // Arrange
            var note = await CreateTestNote("Original Title", "Original content");
            
            // Debug: Check initial note version
            Assert.Equal(1, note.Version);
            
            // Refresh note from database to ensure we have the correct version
            var refreshedNote = await _repository.GetByIdAsync(_testProject.Id, note.Id);
            Assert.NotNull(refreshedNote);
            
            // Debug: Check refreshed note version
            Assert.Equal(1, refreshedNote.Version);
            
            var newTitle = "Updated Title";
            var newContent = "Updated content with more details";
            var newTags = new List<string> { "updated", "test" };

            // Act
            var result = await _repository.UpdateAsync(
                _testProject.Id, 
                refreshedNote.Id, 
                newTitle, 
                newContent, 
                newTags, 
                NoteUpdateMode.Full, 
                refreshedNote.Version);

            // Assert
            Assert.IsType<NoteUpdateResult.SuccessResult>(result);
            var successResult = (NoteUpdateResult.SuccessResult)result;
            var updatedNote = successResult.Note;

            Assert.Equal(newTitle, updatedNote.Title);
            Assert.Equal(newContent, updatedNote.Content);
            Assert.Equal(newTags, updatedNote.Tags);
            Assert.Equal(2, updatedNote.Version); // Should be 2 after update
            Assert.True(updatedNote.UpdatedAt > refreshedNote.UpdatedAt);

            // Verify new version was created (should have 2 versions: initial + updated)
            var versions = await _context.NoteVersions
                .Where(v => v.NoteId == refreshedNote.Id)
                .OrderBy(v => v.Version)
                .ToListAsync();
            Assert.Equal(2, versions.Count);
            Assert.Equal(updatedNote.Version, versions[1].Version);
            Assert.Equal(newTitle, versions[1].Title);
            Assert.Equal(newContent, versions[1].Content);
        }

        [Fact]
        public async Task UpdateAsync_WithNonExistentNote_ShouldReturnNotFound()
        {
            // Arrange
            var nonExistentNoteId = Guid.NewGuid();

            // Act
            var result = await _repository.UpdateAsync(
                _testProject.Id, 
                nonExistentNoteId, 
                "Title", 
                "Content", 
                new List<string>(), 
                NoteUpdateMode.Full, 
                1);

            // Assert
            Assert.IsType<NoteUpdateResult.NotFoundResult>(result);
        }

        [Fact]
        public async Task GetByProjectAsync_WithCursor_ShouldReturnPagedResults()
        {
            // Arrange
            var notes = new List<Note>();
            for (int i = 0; i < 5; i++)
            {
                var note = await CreateTestNote($"Note {i}", $"Content for note {i}");
                notes.Add(note);
                // Add small delay to ensure different UpdatedAt times
                await Task.Delay(10);
            }

            // Act - Get first page with limit of 3
            var (firstPageItems, firstPageCursor) = await _repository.GetByProjectAsync(
                _testProject.Id, cursor: null, limit: 3);

            // Assert first page
            Assert.Equal(3, firstPageItems.Count());
            Assert.NotNull(firstPageCursor);

            // Act - Get second page using cursor
            var (secondPageItems, secondPageCursor) = await _repository.GetByProjectAsync(
                _testProject.Id, cursor: firstPageCursor, limit: 3);

            // Assert second page
            Assert.Equal(2, secondPageItems.Count());
            Assert.Null(secondPageCursor); // Should be null as we've reached the end

            // Verify no overlap between pages
            var firstPageIds = firstPageItems.Select(n => n.Id).ToHashSet();
            var secondPageIds = secondPageItems.Select(n => n.Id).ToHashSet();
            Assert.Empty(firstPageIds.Intersect(secondPageIds));

            // Verify all notes are returned across both pages
            var allReturnedIds = firstPageIds.Union(secondPageIds).ToHashSet();
            var expectedIds = notes.Select(n => n.Id).ToHashSet();
            Assert.Equal(expectedIds, allReturnedIds);
        }

        [Fact]
        public async Task GetByProjectAsync_WithSearch_ShouldReturnMatchingNotes()
        {
            // Arrange
            await CreateTestNote("JavaScript Tutorial", "Learn JavaScript programming");
            await CreateTestNote("Python Guide", "Python programming basics");
            await CreateTestNote("Web Development", "HTML, CSS, and JavaScript");
            await CreateTestNote("Database Design", "SQL and database concepts");

            // Act - Search for "JavaScript" (case insensitive)
            var (items, _) = await _repository.GetByProjectAsync(
                _testProject.Id, search: "javascript");

            // Assert
            Assert.Equal(2, items.Count());
            Assert.All(items, note => 
                Assert.True(
                    note.Title.Contains("JavaScript", StringComparison.OrdinalIgnoreCase) ||
                    note.Content.Contains("JavaScript", StringComparison.OrdinalIgnoreCase)
                ));
        }

        [Fact]
        public async Task SearchAsync_ShouldReturnMatchingNotes()
        {
            // Arrange
            var note1 = await CreateTestNote("React Tutorial", "Learn React framework for building user interfaces");
            var note2 = await CreateTestNote("Vue.js Guide", "Vue.js is a progressive framework");
            var note3 = await CreateTestNote("Angular Basics", "Angular framework tutorial");
            
            // Add tags to note1
            note1.Tags = new List<string> { "react", "frontend", "tutorial" };
            _context.Notes.Update(note1);
            await _context.SaveChangesAsync();

            // Act
            var results = await _repository.SearchAsync(
                _testProject.Id, "react", SearchMode.Keyword, 10);

            // Assert
            Assert.Single(results);
            var result = results.First();
            Assert.Equal(note1.Id, result.NoteId);
            Assert.Equal(note1.Title, result.Title);
            Assert.True(result.Score > 0);
            Assert.Contains("react", result.Tags, StringComparer.OrdinalIgnoreCase);
        }

        [Fact]
        public async Task SearchAsync_WithEmptyQuery_ShouldReturnEmpty()
        {
            // Arrange
            await CreateTestNote("Test Note", "Test content");

            // Act
            var results = await _repository.SearchAsync(
                _testProject.Id, "", SearchMode.Keyword, 10);

            // Assert
            Assert.Empty(results);
        }

        [Fact]
        public async Task DeleteAsync_ShouldRemoveNoteAndUpdateProjectCount()
        {
            // Arrange
            var note = await CreateTestNote("Note to Delete", "This note will be deleted");
            var initialCount = _testProject.NoteCount;

            // Act
            var result = await _repository.DeleteAsync(_testProject.Id, note.Id);

            // Assert
            Assert.True(result);

            // Verify note is deleted
            var deletedNote = await _context.Notes.FindAsync(note.Id);
            Assert.Null(deletedNote);

            // Verify project count is updated
            var updatedProject = await _context.Projects.FindAsync(_testProject.Id);
            Assert.NotNull(updatedProject);
            Assert.Equal(initialCount - 1, updatedProject.NoteCount);
        }

        [Fact]
        public async Task DeleteAsync_WithPurgeVersions_ShouldRemoveAllVersions()
        {
            // Arrange
            var note = await CreateTestNote("Note with Versions", "Original content");
            
            // Update note to create additional versions
            await _repository.UpdateAsync(
                _testProject.Id, note.Id, "Updated Title", "Updated content", 
                new List<string>(), NoteUpdateMode.Full, note.Version);

            // Verify versions exist
            var versionsBefore = await _context.NoteVersions
                .Where(v => v.NoteId == note.Id)
                .CountAsync();
            Assert.Equal(2, versionsBefore);

            // Act
            var result = await _repository.DeleteAsync(_testProject.Id, note.Id, purgeVersions: true);

            // Assert
            Assert.True(result);

            // Verify all versions are deleted
            var versionsAfter = await _context.NoteVersions
                .Where(v => v.NoteId == note.Id)
                .CountAsync();
            Assert.Equal(0, versionsAfter);
        }

        [Fact]
        public async Task DeleteAsync_WithNonExistentNote_ShouldReturnFalse()
        {
            // Arrange
            var nonExistentNoteId = Guid.NewGuid();

            // Act
            var result = await _repository.DeleteAsync(_testProject.Id, nonExistentNoteId);

            // Assert
            Assert.False(result);
        }

        private async Task<Note> CreateTestNote(string title, string content)
        {
            var note = await _repository.CreateAsync(
                _testProject.Id, 
                title, 
                content, 
                new List<string>());
            
            Assert.NotNull(note);
            return note;
        }
    }
}