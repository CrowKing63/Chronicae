import SwiftUI
import Observation

struct VersionsView: View {
    @Bindable var appState: AppState

    @State private var selectedVersion: VersionSnapshot?
    @State private var versions: [VersionSnapshot] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            content
        }
        .padding(24)
        .task { loadVersions() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("버전 기록")
                .font(.title2.weight(.semibold))
            if let project = appState.activeProject {
                Text("프로젝트 \(project.name)의 최근 30일 스냅샷")
                    .foregroundStyle(.secondary)
            } else {
                Text("프로젝트를 선택하면 버전 기록이 표시됩니다.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var content: some View {
        HStack(spacing: 24) {
            List(versions, selection: $selectedVersion) { version in
                VStack(alignment: .leading, spacing: 4) {
                    Text(version.title)
                        .font(.headline)
                    Text(version.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            .frame(minWidth: 320)

            detailPanel
        }
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let version = selectedVersion {
                Text("선택한 버전")
                    .font(.headline)
                ScrollView {
                    Text(version.preview)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Button("이 버전으로 복구") {
                        restore(version: version)
                    }
                    Button("내보내기") {
                        export(version: version)
                    }
                }
            } else {
                Text("버전을 선택하면 상세 내용이 표시됩니다.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func loadVersions() {
        // TODO: API 연동. 현재는 목업 데이터.
        guard let project = appState.activeProject else {
            versions = []
            selectedVersion = nil
            return
        }

        let draft = VersionSnapshot(
            id: UUID(),
            title: "요약 초안",
            timestamp: Date().addingTimeInterval(-3600),
            preview: "RAG 파이프라인 개선 내용...",
            projectId: project.id
        )

        let final = VersionSnapshot(
            id: UUID(),
            title: "최종 정리",
            timestamp: Date().addingTimeInterval(-7200),
            preview: "## 완료 사항\n- 서버 스캐폴딩\n- API 스펙",
            projectId: project.id
        )

        versions = [draft, final]
        selectedVersion = versions.first
    }

    private func restore(version: VersionSnapshot) {
        // TODO: 복구 API 호출
        appState.lastUpdated = .now
    }

    private func export(version: VersionSnapshot) {
        // TODO: 내보내기 엔드포인트 연결
    }
}

struct VersionSnapshot: Identifiable, Hashable {
    let id: UUID
    var title: String
    var timestamp: Date
    var preview: String
    var projectId: UUID
}
