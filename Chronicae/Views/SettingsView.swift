import SwiftUI
import Observation
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var appState: AppState
    @Bindable var serverManager: ServerManager

    @State private var configuration = ServerConfiguration()
    @State private var autoStart = true
    @State private var isRunningBackup = false
    @State private var errorMessage: String?
    @State private var tokenStatusMessage: String?

    var body: some View {
        Form {
            Section("네트워크") {
                Stepper(value: $configuration.port, in: 1024...65535, step: 1) {
                    Text("포트: \(configuration.port)")
                }
                Toggle("외부 접속 허용", isOn: $configuration.allowExternal)
                    .toggleStyle(.switch)
            }

            Section("보안") {
                VStack(alignment: .leading, spacing: 8) {
                    if let token = configuration.authToken, !token.isEmpty {
                        LabeledContent("현재 토큰") {
                            Text(masked(token: token))
                                .font(.system(.body, design: .monospaced))
                        }
                        Button("iCloud Drive에 토큰 파일 저장") {
                            saveTokenFile(token)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Text("토큰이 설정되지 않았습니다. 토큰을 생성하면 같은 Apple ID가 로그인된 기기에서 REST/SSE 요청 시 인증 헤더를 붙일 수 있습니다.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                    HStack {
                        Button("액세스 토큰 생성") {
                            generateToken()
                        }
                        .buttonStyle(.borderedProminent)
                        Button("토큰 비활성화", role: .destructive) {
                            revokeToken()
                        }
                        .disabled(configuration.authToken == nil)
                    }
                    if let tokenStatusMessage {
                        Text(tokenStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let pathDescription = tokenFilePathDescription {
                        Text(pathDescription)
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Section("백업") {
                Toggle("자동 백업", isOn: $autoStart)
                Button("지금 백업 실행") { runBackup() }
                    .disabled(isRunningBackup)
                if let status = formattedBackupStatus {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("정보") {
                HStack {
                    Text("버전")
                    Spacer()
                    Text("0.1.0 (스캐폴딩)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("상태")
                    Spacer()
                    Text(statusText)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .formStyle(.grouped)
        .onAppear(perform: syncConfiguration)
        .task {
            await appState.refreshBackup(using: serverManager)
        }
        .onChange(of: configuration) { _, newValue in
            serverManager.updateConfiguration(newValue)
        }
        .alert("오류", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("확인", role: .cancel) { errorMessage = nil }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
    }

    private var statusText: String {
        switch serverManager.status {
        case .stopped:
            return "중지됨"
        case .starting:
            return "시작 중"
        case .running:
            return "실행 중"
        case .error:
            return "오류"
        }
    }

    private func syncConfiguration() {
        configuration = serverManager.currentConfiguration()
    }

    private func runBackup() {
        Task {
            await MainActor.run {
                isRunningBackup = true
                errorMessage = nil
                tokenStatusMessage = nil
            }
            do {
                let client = serverManager.makeAPIClient()
                let record = try await client.runBackup()
                await MainActor.run {
                    appState.recordBackup(record)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            await MainActor.run { isRunningBackup = false }
        }
    }

    private var formattedBackupStatus: String? {
        guard let record = appState.lastBackupRecord else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "마지막 백업: \(formatter.string(from: record.completedAt))"
    }

    private func generateToken() {
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        configuration.authToken = token
        saveTokenFile(token)
        tokenStatusMessage = "새 토큰을 생성했습니다."
    }

    private func revokeToken() {
        configuration.authToken = nil
        deleteTokenFile()
        tokenStatusMessage = "토큰을 비활성화했습니다."
    }

    private func saveTokenFile(_ token: String) {
        tokenStatusMessage = nil
        do {
            let url = tokenFileURL
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let payload: [String: Any] = [
                "token": token,
                "generatedAt": ISO8601DateFormatter().string(from: Date())
            ]
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
            try data.write(to: url, options: [.atomic])
            tokenStatusMessage = "토큰 파일을 저장했습니다. (iCloud 동기화에 시간이 걸릴 수 있습니다)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteTokenFile() {
        let url = tokenFileURL
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func masked(token: String) -> String {
        guard token.count > 8 else { return token }
        let prefix = token.prefix(4)
        let suffix = token.suffix(4)
        return "\(prefix)…\(suffix)"
    }

    private var tokenFileURL: URL {
        let base = FileManager.default.homeDirectoryForCurrentUser
        return base
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Chronicae", isDirectory: true)
            .appendingPathComponent("token.json", conformingTo: .json)
    }

    private var tokenFilePathDescription: String? {
        let path = tokenFileURL.path
        return "토큰 파일 경로: \(path)"
    }
}
