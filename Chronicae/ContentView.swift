import SwiftUI
import Observation

struct ContentView: View {
    @Bindable private var appState: AppState
    @Bindable private var serverManager: ServerManager
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var routerToken: UUID?

    init(appState: AppState, serverManager: ServerManager) {
        self.appState = appState
        self.serverManager = serverManager
    }

    var body: some View {
        return NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(appState: appState)
        } content: {
            placeholderView
        } detail: {
            detailView(appState: appState, serverManager: serverManager)
        }
        .task {
            await serverManager.startIfNeeded()
            appState.serverStatus = serverManager.status
            await appState.refreshProjects(using: serverManager)
            await appState.refreshNotes(using: serverManager)
            await appState.refreshBackup(using: serverManager)
            appState.startEventStream(using: serverManager)
        }
        .onChange(of: serverManager.status) { _, newStatus in
            appState.serverStatus = newStatus
            appState.lastUpdated = .now
            if case .running = newStatus {
                Task {
                    await appState.refreshProjects(using: serverManager)
                    await appState.refreshNotes(using: serverManager)
                    await appState.refreshBackup(using: serverManager)
                    await MainActor.run { appState.startEventStream(using: serverManager) }
                }
            } else {
                Task { await MainActor.run { appState.stopEventStream() } }
            }
        }
        .frame(minWidth: 1080, minHeight: 720)
        .onAppear(perform: registerRouter)
        .onDisappear(perform: unregisterRouter)
    }

    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse)
            Text("Chronicae")
                .font(.title2)
                .fontWeight(.medium)
            Text("왼쪽에서 섹션을 선택하세요")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func detailView(appState: AppState, serverManager: ServerManager) -> some View {
        switch appState.selectedSection ?? .dashboard {
        case .dashboard:
            DashboardView(appState: appState, serverManager: serverManager)
        case .storage:
            StorageManagementView(appState: appState, serverManager: serverManager)
        case .versions:
            VersionsView(appState: appState, serverManager: serverManager)
        case .settings:
            SettingsView(appState: appState, serverManager: serverManager)
        }
    }

    @MainActor
    private func registerRouter() {
        guard routerToken == nil else { return }
        routerToken = AppSceneRouter.shared.register { section in
            Task { @MainActor in
                appState.selectedSection = section
            }
        }
    }

    @MainActor
    private func unregisterRouter() {
        guard let routerToken else { return }
        AppSceneRouter.shared.unregister(routerToken)
        self.routerToken = nil
    }
}

#Preview {
    ContentView(appState: AppState(), serverManager: ServerManager.shared)
}
