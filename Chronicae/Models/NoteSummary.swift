import Foundation

struct NoteSummary: Identifiable, Hashable, Codable {
    let id: UUID
    var projectId: UUID
    var title: String
    var content: String
    var excerpt: String
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    var version: Int
}
