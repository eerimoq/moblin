import Foundation
import Network

protocol RemoteControlWebDelegate: AnyObject {
    func remoteControlWebConnected()
    func remoteControlWebGetStatus()
        -> (RemoteControlStatusGeneral, RemoteControlStatusTopLeft, RemoteControlStatusTopRight)
    func remoteControlWebSetRecord(on: Bool)
    func remoteControlWebSetStream(on: Bool)
    func remoteControlWebSetDebugLogging(on: Bool)
    func remoteControlWebSetMute(on: Bool)
    func remoteControlWebSetTorch(on: Bool)
}

private struct StaticFile {
    let path: String
    let name: String
    let ext: String

    init(_ path: String, _ name: String, _ ext: String) {
        self.path = path
        self.name = name
        self.ext = ext
    }

    func makePath() -> String {
        return "\(path)\(name).\(ext)"
    }
}

private let staticFiles: [StaticFile] = [
    StaticFile("/", "index", "html"),
    StaticFile("/", "remote", "html"),
    StaticFile("/", "scoreboard", "html"),
    StaticFile("/", "volleyball", "png"),
    StaticFile("/", "favicon", "ico"),
    StaticFile("/css/", "vanilla-framework-version-4.14.0.min", "css"),
    StaticFile("/css/", "f3b9cc97-Ubuntu[wdth,wght]-latin", "woff2"),
    StaticFile("/css/", "c1b12cdf-Ubuntu-Italic[wdth,wght]-latin", "woff2"),
    StaticFile("/css/", "0bd4277a-UbuntuMono[wght]-latin", "woff2"),
    StaticFile("/js/", "index", "mjs"),
    StaticFile("/js/", "utils", "mjs"),
    StaticFile("/js/", "remote", "mjs"),
    StaticFile("/js/", "scoreboard", "mjs"),
]

class RemoteControlWeb {
    private var server: HttpServer?
    private var started: Bool = false
    private var websocketServer: NWListener?
    private var websocketPort: UInt16 = 0
    private let websocketRetryTimer = SimpleTimer(queue: .main)
    private weak var delegate: (any RemoteControlWebDelegate)?
    private var connections: [NWConnection] = []
    let scoreboardServer = RemoteControlScoreboardServer()

    init(delegate: RemoteControlWebDelegate) {
        self.delegate = delegate
    }

    func start(port: UInt16) {
        started = true
        startServer(port: port)
        startWebsocketServer(port: port + 1)
        scoreboardServer.start(port: port + 2)
    }

    func stop() {
        started = false
        stopServer()
        stopWebsocketServer()
        scoreboardServer.stop()
    }

    func stateChanged(state: RemoteControlAssistantStreamerState) {
        for connection in connections {
            send(connection: connection, message: .event(data: .state(data: state)))
        }
    }

    func log(entry: String) {
        for connection in connections {
            send(connection: connection, message: .event(data: .log(entry: entry)))
        }
    }

    private func startServer(port: UInt16) {
        var routes = staticFiles.map {
            HttpServerRoute(path: $0.makePath(), handler: handleStatic)
        }
        routes.append(HttpServerRoute(path: "/", handler: handleRoot))
        routes.append(HttpServerRoute(path: "/js/config.mjs", handler: handleConfigMjs))
        server = HttpServer(queue: .main, routes: routes)
        server?.start(port: .init(integer: Int(port)))
    }

    private func startWebsocketServer(port: UInt16) {
        websocketPort = port
        setupWebsocketServer()
    }

    private func setupWebsocketServer() {
        let parameters = NWParameters.tcp
        let options = NWProtocolWebSocket.Options()
        options.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.append(options)
        websocketServer = try? NWListener(using: parameters, on: .init(integer: Int(websocketPort)))
        websocketServer?.stateUpdateHandler = handleWebsocketStateUpdate
        websocketServer?.newConnectionHandler = handleNewWebsocketConnection
        websocketServer?.start(queue: .main)
    }

    private func stopServer() {
        server?.stop()
        server = nil
    }

    private func stopWebsocketServer() {
        for connection in connections {
            connection.cancel()
        }
        connections.removeAll()
        websocketRetryTimer.stop()
        websocketServer?.cancel()
        websocketServer = nil
    }

    private func handleRoot(request: HttpServerRequest, response: HttpServerResponse) {
        guard request.method == "GET" else {
            return
        }
        response.send(data: loadResource(name: "index", ext: "html"))
    }

    private func handleStatic(request: HttpServerRequest, response: HttpServerResponse) {
        guard request.method == "GET",
              let staticPath = staticFiles.first(where: {
                  request.path == $0.makePath()
              })
        else {
            return
        }
        response.send(data: loadResource(name: staticPath.name, ext: staticPath.ext))
    }

    private func handleConfigMjs(request: HttpServerRequest, response: HttpServerResponse) {
        guard request.method == "GET" else {
            return
        }
        let configMjs = """
        export const websocketPort = \(websocketPort);
        export const scoreboardWebsocketPort = \(scoreboardServer.port);
        """
        response.send(text: configMjs)
    }

