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

        let pathComponents = request.path.split(separator: "/").map(String.init)
        guard pathComponents.count >= 2 else {
            return httpError(status: 404, code: "not_found", message: "Unknown API route")
        }

        let resource = pathComponents.dropFirst()

        switch resource.first {
        case "projects":
            return handleProjectsRequest(request, components: Array(resource.dropFirst()))
        case "backup":
            return handleBackupRequest(request, components: Array(resource.dropFirst()))
        default:
            return httpError(status: 404, code: "not_found", message: "Unknown API resource")
        }
    }

    private func handleProjectsRequest(_ request: HTTPRequest, components: [String]) -> HTTPResponse {
        if components.isEmpty {
            switch request.method {
            case "GET":
                let data = dataStore.listProjects()
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

        if components.count == 1 {
            switch request.method {
            case "DELETE":
                dataStore.deleteProject(id: projectId)
                return HTTPResponse(statusCode: 204, reasonPhrase: "No Content", headers: [:], body: Data())
            default:
                return methodNotAllowed(["DELETE"])
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
            return handleNotesRequest(request, projectId: projectId, components: Array(components.dropFirst(2)))
        default:
            return httpError(status: 404, code: "unknown_project_action", message: "Unknown project action")
        }
    }

    private func handleNotesRequest(_ request: HTTPRequest, projectId: UUID, components: [String]) -> HTTPResponse {
        if components.isEmpty {
            switch request.method {
            case "GET":
                guard let notes = dataStore.listNotes(projectId: projectId) else {
                    return httpError(status: 404, code: "project_not_found", message: "Project not found")
                }
                return .json(NoteListPayload(items: notes))
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
                guard let note = dataStore.updateNote(projectId: projectId,
                                                      noteId: noteId,
                                                      title: payload.title,
                                                      content: payload.content,
                                                      tags: payload.tags) else {
                    return httpError(status: 404, code: "note_not_found", message: "Note not found")
                }
                return .json(NoteResponsePayload(note: note))
            case "DELETE":
                dataStore.deleteNote(projectId: projectId, noteId: noteId)
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

        guard let versionId = UUID(uuidString: components[0]) else {
            return httpError(status: 400, code: "invalid_version_id", message: "Invalid version identifier")
        }

        guard components.count >= 2 else {
            return httpError(status: 404, code: "unknown_version_action", message: "Unknown version action")
        }

        let action = components[1]

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

    private func methodNotAllowed(_ allowed: [String]) -> HTTPResponse {
        let payload = APIErrorPayload(code: "method_not_allowed", message: "Method not allowed")
        var response = HTTPResponse.json(payload)
        response.statusCode = 405
        response.reasonPhrase = reasonPhrase(for: 405)
        response.headers["Allow"] = allowed.joined(separator: ", ")
        return response
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
