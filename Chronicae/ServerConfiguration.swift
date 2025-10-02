import Foundation

struct ServerConfiguration: Equatable {
    var port: Int = 8843
    var allowExternal: Bool = true
    var projectId: UUID?
    var authToken: String? = nil
}
