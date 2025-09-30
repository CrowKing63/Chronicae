#if canImport(Vapor)
import Vapor

enum VaporBootstrap {
    static func makeApplication(configuration: ServerConfiguration) throws -> Application {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        let app = Application(env)
        configure(app, configuration: configuration)
        return app
    }

    static func configure(_ app: Application, configuration: ServerConfiguration) {
        app.http.server.configuration.hostname = configuration.allowExternal ? "0.0.0.0" : "127.0.0.1"
        app.http.server.configuration.port = configuration.port

        registerRoutes(app)
    }

    static func registerRoutes(_ app: Application) {
        let dataStore = ServerDataStore.shared
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        func jsonResponse<T: Encodable>(_ payload: T, status: HTTPStatus = .ok) throws -> Response {
            let data = try encoder.encode(payload)
            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json")
            return Response(status: status, headers: headers, body: .init(data: data))
        }

        func errorResponse(status: HTTPStatus, code: String, message: String) throws -> Response {
            try jsonResponse(APIErrorPayload(code: code, message: message), status: status)
        }

        app.get("status") { _ in
            StatusResponse(status: "ok")
        }

        let api = app.grouped("api")
        let projects = api.grouped("projects")

        projects.get { _ async throws -> Response in
            let data = await MainActor.run { dataStore.listProjects() }
            let payload = ProjectListPayload(items: data.items, activeProjectId: data.active)
            return try jsonResponse(payload)
        }

        projects.post { req async throws -> Response in
            let create = try req.content.decode(CreateProjectPayload.self)
            let trimmed = create.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return try errorResponse(status: .badRequest, code: "invalid_request", message: "Project name is required")
            }
            let project = await MainActor.run { dataStore.createProject(name: trimmed) }
            let activeId = await MainActor.run { dataStore.listProjects().active }
            let payload = ProjectResponsePayload(project: project, activeProjectId: activeId)
            return try jsonResponse(payload)
        }

        let project = projects.grouped(":projectID")

        project.delete { req async throws -> Response in
            guard let identifier = req.parameters.get("projectID"),
                  let projectId = UUID(uuidString: identifier) else {
                return try errorResponse(status: .badRequest, code: "invalid_project_id", message: "Invalid project identifier")
            }
            await MainActor.run { dataStore.deleteProject(id: projectId) }
            return Response(status: .noContent)
        }

        project.post("switch") { req async throws -> Response in
            guard let projectId = extractProjectId(from: req) else {
                return try errorResponse(status: .badRequest, code: "invalid_project_id", message: "Invalid project identifier")
            }
            let project = await MainActor.run { dataStore.switchProject(id: projectId) }
            guard let project else {
                return try errorResponse(status: .notFound, code: "project_not_found", message: "Project not found")
            }
            let activeId = await MainActor.run { dataStore.listProjects().active }
            let payload = ProjectResponsePayload(project: project, activeProjectId: activeId)
            return try jsonResponse(payload)
        }

        project.post("reset") { req async throws -> Response in
            guard let projectId = extractProjectId(from: req) else {
                return try errorResponse(status: .badRequest, code: "invalid_project_id", message: "Invalid project identifier")
            }
            let project = await MainActor.run { dataStore.resetProject(id: projectId) }
            guard let project else {
                return try errorResponse(status: .notFound, code: "project_not_found", message: "Project not found")
            }
            let activeId = await MainActor.run { dataStore.listProjects().active }
            let payload = ProjectResponsePayload(project: project, activeProjectId: activeId)
            return try jsonResponse(payload)
        }

        project.post("export") { req async throws -> Response in
            guard let projectId = extractProjectId(from: req) else {
                return try errorResponse(status: .badRequest, code: "invalid_project_id", message: "Invalid project identifier")
            }
            let job = await MainActor.run { dataStore.exportProject(id: projectId) }
            guard let job else {
                return try errorResponse(status: .notFound, code: "project_not_found", message: "Project not found")
            }
            return try jsonResponse(job)
        }

        let versions = project.grouped("versions")

        versions.get { req async throws -> Response in
            return try errorResponse(status: .notFound, code: "unsupported", message: "Use notes endpoints")
        }

