import Foundation
import CoreData
import OSLog

@MainActor
final class ServerDataStore {
    private static let defaultActiveProjectKey = "com.chronicae.server.activeProjectID"
    static let shared = ServerDataStore(persistentStore: .shared)

    struct ExportJob: Identifiable, Codable {
        enum Status: String, Codable {
            case queued
            case completed
        }

        let id: UUID
        let projectId: UUID
        var versionId: UUID?
        var status: Status
        var createdAt: Date
    }

    struct BackupRecord: Identifiable, Codable {
        enum Status: String, Codable {
            case success
            case failed
        }

        let id: UUID
        var startedAt: Date
        var completedAt: Date
        var status: Status
        var artifactPath: String?
    }

    private let persistentStore: ServerPersistentStore
    private let context: NSManagedObjectContext
    private let logger = Logger(subsystem: "com.chronicae.app", category: "ServerDataStore")
    private let defaults: UserDefaults
    private let activeProjectKey: String

    init(persistentStore: ServerPersistentStore,
         defaults: UserDefaults = .standard,
         activeProjectKey: String = ServerDataStore.defaultActiveProjectKey,
         seedOnFirstLaunch: Bool = true) {
        self.persistentStore = persistentStore
        self.context = persistentStore.viewContext
        self.defaults = defaults
        self.activeProjectKey = activeProjectKey
        if seedOnFirstLaunch {
            seedIfNeeded()
        }
    }

    private var activeProjectId: UUID? {
        get {
            guard let string = defaults.string(forKey: activeProjectKey) else { return nil }
            return UUID(uuidString: string)
        }
        set {
            if let value = newValue {
                defaults.set(value.uuidString, forKey: activeProjectKey)
            } else {
                defaults.removeObject(forKey: activeProjectKey)
            }
        }
    }

    // MARK: - Projects

    func listProjects() -> (items: [ProjectSummary], active: UUID?) {
        let request: NSFetchRequest<CDProject> = CDProject.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let projects = (try? context.fetch(request)) ?? []
        let summaries = projects.map(makeProjectSummary)
        if activeProjectId == nil, let first = summaries.first?.id {
            activeProjectId = first
        }
        return (summaries, activeProjectId)
    }

    func createProject(name: String) -> ProjectSummary {
        let project = CDProject(context: context)
        project.id = UUID()
        project.name = name
        project.noteCount = 0
        project.lastIndexedAt = nil
        saveIfNeeded()
        activeProjectId = project.id
        return makeProjectSummary(from: project)
    }

    func switchProject(id: UUID) -> ProjectSummary? {
        guard let project = fetchProject(id: id) else { return nil }
        activeProjectId = id
        return makeProjectSummary(from: project)
    }

    func resetProject(id: UUID) -> ProjectSummary? {
        guard let project = fetchProject(id: id) else { return nil }
        for note in project.notes {
            context.delete(note)
        }
        project.noteCount = 0
        project.lastIndexedAt = Date()
        saveIfNeeded()
        let summary = makeProjectSummary(from: project)
        Task { await ServerEventCenter.shared.publish(ServerEvent(type: .projectReset, payload: summary)) }
        return summary
    }

    func deleteProject(id: UUID) {
        guard let project = fetchProject(id: id) else { return }
        let summary = makeProjectSummary(from: project)
        context.delete(project)
        saveIfNeeded()
        if activeProjectId == id {
            activeProjectId = listProjects().items.first?.id
        }
        Task { await ServerEventCenter.shared.publish(ServerEvent(type: .projectDeleted, payload: summary)) }
    }

    // MARK: - Notes

