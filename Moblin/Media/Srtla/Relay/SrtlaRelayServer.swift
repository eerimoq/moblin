import Collections
import CryptoKit
import Foundation
import Network
import Telegraph

protocol SrtlaRelayServerDelegate: AnyObject {
    func srtlaRelayServerTunnelAdded(endpoint: NWEndpoint, relayId: UUID, relayName: String)
    func srtlaRelayServerTunnelRemoved(endpoint: NWEndpoint)
}

private struct SrtlaRelayRequestResponse {
    let onSuccess: (SrtlaRelayResponse?) -> Void
    let onError: (String) -> Void
}

private class Client {
    let webSocket: Telegraph.WebSocket
    private var nextId: Int = 0
    private var identified = false
    private var challenge = ""
    private var salt = ""
    private var requests: [Int: SrtlaRelayRequestResponse] = [:]
    private let password: String
    private let destination: NWEndpoint
    weak var server: SrtlaRelayServer?
    private var tunnelEndpoint: NWEndpoint?
    private var id = UUID()
    private var name = ""

    init(websocket: Telegraph.WebSocket, password: String, destination: NWEndpoint, server: SrtlaRelayServer) {
        self.password = password
        webSocket = websocket
        self.destination = destination
        self.server = server
    }

    func start() {
        challenge = randomString()
        salt = randomString()
        send(message: .hello(
            apiVersion: remoteControlApiVersion,
            authentication: .init(challenge: challenge, salt: salt)
        ))
        identified = false
    }

    func stop() {
        guard let tunnelEndpoint else {
            return
        }
        server?.delegate?.srtlaRelayServerTunnelRemoved(endpoint: tunnelEndpoint)
    }

    func handleStringMessage(message: String) {
        // logger.info("srtla-relay-server: Received \(message)")
        do {
            let message = try SrtlaRelayMessageToServer.fromJson(data: message)
            switch message {
            case let .identify(id: id, name: name, authentication: authentication):
                handleIdentify(id: id, name: name, authentication: authentication)
            case let .response(id: id, result: result, data: data):
                try handleResponse(id: id, result: result, data: data)
            }
        } catch {
            logger.info("srtla-relay-server: Failed to process message with error \(error)")
        }
    }

    private func startTunnel(address: String, port: UInt16, onSuccess: @escaping (UUID, String, UInt16) -> Void) {
        logger.info("srtla-relay-server: Starting tunnel to destination \(address):\(port)")
        performRequest(data: .startTunnel(address: address, port: port)) { response in
            guard let response else {
                return
            }
            switch response {
            case let .startTunnel(port: port):
                onSuccess(self.id, self.name, port)
            }
        } onError: { error in
            logger.info("srtla-relay-server: Start tunnel failed with \(error)")
        }
    }

    private func handleIdentify(id: UUID, name: String, authentication: String) {
        if authentication == remoteControlHashPassword(
            challenge: challenge,
            salt: salt,
            password: password
        ) {
            self.id = id
            self.name = name
            identified = true
            send(message: .identified(result: .ok))
            guard case let .hostPort(host, port) = destination else {
                return
            }
            startTunnel(address: "\(host)", port: port.rawValue) { id, name, port in
                guard let host = self.webSocket.remoteEndpoint?.host else {
                    logger.info("srtla-relay-server: Missing relay host")
                    return
                }
                let endpoint = NWEndpoint.hostPort(
                    host: NWEndpoint.Host(host),
                    port: NWEndpoint.Port(integerLiteral: port)
                )
                self.tunnelEndpoint = endpoint
                self.server?.delegate?.srtlaRelayServerTunnelAdded(endpoint: endpoint, relayId: id, relayName: name)
            }
        } else {
            logger.info("srtla-relay-server: Streamer sent wrong password")
            send(message: .identified(result: .wrongPassword))
            webSocket.close(immediately: false)
        }
    }

    private func handleResponse(id: Int, result: SrtlaRelayResult, data: SrtlaRelayResponse?) throws {
        guard identified else {
            throw "Streamer not identified"
        }
        guard let request = requests[id] else {
            logger.info("srtla-relay-server: Unexpected id in response")
            return
        }
        switch result {
        case .ok:
            request.onSuccess(data)
        case .wrongPassword:
            request.onError("Wrong password")
        case .notIdentified:
            logger.info("srtla-relay-server: Not identified")
        case .alreadyIdentified:
            logger.info("srtla-relay-server: Already identified")
        case .unknownRequest:
            logger.info("srtla-relay-server: Unknown request")
        }
    }

