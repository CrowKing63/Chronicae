import AppKit

@MainActor
final class ChronicaeAppDelegate: NSObject, NSApplicationDelegate {
    private var hasHiddenInitialWindows = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        Task { await ServerManager.shared.startIfNeeded() }

        DispatchQueue.main.async { [weak self] in
            guard let self, !self.hasHiddenInitialWindows else { return }
            NSApp.windows.filter { $0.isVisible }.forEach { $0.orderOut(nil) }
            self.hasHiddenInitialWindows = true
        }
    }
}
