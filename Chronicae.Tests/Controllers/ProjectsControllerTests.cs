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

public class ProjectsControllerTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;

    public ProjectsControllerTests(WebApplicationFactory<Program> factory)
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
    public async Task GetProjects_ShouldReturnProjectList()
    {
        // Arrange
        await SeedTestDataAsync();

        // Act
        var response = await _client.GetAsync("/api/projects");

        // Assert
        response.EnsureSuccessStatusCode();
        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<ProjectListResponse>(content, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        Assert.NotNull(result);
        Assert.NotEmpty(result.Items);
        Assert.True(result.Items.Count() >= 2); // We seeded 2 projects
    }

    [Fact]
    public async Task GetProjects_WithIncludeStats_ShouldReturnProjectsWithStats()
    {
        // Arrange
        await SeedTestDataAsync();

        // Act
        var response = await _client.GetAsync("/api/projects?includeStats=true");

        // Assert
        response.EnsureSuccessStatusCode();
        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<ProjectListResponse>(content, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        Assert.NotNull(result);
        Assert.NotEmpty(result.Items);
        
        var projectWithNotes = result.Items.FirstOrDefault(p => p.NoteCount > 0);
        Assert.NotNull(projectWithNotes);
        Assert.NotNull(projectWithNotes.Stats);
    }

    [Fact]
    public async Task CreateProject_WithValidData_ShouldReturnCreated()
    {
        // Arrange
        var request = new CreateProjectRequest
        {
            Name = "New Test Project"
        };

        // Act
        var response = await _client.PostAsJsonAsync("/api/projects", request);

        // Assert
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<ProjectResponse>(content, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        Assert.NotNull(result);
        Assert.NotNull(result.Project);
        Assert.Equal("New Test Project", result.Project.Name);
        Assert.NotEqual(Guid.Empty, result.Project.Id);
    }

    [Fact]
    public async Task CreateProject_WithEmptyName_ShouldReturnBadRequest()
    {
        // Arrange
        var request = new CreateProjectRequest
        {
            Name = ""
        };

        // Act
        var response = await _client.PostAsJsonAsync("/api/projects", request);

        // Assert
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var content = await response.Content.ReadAsStringAsync();
        var error = JsonSerializer.Deserialize<JsonElement>(content);
        
        Assert.True(error.TryGetProperty("code", out var code));
        Assert.Equal("invalid_request", code.GetString());
    }

    [Fact]
    public async Task SwitchProject_ShouldUpdateActiveProject()
    {
        // Arrange
        var projectId = await SeedTestDataAsync();

        // Act
        var response = await _client.PostAsync($"/api/projects/{projectId}/switch", null);

        // Assert
        response.EnsureSuccessStatusCode();
        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<ProjectResponse>(content, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        Assert.NotNull(result);
        Assert.NotNull(result.Project);
        Assert.Equal(projectId, result.Project.Id);
        Assert.Equal(projectId, result.ActiveProjectId);
    }

    [Fact]
    public async Task SwitchProject_WithInvalidId_ShouldReturnNotFound()
    {
        // Arrange
        var invalidId = Guid.NewGuid();

        // Act
        var response = await _client.PostAsync($"/api/projects/{invalidId}/switch", null);

        // Assert
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var content = await response.Content.ReadAsStringAsync();
        var error = JsonSerializer.Deserialize<JsonElement>(content);
        
        Assert.True(error.TryGetProperty("code", out var code));
        Assert.Equal("project_not_found", code.GetString());
    }

    [Fact]
    public async Task GetProject_WithValidId_ShouldReturnProject()
    {
        // Arrange
        var projectId = await SeedTestDataAsync();

        // Act
        var response = await _client.GetAsync($"/api/projects/{projectId}");

        // Assert
        response.EnsureSuccessStatusCode();
        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<ProjectDetailResponse>(content, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        Assert.NotNull(result);
        Assert.NotNull(result.Project);
        Assert.Equal(projectId, result.Project.Id);
    }

    [Fact]
    public async Task GetProject_WithInvalidId_ShouldReturnNotFound()
    {
        // Arrange
        var invalidId = Guid.NewGuid();

        // Act
        var response = await _client.GetAsync($"/api/projects/{invalidId}");

        // Assert
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task UpdateProject_WithValidData_ShouldReturnUpdated()
    {
        // Arrange
        var projectId = await SeedTestDataAsync();
        var request = new UpdateProjectRequest
        {
            Name = "Updated Project Name"
        };

        // Act
        var response = await _client.PutAsJsonAsync($"/api/projects/{projectId}", request);

        // Assert
        response.EnsureSuccessStatusCode();
        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<ProjectResponse>(content, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        Assert.NotNull(result);
        Assert.NotNull(result.Project);
        Assert.Equal("Updated Project Name", result.Project.Name);
    }

    [Fact]
    public async Task DeleteProject_WithValidId_ShouldReturnNoContent()
    {
        // Arrange
        var projectId = await SeedTestDataAsync();

        // Act
        var response = await _client.DeleteAsync($"/api/projects/{projectId}");

        // Assert
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);

        // Verify project is deleted
        var getResponse = await _client.GetAsync($"/api/projects/{projectId}");
        Assert.Equal(HttpStatusCode.NotFound, getResponse.StatusCode);
    }

    private async Task<Guid> SeedTestDataAsync()
    {
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ChronicaeDbContext>();

        // Clear existing data
        context.Notes.RemoveRange(context.Notes);
        context.Projects.RemoveRange(context.Projects);
        await context.SaveChangesAsync();

        // Add test projects
        var project1 = new Project
        {
            Id = Guid.NewGuid(),
            Name = "Test Project 1",
            NoteCount = 0
        };

        var project2 = new Project
        {
            Id = Guid.NewGuid(),
            Name = "Test Project 2",
            NoteCount = 2
        };

        context.Projects.AddRange(project1, project2);

        // Add test notes to project2
        var note1 = new Note
        {
            Id = Guid.NewGuid(),
            ProjectId = project2.Id,
            Title = "Test Note 1",
            Content = "This is test note content 1",
            Excerpt = "This is test note content 1",
            Tags = new List<string> { "test", "sample" },
            CreatedAt = DateTime.UtcNow.AddDays(-2),
            UpdatedAt = DateTime.UtcNow.AddDays(-1),
            Version = 1
        };

        var note2 = new Note
        {
            Id = Guid.NewGuid(),
            ProjectId = project2.Id,
            Title = "Test Note 2",
            Content = "This is test note content 2",
            Excerpt = "This is test note content 2",
            Tags = new List<string> { "test" },
            CreatedAt = DateTime.UtcNow.AddDays(-1),
            UpdatedAt = DateTime.UtcNow,
            Version = 1
        };

        context.Notes.AddRange(note1, note2);
        await context.SaveChangesAsync();

        return project1.Id;
    }
}