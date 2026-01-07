import Foundation
import Network

protocol RemoteControlWebUIDelegate: AnyObject {
    func remoteControlWebUIGetStatus()
        -> (RemoteControlStatusGeneral, RemoteControlStatusTopLeft, RemoteControlStatusTopRight)
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
    private var connection: NWConnection?

    func reload() {
        stop()
        start()
    }

    func log(entry: String) {
        guard let connection else {
            return
        }
        send(connection: connection, message: .event(data: .log(entry: entry)))
    }

    private func start() {
        let routes = staticPaths.map {
            HttpServerRoute(path: $0.makePath(), handler: handleStatic)
        }
        server = HttpServer(queue: .main, routes: routes)
        server?.start(port: .init(integer: 80))
        let parameters = NWParameters.tcp
        let options = NWProtocolWebSocket.Options()
        options.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.append(options)
        websocketServer = try? NWListener(using: parameters, on: NWEndpoint.Port(rawValue: 81)!)
        websocketServer?.newConnectionHandler = handleNewWebsocketConnection
        websocketServer?.stateUpdateHandler = handleWebsocketStateUpdate
        websocketServer?.start(queue: .main)
    }

    private func stop() {
        server?.stop()
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
        self.connection = connection
        connection.start(queue: .main)
        receiveWebsocketPacket(connection: connection)
    }

    private func handleWebsocketStateUpdate(_: NWListener.State) {}

    private func receiveWebsocketPacket(connection: NWConnection) {
        connection.receiveMessage { data, context, _, _ in
            switch context?.webSocketOperation() {
            case .text:
                if let data, !data.isEmpty {
                    self.handleWebsocketMessage(connection: connection, packet: data)
                    self.receiveWebsocketPacket(connection: connection)
                } else {
                    // self.handleDisconnected(webSocket: webSocket)
                }
            case .ping:
                connection.sendWebSocket(data: data, opcode: .pong)
                self.receiveWebsocketPacket(connection: connection)
            case .pong:
                // self.handlePong(webSocket: webSocket)
                self.receiveWebsocketPacket(connection: connection)
            default:
                break
                // self.handleDisconnected(webSocket: webSocket)
            }
        }
    }

    private func handleWebsocketMessage(connection: NWConnection, packet: Data) {
        guard let message = String(bytes: packet, encoding: .utf8) else {
            return
        }
        do {
            switch try RemoteControlMessageToStreamer.fromJson(data: message) {
            case .hello:
                break
            case .identified:
                break
            case let .request(id: id, data: data):
                handleRequest(connection: connection, id: id, data: data)
            case .pong:
                break
                // gotPong = true
            }
        } catch {
            logger.info("remote-control-web-ui: Decode failed")
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
}
