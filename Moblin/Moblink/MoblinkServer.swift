import Collections
import CryptoKit
import Foundation
import Network
import Telegraph

protocol MoblinkServerDelegate: AnyObject {
    func moblinkServerTunnelAdded(endpoint: NWEndpoint, relayId: UUID, relayName: String)
    func moblinkServerTunnelRemoved(endpoint: NWEndpoint)
}

private struct RequestResponse {
    let onSuccess: (MoblinkResponse?) -> Void
    let onError: (String) -> Void
}

private class Client {
    let webSocket: Telegraph.WebSocket
    private var nextId: Int = 0
    private var identified = false
    private var challenge = ""
    private var salt = ""
    private var requests: [Int: RequestResponse] = [:]
    private let password: String
    private var address: String?
    private var port: UInt16?
    weak var server: MoblinkServer?
    private var tunnelEndpoint: NWEndpoint?
    private var relayId = UUID()
    var name = ""
    var batteryPercentage: Int?

    init(websocket: Telegraph.WebSocket, password: String, server: MoblinkServer) {
        self.password = password
        webSocket = websocket
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
        webSocket.close(immediately: true)
        reportTunnelRemoved()
        requests.removeAll()
    }

    func handleStringMessage(message: String) {
        // logger.info("moblink-server: Received \(message)")
        do {
            let message = try MoblinkMessageToServer.fromJson(data: message)
            switch message {
            case let .identify(id: relayId, name: name, authentication: authentication):
                try handleIdentify(relayId: relayId, name: name, authentication: authentication)
            case let .response(id: id, result: result, data: data):
                try handleResponse(id: id, result: result, data: data)
            }
        } catch {
            logger.info("moblink-server: Failed to process message with error \(error)")
            webSocket.close(immediately: false)
        }
    }

    func startTunnel(address: String, port: UInt16) {
        self.address = address
        self.port = port
        startTunnelInternal()
    }

    func stopTunnel() {
        reportTunnelRemoved()
    }

    func updateStatus() {
        performRequest(data: .status) { response in
            guard case let .status(batteryPercentage: batteryPercentage) = response else {
                return
            }
            self.batteryPercentage = batteryPercentage
        } onError: { error in
            logger.info("moblink-server: Status failed with \(error)")
        }
    }

    private func startTunnelInternal() {
        guard identified, let address, let port else {
            return
        }
        reportTunnelRemoved()
        executeStartTunnel(address: address, port: port) { id, name, port in
            guard let host = self.webSocket.remoteEndpoint?.host else {
                logger.info("moblink-server: Missing relay host")
                return
            }
            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: port)
            )
            self.tunnelEndpoint = endpoint
            self.server?.delegate?.moblinkServerTunnelAdded(endpoint: endpoint, relayId: id, relayName: name)
        }
    }

    private func reportTunnelRemoved() {
        if let tunnelEndpoint {
            server?.delegate?.moblinkServerTunnelRemoved(endpoint: tunnelEndpoint)
        }
        tunnelEndpoint = nil
    }

    private func executeStartTunnel(address: String, port: UInt16,
                                    onSuccess: @escaping (UUID, String, UInt16) -> Void)
    {
        logger.info("moblink-server: Starting tunnel to destination \(address):\(port)")
        performRequest(data: .startTunnel(address: address, port: port)) { response in
            guard case let .startTunnel(port: port) = response else {
                return
            }
            onSuccess(self.relayId, self.name, port)
        } onError: { error in
            logger.info("moblink-server: Start tunnel failed with \(error)")
        }
    }

    private func handleIdentify(relayId: UUID, name: String, authentication: String) throws {
        if authentication == remoteControlHashPassword(
            challenge: challenge,
            salt: salt,
            password: password
        ) {
            self.relayId = relayId
            self.name = name
            identified = true
            send(message: .identified(result: .ok))
            startTunnelInternal()
            updateStatus()
        } else {
            send(message: .identified(result: .wrongPassword))
            throw "Client sent wrong password"
        }
    }

    private func handleResponse(id: Int, result: MoblinkResult, data: MoblinkResponse?) throws {
        guard identified else {
            throw "Streamer not identified"
        }
        guard let request = requests[id] else {
            logger.info("moblink-server: Unexpected id in response")
            return
        }
        switch result {
        case .ok:
            request.onSuccess(data)
        case .wrongPassword:
            request.onError("Wrong password")
        case .notIdentified:
            logger.info("moblink-server: Not identified")
        case .alreadyIdentified:
            logger.info("moblink-server: Already identified")
        case .unknownRequest:
            logger.info("moblink-server: Unknown request")
        }
    }

    private func performRequest(
        data: MoblinkRequest,
        onSuccess: @escaping (MoblinkResponse?) -> Void,
        onError: @escaping (String) -> Void
    ) {
        let id = getNextId()
        requests[id] = RequestResponse(onSuccess: onSuccess, onError: onError)
        send(message: .request(id: id, data: data))
    }

    private func getNextId() -> Int {
        nextId += 1
        return nextId
    }

    private func send(message: MoblinkMessageToClient) {
        guard let text = message.toJson() else {
            return
        }
        // logger.info("moblink-server: Sending \(text)")
        webSocket.send(text: text)
    }
}

