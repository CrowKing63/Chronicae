import Foundation
import Network

struct HTTPRequest {
    let method: String
    let path: String
    let version: String
    let headers: [String: String]
    let body: Data
}

struct HTTPResponse {
    var statusCode: Int
    var reasonPhrase: String
    var headers: [String: String]
    var body: Data

    init(statusCode: Int = 200, reasonPhrase: String = "OK", headers: [String: String] = [:], body: Data = Data()) {
        self.statusCode = statusCode
        self.reasonPhrase = reasonPhrase
        self.headers = headers
        self.body = body
    }

    func serialized() -> Data {
        var response = "HTTP/1.1 \(statusCode) \(reasonPhrase)\r\n"
        var headerLines = headers
        headerLines["Content-Length"] = "\(body.count)"
        headerLines["Connection"] = "close"
        for (key, value) in headerLines {
            response += "\(key): \(value)\r\n"
        }
        response += "\r\n"
        var data = Data(response.utf8)
        data.append(body)
        return data
    }

    static func text(_ string: String, statusCode: Int = 200, contentType: String = "text/plain; charset=utf-8") -> HTTPResponse {
        let data = Data(string.utf8)
        return HTTPResponse(statusCode: statusCode,
                            reasonPhrase: statusDescription(for: statusCode),
                            headers: ["Content-Type": contentType],
                            body: data)
    }

    static func json<T: Encodable>(_ payload: T, encoder: JSONEncoder = JSONEncoder()) -> HTTPResponse {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(payload) {
            return HTTPResponse(statusCode: 200,
                                reasonPhrase: "OK",
                                headers: ["Content-Type": "application/json"],
                                body: data)
        } else {
            return HTTPResponse(statusCode: 500,
                                reasonPhrase: "Internal Server Error",
                                headers: ["Content-Type": "application/json"],
                                body: Data("{\"error\":\"encoding_failed\"}".utf8))
        }
    }

    static func notFound() -> HTTPResponse {
        return HTTPResponse.text("Not Found", statusCode: 404)
    }

    private static func statusDescription(for code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 201: return "Created"
        case 202: return "Accepted"
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 409: return "Conflict"
        case 500: return "Internal Server Error"
        default: return "OK"
        }
    }
}

typealias HTTPHandler = @MainActor @Sendable (HTTPRequest) -> HTTPResponse

enum HTTPListenerEvent: Sendable {
    case ready
    case waiting
    case cancelled
    case failed(String)
}

final class SimpleHTTPServer {
    @MainActor private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.chronicae.http", qos: .userInitiated)
    private let handler: HTTPHandler
    private let eventHandler: (@Sendable (HTTPListenerEvent) -> Void)?
    
    init(handler: @escaping HTTPHandler, eventHandler: (@Sendable (HTTPListenerEvent) -> Void)? = nil) {
        self.handler = handler
        self.eventHandler = eventHandler
    }

    @MainActor
    func start(port: Int, allowExternal: Bool) throws {
        guard listener == nil else { return }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        if !allowExternal {
            parameters.requiredInterfaceType = .loopback
        }

        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw HTTPServerError.invalidPort
        }

        let listener = try NWListener(using: parameters, on: nwPort)
        listener.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .failed(let error):
                    self.eventHandler?(.failed(error.localizedDescription))
                    print("HTTP server failed: \(error.localizedDescription)")
                    self.listener?.cancel()
                    self.listener = nil
                case .ready:
                    self.eventHandler?(.ready)
                case .waiting:
                    self.eventHandler?(.waiting)
                case .cancelled:
                    self.eventHandler?(.cancelled)
                default:
                    break
                }
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor [weak self] in
                self?.setupConnection(connection)
            }
        }
        self.listener = listener
        listener.start(queue: queue)
    }

    @MainActor
    func stop() {
        listener?.cancel()
        listener = nil
    }

    @MainActor
    private func setupConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .ready:
                    self.receive(on: connection, buffer: Data())
                case .failed, .cancelled:
                    connection.cancel()
                default:
                    break
                }
            }
        }
        connection.start(queue: queue)
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            var currentBuffer = buffer
            if let data {
                currentBuffer.append(data)
            }

            if let range = currentBuffer.range(of: Data("\r\n\r\n".utf8)) {
                let headerData = currentBuffer.subdata(in: 0..<range.upperBound)
                let bodyData = currentBuffer.count > range.upperBound ? currentBuffer.subdata(in: range.upperBound..<currentBuffer.count) : Data()
                self?.handleRequest(headerData: headerData, body: bodyData, connection: connection)
                return
            }

            if isComplete || error != nil {
                connection.cancel()
                return
            }

            self?.receive(on: connection, buffer: currentBuffer)
        }
    }

    private func handleRequest(headerData: Data, body: Data, connection: NWConnection) {
        guard let request = HTTPParser.parse(headerData: headerData, body: body) else {
            let response = HTTPResponse(statusCode: 400, reasonPhrase: "Bad Request", headers: ["Content-Type": "text/plain"], body: Data("Bad Request".utf8))
            send(response: response, over: connection)
            return
        }

        Task { @MainActor in
            if request.path == "/events" || request.path == "/api/events" {
                self.handleEventStream(connection: connection)
                return
            }
            let response = handler(request)
            self.send(response: response, over: connection)
        }
    }

    private func handleEventStream(connection: NWConnection) {
        let headers = "HTTP/1.1 200 OK\r\n" +
            "Content-Type: text/event-stream\r\n" +
            "Cache-Control: no-cache\r\n" +
            "Connection: keep-alive\r\n" +
            "Access-Control-Allow-Origin: *\r\n\r\n"
        let data = Data(headers.utf8)
        connection.send(content: data, completion: .contentProcessed { error in
            if error == nil {
                Task { await ServerEventCenter.shared.registerHTTP(connection: connection) }
            } else {
                connection.cancel()
            }
        })
    }

    @MainActor
    private func send(response: HTTPResponse, over connection: NWConnection) {
        let data = response.serialized()
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

enum HTTPServerError: Error {
    case invalidPort
}

enum HTTPParser {
    static func parse(headerData: Data, body: Data) -> HTTPRequest? {
        guard let headerString = String(data: headerData, encoding: .utf8) else { return nil }
        let lines = headerString.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 3 else { return nil }

        let method = String(parts[0])
        let path = String(parts[1])
        let version = String(parts[2])

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let headerParts = line.split(separator: ":", maxSplits: 1)
            guard headerParts.count == 2 else { continue }
            let key = headerParts[0].trimmingCharacters(in: .whitespaces)
            let value = headerParts[1].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        return HTTPRequest(method: method, path: path, version: version, headers: headers, body: body)
    }
}
