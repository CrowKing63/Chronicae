using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Chronicae.Data;
using Chronicae.Core.Models;
using Chronicae.Server.Models;

namespace Chronicae.Tests.Controllers;

public class NotesControllerTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;

    public NotesControllerTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                // Remove the existing DbContext registration
                var descriptor = services.SingleOrDefault(
                    d => d.ServiceType == typeof(DbContextOptions<ChronicaeDbContext>));
                if (descriptor != null)
                {
                    services.Remove(descriptor);
                }

                // Add InMemory database for testing
                services.AddDbContext<ChronicaeDbContext>(options =>
                {
                    options.UseInMemoryDatabase("TestDb_" + Guid.NewGuid());
                });
            });
        });

        _client = _factory.CreateClient();
    }

    [Fact]
    public async Task CreateNote_ShouldReturnCreated()
    {
        // Arrange
        var projectId = await SeedTestDataAsync();
        var request = new CreateNoteRequest
        {
            Title = "New Test Note",
            Content = "This is the content of the new test note",
            Tags = new List<string> { "test", "new" }
        };

        // Act
        var response = await _client.PostAsJsonAsync($"/api/projects/{projectId}/notes", request);

        // Assert
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<NoteResponse>(content, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        Assert.NotNull(result);
        Assert.NotNull(result.Note);
        Assert.Equal("New Test Note", result.Note.Title);
        Assert.Equal("This is the content of the new test note", result.Note.Content);
        Assert.Equal(2, result.Note.Tags.Count);
        Assert.Contains("test", result.Note.Tags);
        Assert.Contains("new", result.Note.Tags);
        Assert.Equal(1, result.Note.Version);
    }

    [Fact]
    public async Task CreateNote_WithInvalidProjectId_ShouldReturnNotFound()
    {
        // Arrange
        var invalidProjectId = Guid.NewGuid();
        var request = new CreateNoteRequest
        {
            Title = "Test Note",
            Content = "Test content",
            Tags = new List<string>()
        };

        // Act
        var response = await _client.PostAsJsonAsync($"/api/projects/{invalidProjectId}/notes", request);

        // Assert
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task GetNotes_WithPagination_ShouldReturnPagedResults()
    {
        // Arrange
        var projectId = await SeedTestDataAsync();

        // Act
        var response = await _client.GetAsync($"/api/projects/{projectId}/notes?limit=2");

        // Assert
        response.EnsureSuccessStatusCode();
        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<NoteListResponse>(content, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        Assert.NotNull(result);
        Assert.NotNull(result.Items);
        Assert.True(result.Items.Count() <= 2);
        
        // If there are more than 2 notes, we should have a next cursor
        if (result.Items.Count() == 2)
        {
            Assert.NotNull(result.NextCursor);
        }
    }

    [Fact]
    public async Task GetNotes_WithCursor_ShouldReturnNextPage()
    {
        // Arrange
        var projectId = await SeedTestDataAsync();
        
        // Get first page
        var firstPageResponse = await _client.GetAsync($"/api/projects/{projectId}/notes?limit=1");
        firstPageResponse.EnsureSuccessStatusCode();
        var firstPageContent = await firstPageResponse.Content.ReadAsStringAsync();
        var firstPageResult = JsonSerializer.Deserialize<NoteListResponse>(firstPageContent, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        Assert.NotNull(firstPageResult?.NextCursor);

        // Act - Get second page using cursor
        var response = await _client.GetAsync($"/api/projects/{projectId}/notes?limit=1&cursor={firstPageResult.NextCursor}");

        // Assert
        response.EnsureSuccessStatusCode();
        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<NoteListResponse>(content, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        Assert.NotNull(result);
        Assert.NotNull(result.Items);
        Assert.Single(result.Items);
        
        // The note should be different from the first page
        var firstPageNoteId = firstPageResult.Items.First().Id;
        var secondPageNoteId = result.Items.First().Id;
        Assert.NotEqual(firstPageNoteId, secondPageNoteId);
    }

    [Fact]
    public async Task GetNotes_WithSearch_ShouldReturnFilteredResults()
    {
        // Arrange
        var projectId = await SeedTestDataAsync();

        // Act
        var response = await _client.GetAsync($"/api/projects/{projectId}/notes?search=important");

        // Assert
        response.EnsureSuccessStatusCode();
        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<NoteListResponse>(content, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        Assert.NotNull(result);
        Assert.NotNull(result.Items);
        
        // Should only return notes containing "important"
        foreach (var note in result.Items)
        {
            Assert.True(
                note.Title.Contains("important", StringComparison.OrdinalIgnoreCase) ||
                note.Content.Contains("important", StringComparison.OrdinalIgnoreCase) ||
                note.Tags.Any(tag => tag.Contains("important", StringComparison.OrdinalIgnoreCase))
            );
        }
    }

    [Fact]
    public async Task UpdateNote_WithConflict_ShouldReturn409()
    {
        // Arrange
        var (projectId, noteId) = await SeedTestDataWithSpecificNoteAsync();
        
        // Simulate concurrent update by updating the note first
        var firstUpdateRequest = new UpdateNoteRequest
        {
            Title = "First Update",
            Content = "First update content",
            Tags = new List<string> { "updated" },
            LastKnownVersion = 1
        };
        
        var firstUpdateResponse = await _client.PutAsJsonAsync($"/api/projects/{projectId}/notes/{noteId}", firstUpdateRequest);
        firstUpdateResponse.EnsureSuccessStatusCode();

        // Act - Try to update with stale version
        var conflictUpdateRequest = new UpdateNoteRequest
        {
            Title = "Conflicting Update",
            Content = "Conflicting update content",
            Tags = new List<string> { "conflict" },
            LastKnownVersion = 1 // Stale version
        };

        var response = await _client.PutAsJsonAsync($"/api/projects/{projectId}/notes/{noteId}", conflictUpdateRequest);

        // Assert
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        var content = await response.Content.ReadAsStringAsync();
        var error = JsonSerializer.Deserialize<NoteConflictResponse>(content, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        Assert.NotNull(error);
        Assert.Equal("note_conflict", error.Code);
        Assert.NotNull(error.Note);
        Assert.Equal(2, error.Note.Version); // Should be version 2 after first update
    }

    [Fact]
    public async Task UpdateNote_WithValidVersion_ShouldReturnUpdated()
    {
        // Arrange
        var (projectId, noteId) = await SeedTestDataWithSpecificNoteAsync();
        var request = new UpdateNoteRequest
        {
            Title = "Updated Note Title",
            Content = "Updated note content",
            Tags = new List<string> { "updated", "test" },
            LastKnownVersion = 1
        };

        // Act
        var response = await _client.PutAsJsonAsync($"/api/projects/{projectId}/notes/{noteId}", request);

        // Assert
        response.EnsureSuccessStatusCode();
        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<NoteResponse>(content, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        Assert.NotNull(result);
        Assert.NotNull(result.Note);
        Assert.Equal("Updated Note Title", result.Note.Title);
        Assert.Equal("Updated note content", result.Note.Content);
        Assert.Equal(2, result.Note.Version); // Version should increment
        Assert.Contains("updated", result.Note.Tags);
        Assert.Contains("test", result.Note.Tags);
    }

    [Fact]
    public async Task UpdateNote_WithIfMatchHeader_ShouldRespectVersioning()
    {
        // Arrange
        var (projectId, noteId) = await SeedTestDataWithSpecificNoteAsync();
        var request = new UpdateNoteRequest
        {
            Title = "Updated with If-Match",
            Content = "Updated content",
            Tags = new List<string> { "header-test" }
        };

        _client.DefaultRequestHeaders.Add("If-Match", "1");

        // Act
        var response = await _client.PutAsJsonAsync($"/api/projects/{projectId}/notes/{noteId}", request);

        // Assert
        response.EnsureSuccessStatusCode();
        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<NoteResponse>(content, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        Assert.NotNull(result);
        Assert.NotNull(result.Note);
        Assert.Equal("Updated with If-Match", result.Note.Title);
        Assert.Equal(2, result.Note.Version);
    }

    [Fact]
    public async Task PatchNote_ShouldPartiallyUpdateNote()
    {
        // Arrange
        var (projectId, noteId) = await SeedTestDataWithSpecificNoteAsync();
        var request = new UpdateNoteRequest
        {
            Title = "Partially Updated Title",
            // Content and Tags not provided - should remain unchanged
            LastKnownVersion = 1
        };

        // Act
        var response = await _client.SendAsync(new HttpRequestMessage(HttpMethod.Patch, $"/api/projects/{projectId}/notes/{noteId}")
        {
            Content = JsonContent.Create(request)
        });

        // Assert
        response.EnsureSuccessStatusCode();
        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<NoteResponse>(content, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        Assert.NotNull(result);
        Assert.NotNull(result.Note);
        Assert.Equal("Partially Updated Title", result.Note.Title);
        // Original content should be preserved
        Assert.Equal("This is a specific test note for conflict testing", result.Note.Content);
    }

    [Fact]
    public async Task DeleteNote_ShouldReturnNoContent()
    {
        // Arrange
        var (projectId, noteId) = await SeedTestDataWithSpecificNoteAsync();

        // Act
        var response = await _client.DeleteAsync($"/api/projects/{projectId}/notes/{noteId}");

        // Assert
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);

        // Verify note is deleted
        var getResponse = await _client.GetAsync($"/api/projects/{projectId}/notes/{noteId}");
        Assert.Equal(HttpStatusCode.NotFound, getResponse.StatusCode);
    }

    [Fact]
    public async Task DeleteNote_WithPurgeVersions_ShouldDeleteAllVersions()
    {
        // Arrange
        var (projectId, noteId) = await SeedTestDataWithSpecificNoteAsync();

        // Act
        var response = await _client.DeleteAsync($"/api/projects/{projectId}/notes/{noteId}?purgeVersions=true");

        // Assert
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);

        // Verify versions are also deleted
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ChronicaeDbContext>();
        var versions = await context.NoteVersions.Where(v => v.NoteId == noteId).ToListAsync();
        Assert.Empty(versions);
    }

    [Fact]
    public async Task GetNote_WithValidId_ShouldReturnNote()
    {
        // Arrange
        var (projectId, noteId) = await SeedTestDataWithSpecificNoteAsync();

        // Act
        var response = await _client.GetAsync($"/api/projects/{projectId}/notes/{noteId}");

        // Assert
        response.EnsureSuccessStatusCode();
        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<NoteResponse>(content, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        Assert.NotNull(result);
        Assert.NotNull(result.Note);
        Assert.Equal(noteId, result.Note.Id);
        Assert.Equal(projectId, result.Note.ProjectId);
    }

    private async Task<Guid> SeedTestDataAsync()
    {
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ChronicaeDbContext>();

        // Clear existing data
        context.Notes.RemoveRange(context.Notes);
        context.Projects.RemoveRange(context.Projects);
        await context.SaveChangesAsync();

        // Add test project
        var project = new Project
        {
            Id = Guid.NewGuid(),
            Name = "Test Project for Notes",
            NoteCount = 3
        };

        context.Projects.Add(project);

        // Add test notes
        var notes = new[]
        {
            new Note
            {
                Id = Guid.NewGuid(),
                ProjectId = project.Id,
                Title = "Important Note 1",
                Content = "This is an important note with some content",
                Excerpt = "This is an important note with some content",
                Tags = new List<string> { "important", "work" },
                CreatedAt = DateTime.UtcNow.AddDays(-3),
                UpdatedAt = DateTime.UtcNow.AddDays(-2),
                Version = 1
            },
            new Note
            {
                Id = Guid.NewGuid(),
                ProjectId = project.Id,
                Title = "Regular Note 2",
                Content = "This is a regular note",
                Excerpt = "This is a regular note",
                Tags = new List<string> { "regular" },
                CreatedAt = DateTime.UtcNow.AddDays(-2),
                UpdatedAt = DateTime.UtcNow.AddDays(-1),
                Version = 1
            },
            new Note
            {
                Id = Guid.NewGuid(),
                ProjectId = project.Id,
                Title = "Another Important Note",
                Content = "This note is also important for testing",
                Excerpt = "This note is also important for testing",
                Tags = new List<string> { "important", "testing" },
                CreatedAt = DateTime.UtcNow.AddDays(-1),
                UpdatedAt = DateTime.UtcNow,
                Version = 1
            }
        };

        context.Notes.AddRange(notes);
        await context.SaveChangesAsync();

        return project.Id;
    }

    private async Task<(Guid ProjectId, Guid NoteId)> SeedTestDataWithSpecificNoteAsync()
    {
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ChronicaeDbContext>();

        // Clear existing data
        context.Notes.RemoveRange(context.Notes);
        context.Projects.RemoveRange(context.Projects);
        await context.SaveChangesAsync();

        // Add test project
        var project = new Project
        {
            Id = Guid.NewGuid(),
            Name = "Test Project for Specific Note",
            NoteCount = 1
        };

        context.Projects.Add(project);

        // Add specific test note
        var note = new Note
        {
            Id = Guid.NewGuid(),
            ProjectId = project.Id,
            Title = "Specific Test Note",
            Content = "This is a specific test note for conflict testing",
            Excerpt = "This is a specific test note for conflict testing",
            Tags = new List<string> { "specific", "test" },
            CreatedAt = DateTime.UtcNow.AddHours(-1),
            UpdatedAt = DateTime.UtcNow.AddMinutes(-30),
            Version = 1
        };

        context.Notes.Add(note);
        await context.SaveChangesAsync();

        return (project.Id, note.Id);
    }
}