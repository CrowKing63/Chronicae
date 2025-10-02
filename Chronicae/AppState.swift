import Foundation
import Observation

@Observable final class AppState {
    enum Section: String, CaseIterable, Identifiable {
        case dashboard = "대시보드"
        case storage = "저장소 관리"
        case versions = "버전 기록"
        case settings = "설정"

        var id: String { rawValue }
    }

    var selectedSection: Section? = .dashboard
    var serverStatus: ServerStatus = .stopped
    var activeProject: ProjectSummary? = nil
    var projects: [ProjectSummary] = []
    var notes: [NoteSummary] = []
    var selectedNote: NoteSummary? = nil
    var lastUpdated: Date = .now
    var lastErrorMessage: String? = nil
    var lastBackupRecord: ServerDataStore.BackupRecord? = nil
    var lastExportJob: ServerDataStore.ExportJob? = nil
    @ObservationIgnored private var eventStreamClient: EventStreamClient?
    @ObservationIgnored private var reconnectTask: Task<Void, Never>? = nil
    private let eventDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    @MainActor
    func refreshProjects(using serverManager: ServerManager) async {
        do {
            let client = serverManager.makeAPIClient()
            let payload = try await client.fetchProjects()
            projects = payload.items
            if let activeId = payload.activeProjectId,
               let selected = payload.items.first(where: { $0.id == activeId }) {
                activeProject = selected
            } else {
                activeProject = payload.items.first
            }
            notes = []
            selectedNote = nil
            lastUpdated = .now
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    func refreshNotes(using serverManager: ServerManager) async {
        guard let projectId = activeProject?.id else {
            notes = []
            selectedNote = nil
            return
        }
        do {
            let client = serverManager.makeAPIClient()
            let fetched = try await client.fetchNotes(projectId: projectId)
            notes = fetched
            if let current = selectedNote, let preserved = fetched.first(where: { $0.id == current.id }) {
                selectedNote = preserved
            } else {
                selectedNote = fetched.first
            }
            lastUpdated = .now
            lastErrorMessage = nil
        } catch {
            notes = []
            selectedNote = nil
            lastErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    func refreshBackup(using serverManager: ServerManager) async {
        do {
            let client = serverManager.makeAPIClient()
            let history = try await client.fetchBackupHistory()
            lastBackupRecord = history.first
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    func recordBackup(_ record: ServerDataStore.BackupRecord) {
        lastBackupRecord = record
        lastUpdated = .now
    }

    @MainActor
    func recordExportJob(_ job: ServerDataStore.ExportJob) {
        lastExportJob = job
        lastUpdated = .now
    }

    @MainActor
    func updateSelectedNote(_ note: NoteSummary) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        }
        selectedNote = note
        lastUpdated = .now
    }

    @MainActor
    func removeNote(id: UUID) {
        notes.removeAll { $0.id == id }
        if selectedNote?.id == id {
            selectedNote = notes.first
        }
        lastUpdated = .now
    }

    @MainActor
    func startEventStream(using serverManager: ServerManager) {
        let url = serverManager.eventsURL()
        eventStreamClient?.stop()
        let client = EventStreamClient(onMessage: { [weak self] message in
            guard let self else { return }
            Task { await self.handleEvent(message: message, serverManager: serverManager) }
        }, onError: { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.scheduleReconnect(using: serverManager) }
        })
        eventStreamClient = client
        let token = serverManager.currentConfiguration().authToken
        client.start(url: url, token: token)
    }

    @MainActor
    func stopEventStream() {
        reconnectTask?.cancel()
        reconnectTask = nil
        eventStreamClient?.stop()
        eventStreamClient = nil
    }

    @MainActor
    private func scheduleReconnect(using serverManager: ServerManager) {
        guard reconnectTask == nil else { return }
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                guard let self else { return }
                self.startEventStream(using: serverManager)
                self.reconnectTask = nil
            }
        }
    }

    @MainActor
    private func handleEvent(message: EventStreamMessage, serverManager: ServerManager) async {
        guard let eventType = AppEventType(rawValue: message.event) else { return }
        switch eventType {
        case .projectReset, .projectDeleted:
            await refreshProjects(using: serverManager)
            await refreshNotes(using: serverManager)
        case .noteCreated, .noteUpdated:
            if let note: NoteSummary = decode(message.data) {
                upsert(note: note)
            } else {
                await refreshNotes(using: serverManager)
            }
        case .noteDeleted:
            if let payload: NoteIdentifierPayload = decode(message.data) {
                removeNote(id: payload.id)
            } else {
                await refreshNotes(using: serverManager)
            }
        case .noteVersionRestored:
            await refreshNotes(using: serverManager)
        case .noteExportQueued, .noteVersionExportQueued:
            break
        case .backupCompleted:
            if let payload: BackupRecordPayload = decode(message.data),
               let status = ServerDataStore.BackupRecord.Status(rawValue: payload.status) {
                let record = ServerDataStore.BackupRecord(id: payload.id,
                                                         startedAt: payload.startedAt,
                                                         completedAt: payload.completedAt,
                                                         status: status,
                                                         artifactPath: payload.artifactPath)
                recordBackup(record)
            } else {
                await refreshBackup(using: serverManager)
            }
        case .ping:
            break
        }
    }

    private func decode<T: Decodable>(_ data: Data) -> T? {
        try? eventDecoder.decode(T.self, from: data)
    }

    @MainActor
    private func upsert(note: NoteSummary) {
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx] = note
        } else {
            notes.append(note)
        }
        notes.sort { $0.updatedAt > $1.updatedAt }
        if selectedNote?.id == note.id {
            selectedNote = note
        }
        lastUpdated = .now
    }
}

struct ProjectSummary: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var noteCount: Int
    var lastIndexedAt: Date?
}
