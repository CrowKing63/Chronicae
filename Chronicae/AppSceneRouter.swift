import Foundation

@MainActor
final class AppSceneRouter {
    enum SceneID: String {
        case main
    }

    static let shared = AppSceneRouter()

    private var handlers: [UUID: (AppState.Section) -> Void] = [:]
    private var pendingSection: AppState.Section?

    private init() {}

    func register(_ handler: @escaping (AppState.Section) -> Void) -> UUID {
        let token = UUID()
        handlers[token] = handler
        if let pendingSection {
            handler(pendingSection)
            self.pendingSection = nil
        }
        return token
    }

    func unregister(_ token: UUID) {
        handlers[token] = nil
    }

    func route(to section: AppState.Section) {
        if handlers.isEmpty {
            pendingSection = section
            return
        }

        for handler in handlers.values {
            handler(section)
        }
        pendingSection = nil
    }
}
