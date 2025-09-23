import Foundation

struct ServerConfiguration: Equatable {
    var port: Int = 8843
    var allowExternal: Bool = false
    var projectId: UUID?
}
