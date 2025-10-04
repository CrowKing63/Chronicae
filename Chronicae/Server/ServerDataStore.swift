import Foundation
import CoreData
import OSLog

@MainActor
final class ServerDataStore {
    static let shared = ServerDataStore(persistentStore: .shared)

    struct NoteListResult {
        let items: [NoteSummary]
        let nextCursor: String?
    }

    enum SearchMode: String, Codable, Sendable {
        case keyword
        case semantic
    }

    struct SearchResult: Codable, Sendable {
        let noteId: UUID
        let projectId: UUID
        let title: String
        let snippet: String
        let score: Double
    }

    struct AIQueryOptions: Codable, Sendable {
        let temperature: Double?
        let maxTokens: Int?
    }

    struct IndexJob: Identifiable, Codable, Sendable {
        enum Status: String, Codable, Sendable {
            case queued
            case inProgress
            case completed
        }

        let id: UUID
        let projectId: UUID?
        var status: Status
        let startedAt: Date
        var finishedAt: Date?
    }

    struct AIMode: Codable, Sendable {
        let id: String
        let name: String
        let description: String
    }

    struct AISession: Identifiable, Codable, Sendable {
        enum Status: String, Codable, Sendable {
            case processing
            case completed
        }

        struct Message: Codable, Sendable {
            enum Role: String, Codable, Sendable {
                case user
                case assistant
            }

            let id: UUID
            let role: Role
            let content: String
            let createdAt: Date
        }

        let id: UUID
        let projectId: UUID?
        let mode: String
        let createdAt: Date
        var updatedAt: Date
        var status: Status
        var messages: [Message]
    }

    struct ExportJob: Identifiable, Codable, Sendable {
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

    struct BackupRecord: Identifiable, Codable, Sendable {
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

    struct VersionDetail: Codable, Sendable {
        let snapshot: VersionSnapshot
        let content: String
    }

    private let persistentStore: ServerPersistentStore
    private let context: NSManagedObjectContext
    private let logger = Logger(subsystem: "com.chronicae.app", category: "ServerDataStore")
    private let defaults: UserDefaults
    private let activeProjectKey: String
    private let eventEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
    private var indexJobs: [IndexJob] = []
    private var aiSessions: [UUID: AISession] = [:]
    private static let cursorDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    init(persistentStore: ServerPersistentStore,
         defaults: UserDefaults = .standard,
         activeProjectKey: String = "com.chronicae.server.activeProjectID",
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

    func listProjects(includeStats: Bool = false) -> (items: [ProjectSummary], active: UUID?) {
        let request: NSFetchRequest<CDProject> = CDProject.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let projects = (try? context.fetch(request)) ?? []
        let summaries = projects.map { project in
            let stats = includeStats ? makeProjectStats(from: project) : nil
            return makeProjectSummary(from: project, stats: stats)
        }
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
        let summary = makeProjectSummary(from: project)
        publishEvent(type: .projectSwitched, payload: summary)
        return summary
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
        publishEvent(type: .projectReset, payload: summary)
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
        publishEvent(type: .projectDeleted, payload: summary)
    }

    func fetchProjectSummary(id: UUID, includeStats: Bool = false) -> ProjectSummary? {
        guard let project = fetchProject(id: id) else { return nil }
        let stats = includeStats ? makeProjectStats(from: project) : nil
        return makeProjectSummary(from: project, stats: stats)
    }

    func updateProject(id: UUID, name: String, includeStats: Bool = false) -> ProjectSummary? {
        guard let project = fetchProject(id: id) else { return nil }
        project.name = name
        saveIfNeeded()
        let stats = includeStats ? makeProjectStats(from: project) : nil
        return makeProjectSummary(from: project, stats: stats)
    }

    // MARK: - Notes

    func listNotes(projectId: UUID,
                   cursor: String? = nil,
                   limit: Int = 50,
                   search: String? = nil) -> NoteListResult? {
        guard fetchProject(id: projectId) != nil else { return nil }

        let request: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        var predicates: [NSPredicate] = [NSPredicate(format: "project.id == %@", projectId as CVarArg)]

        if let term = search?.trimmingCharacters(in: .whitespacesAndNewlines), !term.isEmpty {
            let searchPredicates = [
                NSPredicate(format: "title CONTAINS[cd] %@", term),
                NSPredicate(format: "content CONTAINS[cd] %@", term),
                NSPredicate(format: "excerpt CONTAINS[cd] %@", term),
                NSPredicate(format: "tags CONTAINS[cd] %@", term)
            ]
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: searchPredicates))
        }

