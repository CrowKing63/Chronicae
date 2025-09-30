import Foundation

struct ServerAPIClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Projects

    func fetchProjects() async throws -> ProjectListPayload {
        try await request(path: "/api/projects", method: "GET", body: EmptyBody())
    }

    func createProject(name: String) async throws -> ProjectResponsePayload {
        let payload = CreateProjectPayload(name: name)
        return try await request(path: "/api/projects", method: "POST", body: payload)
    }

    func switchProject(id: UUID) async throws -> ProjectResponsePayload {
        try await request(path: "/api/projects/\(id.uuidString)/switch", method: "POST", body: EmptyBody())
    }

    func resetProject(id: UUID) async throws -> ProjectResponsePayload {
        try await request(path: "/api/projects/\(id.uuidString)/reset", method: "POST", body: EmptyBody())
    }

    func deleteProject(id: UUID) async throws {
        _ = try await request(path: "/api/projects/\(id.uuidString)", method: "DELETE", body: EmptyBody(), expecting: EmptyResponse.self)
    }

    func exportProject(id: UUID) async throws -> ServerDataStore.ExportJob {
        try await request(path: "/api/projects/\(id.uuidString)/export", method: "POST", body: EmptyBody())
    }

    // MARK: - Notes

    func fetchNotes(projectId: UUID) async throws -> [NoteSummary] {
        let response: NoteListPayload = try await request(path: "/api/projects/\(projectId.uuidString)/notes", method: "GET", body: EmptyBody())
        return response.items
    }

    func createNote(projectId: UUID, title: String, content: String, tags: [String]) async throws -> NoteSummary {
        let payload = NoteCreatePayload(title: title, content: content, tags: tags)
        let response: NoteResponsePayload = try await request(path: "/api/projects/\(projectId.uuidString)/notes", method: "POST", body: payload)
        return response.note
    }

    func updateNote(projectId: UUID, noteId: UUID, title: String, content: String, tags: [String]) async throws -> NoteSummary {
        let payload = NoteUpdatePayload(title: title, content: content, tags: tags)
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
        case .emptyBody:
            return "서버에서 비어 있는 응답이 도착했습니다."
        }
    }
}
