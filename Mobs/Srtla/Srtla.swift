import Foundation
import Network

protocol SrtlaDelegate: AnyObject {
    func srtlaReady(port: UInt16)
    func srtlaError()
    func srtlaPacketSent(byteCount: Int)
    func srtlaPacketReceived(byteCount: Int)
    func srtlaConnectionTypeChanged(type: String)
}

private enum State {
    case idle
    case waitForRemoteSocketConnected
    case waitForGroupId
    case waitForRegistered
    case waitForLocalSocketListening
    case running
}

class Srtla {
    private var remoteConnections: [RemoteConnection] = []
    private var localListener: LocalListener?
    private weak var delegate: (any SrtlaDelegate)?
    private var groupId: Data?
    private let passThrough: Bool
    private var connectTimer: Timer?
    private var state = State.idle {
        didSet {
            logger.info("srtla: State \(oldValue) -> \(state)")
        }
    }

    init(delegate: SrtlaDelegate, passThrough: Bool) {
        self.delegate = delegate
        self.passThrough = passThrough
        logger.info("srtla: SRT instead of SRTLA: \(passThrough)")
        if passThrough {
            remoteConnections.append(RemoteConnection(type: nil))
        } else {
            remoteConnections.append(RemoteConnection(type: .cellular))
            remoteConnections.append(RemoteConnection(type: .wifi))
            remoteConnections.append(RemoteConnection(type: .wiredEthernet))
        }
    }

    func start(uri: String, timeout: Double) {
        guard
            let url = URL(string: uri),
            let host = url.host,
            let port = url.port
        else {
            logger.error("srtla: Failed to start")
            return
        }
        for connection in remoteConnections {
            startRemote(connection: connection, host: host, port: port)
        }
        connectTimer = Timer
            .scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
                logger.info("srtla: Connect timer expired")
                self.onDisconnected()
            }
        state = .waitForRemoteSocketConnected
    }

    func stop() {
        for connection in remoteConnections {
            stopRemote(connection: connection)
        }
        remoteConnections = []
        stopListener()
        connectTimer?.invalidate()
        connectTimer = nil
        state = .idle
    }

    func startRemote(connection: RemoteConnection, host: String, port: Int) {
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

    func stopRemote(connection: RemoteConnection) {
        connection.stop()
        connection.onSocketConnected = nil
        connection.onReg2 = nil
        connection.onRegistered = nil
        connection.packetHandler = nil
        connection.onSrtAck = nil
        connection.onSrtNak = nil
        connection.onSrtlaAck = nil
    }

    func startListener() {
        guard localListener == nil else {
            return
        }
        localListener = LocalListener()
        localListener!.packetHandler = handleLocalPacket(packet:)
        localListener!.onReady = handleLocalReady(port:)
        localListener!.onError = handleLocalError
        localListener!.start()
        state = .waitForLocalSocketListening
    }

    func stopListener() {
        localListener?.stop()
        localListener?.packetHandler = nil
        localListener?.onReady = nil
        localListener?.onError = nil
        localListener = nil
    }

    func handleLocalReady(port: UInt16) {
        guard state == .waitForLocalSocketListening else {
            return
        }
        state = .running
        delegate?.srtlaReady(port: port)
        connectTimer?.invalidate()
        connectTimer = nil
    }

    func handleLocalError() {
        onDisconnected()
    }

    func onDisconnected() {
        stop()
        delegate?.srtlaError()
        state = .idle
    }

    func handleLocalPacket(packet: Data) {
        guard let connection = findBestRemoteConnection() else {
            logger.warning("srtla: local: No remote connection found")
            onDisconnected()
            return
        }
        connection.sendSrtPacket(packet: packet)
        delegate?.srtlaPacketSent(byteCount: packet.count)
    }

    func handleRemoteConnected(connection: RemoteConnection) {
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

    func handleRemoteRegistered(connection _: RemoteConnection) {
        guard state == .waitForRegistered else {
            return
        }
        startListener()
    }

    func handleRemotePacket(packet: Data) {
        localListener?.sendPacket(packet: packet)
        delegate?.srtlaPacketReceived(byteCount: packet.count)
    }

    func handleSrtAck(sn: UInt32) {
        for connection in remoteConnections {
            connection.handleSrtAckSn(sn: sn)
        }
    }

    func handleSrtNak(sn: UInt32) {
        for connection in remoteConnections {
            connection.handleSrtNakSn(sn: sn)
        }
    }

    func handleSrtlaAck(sn: UInt32) {
        for connection in remoteConnections {
            connection.handleSrtlaAckSn(sn: sn)
        }
    }

    func handleGroupId(groupId: Data) {
        guard state == .waitForGroupId else {
            return
        }
        self.groupId = groupId
        for connection in remoteConnections {
            connection.register(groupId: groupId)
        }
        state = .waitForRegistered
    }

    func findBestRemoteConnection() -> RemoteConnection? {
        var bestConnection: RemoteConnection?
        var bestScore = -1
        for connection in remoteConnections {
            let score = connection.score()
            if score > bestScore {
                bestConnection = connection
                bestScore = score
            }
        }
        return bestConnection
    }

    func findBestConnectionType() -> String? {
        var bestTypeString: String?
        var bestWindowSize = -1
        for connection in remoteConnections where connection.windowSize > bestWindowSize {
            bestTypeString = connection.typeString
            bestWindowSize = connection.windowSize
        }
        return bestTypeString
    }

    func logStatistics() {
        for connection in remoteConnections {
            connection.logStatistics()
        }
    }
}
