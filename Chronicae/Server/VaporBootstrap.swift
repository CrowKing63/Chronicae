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

        func noteConflictResponse(_ note: NoteSummary) throws -> Response {
            let payload = NoteConflictPayload(code: "note_conflict",
                                              message: "Note has been updated to version \(note.version). Refresh before retrying.",
                                              note: note)
            return try jsonResponse(payload, status: .conflict)
        }

        func parseIfMatchVersion(_ header: String?) -> Int? {
            guard let header else { return nil }
            let candidates = header.split(separator: ",")
            for candidate in candidates {
                var token = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                if token.hasPrefix("W/") {
                    token = String(token.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                token = token.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                if let value = Int(token) {
                    return value
                }
            }
            return nil
        }

        app.get("status") { _ in
            StatusResponse(status: "ok")
        }

        let api = app.grouped("api")
        let projects = api.grouped("projects")

        projects.get { req async throws -> Response in
            let includeStats = parseBooleanFlag(req.query[String.self, at: "includeStats"])
            let data = await MainActor.run { dataStore.listProjects(includeStats: includeStats) }
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

        project.get { req async throws -> Response in
            guard let projectId = extractProjectId(from: req) else {
                return try errorResponse(status: .badRequest, code: "invalid_project_id", message: "Invalid project identifier")
            }
            let includeStats = parseBooleanFlag(req.query[String.self, at: "includeStats"])
            guard let result = await MainActor.run({ dataStore.fetchProjectSummary(id: projectId, includeStats: includeStats) }) else {
                return try errorResponse(status: .notFound, code: "project_not_found", message: "Project not found")
            }
            return try jsonResponse(ProjectDetailPayload(project: result))
        }

        project.put { req async throws -> Response in
            guard let projectId = extractProjectId(from: req) else {
                return try errorResponse(status: .badRequest, code: "invalid_project_id", message: "Invalid project identifier")
            }
            let includeStats = parseBooleanFlag(req.query[String.self, at: "includeStats"])
            let payload = try req.content.decode(ProjectUpdatePayload.self)
            let trimmed = payload.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty else {
                return try errorResponse(status: .badRequest, code: "invalid_request", message: "Project name is required")
            }
            guard let updated = await MainActor.run({ dataStore.updateProject(id: projectId,
                                                                              name: trimmed,
                                                                              includeStats: includeStats) }) else {
                return try errorResponse(status: .notFound, code: "project_not_found", message: "Project not found")
            }
            let activeId = await MainActor.run { dataStore.listProjects().active }
            let responsePayload = ProjectResponsePayload(project: updated, activeProjectId: activeId)
            return try jsonResponse(responsePayload)
        }

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
            let limitValue = req.query[Int.self, at: "limit"] ?? 50
            let boundedLimit = max(1, min(limitValue, 200))
            let cursor = req.query[String.self, at: "cursor"]
            let searchTerm = req.query[String.self, at: "search"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            let sanitizedSearch = (searchTerm?.isEmpty == true) ? nil : searchTerm

            guard let result = await MainActor.run({
                dataStore.listNotes(projectId: projectId,
                                    cursor: cursor,
                                    limit: boundedLimit,
                                    search: sanitizedSearch)
            }) else {
                return try errorResponse(status: .notFound, code: "project_not_found", message: "Project not found")
            }
            return try jsonResponse(NoteListPayload(items: result.items, nextCursor: result.nextCursor))
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
            guard payload.title != nil, payload.content != nil, payload.tags != nil else {
                return try errorResponse(status: .badRequest, code: "invalid_request", message: "Missing fields for full update")
            }
            let headerVersion = parseIfMatchVersion(req.headers.first(name: .ifMatch))
            let lastKnownVersion = payload.lastKnownVersion ?? headerVersion
            let result = await MainActor.run {
                dataStore.updateNote(projectId: projectId,
                                     noteId: noteId,
                                     title: payload.title,
                                     content: payload.content,
                                     tags: payload.tags,
                                     mode: .full,
                                     lastKnownVersion: lastKnownVersion)
            }
            switch result {
            case .success(let note):
                return try jsonResponse(NoteResponsePayload(note: note))
            case .conflict(let current):
                return try noteConflictResponse(current)
            case .invalidPayload:
                return try errorResponse(status: .badRequest, code: "invalid_request", message: "Invalid note payload")
            case .notFound:
                return try errorResponse(status: .notFound, code: "note_not_found", message: "Note not found")
            }
        }

        note.patch { req async throws -> Response in
            guard
                let projectId = extractProjectId(from: req),
                let noteId = extractNoteId(from: req)
            else {
                return try errorResponse(status: .badRequest, code: "invalid_identifier", message: "Invalid identifier")
            }
            let payload = try req.content.decode(NoteUpdatePayload.self)
            if payload.title == nil, payload.content == nil, payload.tags == nil {
                return try errorResponse(status: .badRequest, code: "invalid_request", message: "No fields to update")
            }
            let headerVersion = parseIfMatchVersion(req.headers.first(name: .ifMatch))
            let lastKnownVersion = payload.lastKnownVersion ?? headerVersion
            let result = await MainActor.run {
                dataStore.updateNote(projectId: projectId,
                                     noteId: noteId,
                                     title: payload.title,
                                     content: payload.content,
                                     tags: payload.tags,
                                     mode: .partial,
                                     lastKnownVersion: lastKnownVersion)
            }
            switch result {
            case .success(let note):
                return try jsonResponse(NoteResponsePayload(note: note))
            case .conflict(let current):
                return try noteConflictResponse(current)
            case .invalidPayload:
                return try errorResponse(status: .badRequest, code: "invalid_request", message: "Invalid note payload")
            case .notFound:
                return try errorResponse(status: .notFound, code: "note_not_found", message: "Note not found")
            }
        }

        note.delete { req async throws -> Response in
            guard
                let projectId = extractProjectId(from: req),
                let noteId = extractNoteId(from: req)
            else {
                return try errorResponse(status: .badRequest, code: "invalid_identifier", message: "Invalid identifier")
            }
            let purgeVersions = parseBooleanFlag(req.query[String.self, at: "purgeVersions"])
            await MainActor.run {
                dataStore.deleteNote(projectId: projectId,
                                     noteId: noteId,
                                     purgeVersions: purgeVersions)
            }
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

        noteVersion.get { req async throws -> Response in
            guard let noteId = extractNoteId(from: req), let versionId = extractVersionId(from: req) else {
                return try errorResponse(status: .badRequest, code: "invalid_identifier", message: "Invalid identifier")
            }
            guard let detail = await MainActor.run({ dataStore.fetchVersionDetail(noteId: noteId, versionId: versionId) }) else {
                return try errorResponse(status: .notFound, code: "version_not_found", message: "Version not found")
            }
            return try jsonResponse(VersionDetailPayload(version: detail.snapshot, content: detail.content))
        }

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

        api.get("search") { req async throws -> Response in
            guard let rawQuery = req.query[String.self, at: "query"]?.trimmingCharacters(in: .whitespacesAndNewlines), !rawQuery.isEmpty else {
                return try errorResponse(status: .badRequest, code: "invalid_request", message: "Query parameter is required")
            }
            let projectId = req.query[String.self, at: "projectId"].flatMap(UUID.init)
            let modeValue = req.query[String.self, at: "mode"]?.lowercased() ?? "keyword"
            let mode = ServerDataStore.SearchMode(rawValue: modeValue) ?? .keyword
            let limit = min(max(req.query[Int.self, at: "limit"] ?? 20, 1), 100)
            let items = await MainActor.run {
                dataStore.searchNotes(projectId: projectId, query: rawQuery, mode: mode, limit: limit)
            }
            return try jsonResponse(SearchResponsePayload(query: rawQuery, mode: mode.rawValue, items: items))
        }

        api.post("index:rebuild") { req async throws -> Response in
            let payload = try req.content.decode(IndexRebuildRequestPayload?.self)
            let job = await MainActor.run { dataStore.rebuildIndex(projectId: payload?.projectId) }
            var response = try jsonResponse(IndexRebuildResponsePayload(job: job), status: .accepted)
            response.headers.replaceOrAdd(name: .location, value: "/api/index/jobs")
            return response
        }

        api.get("index", "jobs") { _ async throws -> Response in
            let jobs = await MainActor.run { dataStore.listIndexJobs() }
            return try jsonResponse(IndexJobListPayload(items: jobs))
        }

        let ai = api.grouped("ai")

        ai.post("query") { req async throws -> Response in
            let payload = try req.content.decode(AIQueryRequestPayload.self)
            let options = ServerDataStore.AIQueryOptions(temperature: payload.options?.temperature,
                                                         maxTokens: payload.options?.maxTokens)
            let session = await MainActor.run {
                dataStore.createAISession(projectId: payload.projectId,
                                           mode: payload.mode,
                                           query: payload.query,
                                           options: options)
            }
            var response = try jsonResponse(AIQueryAcceptedPayload(sessionId: session.id,
                                                                   status: session.status,
                                                                   location: "/api/ai/sessions/\(session.id.uuidString)/stream"),
                                            status: .accepted)
            response.headers.replaceOrAdd(name: .location, value: "/api/ai/sessions/\(session.id.uuidString)/stream")
            return response
        }

        ai.get("modes") { _ async throws -> Response in
            let items = await MainActor.run { dataStore.availableAIModes() }
            return try jsonResponse(AIModeListPayload(items: items))
        }

        let aiSessions = ai.grouped("sessions")

        aiSessions.get(":sessionID") { req async throws -> Response in
            guard let sessionId = req.parameters.get("sessionID").flatMap(UUID.init) else {
                return try errorResponse(status: .badRequest, code: "invalid_session_id", message: "Invalid AI session identifier")
            }
            guard let session = await MainActor.run({ dataStore.fetchAISession(id: sessionId) }) else {
                return try errorResponse(status: .notFound, code: "session_not_found", message: "AI session not found")
            }
            return try jsonResponse(AISessionPayload(session: session))
        }

        aiSessions.delete(":sessionID") { req async throws -> Response in
            guard let sessionId = req.parameters.get("sessionID").flatMap(UUID.init) else {
                return try errorResponse(status: .badRequest, code: "invalid_session_id", message: "Invalid AI session identifier")
            }
            await MainActor.run { dataStore.deleteAISession(id: sessionId) }
            return Response(status: .noContent)
        }

        aiSessions.get(":sessionID", "stream") { req async throws -> Response in
            guard let sessionId = req.parameters.get("sessionID").flatMap(UUID.init) else {
                return try errorResponse(status: .badRequest, code: "invalid_session_id", message: "Invalid AI session identifier")
            }
            guard let session = await MainActor.run({ dataStore.fetchAISession(id: sessionId) }) else {
                return try errorResponse(status: .notFound, code: "session_not_found", message: "AI session not found")
            }
            let body = makeAIStreamBody(for: session)
            var headers = HTTPHeaders()
            headers.replaceOrAdd(name: .contentType, value: "text/event-stream")
            headers.replaceOrAdd(name: .cacheControl, value: "no-cache")
            return Response(status: .ok, headers: headers, body: .init(string: body))
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

private func parseBooleanFlag(_ value: String?) -> Bool {
    guard let value else { return false }
    switch value.lowercased() {
    case "1", "true", "yes", "on":
        return true
    default:
        return false
    }
}

private func extractNoteId(from req: Request) -> UUID? {
    guard let identifier = req.parameters.get("noteID") else { return nil }
    return UUID(uuidString: identifier)
}

private func extractVersionId(from req: Request) -> UUID? {
    guard let identifier = req.parameters.get("versionID") else { return nil }
    return UUID(uuidString: identifier)
}

private func makeAIStreamBody(for session: ServerDataStore.AISession) -> String {
    var lines: [String] = []
    for message in session.messages {
        lines.append("event: message_delta")
        let role = message.role.rawValue
        let content = message.content.replacingOccurrences(of: "\n", with: "\\n")
        lines.append("data: {\"role\": \"\(role)\", \"content\": \"\(content)\"}")
        lines.append("")
        if message.role == .assistant {
            lines.append("event: message_done")
            lines.append("data: {\"sessionId\": \"\(session.id.uuidString)\"}")
            lines.append("")
        }
    }
    lines.append("event: status")
    lines.append("data: {\"status\": \"\(session.status.rawValue)\"}")
    lines.append("")
    return lines.joined(separator: "\n")
}
#endif
