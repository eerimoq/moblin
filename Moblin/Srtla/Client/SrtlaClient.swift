// SRTLA is a bonding protocol on top of SRT.
// Designed by rationalsa for the BELABOX projecct.
// https://github.com/BELABOX/srtla

import Foundation
import Network

protocol SrtlaDelegate: AnyObject {
    func srtlaReady(port: UInt16)
    func srtlaError(message: String)
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

let srtlaDispatchQueue = DispatchQueue(label: "com.eerimoq.srtla")

class SrtlaClient {
    private var remoteConnections: [RemoteConnection] = []
    private var localListener: LocalListener?
    private weak var delegate: (any SrtlaDelegate)?
    private let passThrough: Bool
    private var connectTimer: DispatchSourceTimer?
    private var state: State = .idle {
        didSet {
            logger.info("srtla: State \(oldValue) -> \(state)")
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
        setNetworkInterfaceNames(networkInterfaceNames: networkInterfaceNames)
        updateConnectionPriorities(connectionPriorities: connectionPriorities)
        logger.info("srtla: SRT instead of SRTLA: \(passThrough)")
        if passThrough {
            remoteConnections.append(RemoteConnection(
                type: nil,
                mpegtsPacketsPerPacket: mpegtsPacketsPerPacket,
                interface: nil,
                networkInterfaces: networkInterfaces,
                priority: 1.0
            ))
        } else {
            remoteConnections.append(RemoteConnection(
                type: .cellular,
                mpegtsPacketsPerPacket: mpegtsPacketsPerPacket,
                interface: nil,
                networkInterfaces: networkInterfaces,
                priority: getConnectionPriority(name: "Cellular")
            ))
            remoteConnections.append(RemoteConnection(
                type: .wifi,
                mpegtsPacketsPerPacket: mpegtsPacketsPerPacket,
                interface: nil,
                networkInterfaces: networkInterfaces,
                priority: getConnectionPriority(name: "WiFi")
            ))
        }
    }

    deinit {
        logger.info("srtla: srtla deinit")
    }

    func start(uri: String, timeout: Double) {
        srtlaDispatchQueue.async {
            if !self.passThrough {
                self.networkPathMonitor.pathUpdateHandler = self.handleNetworkPathUpdate(path:)
                self.networkPathMonitor.start(queue: srtlaDispatchQueue)
            }
            self.totalByteCount = 0
            guard let url = URL(string: uri), let host = url.host, let port = url.port else {
                logger.error("srtla: Malformed URL")
                return
            }
            self.host = host
            self.port = port
            for connection in self.remoteConnections {
                self.startRemote(connection: connection, host: host, port: port)
            }
            self.connectTimer = DispatchSource.makeTimerSource(queue: srtlaDispatchQueue)
            logger.info("srtla: Setting connect timer to \(timeout) seconds")
            self.connectTimer!.schedule(deadline: .now() + timeout)
            self.connectTimer!.setEventHandler {
                logger.info("srtla: Connect timer expired after \(timeout) seconds")
                self.onDisconnected(message: "connect timer expired")
            }
            self.connectTimer!.activate()
            self.state = .waitForRemoteSocketConnected
        }
    }

    func stop() {
        srtlaDispatchQueue.async {
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

    func setNetworkInterfaceNames(networkInterfaceNames: [SettingsNetworkInterfaceName]) {
        srtlaDispatchQueue.async {
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
        srtlaDispatchQueue.async {
            self.updateConnectionPriorities(connectionPriorities: connectionPriorities)
            for connection in self.remoteConnections {
                var name: String
                if let interface = connection.interface {
                    name = interface.name
                } else {
                    switch connection.type {
                    case .cellular:
                        name = "Cellular"
                    case .wifi:
                        name = "WiFi"
                    default:
                        name = ""
                    }
                }
                connection.setPriority(priority: self.getConnectionPriority(name: name))
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

    private func handleNetworkPathUpdate(path: NWPath) {
        logger.debug("srtla: interface: \(path.debugDescription)")
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
        for interface in path.availableInterfaces where interface.type == .wiredEthernet {
            guard !newRemoteConnections.contains(where: { connection in
                connection.interface == interface
            }) else {
                continue
            }
            newRemoteConnections.append(RemoteConnection(
                type: .wiredEthernet,
                mpegtsPacketsPerPacket: mpegtsPacketsPerPacket,
                interface: interface,
                networkInterfaces: self.networkInterfaces,
                priority: getConnectionPriority(name: interface.name)
            ))
            startRemote(connection: newRemoteConnections.last!, host: host, port: port)
            if let groupId {
                newRemoteConnections.last!.register(groupId: groupId)
            }
        }
        remoteConnections = newRemoteConnections
    }

    func connectionStatistics() -> String? {
        var connections: [BondingConnection] = []
        srtlaDispatchQueue.sync {
            for connection in remoteConnections where connection.isEnabled() {
                guard let byteCount = connection.getDataSentDelta() else {
                    continue
                }
                connections.append(BondingConnection(
                    name: connection.typeString,
                    usage: byteCount
                ))
            }
        }
        return bondingStatistics(connections: connections)
    }

    func logStatistics() {
        srtlaDispatchQueue.async {
            for connection in self.remoteConnections {
                connection.logStatistics()
            }
        }
    }

    func getTotalByteCount() -> Int64 {
        srtlaDispatchQueue.sync {
            totalByteCount
        }
    }

    private func startRemote(connection: RemoteConnection, host: String, port: Int) {
        connection.onSocketConnected = {
            self.handleRemoteConnected(connection: connection)
        }
        connection.onReg2 = handleGroupId(groupId:)
        connection.onRegistered = {
            self.handleRemoteRegistered(connection: connection)
        }
        connection.packetHandler = handleRemotePacket(packet:)
        connection.onSrtAck = handleSrtAck(sn:)
        connection.onSrtNak = handleSrtNak(sn:)
        connection.onSrtlaAck = handleSrtlaAck(sn:)
        connection.start(host: host, port: UInt16(port))
    }

    private func stopRemote(connection: RemoteConnection) {
        connection.stop(reason: "Stopping stream")
        connection.onSocketConnected = nil
        connection.onReg2 = nil
        connection.onRegistered = nil
        connection.packetHandler = nil
        connection.onSrtAck = nil
        connection.onSrtNak = nil
        connection.onSrtlaAck = nil
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
        connectTimer?.cancel()
        connectTimer = nil
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
            logger.warning("srtla: local: No remote connection found")
            onDisconnected(message: "no remote connection found")
            return
        }
        connection.sendSrtPacket(packet: packet)
        totalByteCount += Int64(packet.count)
    }

    private func handleRemoteConnected(connection: RemoteConnection) {
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

    private func handleRemoteRegistered(connection _: RemoteConnection) {
        guard state == .waitForRegistered else {
            return
        }
        startListener()
    }

    private func handleRemotePacket(packet: Data) {
        localListener?.sendPacket(packet: packet)
        totalByteCount += Int64(packet.count)
    }

    private func handleSrtAck(sn: UInt32) {
        for connection in remoteConnections {
            connection.handleSrtAckSn(sn: sn)
        }
    }

    private func handleSrtNak(sn: UInt32) {
        for connection in remoteConnections {
            connection.handleSrtNakSn(sn: sn)
        }
    }

    private func handleSrtlaAck(sn: UInt32) {
        for connection in remoteConnections {
            connection.handleSrtlaAckSn(sn: sn)
        }
    }

    private func handleGroupId(groupId: Data) {
        guard state == .waitForGroupId else {
            return
        }
        self.groupId = groupId
        for connection in remoteConnections {
            connection.register(groupId: groupId)
        }
        state = .waitForRegistered
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