        if let cursor, let decoded = decodeCursor(cursor) {
            let paginationPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "updatedAt < %@", decoded.updatedAt as NSDate),
                NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "updatedAt == %@", decoded.updatedAt as NSDate),
                    NSPredicate(format: "createdAt < %@", decoded.createdAt as NSDate)
                ])
            ])
            predicates.append(paginationPredicate)
            predicates.append(NSPredicate(format: "NOT (id == %@)", decoded.id as CVarArg))
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [
            NSSortDescriptor(key: "updatedAt", ascending: false),
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]

        let boundedLimit = max(1, min(limit, 200))
        request.fetchLimit = boundedLimit + 1

        let notes = (try? context.fetch(request)) ?? []
        let paged = Array(notes.prefix(boundedLimit))
        let items = paged.map(makeNoteSummary)

        let nextCursor: String?
        if notes.count > boundedLimit, let last = paged.last {
            nextCursor = encodeCursor(updatedAt: last.updatedAt,
                                      createdAt: last.createdAt,
                                      id: last.id)
        } else {
            nextCursor = nil
        }

        return NoteListResult(items: items, nextCursor: nextCursor)
    }

    func fetchNote(projectId: UUID, noteId: UUID) -> NoteSummary? {
        guard let note = fetchNoteEntity(projectId: projectId, noteId: noteId) else { return nil }
        return makeNoteSummary(from: note)
    }

    enum NoteUpdateMode {
        case full
        case partial
    }

    enum NoteUpdateResult {
        case success(NoteSummary)
        case conflict(NoteSummary)
        case invalidPayload
        case notFound
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
        publishEvent(type: .noteCreated, payload: summary)
        return summary
    }

    func updateNote(projectId: UUID,
                    noteId: UUID,
                    title: String?,
                    content: String?,
                    tags: [String]?,
                    mode: NoteUpdateMode,
                    lastKnownVersion: Int?) -> NoteUpdateResult {
        guard let note = fetchNoteEntity(projectId: projectId, noteId: noteId) else {
            return .notFound
        }

        if let lastKnownVersion, Int(note.version) != lastKnownVersion {
            return .conflict(makeNoteSummary(from: note))
        }

        let resolvedTitle: String
        let resolvedContent: String
        let resolvedTags: [String]

        switch mode {
        case .full:
            guard let title, let content, let tags else {
                return .invalidPayload
            }
            resolvedTitle = title
            resolvedContent = content
            resolvedTags = tags
        case .partial:
            guard title != nil || content != nil || tags != nil else {
                return .invalidPayload
            }
            resolvedTitle = title ?? note.title
            resolvedContent = content ?? note.content
            resolvedTags = tags ?? decodeTags(note.tags)
        }

        var hasChanges = false

        if note.title != resolvedTitle {
            note.title = resolvedTitle
            hasChanges = true
        }

        if note.content != resolvedContent {
            note.content = resolvedContent
            note.excerpt = makeExcerpt(from: resolvedContent)
            hasChanges = true
        } else if mode == .full {
            note.excerpt = makeExcerpt(from: resolvedContent)
        }

        let encodedTags = encodeTags(resolvedTags)
        if note.tags != encodedTags {
            note.tags = encodedTags
            hasChanges = true
        }

        if hasChanges {
            note.updatedAt = Date()
            note.version += 1
            _ = appendVersion(for: note)
            note.project.lastIndexedAt = note.updatedAt
            saveIfNeeded()
            let summary = makeNoteSummary(from: note)
            publishEvent(type: .noteUpdated, payload: summary)
            return .success(summary)
        } else {
            saveIfNeeded()
            let summary = makeNoteSummary(from: note)
            return .success(summary)
        }
    }

    func searchNotes(projectId: UUID?, query: String, mode: SearchMode = .keyword, limit: Int = 20) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let request: NSFetchRequest<CDNote> = CDNote.fetchRequest()
        var predicates: [NSPredicate] = []
        if let projectId {
            predicates.append(NSPredicate(format: "project.id == %@", projectId as CVarArg))
        }
        let keywordPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "title CONTAINS[cd] %@", trimmed),
            NSPredicate(format: "content CONTAINS[cd] %@", trimmed),
            NSPredicate(format: "excerpt CONTAINS[cd] %@", trimmed),
            NSPredicate(format: "tags CONTAINS[cd] %@", trimmed)
        ])
        predicates.append(keywordPredicate)
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        let boundedLimit = max(1, min(limit, 50))
        request.fetchLimit = boundedLimit
        let matches = (try? context.fetch(request)) ?? []

        return matches.map { note in
            let snippet = makeSearchSnippet(from: note, query: trimmed)
            let score = computeSearchScore(for: note, query: trimmed, mode: mode)
            return SearchResult(noteId: note.id,
                                projectId: note.project.id,
                                title: note.title,
                                snippet: snippet,
                                score: score)
        }
    }

    func rebuildIndex(projectId: UUID?) -> IndexJob {
        var job = IndexJob(id: UUID(),
                           projectId: projectId,
                           status: .queued,
                           startedAt: Date(),
                           finishedAt: nil)
        indexJobs.insert(job, at: 0)
        if indexJobs.count > 20 {
            indexJobs = Array(indexJobs.prefix(20))
        }
        job.status = .completed
        job.finishedAt = Date()
        indexJobs[0] = job
        publishEvent(type: .indexJobCompleted, payload: job)
        return job
    }

    func listIndexJobs() -> [IndexJob] {
        indexJobs
    }

    func createAISession(projectId: UUID?, mode: String, query: String, options: AIQueryOptions?) -> AISession {
        let now = Date()
        let sessionId = UUID()
        let userMessage = AISession.Message(id: UUID(), role: .user, content: query, createdAt: now)
        let assistantContent = synthesizeAIResponse(query: query, mode: mode, options: options)
        let assistantMessage = AISession.Message(id: UUID(), role: .assistant, content: assistantContent, createdAt: now)
        var session = AISession(id: sessionId,
                                projectId: projectId,
                                mode: mode,
                                createdAt: now,
                                updatedAt: now,
                                status: .completed,
                                messages: [userMessage, assistantMessage])
        aiSessions[sessionId] = session
        publishEvent(type: .aiSessionCompleted, payload: session)
        return session
    }

    func fetchAISession(id: UUID) -> AISession? {
        aiSessions[id]
    }

    func deleteAISession(id: UUID) {
        aiSessions.removeValue(forKey: id)
    }

    func availableAIModes() -> [AIMode] {
        [
            AIMode(id: "local_rag", name: "로컬 RAG", description: "내장된 노트 지식을 기반으로 응답"),
            AIMode(id: "summary", name: "요약", description: "요약 전용 모드")
        ]
    }

    func deleteNote(projectId: UUID, noteId: UUID, purgeVersions: Bool = false) {
        guard let note = fetchNoteEntity(projectId: projectId, noteId: noteId) else { return }
        if purgeVersions {
            for version in Array(note.versions) {
                context.delete(version)
            }
        }
        let project = note.project
        let payload = NoteIdentifierPayload(id: note.id, projectId: project.id)
        context.delete(note)
        updateNoteCount(for: project)
        project.lastIndexedAt = Date()
        saveIfNeeded()
        publishEvent(type: .noteDeleted, payload: payload)
    }

    // MARK: - Versions & backups

    func listVersions(noteId: UUID, limit: Int = 50) -> [VersionSnapshot]? {
        guard fetchNoteEntity(projectId: nil, noteId: noteId) != nil else { return nil }
        let request: NSFetchRequest<CDNoteVersion> = CDNoteVersion.fetchRequest()
        request.predicate = NSPredicate(format: "note.id == %@", noteId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = limit
        let versions = (try? context.fetch(request)) ?? []
        return versions.map(makeVersionSnapshot)
    }

    func fetchVersionDetail(noteId: UUID, versionId: UUID) -> VersionDetail? {
        guard let version = fetchNoteVersion(versionId: versionId, noteId: noteId) else { return nil }
        let snapshot = makeVersionSnapshot(from: version)
        return VersionDetail(snapshot: snapshot, content: version.content)
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
        publishEvent(type: .noteVersionRestored, payload: snapshot)
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
        publishEvent(type: .noteExportQueued, payload: payload)
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
        publishEvent(type: .noteVersionExportQueued, payload: payload)
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
        publishEvent(type: .backupCompleted, payload: payload)
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

    private func encodeCursor(updatedAt: Date, createdAt: Date, id: UUID) -> String {
        let formatter = Self.cursorDateFormatter
        let raw = [
            formatter.string(from: updatedAt),
            formatter.string(from: createdAt),
            id.uuidString
        ].joined(separator: "|")
        return Data(raw.utf8).base64EncodedString()
    }

    private func decodeCursor(_ value: String) -> (updatedAt: Date, createdAt: Date, id: UUID)? {
        guard let data = Data(base64Encoded: value),
              let raw = String(data: data, encoding: .utf8) else { return nil }
        let parts = raw.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        let formatter = Self.cursorDateFormatter
        guard let updated = formatter.date(from: String(parts[0])),
              let created = formatter.date(from: String(parts[1])),
              let id = UUID(uuidString: String(parts[2])) else { return nil }
        return (updated, created, id)
    }

    private func makeSearchSnippet(from note: CDNote, query: String, limit: Int = 160) -> String {
        let lowercasedQuery = query.lowercased()
        let source = note.content.isEmpty ? (note.excerpt ?? "") : note.content
        let lower = source.lowercased()
        if let range = lower.range(of: lowercasedQuery) {
            let startIndex = source.index(range.lowerBound, offsetBy: -min(30, source.distance(from: source.startIndex, to: range.lowerBound)), limitedBy: source.startIndex) ?? source.startIndex
            let endIndex = source.index(range.upperBound, offsetBy: limit, limitedBy: source.endIndex) ?? source.endIndex
            let snippet = source[startIndex..<endIndex]
            return snippet.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return makeExcerpt(from: source, limit: limit)
    }

    private func computeSearchScore(for note: CDNote, query: String, mode: SearchMode) -> Double {
        let lowerQuery = query.lowercased()
        var score = 0.0
        if note.title.lowercased().contains(lowerQuery) {
            score += 0.6
        }
        if note.content.lowercased().contains(lowerQuery) {
            score += 0.3
        }
        if decodeTags(note.tags).contains(where: { $0.lowercased().contains(lowerQuery) }) {
            score += 0.2
        }
        if mode == .semantic {
            score += 0.1
        }
        return min(score, 1.0)
    }

    private func synthesizeAIResponse(query: String, mode: String, options: AIQueryOptions?) -> String {
        var components: [String] = []
        components.append("질문: \(query)")
        switch mode.lowercased() {
        case "summary":
            components.append("응답: 제공된 노트를 기반으로 핵심만 요약했습니다.")
        default:
            components.append("응답: 로컬 검색 결과를 참고해 답변을 생성했습니다.")
        }
        if let temperature = options?.temperature {
            components.append("temperature=\(String(format: "%.2f", temperature))")
        }
        if let maxTokens = options?.maxTokens {
            components.append("maxTokens=\(maxTokens)")
        }
        return components.joined(separator: "\n")
    }

    private func makeProjectSummary(from project: CDProject, stats: ProjectSummary.Stats? = nil) -> ProjectSummary {
        ProjectSummary(id: project.id,
                       name: project.name,
                       noteCount: Int(project.noteCount),
                       lastIndexedAt: project.lastIndexedAt,
                       stats: stats)
    }

    private func makeProjectStats(from project: CDProject) -> ProjectSummary.Stats {
        var versionCount = 0
        var latestUpdatedAt: Date?
        var uniqueTags = Set<String>()
        var totalNoteLength = 0
        let notes = project.notes

        for note in notes {
            versionCount += note.versions.count
            if let currentLatest = latestUpdatedAt {
                if note.updatedAt > currentLatest {
                    latestUpdatedAt = note.updatedAt
                }
            } else {
                latestUpdatedAt = note.updatedAt
            }
            decodeTags(note.tags).forEach { uniqueTags.insert($0) }
            totalNoteLength += note.content.count
        }

        let noteCount = notes.count
        let averageLength = noteCount > 0 ? Double(totalNoteLength) / Double(noteCount) : 0

        return ProjectSummary.Stats(versionCount: versionCount,
                                    latestNoteUpdatedAt: latestUpdatedAt,
                                    uniqueTagCount: uniqueTags.count,
                                    averageNoteLength: averageLength)
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
                        noteId: version.note.id,
                        version: Int(version.version))
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

    private func publishEvent<T: Encodable>(type: AppEventType, payload: T) {
        do {
            let data = try eventEncoder.encode(payload)
            Task { await ServerEventCenter.shared.publish(type: type, payloadJSON: data) }
        } catch {
            logger.error("Failed to encode event \(type.rawValue): \(error.localizedDescription)")
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
