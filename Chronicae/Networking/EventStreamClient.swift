import Foundation

private enum EventStreamError: LocalizedError {
    case httpStatus(code: Int)

    var errorDescription: String? {
        switch self {
        case .httpStatus(let code):
            return "Event stream request failed with status code \(code)."
        }
    }
}

struct EventStreamMessage {
    let event: String
    let data: Data
}

final class EventStreamClient: NSObject {
    private var task: URLSessionDataTask?
    private var buffer = Data()
    private let delegateQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.chronicae.eventstream.delegate"
        q.maxConcurrentOperationCount = 1
        return q
    }()
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 0
        configuration.timeoutIntervalForResource = 0
        return URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
    }()

    var onMessage: @Sendable (EventStreamMessage) -> Void
    var onError: @Sendable (Error) -> Void

    init(onMessage: @escaping @Sendable (EventStreamMessage) -> Void,
         onError: @escaping @Sendable (Error) -> Void) {
        self.onMessage = onMessage
        self.onError = onError
    }

    func start(url: URL, token: String?) {
        stop()
        var request = URLRequest(url: url)
        request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let token, !token.isEmpty {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        task = session.dataTask(with: request)
        task?.resume()
    }

    func stop() {
        task?.cancel()
        task = nil
        // Ensure buffer is mutated only on the delegate queue to avoid races
        delegateQueue.addOperation { [weak self] in
            self?.buffer.removeAll(keepingCapacity: true)
        }
    }
}

extension EventStreamClient: URLSessionDataDelegate {
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse else {
            completionHandler(.allow)
            return
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = EventStreamError.httpStatus(code: httpResponse.statusCode)
            dataTask.cancel()
            onError(error)
            completionHandler(.cancel)
            return
        }

        completionHandler(.allow)
    }

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
            let messageData = Data(buffer[..<range.lowerBound])
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
