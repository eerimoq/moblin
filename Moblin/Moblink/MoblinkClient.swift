import Foundation
import Network
import SwiftUI

private let moblinkClientQueue = DispatchQueue(label: "com.eerimoq.moblink-client")

struct MoblinkClientDiscoveredServer: Identifiable {
    var id = UUID()
    var name: String
    var urls: [String]
}

class DiscoveredSerivce {
    var service: NetService
    var urls: [String]

    init(service: NetService) {
        self.service = service
        urls = []
    }
}

enum MoblinkClientState: String {
    case none = "None"
    case connecting = "Connecting"
    case connected = "Connected"
    case waitingForCellular = "Waiting for cellular"
    case wrongPassword = "Wrong password"
    case unknownError = "Unknown error"
}

protocol MoblinkClientDelegate: AnyObject {
    func moblinkClientNewState(state: MoblinkClientState)
    func moblinkClientGetBatteryPercentage() -> Int
    func moblinkClientDiscoveredServers(servers: [MoblinkClientDiscoveredServer])
}

class MoblinkClient: NSObject {
    private var clientUrl: URL
    private var password: String
    private weak var delegate: (any MoblinkClientDelegate)?
    private var webSocket: WebSocketClient
    private let name: String
    private var startTunnelId: Int?
    private var destination: NWEndpoint?
    private var serverListener: NWListener?
    private var serverConnection: NWConnection?
    private var destinationConnection: NWConnection?
    private var state: MoblinkClientState = .none
    private var started = false
    private let reconnectTimer = SimpleTimer(queue: .main)
    private let networkPathMonitor = NWPathMonitor()
    private var cellularInterface: NWInterface?
    private var bonjourBrowser: NetServiceBrowser?
    private var discoveredServices: [DiscoveredSerivce] = []
    @AppStorage("srtlaRelayId") var id = ""

