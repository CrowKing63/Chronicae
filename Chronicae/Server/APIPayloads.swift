import Foundation

struct APIErrorPayload: Codable, Error {
    let code: String
    let message: String
}

struct CreateProjectPayload: Codable {
    let name: String
}

struct ProjectUpdatePayload: Codable {
    let name: String?
}

struct ProjectListPayload: Codable {
    let items: [ProjectSummary]
    let activeProjectId: UUID?
}

struct ProjectResponsePayload: Codable {
    let project: ProjectSummary
    let activeProjectId: UUID?
}

struct ProjectDetailPayload: Codable {
    let project: ProjectSummary
}

struct NoteCreatePayload: Codable {
    let title: String
    let content: String
    let tags: [String]
}

struct NoteUpdatePayload: Codable {
    let title: String?
    let content: String?
    let tags: [String]?
    let lastKnownVersion: Int?
}

struct NoteListPayload: Codable {
    let items: [NoteSummary]
    let nextCursor: String?
}

struct NoteResponsePayload: Codable {
    let note: NoteSummary
}

struct NoteConflictPayload: Codable {
    let code: String
    let message: String
    let note: NoteSummary
}

struct SearchResponsePayload: Codable {
    let query: String
    let mode: String
    let items: [ServerDataStore.SearchResult]
}

struct IndexRebuildRequestPayload: Codable {
    let projectId: UUID?
}

struct IndexRebuildResponsePayload: Codable {
    let job: ServerDataStore.IndexJob
}

struct IndexJobListPayload: Codable {
    let items: [ServerDataStore.IndexJob]
}

struct AIQueryRequestPayload: Codable {
    struct Options: Codable {
        let temperature: Double?
        let maxTokens: Int?
    }

    struct HistoryMessage: Codable {
        let role: String
        let content: String
    }

    let mode: String
    let projectId: UUID?
    let query: String
    let history: [HistoryMessage]?
    let options: Options?
}

struct AIQueryAcceptedPayload: Codable {
    let sessionId: UUID
    let status: ServerDataStore.AISession.Status
    let location: String
}

struct AISessionPayload: Codable {
    let session: ServerDataStore.AISession
}

struct AIModeListPayload: Codable {
    let items: [ServerDataStore.AIMode]
}

struct VersionListPayload: Codable {
    let items: [VersionSnapshot]
}

struct VersionRestorePayload: Codable {
    let version: VersionSnapshot
}

struct VersionDetailPayload: Codable {
    let version: VersionSnapshot
    let content: String
}
