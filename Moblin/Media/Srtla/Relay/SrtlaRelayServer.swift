import Collections
import CryptoKit
import Foundation
import Network
import SwiftUI
import Telegraph

private let srtlaRelayServerQueue = DispatchQueue(label: "com.eerimoq.srtla-relay-server")

protocol SrtlaRelayServerDelegate: AnyObject {
    func srtlaRelayServerStatusChanged(status: String)
    func srtlaRelayServerGetBatteryPercentage() -> Int
}

private class Client {
    let webSocket: Telegraph.WebSocket
    private var identified = false
    private var challenge = ""
    private var salt = ""
    private let password: String
    weak var server: SrtlaRelayServer!
    private var clientListener: NWListener?
    private var clientConnection: NWConnection?
    private var destinationConnection: NWConnection?
    private var destination: NWEndpoint?
    private var startTunnelId: Int?

    init(websocket: Telegraph.WebSocket, password: String, server: SrtlaRelayServer) {
        self.password = password
        webSocket = websocket
        self.server = server
    }

    func start() {
        challenge = randomString()
        salt = randomString()
        send(message: .hello(
            apiVersion: srtlaRelayApiVersion,
            id: UUID(uuidString: server.id) ?? .init(),
            name: server.name,
            authentication: .init(challenge: challenge, salt: salt)
        ))
        identified = false
    }

    func stop() {
        webSocket.close(immediately: true)
    }

    func handleStringMessage(message: String) {
        // logger.info("srtla-relay-server: Received \(message)")
        do {
            let message = try SrtlaRelayMessageToServer.fromJson(data: message)
            switch message {
            case let .identify(authentication: authentication):
                try handleIdentify(authentication: authentication)
            case let .request(id: id, data: data):
                try handleRequest(id: id, data: data)
            }
        } catch {
            logger.info("srtla-relay-server: Failed to process message with error \(error)")
            webSocket.close(immediately: false)
        }
    }

    private func handleIdentify(authentication: String) throws {
        if authentication == remoteControlHashPassword(challenge: challenge, salt: salt, password: password) {
            identified = true
            send(message: .identified(result: .ok))
        } else {
            send(message: .identified(result: .wrongPassword))
            throw "Client sent wrong password"
        }
    }

    private func handleRequest(id: Int, data: SrtlaRelayRequest) throws {
        guard identified else {
            throw "Streamer not identified"
        }
        switch data {
        case let .startTunnel(address: address, port: port):
            handleStartTunnel(id: id, address: address, port: port)
        case .status:
            handleStatus(id: id)
        }
    }

    private func handleStartTunnel(id: Int, address: String, port: UInt16) {
        stopTunnel()
        logger.info("srtla-relay-server: Start tunnel to \(address):\(port)")
        destination = .hostPort(host: NWEndpoint.Host(address), port: NWEndpoint.Port(integerLiteral: port))
        do {
            let options = NWProtocolUDP.Options()
            let parameters = NWParameters(dtls: .none, udp: options)
            clientListener = try NWListener(using: parameters)
            clientListener?.stateUpdateHandler = handleListenerStateChange
            clientListener?.newConnectionHandler = handleNewListenerConnection
            clientListener?.start(queue: srtlaRelayServerQueue)
        } catch {
            logger.error("srtla-relay-server: Failed to create server listener with error \(error)")
        }
        let params = NWParameters(dtls: .none)
        params.requiredInterfaceType = .cellular
        params.prohibitExpensivePaths = false
        guard case let .hostPort(host, port) = destination else {
            return
        }
        destinationConnection = NWConnection(host: host, port: port, using: params)
        destinationConnection?.stateUpdateHandler = handleDestinationStateUpdate(to:)
        destinationConnection?.start(queue: srtlaRelayServerQueue)
        receiveDestinationPacket()
        startTunnelId = id
    }