    private func performRequest(
        data: SrtlaRelayRequest,
        onSuccess: @escaping (SrtlaRelayResponse?) -> Void,
        onError: @escaping (String) -> Void
    ) {
        let id = getNextId()
        requests[id] = SrtlaRelayRequestResponse(onSuccess: onSuccess, onError: onError)
        send(message: .request(id: id, data: data))
    }

    private func getNextId() -> Int {
        nextId += 1
        return nextId
    }

    private func send(message: SrtlaRelayMessageToClient) {
        guard let text = message.toJson() else {
            return
        }
        // logger.info("srtla-relay-server: Sending \(text)")
        webSocket.send(text: text)
    }
}

class SrtlaRelayServer: NSObject {
    private let port: UInt16
    private let password: String
    private let destination: NWEndpoint
    private var server: Server
    var connectionErrorMessage = ""
    private var retryStartTimer = SimpleTimer(queue: .main)
    fileprivate weak var delegate: (any SrtlaRelayServerDelegate)?
    private var clients: [Client] = []

    init(port: UInt16, password: String, destination: NWEndpoint) {
        self.port = port
        self.password = password
        self.destination = destination
        server = Server()
        super.init()
        server.webSocketConfig.pingInterval = 10
        server.webSocketConfig.readTimeout = 20
        server.webSocketDelegate = self
    }

    func start(delegate: SrtlaRelayServerDelegate) {
        stop()
        logger.info("srtla-relay-server: start")
        self.delegate = delegate
        startInternal()
    }

    func stop() {
        logger.info("srtla-relay-server: stop")
        server.stop(immediately: true)
        stopRetryStartTimer()
        for client in clients {
            client.stop()
        }
        clients.removeAll()
        delegate = nil
    }

    private func startInternal() {
        do {
            try server.start(port: Endpoint.Port(port))
            stopRetryStartTimer()
        } catch {
            logger.debug("srtla-relay-server: Failed to start server with error \(error)")
            connectionErrorMessage = error.localizedDescription
            startRetryStartTimer()
        }
    }

    private func startRetryStartTimer() {
        retryStartTimer.startSingleShot(timeout: 5) {
            self.startInternal()
        }
    }

    private func stopRetryStartTimer() {
        retryStartTimer.stop()
    }

    private func handleConnected(webSocket: Telegraph.WebSocket) {
        logger.info("srtla-relay-server: Client connected")
        let client = Client(websocket: webSocket, password: password, destination: destination, server: self)
        client.start()
        clients.append(client)
    }

    private func handleDisconnected(webSocket: Telegraph.WebSocket, error: Error?) {
        if let error {
            logger.info("srtla-relay-server: Client disconnected \(error)")
        } else {
            logger.info("srtla-relay-server: Client disconnected")
        }
        if let client = clients.first(where: { $0.webSocket.isSame(other: webSocket) }) {
            client.stop()
        }
        clients.removeAll(where: { $0.webSocket.isSame(other: webSocket) })
    }

    private func handleMessage(webSocket: Telegraph.WebSocket, message: Telegraph.WebSocketMessage) {
        switch message.payload {
        case let .text(data):
            // logger.info("srtla-relay-server: Got \(data)")
            guard let client = clients.first(where: { $0.webSocket.isSame(other: webSocket) }) else {
                return
            }
            client.handleStringMessage(message: data)
        default:
            break
        }
    }
}

extension SrtlaRelayServer: ServerWebSocketDelegate {
    func server(
        _: Telegraph.Server,
        webSocketDidConnect webSocket: Telegraph.WebSocket,
        handshake _: Telegraph.HTTPRequest
    ) {
        DispatchQueue.main.async {
            self.handleConnected(webSocket: webSocket)
        }
    }

    func server(_: Telegraph.Server, webSocketDidDisconnect webSocket: Telegraph.WebSocket, error: Error?) {
        DispatchQueue.main.async {
            self.handleDisconnected(webSocket: webSocket, error: error)
        }
    }

    func server(
        _: Telegraph.Server,
        webSocket: Telegraph.WebSocket,
        didReceiveMessage message: Telegraph.WebSocketMessage
    ) {
        DispatchQueue.main.async {
            self.handleMessage(webSocket: webSocket, message: message)
        }
    }
}
