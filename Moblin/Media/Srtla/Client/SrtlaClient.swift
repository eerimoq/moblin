// SRTLA is a bonding protocol on top of SRT.
// Designed by rationalsa for the BELABOX projecct.
// https://github.com/BELABOX/srtla

import Foundation
import Network

protocol SrtlaDelegate: AnyObject {
    func srtlaReady(port: UInt16)
    func srtlaError(message: String)
    func moblinkStreamerDestinationAddress(address: String, port: UInt16)
}

private enum State {
    case idle
    case waitForRemoteSocketConnected
    case waitForGroupId
    case waitForRegistered
    case waitForLocalSocketListening
    case running
}

class SrtlaNetworkInterfaces {
    var names: [String: String] = [:]
}

let srtlaClientQueue = DispatchQueue(label: "com.eerimoq.srtla-client")

class SrtlaClient: NSObject {
    private var remoteConnections: [RemoteConnection] = []
    private var localListener: LocalListener?
    private weak var delegate: (any SrtlaDelegate)?
    private let passThrough: Bool
    private var connectTimer = SimpleTimer(queue: srtlaClientQueue)
    private var state: State = .idle {
        didSet {
            logger.debug("srtla: State \(oldValue) -> \(state)")
        }
    }

    private let networkPathMonitor = NWPathMonitor()
    private let mpegtsPacketsPerPacket: Int
    private var host: String = ""
    private var port: Int = 0
    private var groupId: Data?

    private var totalByteCount: Int64 = 0
    private var networkInterfaces: SrtlaNetworkInterfaces
    private var connectionPriorities: [SettingsStreamSrtConnectionPriority]

    init(
        delegate: SrtlaDelegate,
        passThrough: Bool,
        mpegtsPacketsPerPacket: Int,
        networkInterfaceNames: [SettingsNetworkInterfaceName],
        connectionPriorities: SettingsStreamSrtConnectionPriorities
    ) {
        self.delegate = delegate
        self.passThrough = passThrough
        self.mpegtsPacketsPerPacket = mpegtsPacketsPerPacket
        networkInterfaces = .init()
        self.connectionPriorities = .init()
        super.init()
        setNetworkInterfaceNames(networkInterfaceNames: networkInterfaceNames)
        updateConnectionPriorities(connectionPriorities: connectionPriorities)
        logger.debug("srtla: SRT instead of SRTLA: \(passThrough)")
        if passThrough {
            remoteConnections.append(RemoteConnection(
                type: nil,
                mpegtsPacketsPerPacket: mpegtsPacketsPerPacket,
                interface: nil,
                networkInterfaces: networkInterfaces,
                priority: 1.0
            ))
        }
    }

    deinit {
        logger.debug("srtla: srtla deinit")
    }

    func start(uri: String, timeout: Double, dnsLookupStrategy: SettingsDnsLookupStrategy) {
        srtlaClientQueue.async {
            guard let url = URL(string: uri), var host = url.host, let port = url.port else {
                logger.error("srtla: Malformed URL")
                return
            }
            if IPv4Address(host) == nil, IPv6Address(host) == nil {
                logger.info("dns: Lookup strategy \(dnsLookupStrategy)")
                switch dnsLookupStrategy {
                case .ipv4:
                    host = performDnsLookup(host: host, family: .ipv4) ?? host
                case .ipv6:
                    host = performDnsLookup(host: host, family: .ipv6) ?? host
                case .ipv4AndIpv6:
                    host = performDnsLookup(host: host, family: .unspec) ?? host
                case .system:
                    break
                }
            }
            if !self.passThrough {
                self.networkPathMonitor.pathUpdateHandler = self.handleNetworkPathUpdate(path:)
                self.networkPathMonitor.start(queue: srtlaClientQueue)
            }
            self.totalByteCount = 0
            self.host = host
            self.port = port
            logger.info("srtla: Using destination address \(host) and port \(port)")
            for connection in self.remoteConnections {
                self.startRemote(connection: connection,
                                 host: NWEndpoint.Host(host),
                                 port: NWEndpoint.Port(integerLiteral: UInt16(port)))
            }
            logger.debug("srtla: Setting connect timer to \(timeout) seconds")
            self.connectTimer.startSingleShot(timeout: timeout) {
                logger.debug("srtla: Connect timer expired after \(timeout) seconds")
                self.onDisconnected(message: "connect timer expired")
            }
            self.state = .waitForRemoteSocketConnected
            self.delegate?.moblinkStreamerDestinationAddress(address: host, port: UInt16(port))
        }
    }

