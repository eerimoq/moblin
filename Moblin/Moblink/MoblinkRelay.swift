import Foundation
import Network
import SwiftUI

private let moblinkRelayQueue = DispatchQueue(label: "com.eerimoq.moblink-relay")

enum MoblinkRelayState: String {
    case none = "None"
    case connecting = "Connecting"
    case connected = "Connected"
    case waitingForCellular = "Waiting for cellular"
    case wrongPassword = "Wrong password"
    case unknownError = "Unknown error"
}

protocol MoblinkRelayDelegate: AnyObject {
    func moblinkRelayNewState(state: MoblinkRelayState)
    func moblinkRelayGetBatteryPercentage() -> Int
}

private class Relay: NSObject {
    private var clientUrl: URL
    private var password: String
    private weak var delegate: (any MoblinkRelayDelegate)?
    private var webSocket: WebSocketClient
    private let name: String
    private var startTunnelId: Int?
    private var destination: NWEndpoint?
    private var streamerListener: NWListener?
    private var streamerConnection: NWConnection?
    private var destinationConnection: NWConnection?
    private var state: MoblinkRelayState = .none
    private var started = false
    private let reconnectTimer = SimpleTimer(queue: .main)
    private var cellularInterface: NWInterface?
    private var id: String

    init(id: String, name: String, clientUrl: URL, password: String, delegate: MoblinkRelayDelegate) {
        self.id = id
        self.name = name
        self.clientUrl = clientUrl
        self.password = password
        self.delegate = delegate
        webSocket = .init(url: clientUrl)
    }

    func start() {
        logger.info("moblink-client: Start")
        started = true
        startInternal()
    }

    func stop() {
        logger.info("moblink-client: Stop")
        stopInternal()
        started = false
    }

    func setInterface(interface: NWInterface?) {
        cellularInterface = interface
    }

    private func startInternal() {
        guard started else {
            return
        }
        stopInternal()
        setState(state: .connecting)
        webSocket = .init(url: clientUrl, cellular: false)
        webSocket.delegate = self
        webSocket.start()
    }

    private func stopInternal() {
        reconnectTimer.stop()
        setState(state: .none)
        webSocket.delegate = nil
        webSocket.stop()
        stopTunnel()
    }

    private func reconnect(reason: String) {
        logger.info("moblink-client: Reconnecting soon with reason \(reason)")
        stopInternal()
        reconnectTimer.startSingleShot(timeout: 5.0) {
            self.startInternal()
        }
    }

    private func setState(state: MoblinkRelayState) {
        guard state != self.state else {
            return
        }
        logger.info("moblink-client: State change \(self.state) -> \(state)")
        self.state = state
        delegate?.moblinkRelayNewState(state: state)
    }

    private func send(message: MoblinkMessageToStreamer) {
        do {
            let message = try message.toJson()
            webSocket.send(string: message)
        } catch {
            logger.info("moblink-client: Encode failed")
        }
    }

    private func handleMessage(message: String) throws {
        do {
            switch try MoblinkMessageToRelay.fromJson(data: message) {
            case let .hello(apiVersion: apiVersion, authentication: authentication):
                handleHello(apiVersion: apiVersion, authentication: authentication)
            case let .identified(result: result):
                if !handleIdentified(result: result) {
                    logger.info("moblink-client: Failed to identify")
                    return
                }
                setState(state: .connected)
            case let .request(id: id, data: data):
                handleRequest(id: id, data: data)
            }
        } catch {
            logger.info("moblink-client: Decode failed")
        }
    }

    private func handleHello(apiVersion _: String, authentication: MoblinkAuthentication) {
        let hash = remoteControlHashPassword(
            challenge: authentication.challenge,
            salt: authentication.salt,
            password: password
        )
        guard let id = UUID(uuidString: id) else {
            return
        }
        send(message: .identify(id: id, name: name, authentication: hash))
    }

    private func handleIdentified(result: MoblinkResult) -> Bool {
        switch result {
        case .ok:
            return true
        case .wrongPassword:
            reconnect(reason: "Wrong password")
            setState(state: .wrongPassword)
        default:
            reconnect(reason: "Unknown error")
            setState(state: .unknownError)
        }
        return false
    }

    private func handleRequest(id: Int, data: MoblinkRequest) {
        switch data {
        case let .startTunnel(address: address, port: port):
            handleStartTunnel(id: id, address: address, port: port)
        case .status:
            handleStatus(id: id)
        }
    }