class MoblinkServer: NSObject {
    private let port: UInt16
    private let password: String
    private var server: Server
    var connectionErrorMessage = ""
    private var retryStartTimer = SimpleTimer(queue: .main)
    fileprivate weak var delegate: (any MoblinkServerDelegate)?
    private var clients: [Client] = []
    private var destinationAddress: String?
    private var destinationPort: UInt16?

    init(port: UInt16, password: String) {
        self.port = port
        self.password = password
        server = Server()
        super.init()
        server.webSocketConfig.pingInterval = 10
        server.webSocketConfig.readTimeout = 20
        server.webSocketDelegate = self
    }

    func start(delegate: MoblinkServerDelegate) {
        stop()
        logger.info("moblink-server: start")
        self.delegate = delegate
        startInternal()
    }

    func stop() {
        logger.info("moblink-server: stop")
        server.stop(immediately: false)
        stopRetryStartTimer()
        for client in clients {
            client.stop()
        }
        clients.removeAll()
        delegate = nil
    }

    func startTunnels(address: String, port: UInt16) {
        destinationAddress = address
        destinationPort = port
        for client in clients {
            client.startTunnel(address: address, port: port)
        }
    }

    func stopTunnels() {
        destinationAddress = nil
        destinationPort = nil
        for client in clients {
            client.stopTunnel()
        }
    }

    func getStatuses() -> [(String, Int?)] {
        return clients.map { ($0.name, $0.batteryPercentage) }
    }

    func updateStatus() {
        for client in clients {
            client.updateStatus()
        }
    }

    private func startInternal() {
        do {
            try server.start(port: Endpoint.Port(port))
            stopRetryStartTimer()
        } catch {
            logger.debug("moblink-server: Failed to start server with error \(error)")
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
        logger.info("moblink-server: Client connected")
        let client = Client(websocket: webSocket, password: password, server: self)
        client.start()
        clients.append(client)
        guard let destinationAddress, let destinationPort else {
            return
        }
        client.startTunnel(address: destinationAddress, port: destinationPort)
    }

    private func handleDisconnected(webSocket: Telegraph.WebSocket, error: Error?) {
        if let error {
            logger.info("moblink-server: Client disconnected \(error)")
        } else {
            logger.info("moblink-server: Client disconnected")
        }
        if let client = clients.first(where: { $0.webSocket.isSame(other: webSocket) }) {
            client.stop()
        }
        clients.removeAll(where: { $0.webSocket.isSame(other: webSocket) })
    }

    private func handleMessage(webSocket: Telegraph.WebSocket, message: Telegraph.WebSocketMessage) {
        switch message.payload {
        case let .text(data):
            // logger.info("moblink-server: Got \(data)")
            guard let client = clients.first(where: { $0.webSocket.isSame(other: webSocket) }) else {
                return
            }
            client.handleStringMessage(message: data)
        default:
            break
        }
    }
}

extension MoblinkServer: ServerWebSocketDelegate {
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
