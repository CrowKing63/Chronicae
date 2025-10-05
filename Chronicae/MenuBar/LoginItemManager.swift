import Combine
import Foundation
import ServiceManagement

@MainActor
final class LoginItemManager: ObservableObject {
    @Published private(set) var isEnabled: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var isSupported: Bool = true

    private var isUpdating = false

    init() {
        refresh()
    }

    func refresh() {
        guard #available(macOS 13.0, *) else {
            isSupported = false
            isEnabled = false
            return
        }

        isSupported = true
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func update(enabled: Bool) {
        guard !isUpdating else { return }
        guard #available(macOS 13.0, *) else {
            isSupported = false
            errorMessage = "이 macOS 버전에서는 로그인 항목을 설정할 수 없습니다."
            return
        }

        isUpdating = true
        Task { @MainActor [self] in
            do {
                try updateLoginItem(enabled: enabled)
                isEnabled = enabled
                errorMessage = nil
            } catch {
                refresh()
                errorMessage = error.localizedDescription
            }
            isUpdating = false
        }
    }

    @available(macOS 13.0, *)
    private func updateLoginItem(enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