    func stop() {
        srtlaClientQueue.async {
            for connection in self.remoteConnections {
                self.stopRemote(connection: connection)
            }
            self.remoteConnections = []
            self.stopListener()
            self.cancelConnectTimer()
            self.state = .idle
            self.networkPathMonitor.cancel()
        }
    }

    func addMoblink(endpoint: NWEndpoint, id: UUID, name: String) {
        guard case let .hostPort(host, port) = endpoint else {
            return
        }
        srtlaClientQueue.async {
            guard self.state != .idle else {
                return
            }
            let remoteConnection = RemoteConnection(
                type: .other,
                mpegtsPacketsPerPacket: self.mpegtsPacketsPerPacket,
                interface: nil,
                networkInterfaces: self.networkInterfaces,
                priority: self.getRelayConnectionPriority(relayId: id),
                relayId: id,
                relayName: name
            )
            self.startRemote(connection: remoteConnection, host: host, port: port)
            if let groupId = self.groupId {
                remoteConnection.register(groupId: groupId)
            }
            self.remoteConnections.append(remoteConnection)
        }
    }

    func removeMoblink(endpoint: NWEndpoint) {
        guard case let .hostPort(host, port) = endpoint else {
            return
        }
        srtlaClientQueue.async {
            guard self.state != .idle else {
                return
            }
            guard let remoteConnection = self.remoteConnections.first(where: { $0.host == host && $0.port == port })
            else {
                return
            }
            self.stopRemote(connection: remoteConnection)
            self.remoteConnections.removeAll(where: { $0 === remoteConnection })
        }
    }

    func setNetworkInterfaceNames(networkInterfaceNames: [SettingsNetworkInterfaceName]) {
        srtlaClientQueue.async {
            self.networkInterfaces.names.removeAll()
            for interface in networkInterfaceNames {
                self.networkInterfaces.names[interface.interfaceName] = interface.name
            }
        }
    }

    private func updateConnectionPriorities(connectionPriorities: SettingsStreamSrtConnectionPriorities) {
        self.connectionPriorities = .init()
        guard connectionPriorities.enabled else {
            return
        }
        guard let lowestPriority = connectionPriorities.priorities
            .filter({ priority in priority.enabled! })
            .min(by: { first, second in
                first.priority < second.priority
            })
        else {
            return
        }
        for connectionPriority in connectionPriorities.priorities {
            let priority = connectionPriority.clone()
            priority.priority -= lowestPriority.priority
            priority.priority += 1
            self.connectionPriorities.append(priority)
        }
    }

    func setConnectionPriorities(connectionPriorities: SettingsStreamSrtConnectionPriorities) {
        srtlaClientQueue.async {
            self.updateConnectionPriorities(connectionPriorities: connectionPriorities)
            for connection in self.remoteConnections {
                if let relayId = connection.relayId {
                    connection.setPriority(priority: self.getRelayConnectionPriority(relayId: relayId))
                } else {
                    let name = interfaceName(type: connection.type, interface: connection.interface)
                    connection.setPriority(priority: self.getConnectionPriority(name: name))
                }
            }
        }
    }

    private func getConnectionPriority(name: String) -> Float {
        guard let priority = connectionPriorities.first(where: { connection in
            connection.name == name
        }) else {
            return 1
        }
        if priority.enabled! {
            return Float(priority.priority)
        } else {
            return 0
        }
    }

    private func getRelayConnectionPriority(relayId: UUID) -> Float {
        guard let priority = connectionPriorities.first(where: { priority in
            priority.relayId == relayId
        }) else {
            return 1
        }
        if priority.enabled! {
            return Float(priority.priority)
        } else {
            return 0
        }
    }

    private func handleNetworkPathUpdate(path: NWPath) {
        var newRemoteConnections: [RemoteConnection] = []
        for connection in remoteConnections {
            if let interface = connection.interface {
                if path.availableInterfaces.contains(interface) {
                    newRemoteConnections.append(connection)
                } else {
                    stopRemote(connection: connection)
                }
            } else {
                newRemoteConnections.append(connection)
            }
        }
        let interfaceTypes: [NWInterface.InterfaceType] = [.cellular, .wifi, .wiredEthernet]
        for interface in path.availableInterfaces where interfaceTypes.contains(interface.type) {
            guard !newRemoteConnections.contains(where: { connection in
                connection.interface == interface
            }) else {
                continue
            }
            let name = interfaceName(type: interface.type, interface: interface)
            newRemoteConnections.append(RemoteConnection(
                type: interface.type,
                mpegtsPacketsPerPacket: mpegtsPacketsPerPacket,
                interface: interface,
                networkInterfaces: networkInterfaces,
                priority: getConnectionPriority(name: name)
            ))
            startRemote(connection: newRemoteConnections.last!,
                        host: NWEndpoint.Host(host),
                        port: NWEndpoint.Port(integerLiteral: UInt16(port)))
            if let groupId {
                newRemoteConnections.last!.register(groupId: groupId)
            }
        }
        remoteConnections = newRemoteConnections.sorted(by: { first, second in
            if first.type == .cellular {
                return true
            } else if second.type == .cellular {
                return false
            } else if first.type == .wifi {
                return true
            } else if second.type == .wifi {
                return false
            } else {
                return true
            }
        })
    }