        // Notes
        let notes = project.grouped("notes")

        notes.get { req async throws -> Response in
            guard let projectId = extractProjectId(from: req) else {
                return try errorResponse(status: .badRequest, code: "invalid_project_id", message: "Invalid project identifier")
            }
            guard let items = await MainActor.run({ dataStore.listNotes(projectId: projectId) }) else {
                return try errorResponse(status: .notFound, code: "project_not_found", message: "Project not found")
            }
            return try jsonResponse(NoteListPayload(items: items))
        }

        notes.post { req async throws -> Response in
            guard let projectId = extractProjectId(from: req) else {
                return try errorResponse(status: .badRequest, code: "invalid_project_id", message: "Invalid project identifier")
            }
            let payload = try req.content.decode(NoteCreatePayload.self)
            guard let note = await MainActor.run({ dataStore.createNote(projectId: projectId,
                                                                        title: payload.title,
                                                                        content: payload.content,
                                                                        tags: payload.tags) }) else {
                return try errorResponse(status: .notFound, code: "project_not_found", message: "Project not found")
            }
            return try jsonResponse(NoteResponsePayload(note: note), status: .created)
        }

        let note = notes.grouped(":noteID")

        note.get { req async throws -> Response in
            guard
                let projectId = extractProjectId(from: req),
                let noteId = extractNoteId(from: req)
            else {
                return try errorResponse(status: .badRequest, code: "invalid_identifier", message: "Invalid identifier")
            }
            guard let note = await MainActor.run({ dataStore.fetchNote(projectId: projectId, noteId: noteId) }) else {
                return try errorResponse(status: .notFound, code: "note_not_found", message: "Note not found")
            }
            return try jsonResponse(NoteResponsePayload(note: note))
        }

        note.put { req async throws -> Response in
            guard
                let projectId = extractProjectId(from: req),
                let noteId = extractNoteId(from: req)
            else {
                return try errorResponse(status: .badRequest, code: "invalid_identifier", message: "Invalid identifier")
            }
            let payload = try req.content.decode(NoteUpdatePayload.self)
            guard let updated = await MainActor.run({ dataStore.updateNote(projectId: projectId,
                                                                           noteId: noteId,
                                                                           title: payload.title,
                                                                           content: payload.content,
                                                                           tags: payload.tags) }) else {
                return try errorResponse(status: .notFound, code: "note_not_found", message: "Note not found")
            }
            return try jsonResponse(NoteResponsePayload(note: updated))
        }

        note.patch { req async throws -> Response in
            guard
                let projectId = extractProjectId(from: req),
                let noteId = extractNoteId(from: req)
            else {
                return try errorResponse(status: .badRequest, code: "invalid_identifier", message: "Invalid identifier")
            }
            let payload = try req.content.decode(NoteUpdatePayload.self)
            guard let updated = await MainActor.run({ dataStore.updateNote(projectId: projectId,
                                                                           noteId: noteId,
                                                                           title: payload.title,
                                                                           content: payload.content,
                                                                           tags: payload.tags) }) else {
                return try errorResponse(status: .notFound, code: "note_not_found", message: "Note not found")
            }
            return try jsonResponse(NoteResponsePayload(note: updated))
        }

        note.delete { req async throws -> Response in
            guard
                let projectId = extractProjectId(from: req),
                let noteId = extractNoteId(from: req)
            else {
                return try errorResponse(status: .badRequest, code: "invalid_identifier", message: "Invalid identifier")
            }
            await MainActor.run { dataStore.deleteNote(projectId: projectId, noteId: noteId) }
            return Response(status: .noContent)
        }

        let noteExport = note.grouped("export")
        noteExport.post { req async throws -> Response in
            guard let noteId = extractNoteId(from: req) else {
                return try errorResponse(status: .badRequest, code: "invalid_note_id", message: "Invalid note identifier")
            }
            guard let job = await MainActor.run({ dataStore.exportNote(noteId: noteId) }) else {
                return try errorResponse(status: .notFound, code: "note_not_found", message: "Note not found")
            }
            return try jsonResponse(job)
        }

        let noteVersions = note.grouped("versions")