    init(name: String, clientUrl: URL, password: String, delegate: MoblinkClientDelegate) {
        self.name = name
        self.clientUrl = clientUrl
        self.password = password
        self.delegate = delegate
        webSocket = .init(url: clientUrl)
        super.init()
        if id.isEmpty {
            id = UUID().uuidString
        }
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

    private func startInternal() {
        guard started else {
            return
        }
        stopInternal()
        setState(state: .connecting)
        webSocket = .init(url: clientUrl, cellular: false)
        webSocket.delegate = self
        webSocket.start()
        networkPathMonitor.pathUpdateHandler = handleNetworkPathUpdate(path:)
        networkPathMonitor.start(queue: .main)
        bonjourBrowser = NetServiceBrowser()
        bonjourBrowser?.delegate = self
        bonjourBrowser?.searchForServices(ofType: moblinkBonjourType, inDomain: moblinkBonjourDomain)
    }

    private func stopInternal() {
        reconnectTimer.stop()
        setState(state: .none)
        webSocket.delegate = nil
        webSocket.stop()
        stopTunnel()
        networkPathMonitor.cancel()
        bonjourBrowser?.stop()
        bonjourBrowser = nil
        delegate?.moblinkClientDiscoveredServers(servers: [])
        discoveredServices.removeAll()
    }

    private func reconnect(reason: String) {
        logger.info("moblink-client: Reconnecting soon with reason \(reason)")
        stopInternal()
        reconnectTimer.startSingleShot(timeout: 5.0) {
            self.startInternal()
        }
    }

    private func handleNetworkPathUpdate(path: NWPath) {
        cellularInterface = path.availableInterfaces.first(where: { $0.type == .cellular })
    }

    private func setState(state: MoblinkClientState) {
        guard state != self.state else {
            return
        }
        logger.info("moblink-client: State change \(self.state) -> \(state)")
        self.state = state
        delegate?.moblinkClientNewState(state: state)
    }

    private func send(message: MoblinkMessageToServer) {
        do {
            let message = try message.toJson()
            webSocket.send(string: message)
        } catch {
            logger.info("moblink-client: Encode failed")
        }
    }

    private func handleMessage(message: String) throws {
        do {
            switch try MoblinkMessageToClient.fromJson(data: message) {
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
            serverListener = try NWListener(using: parameters)
        } catch {
            logger.error("moblink-client: Failed to create server listener with error \(error)")
            reconnect(reason: "Failed to create listener")
            return
        }
        serverListener?.stateUpdateHandler = handleListenerStateChange(to:)
        serverListener?.newConnectionHandler = handleNewListenerConnection(connection:)
        serverListener?.start(queue: moblinkClientQueue)
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
        destinationConnection?.start(queue: moblinkClientQueue)
        receiveDestinationPacket()
        setState(state: .waitingForCellular)
        startTunnelId = id
    }

    private func handleStatus(id: Int) {
        let batteryPercentage = delegate?.moblinkClientGetBatteryPercentage()
        send(message: .response(id: id, result: .ok, data: .status(batteryPercentage: batteryPercentage)))
    }

    func stopTunnel() {
        serverListener?.stateUpdateHandler = nil
        serverListener?.cancel()
        serverListener = nil
        serverConnection?.stateUpdateHandler = nil
        serverConnection?.cancel()
        serverConnection = nil
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
                guard let serverListener = self.serverListener, let startTunnelId = self.startTunnelId else {
                    return
                }
                let port = serverListener.port!.rawValue
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
        serverConnection = connection
        serverConnection?.start(queue: moblinkClientQueue)
        receiveServerPacket()
    }

    private func receiveServerPacket() {
        serverConnection?.receiveMessage { data, _, _, error in
            if let data, !data.isEmpty {
                self.handlePacketFromServer(packet: data)
            }
            if let error {
                logger.info("moblink-client: Server receive error \(error)")
                DispatchQueue.main.async {
                    self.reconnect(reason: "Server receive error")
                }
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
        serverConnection?.send(content: packet, completion: .contentProcessed { _ in
        })
    }

    private func discoveredServersUpdated() {
        var servers: [MoblinkClientDiscoveredServer] = []
        for discoveredService in discoveredServices {
            servers.append(.init(name: discoveredService.service.name, urls: discoveredService.urls))
        }
        delegate?.moblinkClientDiscoveredServers(servers: servers)
    }
}

extension MoblinkClient: WebSocketClientDelegate {
    func webSocketClientConnected(_: WebSocketClient) {}

    func webSocketClientDisconnected(_: WebSocketClient) {
        setState(state: .connecting)
        stopTunnel()
    }

    func webSocketClientReceiveMessage(_: WebSocketClient, string: String) {
        try? handleMessage(message: string)
    }
}

extension MoblinkClient: NetServiceBrowserDelegate {
    func netServiceBrowser(_: NetServiceBrowser, didFind service: NetService, moreComing _: Bool) {
        guard !discoveredServices.contains(where: { $0.service == service }) else {
            return
        }
        discoveredServices.append(.init(service: service))
        service.delegate = self
        service.resolve(withTimeout: 5.0)
    }

    func netServiceBrowser(_: NetServiceBrowser, didRemove service: NetService, moreComing _: Bool) {
        guard let index = discoveredServices.firstIndex(where: { $0.service == service }) else {
            return
        }
        discoveredServices.remove(at: index)
        discoveredServersUpdated()
    }
}

extension MoblinkClient: NetServiceDelegate {
    func netServiceDidResolveAddress(_ service: NetService) {
        guard let discoveredService = discoveredServices.first(where: { $0.service == service }) else {
            return
        }
        for address in service.addresses ?? [] {
            let (address, ipv6) = getAddressInfo(address: address)
            if let url = formatWebsocketUrl(address: address, ipv6: ipv6, port: service.port) {
                discoveredService.urls.append(url)
            }
        }
        discoveredServersUpdated()
    }

    private func getAddressInfo(address: Data) -> (String, Bool) {
        var ipv6 = false
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        address.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            let sockaddrPtr = pointer.bindMemory(to: sockaddr.self)
            guard let unsafePtr = sockaddrPtr.baseAddress else {
                return
            }
            guard getnameinfo(
                unsafePtr,
                socklen_t(address.count),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            ) == 0 else {
                return
            }
            ipv6 = unsafePtr.pointee.sa_family == AF_INET6
        }
        return (String(cString: hostname), ipv6)
    }

    private func formatWebsocketUrl(address: String, ipv6: Bool, port: Int) -> String? {
        var host: String
        if ipv6 {
            guard let address6 = IPv6Address(address), !address6.isLinkLocal, !address6.isLoopback else {
                return nil
            }
            host = "[\(address)]"
        } else {
            guard let address4 = IPv4Address(address), !address4.isLinkLocal, !address4.isLoopback else {
                return nil
            }
            host = address
        }
        return "ws://\(host):\(port)"
    }
}
