import Foundation
import Network

private struct HttpRequestParseResult {
    let method: String
    let path: String
    let version: String
    let headers: [(String, String)]
    // periphery:ignore
    let data: Data
}

private class HttpRequestParser {
    private var data = Data()

    init() {}

    func append(data: Data) {
        self.data += data
    }

    func parse() -> (Bool, HttpRequestParseResult?) {
        var offset = 0
        guard let (startLine, nextLineOffset) = getLine(data: data, offset: offset) else {
            return (false, nil)
        }
        offset = nextLineOffset
        let startParts = startLine.split(separator: " ")
        guard startParts.count == 3 else {
            return (true, nil)
        }
        let method = startParts[0]
        let path = startParts[1]
        let version = startParts[2]
        guard version.hasPrefix("HTTP/1.") else {
            return (true, nil)
        }
        var headers: [(String, String)] = []
        while let (line, nextLineOffset) = getLine(data: data, offset: offset) {
            let parts = line.lowercased().split(separator: " ")
            if parts.count == 2 {
                headers.append((String(parts[0]), String(parts[1])))
            }
            if line.isEmpty {
                return (true, HttpRequestParseResult(method: String(method),
                                                     path: String(path),
                                                     version: String(version),
                                                     headers: headers,
                                                     data: Data()))
            }
            offset = nextLineOffset
        }
        return (false, nil)
    }

    private func getLine(data: Data, offset: Int) -> (String, Int)? {
        let data = data.advanced(by: offset)
        guard let rIndex = data.firstIndex(of: 0xD), data.count > rIndex + 1, data[rIndex + 1] == 0xA else {
            return nil
        }
        guard let line = String(bytes: data[0 ..< rIndex], encoding: .utf8) else {
            return nil
        }
        return (line, offset + rIndex + 2)
    }
}

class HttpServerRequest {
    let method: String
    let path: String
    let version: String
    // periphery:ignore
    let headers: [(String, String)]

    fileprivate init(method: String, path: String, version: String, headers: [(String, String)]) {
        self.method = method
        self.path = path
        self.version = version
        self.headers = headers
    }

    fileprivate func getContentType() -> String {
        switch path.split(separator: ".").last {
        case "html":
            return "text/html"
        case "mjs":
            return "text/javascript"
        case "css":
            return "text/css"
        case "woff2":
            return "font/woff2"
        case "ico":
            return "image/vnd.microsoft.icon"
        default:
            return "text/html"
        }
    }
}

enum HttpServerStatus {
    case ok
    case notFound

    func code() -> Int {
        switch self {
        case .ok:
            return 200
        case .notFound:
            return 404
        }
    }

    func text() -> String {
        switch self {
        case .ok:
            return "OK"
        case .notFound:
            return "Not Found"
        }
    }
}

class HttpServerResponse {
    private weak var connection: HttpServerConnection?

    fileprivate init(connection: HttpServerConnection) {
        self.connection = connection
    }

    func send(data: Data, status: HttpServerStatus = .ok) {
        connection?.sendAndClose(status: status, content: data)
    }

    func send(text: String, status: HttpServerStatus = .ok) {
        send(data: text.utf8Data, status: status)
    }
}

private class HttpServerConnection {
    private let connection: NWConnection
    private weak var server: HttpServer?
    private var parser = HttpRequestParser()
    private var request: HttpServerRequest?

    init(connection: NWConnection, server: HttpServer) {
        self.connection = connection
        self.server = server
    }

    func receiveData() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
            guard let data, error == nil else {
                if let error {
                    logger.info("http-server: Connection error: \(error.localizedDescription)")
                }
                return
            }
            self.handleData(data: data)
            self.receiveData()
        }
    }

    private func handleData(data: Data) {
        parser.append(data: data)
        let (done, result) = parser.parse()
        guard done else {
            return
        }
        guard let result, let server else {
            connection.cancel()
            return
        }
        request = HttpServerRequest(method: result.method,
                                    path: result.path,
                                    version: result.version,
                                    headers: result.headers)
        guard let route = server.findRoute(request: request!) else {
            sendAndClose(status: .notFound, content: Data())
            return
        }
        route.handler(request!, HttpServerResponse(connection: self))
    }

    func sendAndClose(status: HttpServerStatus, content: Data) {
        guard let request else {
            return
        }
        var lines: [String] = []
        lines.append("\(request.version) \(status.code()) \(status.text())")
        if !content.isEmpty {
            lines.append("Content-Type: \(request.getContentType())")
        }
        lines.append("Connection: close")
        lines.append("")
        lines.append("")
        sendAndClose(data: lines.joined(separator: "\r\n").utf8Data + content)
    }

    private func sendAndClose(data: Data) {
        connection.send(content: data, completion: .contentProcessed { _ in
            self.connection.cancel()
        })
    }
}

class HttpServerRoute {
    let path: String
    let handler: (HttpServerRequest, HttpServerResponse) -> Void

    init(path: String, handler: @escaping (HttpServerRequest, HttpServerResponse) -> Void) {
        self.path = path
        self.handler = handler
    }
}

class HttpServer {
    private let queue: DispatchQueue
    private let routes: [HttpServerRoute]
    private var listener: NWListener?
    private let retryTimer: SimpleTimer
    private var port: NWEndpoint.Port = .http
    private var started: Bool = false

    init(queue: DispatchQueue, routes: [HttpServerRoute]) {
        self.queue = queue
        self.routes = routes
        retryTimer = SimpleTimer(queue: queue)
    }

    func start(port: NWEndpoint.Port) {
        logger.debug("http-server: Start")
        queue.async {
            self.startInternal(port: port)
        }
    }

    func stop() {
        logger.debug("http-server: Stop")
        queue.async {
            self.stopInternal()
        }
    }

    private func startInternal(port: NWEndpoint.Port) {
        self.port = port
        started = true
        setupListener()
    }

    private func stopInternal() {
        started = false
        retryTimer.stop()
        listener?.cancel()
        listener = nil
    }

    private func setupListener() {
        listener = try? NWListener(using: .tcp, on: port)
        listener?.service = NWListener.Service(name: "moblin", type: "_http._tcp")
        listener?.stateUpdateHandler = handleStateUpdate
        listener?.newConnectionHandler = handleNewConnection
        listener?.start(queue: queue)
    }

    private func handleStateUpdate(_ newState: NWListener.State) {
        switch newState {
        case .failed:
            retryTimer.startSingleShot(timeout: 1) { [weak self] in
                guard let self, self.started else {
                    return
                }
                self.setupListener()
            }
        default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        let connection = HttpServerConnection(connection: connection, server: self)
        connection.receiveData()
    }

    fileprivate func findRoute(request: HttpServerRequest) -> HttpServerRoute? {
        return routes.first(where: { $0.path == request.path })
    }
}