    func connectionStatistics() -> [BondingConnection] {
        var connections: [BondingConnection] = []
        srtlaClientQueue.sync {
            for connection in remoteConnections where connection.isEnabled() {
                guard let byteCount = connection.getDataSentDelta() else {
                    continue
                }
                connections.append(BondingConnection(
                    name: connection.typeString,
                    usage: byteCount,
                    rtt: connection.rtt
                ))
            }
        }
        return connections
    }

    func logStatistics() {
        srtlaClientQueue.async {
            for connection in self.remoteConnections {
                connection.logStatistics()
            }
        }
    }

    func getTotalByteCount() -> Int64 {
        srtlaClientQueue.sync {
            totalByteCount
        }
    }

    private func startRemote(connection: RemoteConnection, host: NWEndpoint.Host, port: NWEndpoint.Port) {
        connection.delegate = self
        connection.start(host: host, port: port)
    }

    private func stopRemote(connection: RemoteConnection) {
        connection.stop(reason: "Stopping stream")
        connection.delegate = nil
    }

    private func startListener() {
        guard localListener == nil else {
            return
        }
        localListener = LocalListener()
        localListener!.onReady = handleLocalReady(port:)
        localListener!.onError = handleLocalError
        localListener!.start()
        state = .waitForLocalSocketListening
    }

    private func stopListener() {
        localListener?.stop()
        localListener?.onReady = nil
        localListener?.onError = nil
        localListener = nil
    }

    private func handleLocalReady(port: UInt16) {
        guard state == .waitForLocalSocketListening else {
            return
        }
        state = .running
        delegate?.srtlaReady(port: port)
        cancelConnectTimer()
    }

    private func cancelConnectTimer() {
        connectTimer.stop()
    }

    private func handleLocalError(message: String) {
        onDisconnected(message: message)
    }

    private func onDisconnected(message: String) {
        guard state != .idle else {
            return
        }
        stop()
        delegate?.srtlaError(message: message)
        state = .idle
    }

    func handleLocalPacket(packet: Data) {
        guard let connection = selectRemoteConnection() else {
            return
        }
        connection.sendSrtPacket(packet: packet)
        totalByteCount += Int64(packet.count)
    }

    private func selectRemoteConnection() -> RemoteConnection? {
        var selectedConnection: RemoteConnection?
        var selectedScore = -1
        for connection in remoteConnections {
            let score = connection.score()
            if score > selectedScore {
                selectedConnection = connection
                selectedScore = score
            }
        }
        return selectedConnection
    }
}

extension SrtlaClient: RemoteConnectionDelegate {
    func remoteConnectionOnSocketConnected(connection: RemoteConnection) {
        guard state == .waitForRemoteSocketConnected else {
            return
        }
        if passThrough {
            startListener()
        } else {
            connection.sendSrtlaReg1()
            state = .waitForGroupId
        }
    }

    func remoteConnectionOnReg2(groupId: Data) {
        guard state == .waitForGroupId else {
            return
        }
        self.groupId = groupId
        for connection in remoteConnections {
            connection.register(groupId: groupId)
        }
        state = .waitForRegistered
    }

    func remoteConnectionOnRegistered() {
        guard state == .waitForRegistered else {
            return
        }
        startListener()
    }

    func remoteConnectionPacketHandler(packet: Data) {
        localListener?.sendPacket(packet: packet)
        totalByteCount += Int64(packet.count)
    }

    func remoteConnectionOnSrtAck(sn: UInt32) {
        for connection in remoteConnections {
            connection.handleSrtAckSn(sn: sn)
        }
    }

    func remoteConnectionOnSrtNak(sn: UInt32) {
        for connection in remoteConnections {
            connection.handleSrtNakSn(sn: sn)
        }
    }

    func remoteConnectionOnSrtlaAck(sn: UInt32) {
        for connection in remoteConnections {
            connection.handleSrtlaAckSn(sn: sn)
        }
    }
}

private func interfaceName(type: NWInterface.InterfaceType?, interface: NWInterface?) -> String {
    switch type {
    case .cellular:
        return "Cellular"
    case .wifi:
        return "WiFi"
    default:
        return interface?.name ?? ""
    }
}
