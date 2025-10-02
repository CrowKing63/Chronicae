import Foundation
import Network

#if canImport(Vapor)
import Vapor
#endif

actor ServerEventCenter {
    static let shared = ServerEventCenter()

    private final class HTTPClient: NSObject, @unchecked Sendable {
        let id = UUID()
        let connection: NWConnection

        init(connection: NWConnection) {
            self.connection = connection
        }
    }

#if canImport(Vapor)
    private final class VaporClient: NSObject, @unchecked Sendable {
        let id = UUID()
        let eventLoop: EventLoop
        let writer: Response.Body.StreamWriter
        let onDisconnect: @Sendable () -> Void

        init(eventLoop: EventLoop, writer: @escaping Response.Body.StreamWriter, onDisconnect: @escaping @Sendable () -> Void) {
            self.eventLoop = eventLoop
            self.writer = writer
            self.onDisconnect = onDisconnect
        }
    }

    private var vaporClients: [UUID: VaporClient] = [:]
#endif

    private var httpClients: [UUID: HTTPClient] = [:]

    private init() {
        Task.detached { [weak self] in
            await self?.startPingLoop()
        }
    }

    func registerHTTP(connection: NWConnection) {
        let client = HTTPClient(connection: connection)
        httpClients[client.id] = client
        sendRaw(to: client, text: ": connected\n\n")
    }

#if canImport(Vapor)
    func registerVapor(writer: @escaping Response.Body.StreamWriter, on eventLoop: EventLoop, onDisconnect: @escaping @Sendable () -> Void) -> UUID {
        let client = VaporClient(eventLoop: eventLoop, writer: writer, onDisconnect: onDisconnect)
        vaporClients[client.id] = client
        Task { await sendRaw(to: client, text: ": connected\n\n") }
        return client.id
    }

    func removeVaporClient(id: UUID) {
        if let client = vaporClients.removeValue(forKey: id) {
            client.onDisconnect()
        }
    }
#endif

    func publish(type: AppEventType, payloadJSON: Data) {
        Task { await broadcast(type: type, payloadJSON: payloadJSON) }
    }

    private func broadcast(type: AppEventType, payloadJSON: Data) async {
        guard let jsonString = String(data: payloadJSON, encoding: .utf8) else { return }
        let message = "event: \(type.rawValue)\ndata: \(jsonString)\n\n"
        for client in httpClients.values {
            sendRaw(to: client, text: message)
        }
#if canImport(Vapor)
        for client in vaporClients.values {
            await sendRaw(to: client, text: message)
        }
#endif
    }

    private func sendRaw(to client: HTTPClient, text: String) {
        let data = Data(text.utf8)
        client.connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let _ = error {
                Task { await self?.removeHTTPClient(id: client.id) }
            }
        })
    }

#if canImport(Vapor)
    private func sendRaw(to client: VaporClient, text: String) async {
        var buffer = ByteBufferAllocator().buffer(capacity: text.utf8.count)
        buffer.writeString(text)
        client.eventLoop.execute {
            client.writer(buffer, nil)
        }
    }
#endif

    private func removeHTTPClient(id: UUID) {
        if let client = httpClients.removeValue(forKey: id) {
            client.connection.cancel()
        }
    }

    private func startPingLoop() async {
        while true {
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            await sendPing()
        }
    }

    private func sendPing() async {
        let pingPayload = "event: ping\ndata: {}\n\n"
        for client in httpClients.values {
            sendRaw(to: client, text: pingPayload)
        }
#if canImport(Vapor)
        for client in vaporClients.values {
            await sendRaw(to: client, text: pingPayload)
        }
#endif
    }
}
