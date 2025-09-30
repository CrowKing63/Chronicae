import CoreData
import OSLog

final class ServerPersistentStore {
    static let shared = ServerPersistentStore()

    let container: NSPersistentContainer
    private let logger = Logger(subsystem: "com.chronicae.app", category: "ServerPersistence")

    var viewContext: NSManagedObjectContext { container.viewContext }

    private init(inMemory: Bool = false) {
        let model = Self.makeModel()
        container = NSPersistentContainer(name: "ChronicaeServer", managedObjectModel: model)

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { [weak self] description, error in
            if let error {
                self?.logger.fault("Failed to load persistent store: \(error.localizedDescription)")
            } else {
                self?.logger.info("Loaded persistent store at \(description.url?.absoluteString ?? "<memory>")")
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    static func makeInMemory() -> ServerPersistentStore {
        ServerPersistentStore(inMemory: true)
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // Project
        let project = NSEntityDescription()
        project.name = "CDProject"
        project.managedObjectClassName = NSStringFromClass(CDProject.self)

        let projectId = NSAttributeDescription()
        projectId.name = "id"
        projectId.attributeType = .UUIDAttributeType
        projectId.isOptional = false

        let projectName = NSAttributeDescription()
        projectName.name = "name"
        projectName.attributeType = .stringAttributeType
        projectName.isOptional = false

        let projectNoteCount = NSAttributeDescription()
        projectNoteCount.name = "noteCount"
        projectNoteCount.attributeType = .integer64AttributeType
        projectNoteCount.isOptional = false
        projectNoteCount.defaultValue = 0

        let projectLastIndexed = NSAttributeDescription()
        projectLastIndexed.name = "lastIndexedAt"
        projectLastIndexed.attributeType = .dateAttributeType
        projectLastIndexed.isOptional = true

        project.properties = [projectId, projectName, projectNoteCount, projectLastIndexed]

        // Note
        let note = NSEntityDescription()
        note.name = "CDNote"
        note.managedObjectClassName = NSStringFromClass(CDNote.self)

        let noteId = NSAttributeDescription()
        noteId.name = "id"
        noteId.attributeType = .UUIDAttributeType
        noteId.isOptional = false

        let noteTitle = NSAttributeDescription()
        noteTitle.name = "title"
        noteTitle.attributeType = .stringAttributeType
        noteTitle.isOptional = false

        let noteContent = NSAttributeDescription()
        noteContent.name = "content"
        noteContent.attributeType = .stringAttributeType
        noteContent.isOptional = false

        let noteExcerpt = NSAttributeDescription()
        noteExcerpt.name = "excerpt"
        noteExcerpt.attributeType = .stringAttributeType
        noteExcerpt.isOptional = true

        let noteTags = NSAttributeDescription()
        noteTags.name = "tags"
        noteTags.attributeType = .stringAttributeType
        noteTags.isOptional = true

        let noteCreatedAt = NSAttributeDescription()
        noteCreatedAt.name = "createdAt"
        noteCreatedAt.attributeType = .dateAttributeType
        noteCreatedAt.isOptional = false

        let noteUpdatedAt = NSAttributeDescription()
        noteUpdatedAt.name = "updatedAt"
        noteUpdatedAt.attributeType = .dateAttributeType
        noteUpdatedAt.isOptional = false

        let noteVersionNumber = NSAttributeDescription()
        noteVersionNumber.name = "version"
        noteVersionNumber.attributeType = .integer64AttributeType
        noteVersionNumber.isOptional = false
        noteVersionNumber.defaultValue = 1

        note.properties = [noteId, noteTitle, noteContent, noteExcerpt, noteTags, noteCreatedAt, noteUpdatedAt, noteVersionNumber]

        // Note Version
        let noteVersion = NSEntityDescription()
        noteVersion.name = "CDNoteVersion"
        noteVersion.managedObjectClassName = NSStringFromClass(CDNoteVersion.self)

        let noteVersionId = NSAttributeDescription()
        noteVersionId.name = "id"
        noteVersionId.attributeType = .UUIDAttributeType
        noteVersionId.isOptional = false

        let noteVersionTitle = NSAttributeDescription()
        noteVersionTitle.name = "title"
        noteVersionTitle.attributeType = .stringAttributeType
        noteVersionTitle.isOptional = false

        let noteVersionContent = NSAttributeDescription()
        noteVersionContent.name = "content"
        noteVersionContent.attributeType = .stringAttributeType
        noteVersionContent.isOptional = false

        let noteVersionExcerpt = NSAttributeDescription()
        noteVersionExcerpt.name = "excerpt"
        noteVersionExcerpt.attributeType = .stringAttributeType
        noteVersionExcerpt.isOptional = true

        let noteVersionCreatedAt = NSAttributeDescription()
        noteVersionCreatedAt.name = "createdAt"
        noteVersionCreatedAt.attributeType = .dateAttributeType
        noteVersionCreatedAt.isOptional = false

        let noteVersionNumberAttr = NSAttributeDescription()
        noteVersionNumberAttr.name = "version"
        noteVersionNumberAttr.attributeType = .integer64AttributeType
        noteVersionNumberAttr.isOptional = false

        noteVersion.properties = [noteVersionId, noteVersionTitle, noteVersionContent, noteVersionExcerpt, noteVersionCreatedAt, noteVersionNumberAttr]

        // Backup
        let backup = NSEntityDescription()
        backup.name = "CDBackupRecord"
        backup.managedObjectClassName = NSStringFromClass(CDBackupRecord.self)

        let backupId = NSAttributeDescription()
        backupId.name = "id"
        backupId.attributeType = .UUIDAttributeType
        backupId.isOptional = false

        let startedAt = NSAttributeDescription()
        startedAt.name = "startedAt"
        startedAt.attributeType = .dateAttributeType
        startedAt.isOptional = false

        let completedAt = NSAttributeDescription()
        completedAt.name = "completedAt"
        completedAt.attributeType = .dateAttributeType
        completedAt.isOptional = false

        let status = NSAttributeDescription()
        status.name = "status"
        status.attributeType = .stringAttributeType
        status.isOptional = false

        let artifactPath = NSAttributeDescription()
        artifactPath.name = "artifactPath"
        artifactPath.attributeType = .stringAttributeType
        artifactPath.isOptional = true

        backup.properties = [backupId, startedAt, completedAt, status, artifactPath]

        // Export Job
        let export = NSEntityDescription()
        export.name = "CDExportJob"
        export.managedObjectClassName = NSStringFromClass(CDExportJob.self)

        let exportId = NSAttributeDescription()
        exportId.name = "id"
        exportId.attributeType = .UUIDAttributeType
        exportId.isOptional = false

        let exportProjectId = NSAttributeDescription()
        exportProjectId.name = "projectId"
        exportProjectId.attributeType = .UUIDAttributeType
        exportProjectId.isOptional = false

        let exportVersionId = NSAttributeDescription()
        exportVersionId.name = "versionId"
        exportVersionId.attributeType = .UUIDAttributeType
        exportVersionId.isOptional = true

        let exportStatus = NSAttributeDescription()
        exportStatus.name = "status"
        exportStatus.attributeType = .stringAttributeType
        exportStatus.isOptional = false

        let exportCreatedAt = NSAttributeDescription()
        exportCreatedAt.name = "createdAt"
        exportCreatedAt.attributeType = .dateAttributeType
        exportCreatedAt.isOptional = false

        export.properties = [exportId, exportProjectId, exportVersionId, exportStatus, exportCreatedAt]

        // Relationships
        let projectNotes = NSRelationshipDescription()
        projectNotes.name = "notes"
        projectNotes.destinationEntity = note
        projectNotes.minCount = 0
        projectNotes.maxCount = 0
        projectNotes.deleteRule = .cascadeDeleteRule

        let noteProject = NSRelationshipDescription()
        noteProject.name = "project"
        noteProject.destinationEntity = project
        noteProject.minCount = 1
        noteProject.maxCount = 1
        noteProject.deleteRule = .nullifyDeleteRule

        projectNotes.inverseRelationship = noteProject
        noteProject.inverseRelationship = projectNotes

        project.properties.append(projectNotes)
        note.properties.append(noteProject)

        let noteVersionsRel = NSRelationshipDescription()
        noteVersionsRel.name = "versions"
        noteVersionsRel.destinationEntity = noteVersion
        noteVersionsRel.minCount = 0
        noteVersionsRel.maxCount = 0
        noteVersionsRel.deleteRule = .cascadeDeleteRule

        let versionNoteRel = NSRelationshipDescription()
        versionNoteRel.name = "note"
        versionNoteRel.destinationEntity = note
        versionNoteRel.minCount = 1
        versionNoteRel.maxCount = 1
        versionNoteRel.deleteRule = .nullifyDeleteRule

        noteVersionsRel.inverseRelationship = versionNoteRel
        versionNoteRel.inverseRelationship = noteVersionsRel

        note.properties.append(noteVersionsRel)
        noteVersion.properties.append(versionNoteRel)

        model.entities = [project, note, noteVersion, backup, export]
        return model
    }
}

@objc(CDProject)
final class CDProject: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var noteCount: Int64
    @NSManaged var lastIndexedAt: Date?
    @NSManaged var notes: Set<CDNote>
}

@objc(CDNote)
final class CDNote: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var content: String
    @NSManaged var excerpt: String?
    @NSManaged var tags: String?
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var version: Int64
    @NSManaged var project: CDProject
    @NSManaged var versions: Set<CDNoteVersion>
}

@objc(CDNoteVersion)
final class CDNoteVersion: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var content: String
    @NSManaged var excerpt: String?
    @NSManaged var createdAt: Date
    @NSManaged var version: Int64
    @NSManaged var note: CDNote
}

@objc(CDBackupRecord)
final class CDBackupRecord: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var startedAt: Date
    @NSManaged var completedAt: Date
    @NSManaged var status: String
    @NSManaged var artifactPath: String?
}

@objc(CDExportJob)
final class CDExportJob: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var projectId: UUID
    @NSManaged var versionId: UUID?
    @NSManaged var status: String
    @NSManaged var createdAt: Date
}