        noteVersions.get { req async throws -> Response in
            guard let noteId = extractNoteId(from: req) else {
                return try errorResponse(status: .badRequest, code: "invalid_note_id", message: "Invalid note identifier")
            }
            guard let versions = await MainActor.run({ dataStore.listVersions(noteId: noteId) }) else {
                return try errorResponse(status: .notFound, code: "note_not_found", message: "Note not found")
            }
            return try jsonResponse(VersionListPayload(items: versions))
        }

        let noteVersion = noteVersions.grouped(":versionID")

        noteVersion.post("restore") { req async throws -> Response in
            guard let noteId = extractNoteId(from: req), let versionId = extractVersionId(from: req) else {
                return try errorResponse(status: .badRequest, code: "invalid_identifier", message: "Invalid identifier")
            }
            guard let restored = await MainActor.run({ dataStore.restoreVersion(noteId: noteId, versionId: versionId) }) else {
                return try errorResponse(status: .notFound, code: "version_not_found", message: "Version not found")
            }
            return try jsonResponse(VersionRestorePayload(version: restored))
        }

        noteVersion.post("export") { req async throws -> Response in
            guard let noteId = extractNoteId(from: req), let versionId = extractVersionId(from: req) else {
                return try errorResponse(status: .badRequest, code: "invalid_identifier", message: "Invalid identifier")
            }
            guard let job = await MainActor.run({ dataStore.exportVersion(noteId: noteId, versionId: versionId) }) else {
                return try errorResponse(status: .notFound, code: "version_not_found", message: "Version not found")
            }
            return try jsonResponse(job)
        }

        let backup = api.grouped("backup")

        backup.post("run") { _ async throws -> Response in
            let record = await MainActor.run { dataStore.runBackup() }
            return try jsonResponse(record)
        }

        backup.get("history") { _ async throws -> Response in
            let history = await MainActor.run { dataStore.backupHistory() }
            return try jsonResponse(history)
        }

        app.get("web-app", "**") { req async throws -> Response in
            let components = req.parameters.getCatchall()
            let suffix = components.joined(separator: "/")
            let fullPath = suffix.isEmpty ? "/web-app" : "/web-app/\(suffix)"
            let httpResponse = VisionWebApp.response(for: fullPath)

            var headers = HTTPHeaders()
            for (key, value) in httpResponse.headers {
                headers.replaceOrAdd(name: HTTPHeaders.Name(key), value: value)
            }

            var buffer = ByteBufferAllocator().buffer(capacity: httpResponse.body.count)
            buffer.writeBytes(httpResponse.body)

            return Response(status: HTTPStatus(statusCode: httpResponse.statusCode),
                            headers: headers,
                            body: .init(buffer: buffer))
        }

        let events = api.grouped("events")
        events.get { req async throws -> Response in
            var headers = HTTPHeaders()
            headers.replaceOrAdd(name: .contentType, value: "text/event-stream")
            headers.replaceOrAdd(name: .cacheControl, value: "no-cache")
            headers.replaceOrAdd(name: .connection, value: "keep-alive")
            headers.replaceOrAdd(name: .accessControlAllowOrigin, value: "*")

            var response = Response(status: .ok, headers: headers)
            response.body = .init(stream: { writer in
                let completion = req.eventLoop.makePromise(of: Void.self)
                let id = await ServerEventCenter.shared.registerVapor(writer: writer, on: req.eventLoop) {
                    completion.succeed(())
                }
                completion.futureResult.whenComplete { _ in
                    Task { await ServerEventCenter.shared.removeVaporClient(id: id) }
                }
                return completion.futureResult
            })
            return response
        }
    }
}

private struct StatusResponse: Content {
    let status: String
}

private func extractProjectId(from req: Request) -> UUID? {
    guard let identifier = req.parameters.get("projectID") else { return nil }
    return UUID(uuidString: identifier)
}

private func extractNoteId(from req: Request) -> UUID? {
    guard let identifier = req.parameters.get("noteID") else { return nil }
    return UUID(uuidString: identifier)
}

private func extractVersionId(from req: Request) -> UUID? {
    guard let identifier = req.parameters.get("versionID") else { return nil }
    return UUID(uuidString: identifier)
}
#endif
