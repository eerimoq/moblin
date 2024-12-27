import Foundation
import Network

private let srtlaRelayClientQueue = DispatchQueue(label: "com.eerimoq.srtla-relay-client")

private class Tunnel {
    private let destination: NWEndpoint
    private var serverListener: NWListener?
    private var serverConnection: NWConnection?
    private var destinationConnection: NWConnection?
    private var onListenerReady: ((NWEndpoint.Port) -> Void)?

    init(destination: NWEndpoint) {
        self.destination = destination
    }

    func start(onListenerReady: @escaping (NWEndpoint.Port) -> Void) {
        self.onListenerReady = onListenerReady
        do {
            let options = NWProtocolUDP.Options()
            let parameters = NWParameters(dtls: .none, udp: options)
            serverListener = try NWListener(using: parameters)
        } catch {
            logger.error("srtla-relay-client: Failed to create server listener with error \(error)")
            return
        }
        serverListener?.stateUpdateHandler = handleListenerStateChange(to:)
        serverListener?.newConnectionHandler = handleNewListenerConnection(connection:)
        serverListener?.start(queue: srtlaRelayClientQueue)
        let params = NWParameters(dtls: .none)
        params.requiredInterfaceType = .cellular
        params.prohibitExpensivePaths = false
        guard case let .hostPort(host, port) = destination else {
            return
        }
        destinationConnection = NWConnection(host: host, port: port, using: params)
        destinationConnection?.stateUpdateHandler = handleDestinationStateUpdate(to:)
        destinationConnection?.start(queue: srtlaRelayClientQueue)
    }

    func stop() {
        serverListener?.cancel()
        serverListener = nil
        serverConnection?.cancel()
        serverConnection = nil
        destinationConnection?.cancel()
        destinationConnection = nil
        onListenerReady = nil
    }

    private func handleListenerStateChange(to state: NWListener.State) {
        guard let serverListener else {
            return
        }
        switch state {
        case .setup:
            break
        case .ready:
            onListenerReady?(serverListener.port!)
            onListenerReady = nil
        default:
            break
        }
    }

    private func handleDestinationStateUpdate(to state: NWConnection.State) {
        logger.debug("srtla-relay-client: Destination state change to \(state)")
        switch state {
        case .ready:
            receiveDestinationPacket()
        default:
            break
        }
    }

    private func handleNewListenerConnection(connection: NWConnection) {
        serverConnection = connection
        serverConnection?.start(queue: srtlaRelayClientQueue)
        receiveServerPacket()
    }

    private func receiveServerPacket() {
        serverConnection?.receiveMessage { data, _, _, error in
            if let data, !data.isEmpty {
                self.handlePacketFromServer(packet: data)
            }
            if let error {
                logger.info("srtla-relay-client: Server receive error \(error)")
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
                logger.info("srtla-relay-client: Destination receive error \(error)")
                return
            }
            self.receiveDestinationPacket()
        }
    }

    private func handlePacketFromDestination(packet: Data) {
        serverConnection?.send(content: packet, completion: .contentProcessed { _ in
        })
    }
}

protocol SrtlaRelayClientDelegate: AnyObject {
    func srtlaRelayClientConnected()
    func srtlaRelayClientDisconnected()
}

class SrtlaRelayClient {
    private var clientUrl: URL
    private var password: String
    private weak var delegate: (any SrtlaRelayClientDelegate)?
    private var webSocket: WebSocketClient
    private var connected = false
    private var tunnels: [Tunnel] = []
    private var name: String

    init(name: String, clientUrl: URL, password: String, delegate: SrtlaRelayClientDelegate) {
        self.name = name
        self.clientUrl = clientUrl
        self.password = password
        self.delegate = delegate
        webSocket = .init(url: clientUrl)
    }

    func start() {
        logger.info("srtla-relay-client: start")
        startInternal()
    }

    func stop() {
        logger.info("srtla-relay-client: stop")
        stopInternal()
    }

    private func startInternal() {
        connected = false
        stopInternal()
        webSocket = .init(url: clientUrl)
        webSocket.delegate = self
        webSocket.start()
    }

    func stopInternal() {
        webSocket.stop()
    }

    private func send(message: SrtlaRelayMessageToServer) {
        do {
            let message = try message.toJson()
            webSocket.send(string: message)
        } catch {
            logger.info("srtla-relay-client: Encode failed")
        }
    }

    private func handleMessage(message: String) throws {
        do {
            switch try SrtlaRelayMessageToClient.fromJson(data: message) {
            case let .hello(apiVersion: apiVersion, authentication: authentication):
                handleHello(apiVersion: apiVersion, authentication: authentication)
            case let .identified(result: result):
                if !handleIdentified(result: result) {
                    logger.info("srtla-relay-client: Failed to identify")
                    return
                }
            case let .request(id: id, data: data):
                handleRequest(id: id, data: data)
            }
        } catch {
            logger.info("srtla-relay-client: Decode failed")
        }
    }

    private func handleHello(apiVersion _: String, authentication: SrtlaRelayAuthentication) {
        let hash = remoteControlHashPassword(
            challenge: authentication.challenge,
            salt: authentication.salt,
            password: password
        )
        send(message: .identify(authentication: hash))
    }

    private func handleIdentified(result: SrtlaRelayResult) -> Bool {
        switch result {
        case .ok:
            connected = true
            delegate?.srtlaRelayClientConnected()
            return true
        case .wrongPassword:
            break
        default:
            break
        }
        return false
    }

    private func handleRequest(id: Int, data: SrtlaRelayRequest) {
        switch data {
        case let .startTunnel(address: address, port: port):
            handleStartTunnel(id: id, address: address, port: port)
        }
    }

    private func handleStartTunnel(id: Int, address: String, port: UInt16) {
        logger.info("srtla-relay-client: Start tunnel to \(address):\(port)")
        let tunnel = Tunnel(destination: .hostPort(
            host: NWEndpoint.Host(address),
            port: NWEndpoint.Port(integerLiteral: port)
        ))
        tunnel.start { port in
            DispatchQueue.main.async {
                self.send(message: .response(
                    id: id,
                    result: .ok,
                    data: .startTunnel(name: self.name, port: port.rawValue)
                ))
            }
        }
        tunnels.append(tunnel)
    }
}

extension SrtlaRelayClient: WebSocketClientDelegate {
    func webSocketClientConnected(_: WebSocketClient) {
        logger.info("srtla-relay-client: Connected")
    }

    func webSocketClientDisconnected(_: WebSocketClient) {
        if connected {
            logger.info("srtla-relay-client: Disconnected")
            delegate?.srtlaRelayClientDisconnected()
        }
        connected = false
        for tunnel in tunnels {
            tunnel.stop()
        }
        tunnels.removeAll()
    }

    func webSocketClientReceiveMessage(_: WebSocketClient, string: String) {
        try? handleMessage(message: string)
    }
}
