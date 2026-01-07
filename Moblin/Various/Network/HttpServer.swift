import Foundation
import Network

private class HttpRequestParser {
    private var data = Data()

    init() {}

    func append(data: Data) {
        self.data += data
    }

    func parse() -> (Bool, (String, String, String, [(String, String)], Data)?) {
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
                return (true, (String(method), String(path), String(version), headers, Data()))
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
    // periphery:ignore
    let headers: [(String, String)]

    fileprivate init(method: String, path: String, headers: [(String, String)]) {
        self.method = method
        self.path = path
        self.headers = headers
    }
}

class HttpServerResponse {
    private weak var connection: HttpServerConnection?

    fileprivate init(connection: HttpServerConnection) {
        self.connection = connection
    }

    func send(text: String) {
        connection?.send200AndClose(content: text.utf8Data)
    }
}

private class HttpServerConnection {
    private let connection: NWConnection
    private weak var server: HttpServer?
    private var parser = HttpRequestParser()
    private var version: String = "HTTP/1.0"
    private var request: HttpServerRequest?

    init(connection: NWConnection, server: HttpServer) {
        self.connection = connection
        self.server = server
    }

    func receiveData() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
            guard let data, error == nil else {
                logger.info("http-server: Connection error: \(error?.localizedDescription ?? "")")
                return
            }
            self.handleData(data: data)
            self.receiveData()
        }
    }

    private func handleData(data: Data) {
        parser.append(data: data)
        let (done, requestData) = parser.parse()
        guard done else {
            return
        }
        guard let requestData, let server else {
            connection.cancel()
            return
        }
        request = HttpServerRequest(method: requestData.0,
                                    path: requestData.1,
                                    headers: requestData.3)
        version = requestData.2
        guard let route = server.findRoute(request: request!) else {
            send404AndClose()
            return
        }
        let response = HttpServerResponse(connection: self)
        route.handler(request!, response)
    }

    func send200AndClose(content: Data) {
        sendAndClose(data: """
        \(version) 200 OK\r\n\
        Content-Type: \(getContentType())\r\n\
        Connection: close\r\n\
        \r\n
        """.utf8Data + content)
    }

    func send404AndClose() {
        sendAndClose(data: "\(version) 404 Not Found\r\nConnection: close\r\n\r\n".utf8Data)
    }

    private func sendAndClose(data: Data) {
        connection.send(content: data, completion: .contentProcessed { _ in
            self.connection.cancel()
        })
    }

    private func getContentType() -> String {
        switch request?.path.split(separator: ".").last {
        case "html":
            return "text/html"
        case "mjs":
            return "text/javascript"
        case "css":
            return "text/css"
        case "woff2":
            return "font/woff2"
        default:
            return "text/plain"
        }
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

    init(queue: DispatchQueue, routes: [HttpServerRoute]) {
        self.queue = queue
        self.routes = routes
    }

    func start(port: NWEndpoint.Port) {
        logger.info("http-server: Start")
        queue.async {
            self.startInternal(port: port)
        }
    }

    func stop() {
        logger.info("http-server: Stop")
        queue.async {
            self.stopInternal()
        }
    }

    private func startInternal(port: NWEndpoint.Port) {
        listener = try? NWListener(using: .tcp, on: port)
        listener?.stateUpdateHandler = handleStateUpdate
        listener?.newConnectionHandler = handleNewConnection
        listener?.start(queue: queue)
    }

    private func stopInternal() {
        listener?.cancel()
        listener = nil
    }

    private func handleStateUpdate(_ newState: NWListener.State) {
        logger.info("http-server: State \(newState)")
    }

    private func handleNewConnection(_ connection: NWConnection) {
        logger.info("http-server: New connection \(connection)")
        connection.start(queue: queue)
        let connection = HttpServerConnection(connection: connection, server: self)
        connection.receiveData()
    }

    fileprivate func findRoute(request: HttpServerRequest) -> HttpServerRoute? {
        return routes.first(where: { $0.path == request.path })
    }
}
