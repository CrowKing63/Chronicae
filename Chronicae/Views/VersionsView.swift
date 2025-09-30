import SwiftUI
import Observation

struct VersionsView: View {
    @Bindable var appState: AppState
    @Bindable var serverManager: ServerManager

    @State private var selectedVersion: VersionSnapshot?
    @State private var versions: [VersionSnapshot] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var restoringVersionId: UUID?
    @State private var exportingVersionId: UUID?
    @State private var isNotesLoading = false
    @State private var toast: ToastMessage?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            content
        }
        .padding(24)
        .task { await ensureNotesLoaded() }
        .onChange(of: appState.activeProject?.id) { _, _ in
            Task {
                await ensureNotesLoaded()
                await loadVersions()
            }
        }
        .onChange(of: appState.selectedNote?.id) { _, _ in
            Task { await loadVersions() }
        }
        .alert("오류", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("확인", role: .cancel) { errorMessage = nil }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
        .overlay(alignment: .top) {
            if let toast {
                BannerToastView(message: toast)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toast)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("버전 기록")
                .font(.title2.weight(.semibold))
            if let project = appState.activeProject, let note = appState.selectedNote {
                Text("프로젝트 \(project.name) · 노트 \(note.title)")
                    .foregroundStyle(.secondary)
            } else if let project = appState.activeProject {
                Text("프로젝트 \(project.name)의 노트를 선택하세요")
                    .foregroundStyle(.secondary)
            } else {
                Text("프로젝트를 선택하면 버전 기록이 표시됩니다.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var content: some View {
        Group {
            if isNotesLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("노트를 불러오는 중입니다...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.notes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("프로젝트에 노트가 없습니다.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("버전을 불러오는 중입니다...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if versions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("표시할 버전이 없습니다.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 24) {
                    List(selection: Binding(get: { appState.selectedNote?.id }, set: { id in
                        guard let id, let note = appState.notes.first(where: { $0.id == id }) else { return }
                        appState.updateSelectedNote(note)
                    })) {
                        ForEach(appState.notes) { note in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.title)
                                    .font(.headline)
                                Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .frame(minWidth: 240)

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
                    .disabled(restoringVersionId != nil)
                    .overlay(alignment: .trailing) {
                        if restoringVersionId == version.id {
                            ProgressView()
                                .controlSize(.small)
                                .offset(x: 24)
                        }
                    }
                    Button("내보내기") {
                        export(version: version)
                    }
                    .disabled(exportingVersionId != nil)
                    .overlay(alignment: .trailing) {
                        if exportingVersionId == version.id {
                            ProgressView()
                                .controlSize(.small)
                                .offset(x: 24)
                        }
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

    private func loadVersions() async {
        guard let note = appState.selectedNote else {
            await MainActor.run {
                versions = []
                selectedVersion = nil
            }
            return
        }
        let noteId = note.id
        let projectId = note.projectId

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let client = serverManager.makeAPIClient()
            let latestNote = try await client.fetchNote(projectId: projectId, noteId: noteId)
            await MainActor.run {
                appState.updateSelectedNote(latestNote)
            }
            let fetched = try await client.fetchVersions(projectId: projectId, noteId: noteId)
            await MainActor.run {
                versions = fetched
                selectedVersion = fetched.first
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                versions = []
                selectedVersion = nil
            }
        }
    }

    private func restore(version: VersionSnapshot) {
        Task {
            await MainActor.run { restoringVersionId = version.id }
            do {
                let client = serverManager.makeAPIClient()
                let restoredVersion = try await client.restoreVersion(projectId: version.projectId, noteId: version.noteId, versionId: version.id)
                let updatedNote = try await client.fetchNote(projectId: version.projectId, noteId: restoredVersion.noteId)
                await MainActor.run {
                    appState.updateSelectedNote(updatedNote)
                    showToast("이전 버전으로 복구했습니다", systemImage: "clock.arrow.circlepath")
                }
                await loadVersions()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            await MainActor.run { restoringVersionId = nil }
        }
    }

    private func export(version: VersionSnapshot) {
        Task {
            await MainActor.run { exportingVersionId = version.id }
            do {
                let client = serverManager.makeAPIClient()
                let job = try await client.exportVersion(projectId: version.projectId, noteId: version.noteId, versionId: version.id)
                await MainActor.run {
                    appState.recordExportJob(job)
                    showToast("내보내기 요청을 전송했습니다", systemImage: "square.and.arrow.up")
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            await MainActor.run { exportingVersionId = nil }
        }
    }

    private func ensureNotesLoaded() async {
        await MainActor.run { isNotesLoading = true }
        if appState.activeProject != nil, appState.notes.isEmpty {
            await appState.refreshNotes(using: serverManager)
        }
        await MainActor.run { isNotesLoading = false }
    }

    private func showToast(_ text: String, systemImage: String) {
        let message = ToastMessage(text: text, systemImage: systemImage)
        withAnimation { toast = message }
        Task { @MainActor in
            try await Task.sleep(nanoseconds: 2_000_000_000)
            if toast?.id == message.id {
                withAnimation { toast = nil }
            }
        }
    }
}
