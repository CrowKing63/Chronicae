import SwiftUI
import Observation
import Foundation

struct DashboardView: View {
    @Bindable var appState: AppState
    @Bindable var serverManager: ServerManager
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                serverHeader
                statusGrid
                recentActivity
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var serverHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("서버 상태")
                    .font(.title2.weight(.semibold))
                Text(statusSubtitle)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            Spacer()

            Button(action: toggleServer) {
                Label(buttonLabel, systemImage: buttonIcon)
                    .frame(minWidth: 140)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing)
        }
    }

    private var statusGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 18) {
            GridRow {
                statusBadge
                metricView(title: "현재 프로젝트", value: appState.activeProject?.name ?? "미선택")
                metricView(title: "노트 수", value: "\(appState.activeProject?.noteCount ?? 0)")
            }
            GridRow {
                metricView(title: "서비스 포트", value: "\(serverPort)")
                metricView(title: "업타임", value: uptime)
                metricView(title: "접속 URL", value: accessURL)
            }
            GridRow {
                metricView(title: "최근 인덱싱", value: lastIndexed)
                emptyCell()
                emptyCell()
            }
        }
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 활동")
                .font(.headline)
            if appState.lastUpdated.timeIntervalSinceNow > -5 {
                Text("최근 데이터가 아직 준비되지 않았습니다.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                Text("활동 로그 연동 예정")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusBadge: some View {
        let style = badgeStyle(for: serverManager.status)
        return Label(style.title, systemImage: style.symbol)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(style.background)
            .clipShape(Capsule())
    }

    private func metricView(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var statusSubtitle: String {
        switch serverManager.status {
        case .stopped:
            return "서버가 중지되었습니다."
        case .starting:
            return "서버를 기동 중입니다."
        case .running(let runtime):
            return "포트 \(runtime.port)에서 실행 중"
        case .error(let error):
            return "오류: \(error.message)"
        }
    }

    private var buttonLabel: String {
        switch serverManager.status {
        case .stopped, .error:
            return "서버 시작"
        case .starting:
            return "시작 중..."
        case .running:
            return "서버 중지"
        }
    }

    private var buttonIcon: String {
        switch serverManager.status {
        case .stopped, .error:
            return "play.fill"
        case .starting:
            return "hourglass"
        case .running:
            return "stop.fill"
        }
    }

    private var serverPort: Int {
        switch serverManager.status {
        case .running(let runtime):
            return runtime.port
        default:
            return serverManager.currentConfiguration().port
        }
    }

    private var uptime: String {
        guard case .running(let runtime) = serverManager.status else {
            return "-"
        }
        let interval = Date.now.timeIntervalSince(runtime.startedAt)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .short
        return formatter.string(from: interval) ?? "-"
    }

    private var lastIndexed: String {
        guard let date = appState.activeProject?.lastIndexedAt else { return "-" }
        return DateFormatter.relative.localizedString(for: date, relativeTo: .now)
    }

    private var accessURL: String {
        let host: String
        if serverManager.currentConfiguration().allowExternal {
            host = Host.current().localizedName ?? "0.0.0.0"
        } else {
            host = "localhost"
        }
        return "http://\(host):\(serverPort)"
    }

    private func emptyCell() -> some View {
        Color.clear.frame(maxWidth: .infinity)
    }

    private func badgeStyle(for status: ServerStatus) -> (title: String, symbol: String, background: some ShapeStyle) {
        switch status {
        case .stopped:
            return ("중지", "pause.circle", Color.gray.opacity(0.2))
        case .starting:
            return ("시작 중", "clock.arrow.circlepath", Color.yellow.opacity(0.3))
        case .running:
            return ("실행 중", "checkmark.circle", Color.green.opacity(0.3))
        case .error:
            return ("오류", "exclamationmark.triangle", Color.red.opacity(0.3))
        }
    }

    private func toggleServer() {
        Task {
            isProcessing = true
            defer { isProcessing = false }
            switch serverManager.status {
            case .stopped, .error:
                await serverManager.startIfNeeded()
            case .starting, .running:
                await serverManager.stop()
            }
            appState.serverStatus = serverManager.status
        }
    }
}

private extension DateFormatter {
    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
