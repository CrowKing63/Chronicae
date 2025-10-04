import Foundation

struct VersionSnapshot: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var title: String
    var timestamp: Date
    var preview: String
    var projectId: UUID
    var noteId: UUID
    var version: Int
}
