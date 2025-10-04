import Foundation

@MainActor
struct APIRouter {
    private let dataStore: ServerDataStore
    private let configurationProvider: @MainActor () -> ServerConfiguration

    init(dataStore: ServerDataStore? = nil,
         configurationProvider: @escaping @MainActor () -> ServerConfiguration = { ServerConfiguration() }) {
        self.dataStore = dataStore ?? ServerDataStore.shared
        self.configurationProvider = configurationProvider
    }

    func response(for request: HTTPRequest) -> HTTPResponse? {
        if let failure = authorizationFailureIfNeeded(for: request) {
            return failure
        }
        guard request.path.hasPrefix("/api") else { return nil }

        let (pathOnly, queryItems) = splitPathAndQuery(request.path)
        let pathComponents = pathOnly.split(separator: "/").map(String.init)
        guard pathComponents.count >= 2 else {
            return httpError(status: 404, code: "not_found", message: "Unknown API route")
        }

        let resource = pathComponents.dropFirst()

        switch resource.first {
        case "projects":
            return handleProjectsRequest(request,
                                         queryItems: queryItems,
                                         components: Array(resource.dropFirst()))
        case "backup":
            return handleBackupRequest(request, components: Array(resource.dropFirst()))
        case "search":
            return handleSearchRequest(request, queryItems: queryItems)
        case "index:rebuild":
            return handleIndexRebuildRequest(request)
        case "index":
            return handleIndexRequest(request, components: Array(resource.dropFirst()))
        case "ai":
            return handleAIRequest(request, components: Array(resource.dropFirst()))
        default:
            return httpError(status: 404, code: "not_found", message: "Unknown API resource")
        }
    }

    private func handleProjectsRequest(_ request: HTTPRequest,
                                       queryItems: [String: String],
                                       components: [String]) -> HTTPResponse {
        if components.isEmpty {
            switch request.method {
            case "GET":
                let includeStats = boolValue(for: queryItems["includeStats"])
                let data = dataStore.listProjects(includeStats: includeStats)
                let payload = ProjectListPayload(items: data.items, activeProjectId: data.active)
                return .json(payload)
            case "POST":
                guard let create = request.decodeJSON(CreateProjectPayload.self), !create.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return httpError(status: 400, code: "invalid_request", message: "Project name is required")
                }
                let project = dataStore.createProject(name: create.name)
                let payload = ProjectResponsePayload(project: project, activeProjectId: dataStore.listProjects().active)
                return .json(payload)
            default:
                return methodNotAllowed(["GET", "POST"])
            }
        }

        guard let projectId = UUID(uuidString: components[0]) else {
            return httpError(status: 400, code: "invalid_project_id", message: "Invalid project identifier")
        }

        let includeStats = boolValue(for: queryItems["includeStats"])

        if components.count == 1 {
            switch request.method {
            case "GET":
                guard let project = dataStore.fetchProjectSummary(id: projectId, includeStats: includeStats) else {
                    return httpError(status: 404, code: "project_not_found", message: "Project not found")
                }
                return .json(ProjectDetailPayload(project: project))
            case "PUT":
                guard let payload = request.decodeJSON(ProjectUpdatePayload.self) else {
                    return httpError(status: 400, code: "invalid_request", message: "Invalid project payload")
                }
                let trimmedName = payload.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !trimmedName.isEmpty else {
                    return httpError(status: 400, code: "invalid_request", message: "Project name is required")
                }
                guard let project = dataStore.updateProject(id: projectId,
                                                            name: trimmedName,
                                                            includeStats: includeStats) else {
                    return httpError(status: 404, code: "project_not_found", message: "Project not found")
                }
                let responsePayload = ProjectResponsePayload(project: project,
                                                             activeProjectId: dataStore.listProjects().active)
                return .json(responsePayload)
            case "DELETE":
                dataStore.deleteProject(id: projectId)
                return HTTPResponse(statusCode: 204, reasonPhrase: "No Content", headers: [:], body: Data())
            default:
                return methodNotAllowed(["GET", "PUT", "DELETE"])
            }
        }

        let action = components[1]

