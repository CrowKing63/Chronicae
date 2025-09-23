import Foundation
import Observation
import OSLog
#if canImport(Vapor)
import Vapor
#endif

@MainActor
@Observable
final class ServerManager {
    static let shared = ServerManager()

    var status: ServerStatus = .stopped

    private var configuration = ServerConfiguration()
    private let worker = ServerWorker()
    static let logger = Logger(subsystem: "com.chronicae.app", category: "Server")

    func currentConfiguration() -> ServerConfiguration {
        configuration
    }

    func updateConfiguration(_ configuration: ServerConfiguration) {
        self.configuration = configuration
        worker.refreshConfiguration(configuration)
    }

    func startIfNeeded() async {
        guard case .stopped = status else { return }
        status = .starting
        do {
            let runtime = try worker.start(with: configuration)
            status = .running(runtime)
            Self.logger.info("Server started on port \(runtime.port)")
        } catch {
            status = .error(.init(message: error.localizedDescription, timestamp: .now))
            Self.logger.error("Failed to start server: \(error.localizedDescription)")
        }
    }

    func stop() async {
        do {
            try worker.stop()
            status = .stopped
            Self.logger.info("Server stopped")
        } catch {
            status = .error(.init(message: error.localizedDescription, timestamp: .now))
            Self.logger.error("Failed to stop server: \(error.localizedDescription)")
        }
    }

    func reportServerFailure(message: String) {
        Self.logger.error("Server listener failure: \(message)")
        status = .error(.init(message: message, timestamp: .now))
    }
}

@MainActor
final class ServerWorker {
    private var runtime: ServerStatus.ServerRuntime?
    private var configuration = ServerConfiguration()
    private var httpServer: SimpleHTTPServer?
    #if canImport(Vapor)
    private var application: Application?
    #endif

    func start(with configuration: ServerConfiguration) throws -> ServerStatus.ServerRuntime {
        if let runtime {
            return runtime
        }

        self.configuration = configuration

        #if canImport(Vapor)
        let app = try VaporBootstrap.makeApplication(configuration: configuration)
        try app.start()
        application = app
        #else
        let server = SimpleHTTPServer(
            handler: { [weak self] request in
                guard let self else { return HTTPResponse.notFound() }
                return self.handleOnMain(request: request)
            },
            eventHandler: { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleListenerEvent(event)
                }
            }
        )
        try server.start(port: configuration.port, allowExternal: configuration.allowExternal)
        httpServer = server
        #endif

        let runtime = ServerStatus.ServerRuntime(
            startedAt: .now,
            port: configuration.port,
            projectId: configuration.projectId
        )
        self.runtime = runtime
        return runtime
    }

    func stop() throws {
        guard runtime != nil else { return }

        #if canImport(Vapor)
        application?.shutdown()
        application = nil
        #else
        httpServer?.stop()
        httpServer = nil
        #endif

        runtime = nil
    }

    func refreshConfiguration(_ configuration: ServerConfiguration) {
        let previousConfig = self.configuration
        self.configuration = configuration
        guard var runtime else { return }

        let requiresRestart = runtime.port != configuration.port ||
            previousConfig.allowExternal != configuration.allowExternal

        runtime.projectId = configuration.projectId
        self.runtime = runtime

        if requiresRestart {
            try? self.stop()
            _ = try? self.start(with: configuration)
        }
    }

    nonisolated private func formattedUptime(since date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        return Self.uptimeFormatter.string(from: interval) ?? "0:00"
    }

    nonisolated private static let uptimeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    private func handleOnMain(request: HTTPRequest) -> HTTPResponse {
        let method = request.method
        let path = request.path

        let baseResponse: HTTPResponse

        switch path {
        case "/", "/index.html":
            baseResponse = HTTPResponse.text(WebAssets.indexHTML, contentType: "text/html; charset=utf-8")
        case "/static/app.js":
            baseResponse = HTTPResponse.text(WebAssets.appJS, contentType: "text/javascript; charset=utf-8")
        case "/static/style.css":
            baseResponse = HTTPResponse.text(WebAssets.styleCSS, contentType: "text/css; charset=utf-8")
        case "/api/status":
            struct StatusPayload: Encodable {
                let state: String
                let port: Int
                let startedAt: Date
                let uptime: String
            }
            let currentRuntime = self.runtime
            let currentPort = self.configuration.port
            if let runtime = currentRuntime {
                let payload = StatusPayload(state: "running",
                                            port: runtime.port,
                                            startedAt: runtime.startedAt,
                                            uptime: formattedUptime(since: runtime.startedAt))
                baseResponse = HTTPResponse.json(payload)
            } else {
                let payload = StatusPayload(state: "stopped", port: currentPort, startedAt: .now, uptime: "0")
                baseResponse = HTTPResponse.json(payload)
            }
        case "/docs":
            let html = """
            <!DOCTYPE html>
            <html lang=\"ko\">
            <head><meta charset=\"utf-8\" /><title>Chronicae Docs</title></head>
            <body style=\"font-family:-apple-system, sans-serif; margin:32px;\">
            <h1>Chronicae API 문서</h1>
            <p>상세 사양은 macOS 앱의 <code>docs/api-spec.md</code> 파일을 참고하세요.</p>
            <ul>
                <li><a href=\"/api/status\">/api/status</a></li>
            </ul>
            </body>
            </html>
            """
            baseResponse = HTTPResponse.text(html, contentType: "text/html; charset=utf-8")
        case "/web-app":
            let html = """
            <!DOCTYPE html>
            <html lang=\"ko\">
            <head><meta charset=\"utf-8\" /><title>Chronicae Web</title></head>
            <body style=\"font-family:-apple-system, sans-serif; margin:40px;\">
            <h1>Chronicae Vision Pro 웹앱 (프리뷰)</h1>
            <p>정식 SPA는 추후 배포됩니다. 현재는 서버 상태 확인만 가능합니다.</p>
            <pre id=\"status\">Loading...</pre>
            <script>
            fetch('/api/status')
              .then(res => res.json())
              .then(data => {
                document.getElementById('status').textContent = JSON.stringify(data, null, 2);
              })
              .catch(err => {
                document.getElementById('status').textContent = '오류: ' + err.message;
              });
            </script>
            </body>
            </html>
            """
            baseResponse = HTTPResponse.text(html, contentType: "text/html; charset=utf-8")
        case "/favicon.ico":
            baseResponse = HTTPResponse(statusCode: 204, reasonPhrase: "No Content")
        default:
            baseResponse = HTTPResponse.notFound()
        }

        switch method {
        case "GET":
            return baseResponse
        case "HEAD":
            var response = baseResponse
            response.body = Data()
            return response
        default:
            return HTTPResponse(statusCode: 405,
                                 reasonPhrase: "Method Not Allowed",
                                 headers: ["Allow": "GET, HEAD"],
                                 body: Data())
        }
    }

    private func handleListenerEvent(_ event: HTTPListenerEvent) {
        switch event {
        case .ready, .waiting:
            break
        case .cancelled:
            if runtime != nil {
                runtime = nil
                ServerManager.shared.reportServerFailure(message: "Listener cancelled")
            }
        case .failed(let message):
            if runtime != nil {
                runtime = nil
                #if !canImport(Vapor)
                if httpServer != nil {
                    httpServer?.stop()
                    httpServer = nil
                }
                #endif
                ServerManager.shared.reportServerFailure(message: message)
            }
        }
    }
}
