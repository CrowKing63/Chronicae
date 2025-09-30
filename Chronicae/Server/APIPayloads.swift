import Foundation

struct APIErrorPayload: Codable, Error {
    let code: String
    let message: String
}

struct CreateProjectPayload: Codable {
    let name: String
}

struct ProjectListPayload: Codable {
    let items: [ProjectSummary]
    let activeProjectId: UUID?
}

struct ProjectResponsePayload: Codable {
    let project: ProjectSummary
    let activeProjectId: UUID?
}

struct NoteCreatePayload: Codable {
    let title: String
    let content: String
    let tags: [String]
}

struct NoteUpdatePayload: Codable {
    let title: String
    let content: String
    let tags: [String]
}

struct NoteListPayload: Codable {
    let items: [NoteSummary]
}

struct NoteResponsePayload: Codable {
    let note: NoteSummary
}

struct VersionListPayload: Codable {
    let items: [VersionSnapshot]
}

struct VersionRestorePayload: Codable {
    let version: VersionSnapshot
}
