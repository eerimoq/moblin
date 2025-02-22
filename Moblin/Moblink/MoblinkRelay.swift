import Foundation
import Network
import SwiftUI

private let moblinkRelayQueue = DispatchQueue(label: "com.eerimoq.moblink-relay")

enum MoblinkRelayState: String {
    case waitingForStreamers = "Waiting for streamers"
    case noInterface = "No interface"
    case connecting = "Connecting"
    case connected = "Connected"
    case wrongPassword = "Wrong password"
    case unknownError = "Unknown error"
}

private enum RelayState: String {
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
    private var streamerUrl: URL
    private var password: String
    private weak var delegate: MoblinkRelayDelegate?
    private var webSocket: WebSocketClient
    private let name: String
    private var startTunnelId: Int?
    private var destination: NWEndpoint?
    private var streamerListener: NWListener?
    private var streamerConnection: NWConnection?
    private var destinationConnection: NWConnection?
    var state: RelayState = .none
    private var started = false
    private let reconnectTimer = SimpleTimer(queue: .main)
    var destinationInterface: NWInterface
    private var id: String
    private weak var relay: MoblinkRelay?
    var isMain = false

    init(
        id: String,
        name: String,
        streamerUrl: URL,
        password: String,
        delegate: MoblinkRelayDelegate?,
        destinationInterface: NWInterface,
        relay: MoblinkRelay
    ) {
        self.id = id
        self.name = name
        self.streamerUrl = streamerUrl
        self.password = password
        self.delegate = delegate
        self.destinationInterface = destinationInterface
        self.relay = relay
        webSocket = .init(url: streamerUrl)
    }

    func start() {
        guard !started else {
            return
        }
        logger.info("moblink-client: \(name): Start")
        started = true
        startInternal()
    }

    func stop() {
        guard started else {
            return
        }
        logger.info("moblink-client: \(name): Stop")
        stopInternal()
        started = false
    }

    private func startInternal() {
        guard started else {
            return
        }
        stopInternal()
        setState(state: .connecting)
        webSocket = .init(url: streamerUrl, cellular: false)
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
        logger.info("moblink-client: \(name): Reconnecting soon with reason \(reason)")
        stopInternal()
        reconnectTimer.startSingleShot(timeout: 5.0) { [weak self] in
            self?.startInternal()
        }
    }

    private func setState(state: RelayState) {
        guard state != self.state else {
            return
        }
        logger.info("moblink-client: \(name): State change \(self.state) -> \(state)")
        self.state = state
        relay?.relayStateChanged()
    }

    private func send(message: MoblinkMessageToStreamer) {
        do {
            let message = try message.toJson()
            webSocket.send(string: message)
        } catch {
            logger.info("moblink-client: \(name): Encode failed")
        }
    }

    private func handleMessage(message: String) throws {
        do {
            switch try MoblinkMessageToRelay.fromJson(data: message) {
            case let .hello(apiVersion: apiVersion, authentication: authentication):
                handleHello(apiVersion: apiVersion, authentication: authentication)
            case let .identified(result: result):
                if !handleIdentified(result: result) {
                    logger.info("moblink-client: \(name): Failed to identify")
                    return
                }
                setState(state: .connected)
            case let .request(id: id, data: data):
                handleRequest(id: id, data: data)
            }
        } catch {
            logger.info("moblink-client: \(name): Decode failed")
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
        logger.info("moblink-client: \(name): Start tunnel to \(address):\(port)")
        destination = .hostPort(host: NWEndpoint.Host(address), port: NWEndpoint.Port(integerLiteral: port))
        do {
            let options = NWProtocolUDP.Options()
            let parameters = NWParameters(dtls: .none, udp: options)
            streamerListener = try NWListener(using: parameters)
        } catch {
            logger.error("moblink-client: \(name): Failed to create streamer listener with error \(error)")
            reconnect(reason: "Failed to create listener")
            return
        }
        streamerListener?.stateUpdateHandler = handleListenerStateChange(to:)
        streamerListener?.newConnectionHandler = handleNewListenerConnection(connection:)
        streamerListener?.start(queue: moblinkRelayQueue)
        let params = NWParameters(dtls: .none)
        params.requiredInterface = destinationInterface
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
        var batteryPercentage: Int?
        if isMain {
            batteryPercentage = delegate?.moblinkRelayGetBatteryPercentage()
        }
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
        logger.debug("moblink-client: \(name): Destination state change to \(state)")
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
                logger.info("moblink-client: \(self.name): Streamer receive error \(error)")
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
                logger.info("moblink-client: \(self.name): Destination receive error \(error)")
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
    private let name: String
    let streamerUrl: URL
    private let password: String
    private weak var delegate: MoblinkRelayDelegate?
    private var relays: [Relay] = []
    private let networkPathMonitor = NWPathMonitor()
    private var started = false
    @AppStorage("srtlaRelayId") var id = ""

    init(name: String, streamerUrl: URL, password: String, delegate: MoblinkRelayDelegate) {
        self.name = name
        self.streamerUrl = streamerUrl
        self.password = password
        self.delegate = delegate
        super.init()
        if id.isEmpty {
            id = UUID().uuidString
        }
    }

    func start() {
        started = true
        networkPathMonitor.pathUpdateHandler = handleNetworkPathUpdate(path:)
        networkPathMonitor.start(queue: .main)
        relayStateChanged()
    }

    func stop() {
        started = false
        networkPathMonitor.cancel()
        for relay in relays {
            relay.stop()
        }
        relays.removeAll()
    }

    private func makeRelayId(_ interface: NWInterface) -> String {
        if let value = Int(id.suffix(6), radix: 16) {
            return id.prefix(30) + String(format: "%06X", (value + interface.index) & 0xFFFFFF)
        }
        return id
    }

    private func makeRelayName(_ interface: NWInterface) -> String {
        if interface.type == .cellular {
            return name
        } else {
            return "\(name)-\(interface.index)"
        }
    }

    func relayStateChanged() {
        var state: MoblinkRelayState = .noInterface
        for relay in relays {
            switch relay.state {
            case .none:
                break
            case .connecting:
                state = .connecting
            case .connected:
                if state == .noInterface {
                    state = .connected
                }
            case .waitingForCellular:
                break
            case .wrongPassword:
                state = .wrongPassword
            case .unknownError:
                state = .unknownError
            }
        }
        delegate?.moblinkRelayNewState(state: state)
    }

    private func handleNetworkPathUpdate(path: NWPath) {
        guard started else {
            return
        }
        var relays: [Relay] = []
        for interface in path.availableInterfaces
            where interface.type == .cellular || interface.type == .wiredEthernet
        {
            if let relay = self.relays.first(where: { $0.destinationInterface == interface }) {
                relays.append(relay)
            } else {
                let relay = Relay(
                    id: makeRelayId(interface),
                    name: makeRelayName(interface),
                    streamerUrl: streamerUrl,
                    password: password,
                    delegate: delegate,
                    destinationInterface: interface,
                    relay: self
                )
                relay.start()
                relays.append(relay)
            }
        }
        for relay in self.relays
            where !relays.contains(where: { $0.destinationInterface == relay.destinationInterface })
        {
            relay.stop()
        }
        var mainRelay = relays.first
        for relay in relays {
            relay.isMain = false
            if relay.destinationInterface.type == .cellular {
                mainRelay = relay
                break
            }
        }
        mainRelay?.isMain = true
        self.relays = relays
        relayStateChanged()
        // logger.info("moblink-client: Number of relays is \(relays.count)")
    }
}
