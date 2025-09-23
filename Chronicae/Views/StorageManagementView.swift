import SwiftUI
import Observation

struct StorageManagementView: View {
    @Bindable var appState: AppState
    @Bindable var serverManager: ServerManager
    @State private var newProjectName: String = ""
    @State private var isExporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            projectList
            Spacer()
        }
        .padding(24)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("프로젝트 관리")
                .font(.title2.weight(.semibold))
            Text("프로젝트 전환, 초기화, 내보내기 작업을 수행합니다.")
                .foregroundStyle(.secondary)
        }
    }

    private var projectList: some View {
        VStack(spacing: 16) {
            HStack {
                TextField("새 프로젝트 이름", text: $newProjectName)
                Button("생성") { createProject() }
                    .disabled(newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            List(selection: Binding(get: { appState.activeProject?.id }, set: { id in
                guard let id else { return }
                switchProject(id)
            })) {
                ForEach(appState.projects) { project in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(project.name)
                            .font(.headline)
                        Text("노트 \(project.noteCount)개")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .tag(project.id)
                    .contextMenu {
                        Button("초기화", role: .destructive) { reset(project: project) }
                        Button("내보내기") { export(project: project) }
                        Divider()
                        Button("삭제", role: .destructive) { delete(project: project) }
                    }
                }
            }
            .frame(minHeight: 320)
        }
    }

    private func createProject() {
        // 실제 서버 연동은 추후 구현
        let id = UUID()
        let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let project = ProjectSummary(id: id, name: name, noteCount: 0, lastIndexedAt: nil)
        appState.projects.append(project)
        appState.activeProject = project
        newProjectName = ""
    }

    private func switchProject(_ id: UUID) {
        // 서버 커맨드와 동기화 예정
        guard let project = appState.projects.first(where: { $0.id == id }) else { return }
        appState.activeProject = project
        appState.lastUpdated = .now
    }

    private func reset(project: ProjectSummary) {
        // TODO: API 호출 연동
        appState.lastUpdated = .now
    }

    private func export(project: ProjectSummary) {
        isExporting = true
        // TODO: 내보내기 후 진행 상황 갱신
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isExporting = false
        }
    }

    private func delete(project: ProjectSummary) {
        appState.projects.removeAll { $0.id == project.id }
        if appState.activeProject?.id == project.id {
            appState.activeProject = appState.projects.first
        }
        appState.lastUpdated = .now
    }
}