    private func handleStatus(id: Int) {
        let batteryPercentage = server?.delegate?.srtlaRelayServerGetBatteryPercentage()
        send(message: .response(id: id, result: .ok, data: .status(batteryPercentage: batteryPercentage)))
    }

    private func send(message: SrtlaRelayMessageToClient) {
        guard let text = message.toJson() else {
            return
        }
        // logger.info("srtla-relay-server: Sending \(text)")
        webSocket.send(text: text)
    }

    func stopTunnel() {
        clientListener?.stateUpdateHandler = nil
        clientListener?.cancel()
        clientListener = nil
        clientConnection?.stateUpdateHandler = nil
        clientConnection?.cancel()
        clientConnection = nil
        destinationConnection?.stateUpdateHandler = nil
        destinationConnection?.cancel()
        destinationConnection = nil
    }

    private func handleListenerStateChange(to state: NWListener.State) {
        switch state {
        case .setup:
            break
        case .ready:
            guard let clientListener = clientListener, let startTunnelId = startTunnelId else {
                return
            }
            let port = clientListener.port!.rawValue
            send(message: .response(id: startTunnelId, result: .ok, data: .startTunnel(port: port)))
        default:
            break
        }
    }

    private func handleNewListenerConnection(connection: NWConnection) {
        clientConnection = connection
        clientConnection?.start(queue: srtlaRelayServerQueue)
        receiveServerPacket()
    }

    private func handleDestinationStateUpdate(to state: NWConnection.State) {
        logger.debug("srtla-relay-client: Destination state change to \(state)")
    }

    private func receiveServerPacket() {
        clientConnection?.receiveMessage { data, _, _, error in
            if let data, !data.isEmpty {
                self.handlePacketFromServer(packet: data)
            }
            if let error {
                logger.info("srtla-relay-server: Server receive error \(error)")
                return
            }
            self.receiveServerPacket()
        }
    }

    private func handlePacketFromServer(packet: Data) {
        destinationConnection?.send(content: packet, completion: .contentProcessed { _ in
        })
    }

    private func receiveDestinationPacket() {
        destinationConnection?.receiveMessage { data, _, _, error in
            if let data, !data.isEmpty {
                self.handlePacketFromDestination(packet: data)
            }
            if let error {
                logger.info("srtla-relay-server: Destination receive error \(error)")
                return
            }
            self.receiveDestinationPacket()
        }
    }

    private func handlePacketFromDestination(packet: Data) {
        clientConnection?.send(content: packet, completion: .contentProcessed { _ in
        })
    }
}

class SrtlaRelayServer: NSObject {
    @AppStorage("srtlaRelayId") var id = ""
    let name: String
    private let port: UInt16
    private let password: String
    private var server: Server
    var connectionErrorMessage = ""
    private var retryStartTimer = SimpleTimer(queue: .main)
    fileprivate weak var delegate: (any SrtlaRelayServerDelegate)?
    private var clients: [Client] = []

    init(name: String, port: UInt16, password: String) {
        self.name = name
        self.port = port
        self.password = password
        server = Server()
        super.init()
        if id.isEmpty {
            id = UUID().uuidString
        }
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
        server.stop(immediately: false)
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
        let client = Client(websocket: webSocket, password: password, server: self)
        client.start()
        clients.append(client)
        updateStatus()
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
        updateStatus()
    }

    private func handleMessage(webSocket: Telegraph.WebSocket, message: Telegraph.WebSocketMessage) {
        switch message.payload {
        case let .text(data):
            // logger.info("srtla-relay-server: Got \(data)")
            let client = clients.first(where: { $0.webSocket.isSame(other: webSocket) })
            client?.handleStringMessage(message: data)
        default:
            break
        }
    }

    func updateStatus() {
        var status: String
        if clients.count == 1 {
            status = "1 streamer connected"
        } else {
            status = "\(clients.count) streamers connected"
        }
        delegate?.srtlaRelayServerStatusChanged(status: status)
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
