import SwiftUI
import Observation

struct StorageManagementView: View {
    @Bindable var appState: AppState
    @Bindable var serverManager: ServerManager

    @State private var newProjectName: String = ""
    @State private var isProcessing = false
    @State private var exportingProjectId: UUID?
    @State private var errorMessage: String?

    @State private var noteTitleDraft: String = ""
    @State private var noteContentDraft: String = ""
    @State private var noteTagsDraft: String = ""
    @State private var noteEditorMode: NoteEditorMode = .edit
    @State private var isSavingNote = false
    @State private var isCreatingNote = false
    @State private var toast: ToastMessage?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            HStack(alignment: .top, spacing: 24) {
                projectColumn
                notesColumn
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .alert("오류", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("확인", role: .cancel) { errorMessage = nil }
        } message: {
            if let errorMessage { Text(errorMessage) }
        }
        .task { await initialLoadIfNeeded() }
        .onChange(of: appState.selectedNote?.id) { _ in loadDraftFromSelection() }
        .onChange(of: appState.notes) { _ in loadDraftFromSelection() }
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
            Text("프로젝트 & 노트 관리")
                .font(.title2.weight(.semibold))
            Text("프로젝트를 전환하고 노트를 작성·편집하세요.")
                .foregroundStyle(.secondary)
        }
    }

    private var projectColumn: some View {
        VStack(spacing: 16) {
            HStack {
                TextField("새 프로젝트 이름", text: $newProjectName)
                Button("생성") { createProject() }
                    .disabled(isProcessing || newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            List(selection: Binding(get: { appState.activeProject?.id }, set: { id in
                guard let id, !isProcessing else { return }
                switchProject(id)
            })) {
                ForEach(appState.projects) { project in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(project.name)
                            .font(.headline)
                        Text("노트 \(project.noteCount)개")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if exportingProjectId == project.id {
                            Label("내보내는 중", systemImage: "arrow.up.doc")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(project.id)
                    .contextMenu {
                        Button("초기화", role: .destructive) { reset(project: project) }
                            .disabled(isProcessing)
                        Button("내보내기") { export(project: project) }
                            .disabled(exportingProjectId != nil)
                        Divider()
                        Button("삭제", role: .destructive) { delete(project: project) }
                            .disabled(isProcessing)
                    }
                }
            }
            .frame(minHeight: 320, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                if isProcessing {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 12)
                        .padding(.top, 12)
                }
            }

            if let exportStatus = formattedExportStatus {
                Divider()
                Text(exportStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 260, maxWidth: 320)
    }

    private var notesColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("노트")
                    .font(.headline)
                Spacer()
                Button {
                    createNote()
                } label: {
                    Label("새 노트", systemImage: "plus")
                }
                .disabled(appState.activeProject == nil || isCreatingNote)
            }

            if appState.activeProject == nil {
                Text("프로젝트를 선택하면 노트를 관리할 수 있습니다.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if appState.notes.isEmpty {
                VStack(spacing: 12) {
                    Text("아직 노트가 없습니다.")
                        .foregroundStyle(.secondary)
                    Text("'새 노트' 버튼으로 첫 노트를 만들어 보세요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    List(selection: Binding(get: { appState.selectedNote?.id }, set: { id in
                        guard let id, let note = appState.notes.first(where: { $0.id == id }) else { return }
                        appState.updateSelectedNote(note)
                        loadDraftFromSelection()
                    })) {
                        ForEach(appState.notes) { note in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.title)
                                    .font(.headline)
                                Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(minWidth: 220, maxHeight: .infinity)

                    noteDetail
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var noteDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selected = appState.selectedNote {
                Picker("", selection: $noteEditorMode) {
                    ForEach(NoteEditorMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)

                TextField("제목", text: $noteTitleDraft)
                    .textFieldStyle(.roundedBorder)

                TextField("태그 (콤마로 구분)", text: $noteTagsDraft)
                    .textFieldStyle(.roundedBorder)

                if noteEditorMode == .edit {
                    if !tagSuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("추천 태그")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                                ForEach(tagSuggestions, id: \.self) { suggestion in
                                    Button {
                                        applyTagSuggestion(suggestion)
                                    } label: {
                                        Text(suggestion)
                                            .font(.footnote)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 12)
                                            .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                                    }
                                }
                            }
                        }
                    }

                    TextEditor(text: $noteContentDraft)
                        .frame(minHeight: 240)
                        .font(.body)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if let attributed = try? AttributedString(markdown: noteContentDraft) {
                                Text(attributed)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else if noteContentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("미리볼 내용이 없습니다.")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(noteContentDraft)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(12)
                    }
                    .frame(minHeight: 240)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.03)))
                }

                HStack {
                    Button {
                        saveNote()
                    } label: {
                        Label("저장", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isSavingNote)

                    Button(role: .destructive) {
                        deleteSelectedNote()
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                    .disabled(isSavingNote)

                    Spacer()
                    Text("버전 \(selected.version) · 마지막 수정 \(selected.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("노트를 선택하거나 새로 생성하세요.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Project actions

    private func createProject() {
        let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isProcessing else { return }
        performProjectMutation(onSuccess: {
            newProjectName = ""
            showToast("프로젝트를 생성했습니다", systemImage: "checkmark.circle")
        }) { client in
            try await client.createProject(name: name)
        }
    }

    private func switchProject(_ id: UUID) {
        guard appState.activeProject?.id != id else { return }
        performProjectMutation { client in
            try await client.switchProject(id: id)
        }
    }

    private func reset(project: ProjectSummary) {
        performProjectMutation(onSuccess: {
            showToast("프로젝트를 초기화했습니다", systemImage: "arrow.counterclockwise")
        }) { client in
            try await client.resetProject(id: project.id)
        }
    }

    private func export(project: ProjectSummary) {
        Task {
            await MainActor.run {
                exportingProjectId = project.id
                errorMessage = nil
            }
            do {
                let client = serverManager.makeAPIClient()
                let job = try await client.exportProject(id: project.id)
                await MainActor.run {
                    appState.recordExportJob(job)
                    showToast("내보내기 요청을 전송했습니다", systemImage: "square.and.arrow.up")
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
            await MainActor.run { exportingProjectId = nil }
        }
    }

    private func delete(project: ProjectSummary) {
        performProjectMutation(onSuccess: {
            showToast("프로젝트를 삭제했습니다", systemImage: "trash")
        }) { client in
            try await client.deleteProject(id: project.id)
        }
    }

    private func performProjectMutation(onSuccess: @MainActor @escaping () -> Void = {}, _ work: @escaping (ServerAPIClient) async throws -> Void) {
        Task {
            await MainActor.run {
                isProcessing = true
                errorMessage = nil
            }
            do {
                let client = serverManager.makeAPIClient()
                try await work(client)
                await appState.refreshProjects(using: serverManager)
                await appState.refreshNotes(using: serverManager)
                await MainActor.run {
                    onSuccess()
                    loadDraftFromSelection()
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
            await MainActor.run { isProcessing = false }
        }
    }

    // MARK: - Note actions

    private func createNote() {
        guard let projectId = appState.activeProject?.id else { return }
        Task {
            await MainActor.run {
                isCreatingNote = true
                errorMessage = nil
            }
            do {
                let client = serverManager.makeAPIClient()
                let note = try await client.createNote(projectId: projectId, title: "새 노트", content: "", tags: [])
                await appState.refreshNotes(using: serverManager)
                await MainActor.run {
                    appState.updateSelectedNote(note)
                    noteEditorMode = .edit
                    loadDraftFromSelection()
                    showToast("새 노트를 만들었습니다", systemImage: "plus")
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
            await MainActor.run { isCreatingNote = false }
        }
    }

    private func saveNote() {
        guard let projectId = appState.activeProject?.id,
              let noteId = appState.selectedNote?.id else { return }
        let tags = currentTags
        Task {
            await MainActor.run {
                isSavingNote = true
                errorMessage = nil
            }
            do {
                let client = serverManager.makeAPIClient()
                let updated = try await client.updateNote(projectId: projectId,
                                                          noteId: noteId,
                                                          title: noteTitleDraft,
                                                          content: noteContentDraft,
                                                          tags: tags)
                await appState.refreshNotes(using: serverManager)
                await MainActor.run {
                    appState.updateSelectedNote(updated)
                    loadDraftFromSelection()
                    showToast("노트를 저장했습니다", systemImage: "checkmark.circle")
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
            await MainActor.run { isSavingNote = false }
        }
    }

    private func deleteSelectedNote() {
        guard let projectId = appState.activeProject?.id,
              let noteId = appState.selectedNote?.id else { return }
        Task {
            await MainActor.run {
                isSavingNote = true
                errorMessage = nil
            }
            do {
                let client = serverManager.makeAPIClient()
                try await client.deleteNote(projectId: projectId, noteId: noteId)
                await appState.refreshNotes(using: serverManager)
                await MainActor.run {
                    appState.removeNote(id: noteId)
                    noteEditorMode = .edit
                    loadDraftFromSelection()
                    showToast("노트를 삭제했습니다", systemImage: "trash")
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
            await MainActor.run { isSavingNote = false }
        }
    }

    // MARK: - Helpers

    private func initialLoadIfNeeded() async {
        if appState.notes.isEmpty {
            await appState.refreshNotes(using: serverManager)
        }
        await MainActor.run { loadDraftFromSelection() }
    }

    private func loadDraftFromSelection() {
        guard let note = appState.selectedNote else {
            noteTitleDraft = ""
            noteContentDraft = ""
            noteTagsDraft = ""
            return
        }
        noteTitleDraft = note.title
        noteContentDraft = note.content
        noteTagsDraft = note.tags.joined(separator: ", ")
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

    private var formattedExportStatus: String? {
        guard let job = appState.lastExportJob else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        let target = job.versionId == nil ? "프로젝트" : "버전"
        return "최근 내보내기: \(target) • \(formatter.string(from: job.createdAt))"
    }

    private var availableTags: [String] {
        Array(Set(appState.notes.flatMap { $0.tags })).sorted()
    }

    private var currentTags: [String] {
        noteTagsDraft
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var currentTagQuery: String {
        let components = noteTagsDraft.components(separatedBy: ",")
        guard let last = components.last else { return "" }
        return last.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var tagSuggestions: [String] {
        let existing = Set(currentTags.map { $0.lowercased() })
        let query = currentTagQuery.lowercased()
        let candidates = availableTags.filter { !existing.contains($0.lowercased()) }
        if query.isEmpty { return Array(candidates.prefix(6)) }
        return candidates.filter { $0.lowercased().contains(query) }.prefix(6).map { $0 }
    }

    private func applyTagSuggestion(_ suggestion: String) {
        var tags = currentTags
        if !tags.contains(where: { $0.caseInsensitiveCompare(suggestion) == .orderedSame }) {
            tags.append(suggestion)
        }
        noteTagsDraft = tags.joined(separator: ", ")
    }

    private enum NoteEditorMode: String, CaseIterable, Identifiable {
        case edit = "편집"
        case preview = "미리보기"

        var id: String { rawValue }
        var title: String { rawValue }
    }
}