    func listNotes(projectId: UUID, limit: Int = 100) -> [NoteSummary]? {
        guard fetchProject(id: projectId) != nil else { return nil }
        let request: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        request.predicate = NSPredicate(format: "project.id == %@", projectId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        request.fetchLimit = limit
        let notes = (try? context.fetch(request)) ?? []
        return notes.map(makeNoteSummary)
    }

    func fetchNote(projectId: UUID, noteId: UUID) -> NoteSummary? {
        guard let note = fetchNoteEntity(projectId: projectId, noteId: noteId) else { return nil }
        return makeNoteSummary(from: note)
    }

    func createNote(projectId: UUID, title: String, content: String, tags: [String]) -> NoteSummary? {
        guard let project = fetchProject(id: projectId) else { return nil }
        let note = CDNote(context: context)
        let now = Date()
        note.id = UUID()
        note.title = title
        note.content = content
        note.excerpt = makeExcerpt(from: content)
        note.tags = encodeTags(tags)
        note.createdAt = now
        note.updatedAt = now
        note.version = 1
        note.project = project

        _ = appendVersion(for: note)
        updateNoteCount(for: project)
        project.lastIndexedAt = now
        saveIfNeeded()
        let summary = makeNoteSummary(from: note)
        Task { await ServerEventCenter.shared.publish(ServerEvent(type: .noteCreated, payload: summary)) }
        return summary
    }

    func updateNote(projectId: UUID, noteId: UUID, title: String, content: String, tags: [String]) -> NoteSummary? {
        guard let note = fetchNoteEntity(projectId: projectId, noteId: noteId) else { return nil }
        note.title = title
        note.content = content
        note.excerpt = makeExcerpt(from: content)
        note.tags = encodeTags(tags)
        note.updatedAt = Date()
        note.version += 1
        _ = appendVersion(for: note)
        note.project.lastIndexedAt = note.updatedAt
        saveIfNeeded()
        let summary = makeNoteSummary(from: note)
        Task { await ServerEventCenter.shared.publish(ServerEvent(type: .noteUpdated, payload: summary)) }
        return summary
    }

    func deleteNote(projectId: UUID, noteId: UUID) {
        guard let note = fetchNoteEntity(projectId: projectId, noteId: noteId) else { return }
        let project = note.project
        let payload = NoteIdentifierPayload(id: note.id, projectId: project.id)
        context.delete(note)
        updateNoteCount(for: project)
        project.lastIndexedAt = Date()
        saveIfNeeded()
        Task { await ServerEventCenter.shared.publish(ServerEvent(type: .noteDeleted, payload: payload)) }
    }

    // MARK: - Versions & backups

    func listVersions(noteId: UUID, limit: Int = 50) -> [VersionSnapshot]? {
        guard let note = fetchNoteEntity(projectId: nil, noteId: noteId) else { return nil }
        let request: NSFetchRequest<CDNoteVersion> = CDNoteVersion.fetchRequest()
        request.predicate = NSPredicate(format: "note.id == %@", noteId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = limit
        let versions = (try? context.fetch(request)) ?? []
        return versions.map(makeVersionSnapshot)
    }

    func restoreVersion(noteId: UUID, versionId: UUID) -> VersionSnapshot? {
        guard let version = fetchNoteVersion(versionId: versionId, noteId: noteId) else { return nil }
        let note = version.note
        note.title = version.title
        note.content = version.content
        note.excerpt = version.excerpt
        note.updatedAt = Date()
        note.version += 1
        let newSnapshot = appendVersion(for: note)
        note.project.lastIndexedAt = note.updatedAt
        saveIfNeeded()
        let snapshot = makeVersionSnapshot(from: newSnapshot)
        Task { await ServerEventCenter.shared.publish(ServerEvent(type: .noteVersionRestored, payload: snapshot)) }
        return snapshot
    }

    func exportProject(id: UUID) -> ExportJob? {
        guard fetchProject(id: id) != nil else { return nil }
        let job = CDExportJob(context: context)
        job.id = UUID()
        job.projectId = id
        job.versionId = nil
        job.status = ExportJob.Status.queued.rawValue
        job.createdAt = Date()
        saveIfNeeded()
        return makeExportJob(from: job)
    }

    func exportNote(noteId: UUID) -> ExportJob? {
        guard let note = fetchNoteEntity(projectId: nil, noteId: noteId) else { return nil }
        let job = CDExportJob(context: context)
        job.id = UUID()
        job.projectId = note.project.id
        job.versionId = nil
        job.status = ExportJob.Status.queued.rawValue
        job.createdAt = Date()
        saveIfNeeded()
        let export = makeExportJob(from: job)
        let payload = ExportJobIdentifierPayload(projectId: export.projectId, versionId: export.versionId)
        Task { await ServerEventCenter.shared.publish(ServerEvent(type: .noteExportQueued, payload: payload)) }
        return export
    }

    func exportVersion(noteId: UUID, versionId: UUID) -> ExportJob? {
        guard let version = fetchNoteVersion(versionId: versionId, noteId: noteId) else { return nil }
        let job = CDExportJob(context: context)
        job.id = UUID()
        job.projectId = version.note.project.id
        job.versionId = version.id
        job.status = ExportJob.Status.queued.rawValue
        job.createdAt = Date()
        saveIfNeeded()
        let export = makeExportJob(from: job)
        let payload = ExportJobIdentifierPayload(projectId: export.projectId, versionId: export.versionId)
        Task { await ServerEventCenter.shared.publish(ServerEvent(type: .noteVersionExportQueued, payload: payload)) }
        return export
    }

    func runBackup() -> BackupRecord {
        let now = Date()
        let record = CDBackupRecord(context: context)
        record.id = UUID()
        record.startedAt = now
        record.completedAt = now.addingTimeInterval(1)
        record.status = BackupRecord.Status.success.rawValue
        record.artifactPath = "backups/chronicae-\(now.ISO8601Format()).zip"
        saveIfNeeded()
        let backup = makeBackupRecord(from: record)
        let payload = BackupRecordPayload(id: backup.id,
                                          startedAt: backup.startedAt,
                                          completedAt: backup.completedAt,
                                          status: backup.status.rawValue,
                                          artifactPath: backup.artifactPath)
        Task { await ServerEventCenter.shared.publish(ServerEvent(type: .backupCompleted, payload: payload)) }
        return backup
    }

    func backupHistory() -> [BackupRecord] {
        let request: NSFetchRequest<CDBackupRecord> = CDBackupRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
        let records = (try? context.fetch(request)) ?? []
        return records.map(makeBackupRecord)
    }

    // MARK: - Helpers

    private func fetchProject(id: UUID) -> CDProject? {
        let request: NSFetchRequest<CDProject> = CDProject.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func fetchNoteEntity(projectId: UUID?, noteId: UUID) -> CDNote? {
        let request: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        if let projectId {
            request.predicate = NSPredicate(format: "id == %@ AND project.id == %@", noteId as CVarArg, projectId as CVarArg)
        } else {
            request.predicate = NSPredicate(format: "id == %@", noteId as CVarArg)
        }
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func fetchNoteVersion(versionId: UUID, noteId: UUID) -> CDNoteVersion? {
        let request: NSFetchRequest<CDNoteVersion> = CDNoteVersion.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND note.id == %@", versionId as CVarArg, noteId as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    @discardableResult
    private func appendVersion(for note: CDNote) -> CDNoteVersion {
        let snapshot = CDNoteVersion(context: context)
        snapshot.id = UUID()
        snapshot.title = note.title
        snapshot.content = note.content
        snapshot.excerpt = note.excerpt
        snapshot.createdAt = note.updatedAt
        snapshot.version = note.version
        snapshot.note = note
        return snapshot
    }

    private func updateNoteCount(for project: CDProject) {
        let request: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        request.predicate = NSPredicate(format: "project.id == %@", project.id as CVarArg)
        let count = (try? context.count(for: request)) ?? 0
        project.noteCount = Int64(count)
    }

    private func makeExcerpt(from content: String, limit: Int = 200) -> String {
        if content.count <= limit { return content }
        let endIndex = content.index(content.startIndex, offsetBy: limit)
        return String(content[..<endIndex]) + "…"
    }

    private func encodeTags(_ tags: [String]) -> String? {
        guard !tags.isEmpty else { return nil }
        if let data = try? JSONEncoder().encode(tags) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    private func decodeTags(_ raw: String?) -> [String] {
        guard let raw, let data = raw.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    private func makeProjectSummary(from project: CDProject) -> ProjectSummary {
        ProjectSummary(id: project.id,
                       name: project.name,
                       noteCount: Int(project.noteCount),
                       lastIndexedAt: project.lastIndexedAt)
    }

    private func makeNoteSummary(from note: CDNote) -> NoteSummary {
        NoteSummary(id: note.id,
                    projectId: note.project.id,
                    title: note.title,
                    content: note.content,
                    excerpt: note.excerpt ?? "",
                    tags: decodeTags(note.tags),
                    createdAt: note.createdAt,
                    updatedAt: note.updatedAt,
                    version: Int(note.version))
    }

    private func makeVersionSnapshot(from version: CDNoteVersion) -> VersionSnapshot {
        VersionSnapshot(id: version.id,
                        title: version.title,
                        timestamp: version.createdAt,
                        preview: version.excerpt ?? "",
                        projectId: version.note.project.id,
                        noteId: version.note.id)
    }

    private func makeExportJob(from job: CDExportJob) -> ExportJob {
        ExportJob(id: job.id,
                  projectId: job.projectId,
                  versionId: job.versionId,
                  status: ExportJob.Status(rawValue: job.status) ?? .queued,
                  createdAt: job.createdAt)
    }

    private func makeBackupRecord(from record: CDBackupRecord) -> BackupRecord {
        BackupRecord(id: record.id,
                     startedAt: record.startedAt,
                     completedAt: record.completedAt,
                     status: BackupRecord.Status(rawValue: record.status) ?? .success,
                     artifactPath: record.artifactPath)
    }

    private func saveIfNeeded() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
            logger.error("Failed to save context: \(error.localizedDescription)")
        }
    }

    private func seedIfNeeded() {
        let request: NSFetchRequest<CDProject> = CDProject.fetchRequest()
        request.fetchLimit = 1
        let existing = (try? context.count(for: request)) ?? 0
        guard existing == 0 else { return }

        let project = CDProject(context: context)
        project.id = UUID()
        project.name = "샘플 프로젝트"
        project.noteCount = 0
        project.lastIndexedAt = Date().addingTimeInterval(-3_600)

        let onboarding = CDNote(context: context)
        let now = Date().addingTimeInterval(-5_400)
        onboarding.id = UUID()
        onboarding.title = "온보딩 노트"
        onboarding.content = "Chronicae에 오신 것을 환영합니다! 여기에 첫 번째 노트를 작성해 보세요."
        onboarding.excerpt = makeExcerpt(from: onboarding.content)
        onboarding.tags = encodeTags(["welcome", "guide"])
        onboarding.createdAt = now
        onboarding.updatedAt = now
        onboarding.version = 1
        onboarding.project = project
        appendVersion(for: onboarding)
        updateNoteCount(for: project)
        project.lastIndexedAt = now

        let backup = CDBackupRecord(context: context)
        backup.id = UUID()
        backup.startedAt = Date().addingTimeInterval(-86_400)
        backup.completedAt = Date().addingTimeInterval(-86_200)
        backup.status = BackupRecord.Status.success.rawValue
        backup.artifactPath = "backups/chronicae-sample.zip"

        saveIfNeeded()
        activeProjectId = project.id
    }
}

extension CDProject {
    @nonobjc static func fetchRequest() -> NSFetchRequest<CDProject> {
        NSFetchRequest<CDProject>(entityName: "CDProject")
    }
}

extension CDNote {
    @nonobjc static func fetchRequest() -> NSFetchRequest<CDNote> {
        NSFetchRequest<CDNote>(entityName: "CDNote")
    }
}

extension CDNoteVersion {
    @nonobjc static func fetchRequest() -> NSFetchRequest<CDNoteVersion> {
        NSFetchRequest<CDNoteVersion>(entityName: "CDNoteVersion")
    }
}

extension CDBackupRecord {
    @nonobjc static func fetchRequest() -> NSFetchRequest<CDBackupRecord> {
        NSFetchRequest<CDBackupRecord>(entityName: "CDBackupRecord")
    }
}

extension CDExportJob {
    @nonobjc static func fetchRequest() -> NSFetchRequest<CDExportJob> {
        NSFetchRequest<CDExportJob>(entityName: "CDExportJob")
    }
}
