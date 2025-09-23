import SwiftUI
import Observation

struct SettingsView: View {
    @Bindable var appState: AppState
    @Bindable var serverManager: ServerManager

    @State private var configuration = ServerConfiguration()
    @State private var autoStart = true

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
                Toggle("서버 시작 시 인증 필요", isOn: .constant(true))
                    .disabled(true)
                Text("인증 옵션은 추후 추가 예정입니다.")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }

            Section("백업") {
                Toggle("자동 백업", isOn: $autoStart)
                Button("지금 백업 실행") {
                    // TODO: 백업 API 호출 연결
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
        .onChange(of: configuration) { _, newValue in
            serverManager.updateConfiguration(newValue)
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
}
