import Foundation

struct NoteIdentifierPayload: Codable, Sendable {
    let id: UUID
    let projectId: UUID
}

struct ExportJobIdentifierPayload: Codable, Sendable {
    let projectId: UUID
    let versionId: UUID?
}

struct BackupRecordPayload: Codable, Sendable {
    let id: UUID
    let startedAt: Date
    let completedAt: Date
    let status: String
    let artifactPath: String?
}