    private func handleWebsocketStateUpdate(_ newState: NWListener.State) {
        switch newState {
        case .failed:
            websocketRetryTimer.startSingleShot(timeout: 1) { [weak self] in
                guard let self, self.started else {
                    return
                }
                self.setupWebsocketServer()
            }
        default:
            break
        }
    }

    private func handleNewWebsocketConnection(_ connection: NWConnection) {
        connections.append(connection)
        connection.start(queue: .main)
        receiveWebsocketPacket(connection: connection)
        delegate?.remoteControlWebConnected()
    }

    private func receiveWebsocketPacket(connection: NWConnection) {
        connection.receiveMessage { data, context, _, _ in
            switch context?.webSocketOperation() {
            case .text:
                if let data, !data.isEmpty {
                    self.handleWebsocketMessage(connection: connection, packet: data)
                    self.receiveWebsocketPacket(connection: connection)
                } else {
                    self.handleDisconnected(connection: connection)
                }
            case .ping:
                connection.sendWebSocket(data: data, opcode: .pong)
                self.receiveWebsocketPacket(connection: connection)
            case .pong:
                self.receiveWebsocketPacket(connection: connection)
            default:
                self.handleDisconnected(connection: connection)
            }
        }
    }

    private func handleDisconnected(connection: NWConnection) {
        connection.cancel()
        connections.removeAll(where: { $0 === connection })
    }

    private func handleWebsocketMessage(connection: NWConnection, packet: Data) {
        guard let message = String(bytes: packet, encoding: .utf8) else {
            return
        }
        switch try? RemoteControlMessageToStreamer.fromJson(data: message) {
        case let .request(id: id, data: data):
            handleRequest(connection: connection, id: id, data: data)
        default:
            break
        }
    }

    private func handleRequest(connection: NWConnection, id: Int, data: RemoteControlRequest) {
        guard let delegate else {
            return
        }
        switch data {
        case .getStatus:
            let (general, topLeft, topRight) = delegate.remoteControlWebGetStatus()
            send(connection: connection,
                 message: .response(
                     id: id,
                     result: .ok,
                     data: .getStatus(general: general, topLeft: topLeft, topRight: topRight)
                 ))
        case let .setRecord(on: on):
            delegate.remoteControlWebSetRecord(on: on)
            sendEmptyOkResponse(connection: connection, id: id)
        case let .setStream(on: on):
            delegate.remoteControlWebSetStream(on: on)
            sendEmptyOkResponse(connection: connection, id: id)
        case let .setMute(on: on):
            delegate.remoteControlWebSetMute(on: on)
            sendEmptyOkResponse(connection: connection, id: id)
        case let .setTorch(on: on):
            delegate.remoteControlWebSetTorch(on: on)
            sendEmptyOkResponse(connection: connection, id: id)
        case let .setDebugLogging(on: on):
            delegate.remoteControlWebSetDebugLogging(on: on)
            sendEmptyOkResponse(connection: connection, id: id)
        default:
            break
        }
    }

    private func send(connection: NWConnection, message: RemoteControlMessageToAssistant) {
        do {
            let message = try message.toJson()
            connection.sendWebSocket(data: message.utf8Data, opcode: .text)
        } catch {
            logger.info("remote-control-web-ui: Encode failed")
        }
    }

    private func sendEmptyOkResponse(connection: NWConnection, id: Int) {
        send(connection: connection, message: .response(id: id, result: .ok, data: nil))
    }
}

class RemoteControlScoreboardServer {
    private var listener: NWListener?
    private var clients: [NWConnection] = []
    var onMessageReceived: ((RemoteControlScoreboardMessage) -> Void)?
    var onClientConnected: ((NWConnection) -> Void)?
    var port: UInt16 = 0

    func start(port: UInt16) {
        self.port = port
        let params = NWParameters.tcp
        params.defaultProtocolStack.applicationProtocols.insert(NWProtocolWebSocket.Options(), at: 0)
        try? listener = NWListener(using: params, on: .init(integer: Int(port)))
        listener?.newConnectionHandler = { connection in
            connection.stateUpdateHandler = { state in
                if case .ready = state {
                    self.clients.append(connection)
                    self.onClientConnected?(connection)
                    self.receive(connection: connection)
                }
            }
            connection.start(queue: .main)
        }
        listener?.start(queue: .main)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        clients.removeAll()
    }

    private func receive(connection: NWConnection) {
        connection.receiveMessage { data, _, _, err in
            if let data,
               let message = try? JSONDecoder().decode(RemoteControlScoreboardMessage.self, from: data)
            {
                self.onMessageReceived?(message)
            }
            if err == nil {
                self.receive(connection: connection)
            } else {
                self.clients.removeAll(where: { $0 === connection })
            }
        }
    }

    func broadcastMessage(_ message: String) {
        for client in clients {
            sendMessage(connection: client, message: message)
        }
    }

    func sendMessage(connection: NWConnection, message: String) {
        connection.sendWebSocket(data: message.data(using: .utf8), opcode: .text)
    }
}
