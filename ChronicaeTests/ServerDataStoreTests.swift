import Foundation
import Testing
@testable import Chronicae

@Suite("ServerDataStore")
struct ServerDataStoreTests {

    private func makeDefaults(suite suffix: String) -> (UserDefaults, String) {
        let suiteName = "com.chronicae.tests.\(suffix).\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Failed to create UserDefaults suite")
        }
        return (defaults, suiteName)
    }

    @Test @MainActor
    func createProjectPersists() async throws {
        let (defaults, suiteName) = makeDefaults(suite: "create")
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ServerDataStore(persistentStore: .makeInMemory(),
                                    defaults: defaults,
                                    activeProjectKey: "test.activeProject",
                                    seedOnFirstLaunch: false)

        let initial = store.listProjects()
        #expect(initial.items.isEmpty)

        let project = store.createProject(name: "Demo")
        let result = store.listProjects()

        #expect(result.items.count == 1)
        #expect(result.items.first?.id == project.id)
        #expect(result.active == project.id)
    }

    @Test @MainActor
    func switchProjectUpdatesActive() async throws {
        let (defaults, suiteName) = makeDefaults(suite: "switch")
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ServerDataStore(persistentStore: .makeInMemory(),
                                    defaults: defaults,
                                    activeProjectKey: "test.activeProject.switch",
                                    seedOnFirstLaunch: false)

        let first = store.createProject(name: "First")
        let second = store.createProject(name: "Second")

        let result = store.switchProject(id: second.id)
        #expect(result?.id == second.id)

        let state = store.listProjects()
        #expect(state.active == second.id)
        #expect(state.items.count == 2)
    }

    @Test @MainActor
    func resetProjectClearsVersions() async throws {
        let (defaults, suiteName) = makeDefaults(suite: "reset")
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ServerDataStore(persistentStore: .makeInMemory(),
                                    defaults: defaults,
                                    activeProjectKey: "test.activeProject.reset",
                                    seedOnFirstLaunch: true)

        let projects = store.listProjects()
        guard let projectId = projects.items.first?.id else {
            Issue.record("Expected seeded project")
            return
        }

        guard let seededNoteId = store.listNotes(projectId: projectId)?.items.first?.id else {
            Issue.record("Expected seeded note")
            return
        }

        let versionsBefore = store.listVersions(noteId: seededNoteId)
        #expect((versionsBefore?.isEmpty) == false)

        let updated = store.resetProject(id: projectId)
        #expect(updated?.noteCount == 0)

        let versionsAfter = store.listVersions(noteId: seededNoteId)
        #expect(versionsAfter?.isEmpty == true)
        let notesAfter = store.listNotes(projectId: projectId)
        #expect(notesAfter?.items.isEmpty == true)
    }

    @Test @MainActor
    func restoreVersionCreatesNewSnapshot() async throws {
        let (defaults, suiteName) = makeDefaults(suite: "restore")
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ServerDataStore(persistentStore: .makeInMemory(),
                                    defaults: defaults,
                                    activeProjectKey: "test.activeProject.restore",
                                    seedOnFirstLaunch: true)

        guard let projectId = store.listProjects().items.first?.id else {
            Issue.record("Expected seeded project")
            return
        }

        guard let notes = store.listNotes(projectId: projectId), let note = notes.items.first else {
            Issue.record("Expected seeded note")
            return
        }

        let updateResult = store.updateNote(projectId: projectId,
                                            noteId: note.id,
                                            title: note.title,
                                            content: note.content + " 업데이트",
                                            tags: ["welcome"],
                                            mode: .full,
                                            lastKnownVersion: note.version)
        guard case let .success(updatedNote) = updateResult else {
            Issue.record("Expected successful note update")
            return
        }
        #expect(updatedNote.version == note.version + 1)

        guard let snapshot = store.listVersions(noteId: note.id)?.first else {
            Issue.record("Expected snapshot after update")
            return
        }

        let restored = store.restoreVersion(noteId: note.id, versionId: snapshot.id)
        #expect(restored?.noteId == snapshot.noteId)
        #expect(restored?.timestamp >= snapshot.timestamp)
    }

    @Test @MainActor
    func createAndUpdateNoteManagesVersions() async throws {
        let (defaults, suiteName) = makeDefaults(suite: "notes")
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ServerDataStore(persistentStore: .makeInMemory(),
                                    defaults: defaults,
                                    activeProjectKey: "test.activeProject.notes",
                                    seedOnFirstLaunch: false)

        let projectId = store.createProject(name: "Docs").id

        guard let createdNote = store.createNote(projectId: projectId,
                                                 title: "Spec",
                                                 content: "Initial content",
                                                 tags: ["spec"]) else {
            Issue.record("Expected note creation")
            return
        }
        #expect(createdNote.version == 1)

        let updateResult = store.updateNote(projectId: projectId,
                                            noteId: createdNote.id,
                                            title: "Spec",
                                            content: "Initial content updated",
                                            tags: ["spec", "v2"],
                                            mode: .full,
                                            lastKnownVersion: createdNote.version)
        guard case let .success(updated) = updateResult else {
            Issue.record("Expected successful update")
            return
        }
        #expect(updated.version == 2)

        let versions = store.listVersions(noteId: createdNote.id)
        #expect((versions?.count ?? 0) >= 2)
    }

    @Test @MainActor
    func deleteNoteDecrementsCount() async throws {
        let (defaults, suiteName) = makeDefaults(suite: "deleteNote")
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ServerDataStore(persistentStore: .makeInMemory(),
                                    defaults: defaults,
                                    activeProjectKey: "test.activeProject.delete",
                                    seedOnFirstLaunch: false)

        let project = store.createProject(name: "Archive")
        guard let note = store.createNote(projectId: project.id,
                                          title: "Temp",
                                          content: "To be deleted",
                                          tags: []) else {
            Issue.record("Failed to create note")
            return
        }

        store.deleteNote(projectId: project.id, noteId: note.id)
        let refreshed = store.listProjects().items.first { $0.id == project.id }
        #expect(refreshed?.noteCount == 0)
        let notes = store.listNotes(projectId: project.id)
        #expect(notes?.items.isEmpty == true)
    }

    @Test @MainActor
    func listNotesSupportsPaginationAndCursor() async throws {
        let (defaults, suiteName) = makeDefaults(suite: "listNotesPagination")
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ServerDataStore(persistentStore: .makeInMemory(),
                                    defaults: defaults,
                                    activeProjectKey: "test.activeProject.pagination",
                                    seedOnFirstLaunch: false)

        let projectId = store.createProject(name: "Paginated").id
        for index in 0..<7 {
            _ = store.createNote(projectId: projectId,
                                 title: "Note \(index)",
                                 content: "Body #\(index)",
                                 tags: ["tag\(index % 2)"])
        }

        guard let firstPage = store.listNotes(projectId: projectId, limit: 3) else {
            Issue.record("Expected first page")
            return
        }
        #expect(firstPage.items.count == 3)
        #expect(firstPage.nextCursor != nil)

        guard let secondCursor = firstPage.nextCursor,
              let secondPage = store.listNotes(projectId: projectId,
                                              cursor: secondCursor,
                                              limit: 3) else {
            Issue.record("Expected second page")
            return
        }

        #expect(secondPage.items.count == 3)
        #expect(secondPage.nextCursor != nil)

        guard let thirdCursor = secondPage.nextCursor,
              let thirdPage = store.listNotes(projectId: projectId,
                                              cursor: thirdCursor,
                                              limit: 3) else {
            Issue.record("Expected third page")
            return
        }

        #expect(thirdPage.items.count == 1)
        #expect(thirdPage.nextCursor == nil)

        let combinedIds = firstPage.items.map(\.id)
            + secondPage.items.map(\.id)
            + thirdPage.items.map(\.id)
        #expect(Set(combinedIds).count == 7)
    }

    @Test @MainActor
    func listNotesAppliesSearchTerm() async throws {
        let (defaults, suiteName) = makeDefaults(suite: "listNotesSearch")
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ServerDataStore(persistentStore: .makeInMemory(),
                                    defaults: defaults,
                                    activeProjectKey: "test.activeProject.search",
                                    seedOnFirstLaunch: false)

        let projectId = store.createProject(name: "Searchable").id

        _ = store.createNote(projectId: projectId,
                             title: "Meeting Notes",
                             content: "Planning agenda",
                             tags: ["team"])
        _ = store.createNote(projectId: projectId,
                             title: "Spec Draft",
                             content: "Design considerations",
                             tags: ["Design", "spec"])
        _ = store.createNote(projectId: projectId,
                             title: "Changelog",
                             content: "Misc updates",
                             tags: ["log"])

        guard let result = store.listNotes(projectId: projectId, search: "spec") else {
            Issue.record("Expected search results")
            return
        }

        #expect(result.items.count == 1)
        #expect(result.items.first?.title == "Spec Draft")

        guard let tagResult = store.listNotes(projectId: projectId, search: "design") else {
            Issue.record("Expected tag search results")
            return
        }

        #expect(tagResult.items.count == 1)
        #expect(tagResult.items.first?.tags.contains { $0.lowercased() == "design" } == true)
    }

    @Test @MainActor
    func keywordSearchProducesSnippet() async throws {
        let (defaults, suiteName) = makeDefaults(suite: "searchSnippet")
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ServerDataStore(persistentStore: .makeInMemory(),
                                    defaults: defaults,
                                    activeProjectKey: "test.activeProject.searchSnippet",
                                    seedOnFirstLaunch: false)

        let projectId = store.createProject(name: "Docs").id
        _ = store.createNote(projectId: projectId,
                             title: "Searchable",
                             content: "이 문서는 검색 테스트를 위해 준비된 콘텐츠입니다.",
                             tags: ["search"])

        let results = store.searchNotes(projectId: projectId, query: "검색", mode: .keyword, limit: 10)
        #expect(results.isEmpty == false)
        #expect(results.first?.snippet.isEmpty == false)
    }

    @Test @MainActor
    func updateNoteDetectsVersionConflicts() async throws {
        let (defaults, suiteName) = makeDefaults(suite: "versionConflict")
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ServerDataStore(persistentStore: .makeInMemory(),
                                    defaults: defaults,
                                    activeProjectKey: "test.activeProject.conflict",
                                    seedOnFirstLaunch: false)

        let projectId = store.createProject(name: "Conflicts").id
        guard let note = store.createNote(projectId: projectId,
                                          title: "Original",
                                          content: "Body",
                                          tags: ["v1"]) else {
            Issue.record("Expected note creation")
            return
        }

        let firstUpdate = store.updateNote(projectId: projectId,
                                           noteId: note.id,
                                           title: "Original",
                                           content: "Body v2",
                                           tags: ["v2"],
                                           mode: .full,
                                           lastKnownVersion: note.version)
        guard case let .success(updatedNote) = firstUpdate else {
            Issue.record("Expected successful update")
            return
        }

        let conflictResult = store.updateNote(projectId: projectId,
                                              noteId: note.id,
                                              title: "Original",
                                              content: "Body v3",
                                              tags: ["v3"],
                                              mode: .full,
                                              lastKnownVersion: note.version)
        guard case let .conflict(current) = conflictResult else {
            Issue.record("Expected version conflict")
            return
        }

        #expect(current.version == updatedNote.version)
        #expect(current.content == updatedNote.content)
    }

    @Test @MainActor
    func patchNoteUpdatesSubset() async throws {
        let (defaults, suiteName) = makeDefaults(suite: "partialUpdate")
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ServerDataStore(persistentStore: .makeInMemory(),
                                    defaults: defaults,
                                    activeProjectKey: "test.activeProject.partial",
                                    seedOnFirstLaunch: false)

        let projectId = store.createProject(name: "Partial").id
        guard let created = store.createNote(projectId: projectId,
                                             title: "Draft",
                                             content: "Round 1",
                                             tags: ["alpha"]) else {
            Issue.record("Expected note creation")
            return
        }

        let patchResult = store.updateNote(projectId: projectId,
                                           noteId: created.id,
                                           title: nil,
                                           content: nil,
                                           tags: ["alpha", "beta"],
                                           mode: .partial,
                                           lastKnownVersion: created.version)
        guard case let .success(patched) = patchResult else {
            Issue.record("Expected successful partial update")
            return
        }

        #expect(patched.title == created.title)
        #expect(patched.content == created.content)
        #expect(Set(patched.tags) == Set(["alpha", "beta"]))

        let clearResult = store.updateNote(projectId: projectId,
                                           noteId: created.id,
                                           title: nil,
                                           content: "Round 2",
                                           tags: [],
                                           mode: .partial,
                                           lastKnownVersion: patched.version)
        guard case let .success(cleared) = clearResult else {
            Issue.record("Expected successful second partial update")
            return
        }

        #expect(cleared.tags.isEmpty)
        #expect(cleared.content == "Round 2")
        #expect(cleared.version == patched.version + 1)
    }

    @Test @MainActor
    func rebuildIndexCreatesJob() async throws {
        let (defaults, suiteName) = makeDefaults(suite: "indexJob")
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ServerDataStore(persistentStore: .makeInMemory(),
                                    defaults: defaults,
                                    activeProjectKey: "test.activeProject.index",
                                    seedOnFirstLaunch: false)

        let job = store.rebuildIndex(projectId: nil)
        #expect(job.status == .completed)
        #expect(store.listIndexJobs().isEmpty == false)
    }

    @Test @MainActor
    func createAISessionStoresMessages() async throws {
        let (defaults, suiteName) = makeDefaults(suite: "aiSession")
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ServerDataStore(persistentStore: .makeInMemory(),
                                    defaults: defaults,
                                    activeProjectKey: "test.activeProject.ai",
                                    seedOnFirstLaunch: false)

        let session = store.createAISession(projectId: nil,
                                            mode: "local_rag",
                                            query: "Chronicae가 무엇인가요?",
                                            options: ServerDataStore.AIQueryOptions(temperature: 0.2,
                                                                                   maxTokens: 256))
        #expect(session.messages.count >= 2)
        guard let fetched = store.fetchAISession(id: session.id) else {
            Issue.record("Expected stored AI session")
            return
        }
        #expect(fetched.id == session.id)
        store.deleteAISession(id: session.id)
        #expect(store.fetchAISession(id: session.id) == nil)
    }

    @Test @MainActor
    func exportProjectCreatesJob() async throws {
        let (defaults, suiteName) = makeDefaults(suite: "exportProject")
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ServerDataStore(persistentStore: .makeInMemory(),
                                    defaults: defaults,
                                    activeProjectKey: "test.activeProject.exportProject",
                                    seedOnFirstLaunch: false)

        let project = store.createProject(name: "Exportable")
        let job = store.exportProject(id: project.id)

        #expect(job?.projectId == project.id)
        #expect(job?.versionId == nil)
    }

    @Test @MainActor
    func runBackupPersistsHistory() async throws {
        let (defaults, suiteName) = makeDefaults(suite: "backup")
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ServerDataStore(persistentStore: .makeInMemory(),
                                    defaults: defaults,
                                    activeProjectKey: "test.activeProject.backup",
                                    seedOnFirstLaunch: false)

        _ = store.runBackup()
        let history = store.backupHistory()

        #expect(history.count == 1)
        #expect(history.first?.artifactPath?.contains("backups/") == true)
    }

}
