import Foundation

struct ServerAPIClient {
    private let baseURL: URL
    private let session: URLSession
    private let authToken: String?

    init(baseURL: URL, authToken: String? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.authToken = authToken
    }

    // MARK: - Projects

    func fetchProjects() async throws -> ProjectListPayload {
        try await request(path: "/api/projects", method: "GET", body: EmptyBody())
    }

    func createProject(name: String) async throws -> ProjectResponsePayload {
        let payload = CreateProjectPayload(name: name)
        return try await request(path: "/api/projects", method: "POST", body: payload)
    }

    func fetchProject(id: UUID, includeStats: Bool = false) async throws -> ProjectSummary {
        let suffix = includeStats ? "?includeStats=true" : ""
        let response: ProjectDetailPayload = try await request(
            path: "/api/projects/\(id.uuidString)\(suffix)",
            method: "GET",
            body: EmptyBody()
        )
        return response.project
    }

    func switchProject(id: UUID) async throws -> ProjectResponsePayload {
        try await request(path: "/api/projects/\(id.uuidString)/switch", method: "POST", body: EmptyBody())
    }

    func resetProject(id: UUID) async throws -> ProjectResponsePayload {
        try await request(path: "/api/projects/\(id.uuidString)/reset", method: "POST", body: EmptyBody())
    }

    func updateProject(id: UUID, name: String, includeStats: Bool = false) async throws -> ProjectResponsePayload {
        let suffix = includeStats ? "?includeStats=true" : ""
        let payload = ProjectUpdatePayload(name: name)
        return try await request(
            path: "/api/projects/\(id.uuidString)\(suffix)",
            method: "PUT",
            body: payload
        )
    }

    func deleteProject(id: UUID) async throws {
        _ = try await request(path: "/api/projects/\(id.uuidString)", method: "DELETE", body: EmptyBody(), expecting: EmptyResponse.self)
    }

    func exportProject(id: UUID) async throws -> ServerDataStore.ExportJob {
        try await request(path: "/api/projects/\(id.uuidString)/export", method: "POST", body: EmptyBody())
    }

    // MARK: - Notes

    func fetchNotes(projectId: UUID,
                    cursor: String? = nil,
                    limit: Int = 50,
                    search: String? = nil) async throws -> NoteListPayload {
        let boundedLimit = max(1, min(limit, 200))
        var components = URLComponents()
        components.path = "/api/projects/\(projectId.uuidString)/notes"
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(boundedLimit))]
        if let cursor, !cursor.isEmpty {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        if let search, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        components.queryItems = queryItems
        let path = components.string ?? "/api/projects/\(projectId.uuidString)/notes?limit=\(boundedLimit)"
        return try await request(path: path, method: "GET", body: EmptyBody())
    }

    func createNote(projectId: UUID, title: String, content: String, tags: [String]) async throws -> NoteSummary {
        let payload = NoteCreatePayload(title: title, content: content, tags: tags)
        let response: NoteResponsePayload = try await request(path: "/api/projects/\(projectId.uuidString)/notes", method: "POST", body: payload)
        return response.note
    }

    func updateNote(projectId: UUID,
                    noteId: UUID,
                    title: String,
                    content: String,
                    tags: [String],
                    lastKnownVersion: Int? = nil) async throws -> NoteSummary {
        let payload = NoteUpdatePayload(title: title,
                                        content: content,
                                        tags: tags,
                                        lastKnownVersion: lastKnownVersion)
        let response: NoteResponsePayload = try await request(path: "/api/projects/\(projectId.uuidString)/notes/\(noteId.uuidString)", method: "PUT", body: payload)
        return response.note
    }

    func deleteNote(projectId: UUID, noteId: UUID) async throws {
        _ = try await request(path: "/api/projects/\(projectId.uuidString)/notes/\(noteId.uuidString)", method: "DELETE", body: EmptyBody(), expecting: EmptyResponse.self)
    }

    func fetchNote(projectId: UUID, noteId: UUID) async throws -> NoteSummary {
        let response: NoteResponsePayload = try await request(path: "/api/projects/\(projectId.uuidString)/notes/\(noteId.uuidString)", method: "GET", body: EmptyBody())
        return response.note
    }

    func exportNote(projectId: UUID, noteId: UUID) async throws -> ServerDataStore.ExportJob {
        try await request(path: "/api/projects/\(projectId.uuidString)/notes/\(noteId.uuidString)/export", method: "POST", body: EmptyBody())
    }

    // MARK: - Versions

    func fetchVersions(projectId: UUID, noteId: UUID) async throws -> [VersionSnapshot] {
        let response: VersionListPayload = try await request(path: "/api/projects/\(projectId.uuidString)/notes/\(noteId.uuidString)/versions", method: "GET", body: EmptyBody())
        return response.items
    }

    func restoreVersion(projectId: UUID, noteId: UUID, versionId: UUID) async throws -> VersionSnapshot {
        let response: VersionRestorePayload = try await request(
            path: "/api/projects/\(projectId.uuidString)/notes/\(noteId.uuidString)/versions/\(versionId.uuidString)/restore",
            method: "POST",
            body: EmptyBody()
        )
        return response.version
    }

    func exportVersion(projectId: UUID, noteId: UUID, versionId: UUID) async throws -> ServerDataStore.ExportJob {
        try await request(
            path: "/api/projects/\(projectId.uuidString)/notes/\(noteId.uuidString)/versions/\(versionId.uuidString)/export",
            method: "POST",
            body: EmptyBody()
        )
    }

    // MARK: - Backup

    func runBackup() async throws -> ServerDataStore.BackupRecord {
        try await request(path: "/api/backup/run", method: "POST", body: EmptyBody())
    }

    func fetchBackupHistory() async throws -> [ServerDataStore.BackupRecord] {
        try await request(path: "/api/backup/history", method: "GET", body: EmptyBody())
    }

    // MARK: - Internal helpers

    @discardableResult
    private func request<T: Decodable, Body: Encodable>(path: String, method: String, body: Body, expecting: T.Type = T.self) async throws -> T {
        let url = try resolve(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        if !(body is EmptyBody) {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServerAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 409, let conflict = try? decode(NoteConflictPayload.self, from: data) {
                throw ServerAPIError.noteConflict(conflict)
            }
            let apiError = try? decode(APIErrorPayload.self, from: data)
            throw ServerAPIError.server(statusCode: httpResponse.statusCode, apiError: apiError)
        }

        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        guard !data.isEmpty else {
            throw ServerAPIError.emptyBody
        }

        return try decode(T.self, from: data)
    }

    private func resolve(path: String) throws -> URL {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw ServerAPIError.invalidURL
        }
        return url
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}

private struct EmptyBody: Encodable {}

private struct EmptyResponse: Decodable {}

enum ServerAPIError: Error {
    case invalidURL
    case invalidResponse
    case server(statusCode: Int, apiError: APIErrorPayload?)
    case noteConflict(NoteConflictPayload)
    case emptyBody
}

extension ServerAPIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 서버 URL입니다."
        case .invalidResponse:
            return "서버 응답을 해석할 수 없습니다."
        case let .server(statusCode, apiError):
            if let message = apiError?.message, !message.isEmpty {
                return message
            }
            return "서버 오류 (코드 \(statusCode))"
        case let .noteConflict(payload):
            return payload.message
        case .emptyBody:
            return "서버에서 비어 있는 응답이 도착했습니다."
        }
    }
}
