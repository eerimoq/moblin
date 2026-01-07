import Foundation
import Network

protocol RemoteControlWebUIDelegate: AnyObject {
    func remoteControlWebUIConnected()
    func remoteControlWebUIGetStatus()
        -> (RemoteControlStatusGeneral, RemoteControlStatusTopLeft, RemoteControlStatusTopRight)
    func remoteControlWebUISetDebugLogging(on: Bool)
}

private struct StaticPath {
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

private let staticPaths: [StaticPath] = [
    StaticPath("/", "index", "html"),
    StaticPath("/css/", "vanilla-framework-version-4.14.0.min", "css"),
    StaticPath("/css/", "f3b9cc97-Ubuntu[wdth,wght]-latin", "woff2"),
    StaticPath("/css/", "c1b12cdf-Ubuntu-Italic[wdth,wght]-latin", "woff2"),
    StaticPath("/css/", "0bd4277a-UbuntuMono[wght]-latin", "woff2"),
    StaticPath("/js/", "index", "mjs"),
    StaticPath("/js/", "utils", "mjs"),
]

class RemoteControlWebUI {
    private var server: HttpServer?
    private var websocketServer: NWListener?
    weak var delegate: (any RemoteControlWebUIDelegate)?
    private var connections: [NWConnection] = []

    func start(port: Int) {
        startServer(port: port)
        startWebsocketServer(port: port + 1)
    }

    func stop() {
        stopServer()
        stopWebsocketServer()
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

    private func startServer(port: Int) {
        let routes = staticPaths.map {
            HttpServerRoute(path: $0.makePath(), handler: handleStatic)
        }
        server = HttpServer(queue: .main, routes: routes)
        server?.start(port: .init(integer: port))
    }

    private func startWebsocketServer(port: Int) {
        let parameters = NWParameters.tcp
        let options = NWProtocolWebSocket.Options()
        options.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.append(options)
        websocketServer = try? NWListener(using: parameters, on: .init(integer: port))
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
        websocketServer?.cancel()
        websocketServer = nil
    }

    private func handleStatic(request: HttpServerRequest, response: HttpServerResponse) {
        guard request.method == "GET",
              let staticPath = staticPaths.first(where: {
                  request.path == $0.makePath()
              })
        else {
            return
        }
        response.send(text: loadStringResource(name: staticPath.name, ext: staticPath.ext))
    }

    private func handleNewWebsocketConnection(_ connection: NWConnection) {
        connections.append(connection)
        connection.start(queue: .main)
        receiveWebsocketPacket(connection: connection)
        delegate?.remoteControlWebUIConnected()
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
            let (general, topLeft, topRight) = delegate.remoteControlWebUIGetStatus()
            send(connection: connection,
                 message: .response(
                     id: id,
                     result: .ok,
                     data: .getStatus(general: general, topLeft: topLeft, topRight: topRight)
                 ))
        case let .setDebugLogging(on: on):
            delegate.remoteControlWebUISetDebugLogging(on: on)
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
