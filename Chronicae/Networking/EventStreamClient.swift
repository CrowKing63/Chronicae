import Foundation

struct EventStreamMessage {
    let event: String
    let data: Data
}

final class EventStreamClient: NSObject {
    private var task: URLSessionDataTask?
    private var buffer = Data()
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 0
        configuration.timeoutIntervalForResource = 0
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    var onMessage: @Sendable (EventStreamMessage) -> Void
    var onError: @Sendable (Error) -> Void

    init(onMessage: @escaping @Sendable (EventStreamMessage) -> Void,
         onError: @escaping @Sendable (Error) -> Void) {
        self.onMessage = onMessage
        self.onError = onError
    }

    func start(url: URL) {
        stop()
        var request = URLRequest(url: url)
        request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
        task = session.dataTask(with: request)
        task?.resume()
    }

    func stop() {
        task?.cancel()
        task = nil
        buffer.removeAll(keepingCapacity: true)
    }
}

extension EventStreamClient: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)
        parseBuffer()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error, (error as NSError).code != NSURLErrorCancelled {
            onError(error)
        }
    }

    private func parseBuffer() {
        while let range = buffer.range(of: Data("\n\n".utf8)) {
            let messageData = buffer[..<range.lowerBound]
            buffer.removeSubrange(..<range.upperBound)
            guard let messageString = String(data: messageData, encoding: .utf8) else { continue }
            let lines = messageString.split(separator: "\n")
            var eventName = ""
            var dataLines: [Substring] = []
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("event:") {
                    eventName = trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("data:") {
                    dataLines.append(trimmed.dropFirst(5))
                }
            }
            guard !eventName.isEmpty else { continue }
            let dataString = dataLines.joined(separator: "\n")
            let data = Data(dataString.utf8)
            onMessage(EventStreamMessage(event: eventName, data: data))
        }
    }
}