        switch action {
        case "switch":
            guard request.method == "POST" else { return methodNotAllowed(["POST"]) }
            guard let project = dataStore.switchProject(id: projectId) else {
                return httpError(status: 404, code: "project_not_found", message: "Project not found")
            }
            let payload = ProjectResponsePayload(project: project, activeProjectId: dataStore.listProjects().active)
            return .json(payload)
        case "reset":
            guard request.method == "POST" else { return methodNotAllowed(["POST"]) }
            guard let project = dataStore.resetProject(id: projectId) else {
                return httpError(status: 404, code: "project_not_found", message: "Project not found")
            }
            let payload = ProjectResponsePayload(project: project, activeProjectId: dataStore.listProjects().active)
            return .json(payload)
        case "export":
            guard request.method == "POST" else { return methodNotAllowed(["POST"]) }
            guard let job = dataStore.exportProject(id: projectId) else {
                return httpError(status: 404, code: "project_not_found", message: "Project not found")
            }
            return .json(job)
        case "notes":
            return handleNotesRequest(request,
                                      queryItems: queryItems,
                                      projectId: projectId,
                                      components: Array(components.dropFirst(2)))
        default:
            return httpError(status: 404, code: "unknown_project_action", message: "Unknown project action")
        }
    }

    private func handleNotesRequest(_ request: HTTPRequest,
                                    queryItems: [String: String],
                                    projectId: UUID,
                                    components: [String]) -> HTTPResponse {
        if components.isEmpty {
            switch request.method {
            case "GET":
                let limit = intValue(for: queryItems["limit"], defaultValue: 50, min: 1, max: 200)
                let cursor = queryItems["cursor"]
                let searchTerm = queryItems["search"].flatMap { raw -> String? in
                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? nil : trimmed
                }

                guard let notes = dataStore.listNotes(projectId: projectId,
                                                      cursor: cursor,
                                                      limit: limit,
                                                      search: searchTerm) else {
                    return httpError(status: 404, code: "project_not_found", message: "Project not found")
                }
                return .json(NoteListPayload(items: notes.items, nextCursor: notes.nextCursor))
            case "POST":
                guard let payload = request.decodeJSON(NoteCreatePayload.self) else {
                    return httpError(status: 400, code: "invalid_request", message: "Invalid note payload")
                }
                guard let note = dataStore.createNote(projectId: projectId,
                                                      title: payload.title,
                                                      content: payload.content,
                                                      tags: payload.tags) else {
                    return httpError(status: 404, code: "project_not_found", message: "Project not found")
                }
                return .json(NoteResponsePayload(note: note))
            default:
                return methodNotAllowed(["GET", "POST"])
            }
        }

        guard let noteId = UUID(uuidString: components[0]) else {
            return httpError(status: 400, code: "invalid_note_id", message: "Invalid note identifier")
        }

        if components.count == 1 {
            switch request.method {
            case "GET":
                guard let note = dataStore.fetchNote(projectId: projectId, noteId: noteId) else {
                    return httpError(status: 404, code: "note_not_found", message: "Note not found")
                }
                return .json(NoteResponsePayload(note: note))
            case "PUT", "PATCH":
                guard let payload = request.decodeJSON(NoteUpdatePayload.self) else {
                    return httpError(status: 400, code: "invalid_request", message: "Invalid note payload")
                }

                let mode: ServerDataStore.NoteUpdateMode = request.method == "PATCH" ? .partial : .full
                if mode == .full {
                    guard payload.title != nil, payload.content != nil, payload.tags != nil else {
                        return httpError(status: 400, code: "invalid_request", message: "Missing fields for full update")
                    }
                } else {
                    if payload.title == nil, payload.content == nil, payload.tags == nil {
                        return httpError(status: 400, code: "invalid_request", message: "No fields to update")
                    }
                }

                let headerVersion = parseIfMatchVersion(from: request.headerValue(for: "If-Match"))
                let lastKnownVersion = payload.lastKnownVersion ?? headerVersion

                let result = dataStore.updateNote(projectId: projectId,
                                                  noteId: noteId,
                                                  title: payload.title,
                                                  content: payload.content,
                                                  tags: payload.tags,
                                                  mode: mode,
                                                  lastKnownVersion: lastKnownVersion)

                switch result {
                case .success(let note):
                    return .json(NoteResponsePayload(note: note))
                case .conflict(let current):
                    return noteConflictResponse(for: current)
                case .invalidPayload:
                    return httpError(status: 400, code: "invalid_request", message: "Invalid note payload")
                case .notFound:
                    return httpError(status: 404, code: "note_not_found", message: "Note not found")
                }
            case "DELETE":
                let purgeVersions = boolValue(for: queryItems["purgeVersions"])
                dataStore.deleteNote(projectId: projectId,
                                     noteId: noteId,
                                     purgeVersions: purgeVersions)
                return HTTPResponse(statusCode: 204, reasonPhrase: "No Content", headers: [:], body: Data())
            default:
                return methodNotAllowed(["GET", "PUT", "PATCH", "DELETE"])
            }
        }

        let action = components[1]

        switch action {
        case "versions":
            return handleNoteVersionsRequest(request,
                                             projectId: projectId,
                                             noteId: noteId,
                                             components: Array(components.dropFirst(2)))
        case "export":
            guard request.method == "POST" else { return methodNotAllowed(["POST"]) }
            guard let job = dataStore.exportNote(noteId: noteId) else {
                return httpError(status: 404, code: "note_not_found", message: "Note not found")
            }
            return .json(job)
        default:
            return httpError(status: 404, code: "unknown_note_action", message: "Unknown note action")
        }
    }

    private func handleNoteVersionsRequest(_ request: HTTPRequest,
                                           projectId: UUID,
                                           noteId: UUID,
                                           components: [String]) -> HTTPResponse {
        guard dataStore.fetchNote(projectId: projectId, noteId: noteId) != nil else {
            return httpError(status: 404, code: "note_not_found", message: "Note not found")
        }
        if components.isEmpty {
            guard request.method == "GET" else { return methodNotAllowed(["GET"]) }
            guard let versions = dataStore.listVersions(noteId: noteId) else {
                return httpError(status: 404, code: "note_not_found", message: "Note not found")
            }
            return .json(VersionListPayload(items: versions))
        }
        let identifierComponent = components[0]
        guard let parsed = parseIdentifierAndInlineAction(identifierComponent) else {
            return httpError(status: 400, code: "invalid_version_id", message: "Invalid version identifier")
        }
        let (versionId, inlineAction) = parsed

        let trailingComponents = Array(components.dropFirst())
        let meaningfulTrailingComponents = trailingComponents.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if inlineAction != nil && !meaningfulTrailingComponents.isEmpty {
            return httpError(status: 404, code: "unknown_version_action", message: "Unknown version action")
        }

        let trailingAction = meaningfulTrailingComponents.first?.lowercased()
        let action = inlineAction ?? trailingAction
        if meaningfulTrailingComponents.count > (inlineAction == nil && action != nil ? 1 : 0) {
            return httpError(status: 404, code: "unknown_version_action", message: "Unknown version action")
        }

        guard let action else {
            guard request.method == "GET" else { return methodNotAllowed(["GET"]) }
            guard let detail = dataStore.fetchVersionDetail(noteId: noteId, versionId: versionId) else {
                return httpError(status: 404, code: "version_not_found", message: "Version not found")
            }
            return .json(VersionDetailPayload(version: detail.snapshot, content: detail.content))
        }

        switch action {
        case "restore":
            guard request.method == "POST" else { return methodNotAllowed(["POST"]) }
            guard let version = dataStore.restoreVersion(noteId: noteId, versionId: versionId) else {
                return httpError(status: 404, code: "version_not_found", message: "Version not found")
            }
            return .json(VersionRestorePayload(version: version))
        case "export":
            guard request.method == "POST" else { return methodNotAllowed(["POST"]) }
            guard let job = dataStore.exportVersion(noteId: noteId, versionId: versionId) else {
                return httpError(status: 404, code: "version_not_found", message: "Version not found")
            }
            return .json(job)
        default:
            return httpError(status: 404, code: "unknown_version_action", message: "Unknown version action")
        }
    }

    private func handleBackupRequest(_ request: HTTPRequest, components: [String]) -> HTTPResponse {
        guard let action = components.first else {
            return methodNotAllowed(["POST"])
        }

        switch action {
        case "run":
            guard request.method == "POST" else { return methodNotAllowed(["POST"]) }
            let record = dataStore.runBackup()
            return .json(record)
        case "history":
            guard request.method == "GET" else { return methodNotAllowed(["GET"]) }
            return .json(dataStore.backupHistory())
        default:
            return httpError(status: 404, code: "unknown_backup_action", message: "Unknown backup action")
        }
    }

    private func httpError(status: Int, code: String, message: String) -> HTTPResponse {
        let payload = APIErrorPayload(code: code, message: message)
        var response = HTTPResponse.json(payload)
        response.statusCode = status
        response.reasonPhrase = reasonPhrase(for: status)
        return response
    }

    private func noteConflictResponse(for note: NoteSummary) -> HTTPResponse {
        let payload = NoteConflictPayload(code: "note_conflict",
                                          message: "Note has been updated to version \(note.version). Refresh before retrying.",
                                          note: note)
        var response = HTTPResponse.json(payload)
        response.statusCode = 409
        response.reasonPhrase = reasonPhrase(for: 409)
        return response
    }

    private func methodNotAllowed(_ allowed: [String]) -> HTTPResponse {
        let payload = APIErrorPayload(code: "method_not_allowed", message: "Method not allowed")
        var response = HTTPResponse.json(payload)
        response.statusCode = 405
        response.reasonPhrase = reasonPhrase(for: 405)
        response.headers["Allow"] = allowed.joined(separator: ", ")
        return response
    }

    private func splitPathAndQuery(_ path: String) -> (String, [String: String]) {
        guard let questionIndex = path.firstIndex(of: "?") else {
            return (path, [:])
        }
        let pathPart = String(path[..<questionIndex])
        let queryPart = String(path[path.index(after: questionIndex)...])
        return (pathPart, parseQuery(queryPart))
    }

    private func parseQuery(_ query: String) -> [String: String] {
        guard !query.isEmpty else { return [:] }
        var items: [String: String] = [:]
        for component in query.split(separator: "&") {
            let parts = component.split(separator: "=", maxSplits: 1).map(String.init)
            guard let rawKey = parts.first, !rawKey.isEmpty else { continue }
            let normalizedKey = rawKey.replacingOccurrences(of: "+", with: " ")
            let key = normalizedKey.removingPercentEncoding ?? normalizedKey
            let rawValue = parts.count > 1 ? parts[1] : ""
            let normalizedValue = rawValue.replacingOccurrences(of: "+", with: " ")
            let value = normalizedValue.removingPercentEncoding ?? normalizedValue
            items[key] = value
        }
        return items
    }

    private func parseIfMatchVersion(from header: String?) -> Int? {
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

    private func parseIdentifierAndInlineAction(_ component: String) -> (UUID, String?)? {
        let parts = component.split(separator: ":", maxSplits: 1).map(String.init)
        guard let idPart = parts.first, let uuid = UUID(uuidString: idPart) else {
            return nil
        }
        if parts.count == 2 {
            let action = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            return (uuid, action.isEmpty ? nil : action.lowercased())
        }
        return (uuid, nil)
    }

    private func handleSearchRequest(_ request: HTTPRequest, queryItems: [String: String]) -> HTTPResponse {
        guard request.method == "GET" else { return methodNotAllowed(["GET"]) }
        guard let rawQuery = queryItems["query"], !rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return httpError(status: 400, code: "invalid_request", message: "Query parameter is required")
        }
        let projectId = queryItems["projectId"].flatMap(UUID.init)
        let mode = ServerDataStore.SearchMode(rawValue: queryItems["mode"]?.lowercased() ?? "keyword") ?? .keyword
        let limit = intValue(for: queryItems["limit"], defaultValue: 20, min: 1, max: 100)
        let results = dataStore.searchNotes(projectId: projectId, query: rawQuery, mode: mode, limit: limit)
        let payload = SearchResponsePayload(query: rawQuery, mode: mode.rawValue, items: results)
        return .json(payload)
    }

    private func handleIndexRebuildRequest(_ request: HTTPRequest) -> HTTPResponse {
        guard request.method == "POST" else { return methodNotAllowed(["POST"]) }
        let payload = request.decodeJSON(IndexRebuildRequestPayload.self)
        let job = dataStore.rebuildIndex(projectId: payload?.projectId)
        var response = HTTPResponse.json(IndexRebuildResponsePayload(job: job))
        response.statusCode = 202
        response.reasonPhrase = reasonPhrase(for: 202)
        return response
    }

    private func handleIndexRequest(_ request: HTTPRequest, components: [String]) -> HTTPResponse {
        guard components.first == "jobs" else {
            return httpError(status: 404, code: "unknown_index_action", message: "Unknown index action")
        }
        guard request.method == "GET" else { return methodNotAllowed(["GET"]) }
        let jobs = dataStore.listIndexJobs()
        return .json(IndexJobListPayload(items: jobs))
    }

    private func handleAIRequest(_ request: HTTPRequest, components: [String]) -> HTTPResponse {
        guard let action = components.first else {
            return methodNotAllowed(["POST"])
        }

        switch action {
        case "query":
            guard request.method == "POST" else { return methodNotAllowed(["POST"]) }
            guard let payload = request.decodeJSON(AIQueryRequestPayload.self) else {
                return httpError(status: 400, code: "invalid_request", message: "Invalid AI query payload")
            }
            let options = ServerDataStore.AIQueryOptions(temperature: payload.options?.temperature,
                                                         maxTokens: payload.options?.maxTokens)
            let session = dataStore.createAISession(projectId: payload.projectId,
                                                    mode: payload.mode,
                                                    query: payload.query,
                                                    options: options)
            var response = HTTPResponse.json(AIQueryAcceptedPayload(sessionId: session.id,
                                                                     status: session.status,
                                                                     location: "/api/ai/sessions/\(session.id.uuidString)/stream"))
            response.statusCode = 202
            response.reasonPhrase = reasonPhrase(for: 202)
            response.headers["Location"] = "/api/ai/sessions/\(session.id.uuidString)/stream"
            return response
        case "sessions":
            return handleAISessionRequest(request, components: Array(components.dropFirst()))
        case "modes":
            guard request.method == "GET" else { return methodNotAllowed(["GET"]) }
            return .json(AIModeListPayload(items: dataStore.availableAIModes()))
        default:
            return httpError(status: 404, code: "unknown_ai_action", message: "Unknown AI action")
        }
    }

    private func handleAISessionRequest(_ request: HTTPRequest, components: [String]) -> HTTPResponse {
        guard let sessionIdString = components.first,
              let sessionId = UUID(uuidString: sessionIdString) else {
            return httpError(status: 400, code: "invalid_session_id", message: "Invalid AI session identifier")
        }

        if components.count == 1 {
            switch request.method {
            case "DELETE":
                dataStore.deleteAISession(id: sessionId)
                return HTTPResponse(statusCode: 204, reasonPhrase: "No Content", headers: [:], body: Data())
            case "GET":
                guard let session = dataStore.fetchAISession(id: sessionId) else {
                    return httpError(status: 404, code: "session_not_found", message: "AI session not found")
                }
                return .json(AISessionPayload(session: session))
            default:
                return methodNotAllowed(["GET", "DELETE"])
            }
        }

        let action = components[1]
        switch action {
        case "stream":
            guard request.method == "GET" else { return methodNotAllowed(["GET"]) }
            guard let session = dataStore.fetchAISession(id: sessionId) else {
                return httpError(status: 404, code: "session_not_found", message: "AI session not found")
            }
            let streamBody = makeAIStreamBody(for: session)
            var response = HTTPResponse(statusCode: 200,
                                        reasonPhrase: reasonPhrase(for: 200),
                                        headers: ["Content-Type": "text/event-stream"],
                                        body: Data(streamBody.utf8))
            response.headers["Cache-Control"] = "no-cache"
            return response
        default:
            return httpError(status: 404, code: "unknown_session_action", message: "Unknown AI session action")
        }
    }

    private func makeAIStreamBody(for session: ServerDataStore.AISession) -> String {
        var lines: [String] = []
        for message in session.messages {
            switch message.role {
            case .user:
                lines.append("event: message_delta")
                lines.append("data: {\"role\": \"user\", \"content\": \"\(message.content)\"}")
                lines.append("")
            case .assistant:
                lines.append("event: message_delta")
                lines.append("data: {\"role\": \"assistant\", \"content\": \"\(message.content)\"}")
                lines.append("")
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

    private func intValue(for value: String?, defaultValue: Int, min lowerBound: Int, max upperBound: Int) -> Int {
        guard let value, let parsed = Int(value) else { return defaultValue }
        return max(lowerBound, min(parsed, upperBound))
    }

    private func boolValue(for value: String?) -> Bool {
        guard let value else { return false }
        switch value.lowercased() {
        case "1", "true", "yes", "on":
            return true
        default:
            return false
        }
    }

    private func reasonPhrase(for statusCode: Int) -> String {
        switch statusCode {
        case 200: return "OK"
        case 201: return "Created"
        case 202: return "Accepted"
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 409: return "Conflict"
        case 500: return "Internal Server Error"
        default: return "OK"
        }
    }

    func authorizationFailureIfNeeded(for request: HTTPRequest) -> HTTPResponse? {
        guard requiresAuthorization(path: request.path) else { return nil }
        guard let token = normalizedToken() else { return nil }
        guard let header = request.headerValue(for: "Authorization"),
              isValidAuthorizationHeader(header, token: token) else {
            var response = httpError(status: 401, code: "unauthorized", message: "Authentication required")
            response.headers["WWW-Authenticate"] = "Bearer"
            return response
        }
        return nil
    }

    private func requiresAuthorization(path: String) -> Bool {
        if path == "/events" || path.hasPrefix("/events?") {
            return true
        }
        return path.hasPrefix("/api")
    }

    private func normalizedToken() -> String? {
        let token = configurationProvider().authToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let token, !token.isEmpty else { return nil }
        return token
    }

    private func isValidAuthorizationHeader(_ header: String, token: String) -> Bool {
        let components = header.split(separator: " ", maxSplits: 1).map(String.init)
        guard components.count == 2 else { return false }
        return components[0].caseInsensitiveCompare("Bearer") == .orderedSame && components[1] == token
    }
}

private extension HTTPRequest {
    func decodeJSON<T: Decodable>(_ type: T.Type) -> T? {
        guard !body.isEmpty else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: body)
    }
}
