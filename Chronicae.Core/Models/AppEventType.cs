namespace Chronicae.Core.Models;

public static class AppEventType
{
    public const string NoteCreated = "note.created";
    public const string NoteUpdated = "note.updated";
    public const string NoteDeleted = "note.deleted";
    public const string ProjectSwitched = "project.switched";
    public const string BackupCompleted = "backup.completed";
    public const string IndexJobCompleted = "index.job.completed";
}