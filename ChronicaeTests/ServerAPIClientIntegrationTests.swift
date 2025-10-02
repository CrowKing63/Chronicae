import Foundation
import Testing
@testable import Chronicae

@Suite("ServerAPIClientIntegration")
struct ServerAPIClientIntegrationTests {

    @Test @MainActor
    func multiDeviceNoteEditingRoundTrip() async throws {
        let (defaults, suiteName) = makeDefaults(suffix: "integration")
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            APIRouterURLProtocol.router = nil
        }

        let store = ServerDataStore(persistentStore: .makeInMemory(),
                                    defaults: defaults,
                                    activeProjectKey: "test.integration.activeProject",
                                    seedOnFirstLaunch: false)

        var configuration = ServerConfiguration()
        APIRouterURLProtocol.router = APIRouter(dataStore: store, configurationProvider: { configuration })

        let clientA = makeClient()
        let clientB = makeClient()

        // Device A creates a shared project
        let createdProject = try await clientA.createProject(name: "Shared Space")
        let projectId = createdProject.project.id

        // Device A seeds an initial note
        let initialNote = try await clientA.createNote(projectId: projectId,
                                                       title: "다중 디바이스 초안",
                                                       content: "Device A writes the first draft.",
                                                       tags: ["sync"])

        // Device B reads the note list and observes Device A's change
        let notesOnB = try await clientB.fetchNotes(projectId: projectId)
        #expect(notesOnB.count == 1)
        #expect(notesOnB.first?.id == initialNote.id)
        #expect(notesOnB.first?.content.contains("Device A") == true)

        // Device B updates the note content
        let updatedNote = try await clientB.updateNote(projectId: projectId,
                                                        noteId: initialNote.id,
                                                        title: "다중 디바이스 초안",
                                                        content: "Device B refined the content.",
                                                        tags: ["sync", "edited"])

        #expect(updatedNote.version == initialNote.version + 1)

        // Device A fetches the latest snapshot to ensure the update is visible
        let fetchedByA = try await clientA.fetchNote(projectId: projectId, noteId: initialNote.id)
        #expect(fetchedByA.content.contains("Device B refined") == true)
        #expect(fetchedByA.tags.contains("edited"))
        #expect(fetchedByA.version == updatedNote.version)

        // Project metadata should reflect the single note
        let projects = store.listProjects()
        #expect(projects.items.count == 1)
        #expect(projects.items.first?.noteCount == 1)
    }

    @Test @MainActor
    func requiresTokenForProtectedEndpoints() async throws {
        let (defaults, suiteName) = makeDefaults(suffix: "auth")
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            APIRouterURLProtocol.router = nil
        }

        let store = ServerDataStore(persistentStore: .makeInMemory(),
                                    defaults: defaults,
                                    activeProjectKey: "test.integration.auth",
                                    seedOnFirstLaunch: false)

        var configuration = ServerConfiguration()
        configuration.authToken = "integration-secret"
        APIRouterURLProtocol.router = APIRouter(dataStore: store, configurationProvider: { configuration })

        let authed = makeClient(token: configuration.authToken)
        let anonymous = makeClient()

        _ = try await authed.createProject(name: "Secure")

        do {
            _ = try await anonymous.fetchProjects()
            Issue.record("Expected unauthorized error")
        } catch let ServerAPIError.server(statusCode, _) {
            #expect(statusCode == 401)
        }

        let payload = try await authed.fetchProjects()
        #expect(payload.items.count == 1)
    }

    private func makeClient(token: String? = nil) -> ServerAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [APIRouterURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return ServerAPIClient(baseURL: URL(string: "http://integration.test")!, authToken: token, session: session)
    }

    private func makeDefaults(suffix: String) -> (UserDefaults, String) {
        let suiteName = "com.chronicae.tests.integration.\(suffix).\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Failed to create UserDefaults suite")
        }
        return (defaults, suiteName)
    }
}

final class APIRouterURLProtocol: URLProtocol {
    @MainActor static var router: APIRouter?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "integration.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let method = request.httpMethod ?? "GET"
        var path = url.path
        if let query = url.query, !query.isEmpty {
            path += "?\(query)"
        }

        let headers = request.allHTTPHeaderFields ?? [:]
        let body = request.httpBody ?? Data()

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let router = APIRouterURLProtocol.router else {
                self.client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
                return
            }

            let httpRequest = HTTPRequest(method: method,
                                          path: path,
                                          version: "HTTP/1.1",
                                          headers: headers,
                                          body: body)

            let httpResponse = router.response(for: httpRequest) ?? HTTPResponse.notFound()

            guard let urlResponse = HTTPURLResponse(url: url,
                                                    statusCode: httpResponse.statusCode,
                                                    httpVersion: "HTTP/1.1",
                                                    headerFields: httpResponse.headers) else {
                self.client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }

            self.client?.urlProtocol(self, didReceive: urlResponse, cacheStoragePolicy: .notAllowed)
            if !httpResponse.body.isEmpty {
                self.client?.urlProtocol(self, didLoad: httpResponse.body)
            }
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {
        // No long-lived work to cancel.
    }
}
