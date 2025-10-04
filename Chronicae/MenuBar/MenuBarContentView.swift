import AppKit
import Observation
import SwiftUI

struct MenuBarContentView: View {
    @Bindable var serverManager: ServerManager
    @ObservedObject var loginItemManager: LoginItemManager

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            statusSection
            Divider()
            Button("Chronicae 열기") { openMainWindow(for: .dashboard) }
            Button("저장소 관리") { openMainWindow(for: .storage) }
            Button("설정") { openMainWindow(for: .settings) }
            Divider()
            loginItemToggle
            if let message = loginItemManager.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            Button("Chronicae 종료", role: .destructive) { NSApp.terminate(nil) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 220)
    }

    private var statusSection: some View {
        HStack(spacing: 8) {
            Image(systemName: statusSymbol)
                .foregroundStyle(statusColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.headline)
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusSymbol: String {
        switch serverManager.status {
        case .running:
            return "checkmark.circle.fill"
        case .starting:
            return "hourglass"
        case .error:
            return "exclamationmark.triangle.fill"
        case .stopped:
            return "pause.circle"
        }
    }

    private var statusColor: Color {
        switch serverManager.status {
        case .running:
            return .green
        case .starting:
            return .yellow
        case .error:
            return .red
        case .stopped:
            return .secondary
        }
    }

    private var statusTitle: String {
        switch serverManager.status {
        case .running:
            return "서버 실행 중"
        case .starting:
            return "서버 시작 중"
        case .error:
            return "서버 오류"
        case .stopped:
            return "서버 중지됨"
        }
    }

    private var statusSubtitle: String {
        switch serverManager.status {
        case .running(let runtime):
            return "포트 \(runtime.port)"
        case .starting:
            return "초기화 중"
        case .error(let error):
            return error.message
        case .stopped:
            return "필요 시 수동으로 시작"
        }
    }

    private var loginItemToggle: some View {
        Group {
            if loginItemManager.isSupported {
                Toggle("로그인 시 실행", isOn: Binding(
                    get: { loginItemManager.isEnabled },
                    set: { loginItemManager.update(enabled: $0) }
                ))
                .toggleStyle(.switch)
            } else {
                Label("로그인 항목 미지원", systemImage: "bolt.slash")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
    }

    private func openMainWindow(for section: AppState.Section) {
        openWindow(id: AppSceneRouter.SceneID.main.rawValue)
        Task { @MainActor in
            NSApp.activate(ignoringOtherApps: true)
            AppSceneRouter.shared.route(to: section)
        }
    }
}
