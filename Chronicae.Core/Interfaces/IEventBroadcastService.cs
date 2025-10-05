using Chronicae.Core.Models;

namespace Chronicae.Core.Interfaces;

public interface IEventBroadcastService
{
    Task PublishAsync(string eventType, object payload);
    Task PublishNoteCreatedAsync(Note note);
    Task PublishNoteUpdatedAsync(Note note);
    Task PublishNoteDeletedAsync(Guid noteId, Guid projectId);
    Task PublishProjectSwitchedAsync(Project project);
    Task PublishBackupCompletedAsync(BackupRecord record);
}