    private func handleStartTunnel(id: Int, address: String, port: UInt16) {
        stopTunnel()
        logger.info("moblink-client: Start tunnel to \(address):\(port)")
        destination = .hostPort(host: NWEndpoint.Host(address), port: NWEndpoint.Port(integerLiteral: port))
        do {
            let options = NWProtocolUDP.Options()
            let parameters = NWParameters(dtls: .none, udp: options)
            streamerListener = try NWListener(using: parameters)
        } catch {
            logger.error("moblink-client: Failed to create streamer listener with error \(error)")
            reconnect(reason: "Failed to create listener")
            return
        }
        streamerListener?.stateUpdateHandler = handleListenerStateChange(to:)
        streamerListener?.newConnectionHandler = handleNewListenerConnection(connection:)
        streamerListener?.start(queue: moblinkRelayQueue)
        guard let cellularInterface else {
            reconnect(reason: "No cellular interface")
            return
        }
        let params = NWParameters(dtls: .none)
        params.requiredInterface = cellularInterface
        params.prohibitExpensivePaths = false
        guard case let .hostPort(host, port) = destination else {
            reconnect(reason: "Failed to parse host and port")
            return
        }
        destinationConnection = NWConnection(host: host, port: port, using: params)
        destinationConnection?.stateUpdateHandler = handleDestinationStateUpdate(to:)
        destinationConnection?.start(queue: moblinkRelayQueue)
        receiveDestinationPacket()
        setState(state: .waitingForCellular)
        startTunnelId = id
    }

    private func handleStatus(id: Int) {
        let batteryPercentage = delegate?.moblinkRelayGetBatteryPercentage()
        send(message: .response(id: id, result: .ok, data: .status(batteryPercentage: batteryPercentage)))
    }

    private func stopTunnel() {
        streamerListener?.stateUpdateHandler = nil
        streamerListener?.cancel()
        streamerListener = nil
        streamerConnection?.stateUpdateHandler = nil
        streamerConnection?.cancel()
        streamerConnection = nil
        destinationConnection?.stateUpdateHandler = nil
        destinationConnection?.cancel()
        destinationConnection = nil
        startTunnelId = nil
    }

    private func handleListenerStateChange(to state: NWListener.State) {
        DispatchQueue.main.async {
            switch state {
            case .setup:
                break
            case .ready:
                guard let streamerListener = self.streamerListener, let startTunnelId = self.startTunnelId else {
                    return
                }
                let port = streamerListener.port!.rawValue
                self.send(message: .response(id: startTunnelId, result: .ok, data: .startTunnel(port: port)))
            case .failed:
                self.reconnect(reason: "Listener failed")
            default:
                break
            }
        }
    }

    private func handleDestinationStateUpdate(to state: NWConnection.State) {
        logger.debug("moblink-client: Destination state change to \(state)")
        DispatchQueue.main.async {
            switch state {
            case .ready:
                self.setState(state: .connected)
            case .failed:
                self.reconnect(reason: "Destination connection failed")
            default:
                self.setState(state: .waitingForCellular)
            }
        }
    }

    private func handleNewListenerConnection(connection: NWConnection) {
        streamerConnection = connection
        streamerConnection?.start(queue: moblinkRelayQueue)
        receiveStreamerPacket()
    }

    private func receiveStreamerPacket() {
        streamerConnection?.receiveMessage { data, _, _, error in
            if let data, !data.isEmpty {
                self.handlePacketFromStreamer(packet: data)
            }
            if let error {
                logger.info("moblink-client: Streamer receive error \(error)")
                DispatchQueue.main.async {
                    self.reconnect(reason: "Streamer receive error")
                }
                return
            }
            self.receiveStreamerPacket()
        }
    }

    private func handlePacketFromStreamer(packet: Data) {
        destinationConnection?.send(content: packet, completion: .contentProcessed { _ in
        })
    }

    private func receiveDestinationPacket() {
        destinationConnection?.receiveMessage { data, _, _, error in
            if let data, !data.isEmpty {
                self.handlePacketFromDestination(packet: data)
            }
            if let error {
                logger.info("moblink-client: Destination receive error \(error)")
                DispatchQueue.main.async {
                    self.reconnect(reason: "Destination receive error")
                }
                return
            }
            self.receiveDestinationPacket()
        }
    }

    private func handlePacketFromDestination(packet: Data) {
        streamerConnection?.send(content: packet, completion: .contentProcessed { _ in
        })
    }
}

extension Relay: WebSocketClientDelegate {
    func webSocketClientConnected(_: WebSocketClient) {}

    func webSocketClientDisconnected(_: WebSocketClient) {
        setState(state: .connecting)
        stopTunnel()
    }

    func webSocketClientReceiveMessage(_: WebSocketClient, string: String) {
        try? handleMessage(message: string)
    }
}

class MoblinkRelay: NSObject {
    private var relay: Relay?
    private let networkPathMonitor = NWPathMonitor()
    @AppStorage("srtlaRelayId") var id = ""

    init(name: String, clientUrl: URL, password: String, delegate: MoblinkRelayDelegate) {
        super.init()
        if id.isEmpty {
            id = UUID().uuidString
        }
        relay = Relay(id: id, name: name, clientUrl: clientUrl, password: password, delegate: delegate)
    }

    func start() {
        relay?.start()
        networkPathMonitor.pathUpdateHandler = handleNetworkPathUpdate(path:)
        networkPathMonitor.start(queue: .main)
    }

    func stop() {
        relay?.stop()
        networkPathMonitor.cancel()
    }

    private func handleNetworkPathUpdate(path: NWPath) {
        relay?.setInterface(interface: path.availableInterfaces.first(where: { $0.type == .cellular }))
    }
}
