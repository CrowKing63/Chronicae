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

        guard let seededNoteId = store.listNotes(projectId: projectId)?.first?.id else {
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
        #expect(notesAfter?.isEmpty == true)
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

        guard let notes = store.listNotes(projectId: projectId), let note = notes.first else {
            Issue.record("Expected seeded note")
            return
        }

        let updated = store.updateNote(projectId: projectId,
                                       noteId: note.id,
                                       title: note.title,
                                       content: note.content + " 업데이트",
                                       tags: ["welcome"])
        #expect(updated?.version == note.version + 1)

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

        let created = store.createNote(projectId: projectId,
                                       title: "Spec",
                                       content: "Initial content",
                                       tags: ["spec"])
        #expect(created?.version == 1)

        let updated = store.updateNote(projectId: projectId,
                                       noteId: created!.id,
                                       title: "Spec",
                                       content: "Initial content updated",
                                       tags: ["spec", "v2"])
        #expect(updated?.version == 2)

        let versions = store.listVersions(noteId: created!.id)
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
        #expect(notes?.isEmpty == true)
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
