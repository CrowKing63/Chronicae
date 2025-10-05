using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Chronicae.Data;
using Chronicae.Core.Models;
using Chronicae.Server.Models;

namespace Chronicae.Tests.Hubs;

public class EventHubTests : IClassFixture<WebApplicationFactory<Program>>, IAsyncDisposable
{
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;
    private HubConnection? _hubConnection;

    public EventHubTests(WebApplicationFactory<Program> factory)
    {
        var databaseName = "TestDb_" + Guid.NewGuid();
        
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

                // Add InMemory database for testing with shared database name
                services.AddDbContext<ChronicaeDbContext>(options =>
                {
                    options.UseInMemoryDatabase(databaseName);
                });
            });
        });

        _client = _factory.CreateClient();
    }

    [Fact]
    public async Task NoteCreated_ShouldBroadcastEvent()
    {
        // Arrange
        var projectId = await SeedTestDataAsync();
        var eventReceived = new TaskCompletionSource<JsonElement>();

        _hubConnection = await CreateHubConnectionAsync();
        _hubConnection.On<JsonElement>("Event", (message) =>
        {
            if (message.TryGetProperty("event", out var eventType) && 
                eventType.GetString() == "note.created")
            {
                eventReceived.SetResult(message);
            }
        });

        await _hubConnection.StartAsync();

        var createRequest = new CreateNoteRequest
        {
            Title = "Test Note for Event",
            Content = "This note should trigger an event",
            Tags = new List<string> { "event-test" }
        };

        // Act
        var response = await _client.PostAsJsonAsync($"/api/projects/{projectId}/notes", createRequest);

        // Assert
        response.EnsureSuccessStatusCode();

        // Wait for the event to be received
        var receivedEvent = await eventReceived.Task.WaitAsync(TimeSpan.FromSeconds(5));

        Assert.True(receivedEvent.TryGetProperty("event", out var eventName));
        Assert.Equal("note.created", eventName.GetString());

        Assert.True(receivedEvent.TryGetProperty("data", out var eventData));
        Assert.True(eventData.TryGetProperty("id", out var noteId));
        Assert.True(eventData.TryGetProperty("title", out var title));
        Assert.Equal("Test Note for Event", title.GetString());

        Assert.True(receivedEvent.TryGetProperty("timestamp", out var timestamp));
        Assert.True(DateTime.TryParse(timestamp.GetString(), out _));
    }

    [Fact]
    public async Task NoteUpdated_ShouldBroadcastEvent()
    {
        // Arrange
        var (projectId, noteId) = await SeedTestDataWithSpecificNoteAsync();
        var eventReceived = new TaskCompletionSource<JsonElement>();

        _hubConnection = await CreateHubConnectionAsync();
        _hubConnection.On<JsonElement>("Event", (message) =>
        {
            if (message.TryGetProperty("event", out var eventType) && 
                eventType.GetString() == "note.updated")
            {
                eventReceived.SetResult(message);
            }
        });

        await _hubConnection.StartAsync();

        var updateRequest = new UpdateNoteRequest
        {
            Title = "Updated Note Title",
            Content = "Updated content",
            Tags = new List<string> { "updated" },
            LastKnownVersion = 1
        };

        // Act
        var response = await _client.PutAsJsonAsync($"/api/projects/{projectId}/notes/{noteId}", updateRequest);

        // Assert
        response.EnsureSuccessStatusCode();

        // Wait for the event to be received
        var receivedEvent = await eventReceived.Task.WaitAsync(TimeSpan.FromSeconds(5));

        Assert.True(receivedEvent.TryGetProperty("event", out var eventName));
        Assert.Equal("note.updated", eventName.GetString());

        Assert.True(receivedEvent.TryGetProperty("data", out var eventData));
        Assert.True(eventData.TryGetProperty("id", out var receivedNoteId));
        Assert.Equal(noteId.ToString(), receivedNoteId.GetString());

        Assert.True(eventData.TryGetProperty("title", out var title));
        Assert.Equal("Updated Note Title", title.GetString());

        Assert.True(eventData.TryGetProperty("version", out var version));
        Assert.Equal(2, version.GetInt32());
    }

    [Fact]
    public async Task NoteDeleted_ShouldBroadcastEvent()
    {
        // Arrange
        var (projectId, noteId) = await SeedTestDataWithSpecificNoteAsync();
        var eventReceived = new TaskCompletionSource<JsonElement>();

        _hubConnection = await CreateHubConnectionAsync();
        _hubConnection.On<JsonElement>("Event", (message) =>
        {
            if (message.TryGetProperty("event", out var eventType) && 
                eventType.GetString() == "note.deleted")
            {
                eventReceived.SetResult(message);
            }
        });

        await _hubConnection.StartAsync();

        // Act
        var response = await _client.DeleteAsync($"/api/projects/{projectId}/notes/{noteId}");

        // Assert
        response.EnsureSuccessStatusCode();

        // Wait for the event to be received
        var receivedEvent = await eventReceived.Task.WaitAsync(TimeSpan.FromSeconds(5));

        Assert.True(receivedEvent.TryGetProperty("event", out var eventName));
        Assert.Equal("note.deleted", eventName.GetString());

        Assert.True(receivedEvent.TryGetProperty("data", out var eventData));
        Assert.True(eventData.TryGetProperty("id", out var receivedNoteId));
        Assert.Equal(noteId.ToString(), receivedNoteId.GetString());

        Assert.True(eventData.TryGetProperty("projectId", out var receivedProjectId));
        Assert.Equal(projectId.ToString(), receivedProjectId.GetString());
    }

    [Fact]
    public async Task ProjectSwitched_ShouldBroadcastEvent()
    {
        // Arrange
        var projectId = await SeedTestDataAsync();
        var eventReceived = new TaskCompletionSource<JsonElement>();

        _hubConnection = await CreateHubConnectionAsync();
        _hubConnection.On<JsonElement>("Event", (message) =>
        {
            if (message.TryGetProperty("event", out var eventType) && 
                eventType.GetString() == "project.switched")
            {
                eventReceived.SetResult(message);
            }
        });

        await _hubConnection.StartAsync();

        // Act
        var response = await _client.PostAsync($"/api/projects/{projectId}/switch", null);

        // Assert
        response.EnsureSuccessStatusCode();

        // Wait for the event to be received
        var receivedEvent = await eventReceived.Task.WaitAsync(TimeSpan.FromSeconds(5));

        Assert.True(receivedEvent.TryGetProperty("event", out var eventName));
        Assert.Equal("project.switched", eventName.GetString());

        Assert.True(receivedEvent.TryGetProperty("data", out var eventData));
        Assert.True(eventData.TryGetProperty("id", out var receivedProjectId));
        Assert.Equal(projectId.ToString(), receivedProjectId.GetString());

        Assert.True(eventData.TryGetProperty("name", out var projectName));
        Assert.NotNull(projectName.GetString());
    }

    [Fact]
    public async Task BackupCompleted_ShouldBroadcastEvent()
    {
        // Arrange
        await SeedTestDataAsync();
        var eventReceived = new TaskCompletionSource<JsonElement>();

        _hubConnection = await CreateHubConnectionAsync();
        _hubConnection.On<JsonElement>("Event", (message) =>
        {
            if (message.TryGetProperty("event", out var eventType) && 
                eventType.GetString() == "backup.completed")
            {
                eventReceived.SetResult(message);
            }
        });

        await _hubConnection.StartAsync();

        // Act
        var response = await _client.PostAsync("/api/backup/run", null);

        // Assert
        response.EnsureSuccessStatusCode();

        // Wait for the event to be received
        var receivedEvent = await eventReceived.Task.WaitAsync(TimeSpan.FromSeconds(10)); // Backup might take longer

        Assert.True(receivedEvent.TryGetProperty("event", out var eventName));
        Assert.Equal("backup.completed", eventName.GetString());

        Assert.True(receivedEvent.TryGetProperty("data", out var eventData));
        Assert.True(eventData.TryGetProperty("id", out var backupId));
        Assert.True(Guid.TryParse(backupId.GetString(), out _));

        Assert.True(eventData.TryGetProperty("status", out var status));
        // In test environment, backup might fail due to file system issues, but event should still be broadcast
        Assert.True(status.GetString() == "Success" || status.GetString() == "Failed");
    }

    [Fact]
    public async Task HubConnection_ShouldReceiveConnectedMessage()
    {
        // Arrange
        var connectedReceived = new TaskCompletionSource<JsonElement>();

        _hubConnection = await CreateHubConnectionAsync();
        _hubConnection.On<JsonElement>("Connected", (message) =>
        {
            connectedReceived.SetResult(message);
        });

        // Act
        await _hubConnection.StartAsync();

        // Assert
        var connectedMessage = await connectedReceived.Task.WaitAsync(TimeSpan.FromSeconds(5));
        
        Assert.True(connectedMessage.TryGetProperty("message", out var message));
        Assert.Equal("connected", message.GetString());
    }

    [Fact]
    public async Task MultipleClients_ShouldAllReceiveEvents()
    {
        // Arrange
        var projectId = await SeedTestDataAsync();
        var client1EventReceived = new TaskCompletionSource<JsonElement>();
        var client2EventReceived = new TaskCompletionSource<JsonElement>();

        // Create two hub connections
        var hubConnection1 = await CreateHubConnectionAsync();
        var hubConnection2 = await CreateHubConnectionAsync();

        hubConnection1.On<JsonElement>("Event", (message) =>
        {
            if (message.TryGetProperty("event", out var eventType) && 
                eventType.GetString() == "note.created")
            {
                client1EventReceived.SetResult(message);
            }
        });

        hubConnection2.On<JsonElement>("Event", (message) =>
        {
            if (message.TryGetProperty("event", out var eventType) && 
                eventType.GetString() == "note.created")
            {
                client2EventReceived.SetResult(message);
            }
        });

        await hubConnection1.StartAsync();
        await hubConnection2.StartAsync();

        var createRequest = new CreateNoteRequest
        {
            Title = "Multi-client Test Note",
            Content = "This should be received by all clients",
            Tags = new List<string> { "multi-client" }
        };

        // Act
        var response = await _client.PostAsJsonAsync($"/api/projects/{projectId}/notes", createRequest);

        // Assert
        response.EnsureSuccessStatusCode();

        // Both clients should receive the event
        var event1 = await client1EventReceived.Task.WaitAsync(TimeSpan.FromSeconds(5));
        var event2 = await client2EventReceived.Task.WaitAsync(TimeSpan.FromSeconds(5));

        Assert.True(event1.TryGetProperty("event", out var eventName1));
        Assert.Equal("note.created", eventName1.GetString());

        Assert.True(event2.TryGetProperty("event", out var eventName2));
        Assert.Equal("note.created", eventName2.GetString());

        // Clean up additional connections
        await hubConnection1.DisposeAsync();
        await hubConnection2.DisposeAsync();
    }

    private async Task<HubConnection> CreateHubConnectionAsync()
    {
        return new HubConnectionBuilder()
            .WithUrl($"{_client.BaseAddress}api/events", options =>
            {
                options.HttpMessageHandlerFactory = _ => _factory.Server.CreateHandler();
            })
            .Build();
    }

    private async Task<Guid> SeedTestDataAsync()
    {
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ChronicaeDbContext>();

        // Ensure database is created
        await context.Database.EnsureCreatedAsync();

        // Clear existing data
        context.Notes.RemoveRange(context.Notes);
        context.Projects.RemoveRange(context.Projects);
        await context.SaveChangesAsync();

        // Add test project
        var project = new Project
        {
            Id = Guid.NewGuid(),
            Name = "Test Project for Events",
            NoteCount = 0
        };

        context.Projects.Add(project);
        await context.SaveChangesAsync();

        return project.Id;
    }

    private async Task<(Guid ProjectId, Guid NoteId)> SeedTestDataWithSpecificNoteAsync()
    {
        using var scope = _factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ChronicaeDbContext>();

        // Ensure database is created
        await context.Database.EnsureCreatedAsync();

        // Clear existing data
        context.Notes.RemoveRange(context.Notes);
        context.Projects.RemoveRange(context.Projects);
        await context.SaveChangesAsync();

        // Add test project
        var project = new Project
        {
            Id = Guid.NewGuid(),
            Name = "Test Project for Specific Note Events",
            NoteCount = 1
        };

        context.Projects.Add(project);

        // Add specific test note
        var note = new Note
        {
            Id = Guid.NewGuid(),
            ProjectId = project.Id,
            Title = "Event Test Note",
            Content = "This note is for testing events",
            Excerpt = "This note is for testing events",
            Tags = new List<string> { "event", "test" },
            CreatedAt = DateTime.UtcNow.AddHours(-1),
            UpdatedAt = DateTime.UtcNow.AddMinutes(-30),
            Version = 1
        };

        context.Notes.Add(note);
        await context.SaveChangesAsync();

        return (project.Id, note.Id);
    }

    public async ValueTask DisposeAsync()
    {
        if (_hubConnection != null)
        {
            await _hubConnection.DisposeAsync();
        }
        _client?.Dispose();
    }
}