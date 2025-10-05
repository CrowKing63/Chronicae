using Microsoft.AspNetCore.SignalR;
using Chronicae.Core.Interfaces;
using Chronicae.Core.Models;
using Chronicae.Server.Hubs;

namespace Chronicae.Server.Services;

public class EventBroadcastService : IEventBroadcastService
{
    private readonly IHubContext<EventHub> _hubContext;
    private readonly ILogger<EventBroadcastService> _logger;

    public EventBroadcastService(IHubContext<EventHub> hubContext, ILogger<EventBroadcastService> logger)
    {
        _hubContext = hubContext;
        _logger = logger;
    }

    public async Task PublishAsync(string eventType, object payload)
    {
        try
        {
            await _hubContext.Clients.All.SendAsync("Event", new
            {
                @event = eventType,
                data = payload,
                timestamp = DateTime.UtcNow
            });
            
            _logger.LogDebug("Broadcasted event: {EventType}", eventType);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to broadcast event: {EventType}", eventType);
        }
    }

    public Task PublishNoteCreatedAsync(Note note) =>
        PublishAsync(AppEventType.NoteCreated, new
        {
            id = note.Id,
            projectId = note.ProjectId,
            title = note.Title,
            excerpt = note.Excerpt,
            tags = note.Tags,
            version = note.Version,
            updatedAt = note.UpdatedAt
        });

    public Task PublishNoteUpdatedAsync(Note note) =>
        PublishAsync(AppEventType.NoteUpdated, new
        {
            id = note.Id,
            projectId = note.ProjectId,
            title = note.Title,
            excerpt = note.Excerpt,
            tags = note.Tags,
            version = note.Version,
            updatedAt = note.UpdatedAt
        });

    public Task PublishNoteDeletedAsync(Guid noteId, Guid projectId) =>
        PublishAsync(AppEventType.NoteDeleted, new { id = noteId, projectId });

    public Task PublishProjectSwitchedAsync(Project project) =>
        PublishAsync(AppEventType.ProjectSwitched, new
        {
            id = project.Id,
            name = project.Name
        });

    public Task PublishBackupCompletedAsync(BackupRecord record) =>
        PublishAsync(AppEventType.BackupCompleted, new
        {
            id = record.Id,
            startedAt = record.StartedAt,
            completedAt = record.CompletedAt,
            status = record.Status.ToString(),
            artifactPath = record.ArtifactPath
        });
}