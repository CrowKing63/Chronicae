import Foundation

enum ServerStatus: Equatable {
    case stopped
    case starting
    case running(ServerRuntime)
    case error(ServerError)

    struct ServerRuntime: Equatable {
        var startedAt: Date
        var port: Int
        var projectId: UUID?
    }

    struct ServerError: Equatable, Identifiable {
        let id = UUID()
        var message: String
        var timestamp: Date
    }
}
