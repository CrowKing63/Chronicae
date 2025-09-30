import Foundation

struct NoteIdentifierPayload: Codable {
    let id: UUID
    let projectId: UUID
}

struct ExportJobIdentifierPayload: Codable {
    let projectId: UUID
    let versionId: UUID?
}

struct BackupRecordPayload: Codable {
    let id: UUID
    let startedAt: Date
    let completedAt: Date
    let status: String
    let artifactPath: String?
}
