import SwiftUI
import Observation

struct ContentView: View {
    @State private var appState = AppState()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var serverManager = ServerManager.shared

    var body: some View {
        @Bindable var appState = appState
        @Bindable var serverManager = serverManager

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
        }
        .onChange(of: serverManager.status) { _, newStatus in
            appState.serverStatus = newStatus
            appState.lastUpdated = .now
        }
        .frame(minWidth: 1080, minHeight: 720)
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
            VersionsView(appState: appState)
        case .settings:
            SettingsView(appState: appState, serverManager: serverManager)
        }
    }
}

#Preview {
    ContentView()
}
