import Foundation

enum AppEventType: String, Codable {
    case projectReset = "project.reset"
    case projectDeleted = "project.deleted"
    case noteCreated = "note.created"
    case noteUpdated = "note.updated"
    case noteDeleted = "note.deleted"
    case noteExportQueued = "note.export.queued"
    case noteVersionRestored = "note.version.restored"
    case noteVersionExportQueued = "note.version.export.queued"
    case backupCompleted = "backup.completed"
    case ping = "ping"
}
