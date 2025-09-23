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
        app.get("status") { _ in
            StatusResponse(status: "ok")
        }
        // TODO: API 사양에 따라 라우트 확장 예정
    }
}

private struct StatusResponse: Content {
    let status: String
}
#endif
