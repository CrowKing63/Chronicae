import Foundation

struct VersionSnapshot: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var timestamp: Date
    var preview: String
    var projectId: UUID
    var noteId: UUID
}
