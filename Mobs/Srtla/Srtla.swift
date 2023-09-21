import Foundation
import Network

protocol SrtlaDelegate: AnyObject {
    func srtlaReady(port: UInt16)
    func srtlaError()
    func srtlaPacketSent(byteCount: Int)
    func srtlaPacketReceived(byteCount: Int)
    func srtlaConnectionTypeChanged(type: String)
}

class Srtla {
    private var queue = DispatchQueue(label: "com.eerimoq.network", qos: .userInitiated)
    private var remoteConnections: [RemoteConnection] = []
    private var localListener: LocalListener?
    private weak var delegate: (any SrtlaDelegate)?
    private var currentConnection: RemoteConnection?
    private var groupId: Data?
    private let passThrough: Bool
    private var connectTimer: Timer?

    init(delegate: SrtlaDelegate, passThrough: Bool) {
        self.delegate = delegate
        self.passThrough = passThrough
        if passThrough {
            remoteConnections.append(RemoteConnection(queue: queue, type: nil))
        } else {
            remoteConnections.append(RemoteConnection(queue: queue, type: .cellular))
            remoteConnections.append(RemoteConnection(queue: queue, type: .wifi))
            remoteConnections.append(RemoteConnection(queue: queue, type: .wiredEthernet))
        }
    }

    func start(uri: String) {
        guard
            let url = URL(string: uri),
            let host = url.host,
            let port = url.port
        else {
            logger.error("srtla: Failed to start")
            return
        }
        for connection in remoteConnections {
            connection.onConnected = {
                self.handleRemoteConnected(connection: connection)
            }
            connection.packetHandler = handleRemotePacket(packet:)
            connection.onReg2 = handleGroupId(groupId:)
            connection.start(host: host, port: UInt16(port))
        }
        connectTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
            self.stop()
            self.delegate?.srtlaError()
        }
    }

    func stop() {
        for connection in remoteConnections {
            connection.stop()
            connection.packetHandler = nil
            connection.onReg2 = nil
        }
        stopListener()
        connectTimer?.invalidate()
        connectTimer = nil
    }

    func startListener() {
        guard localListener == nil else {
            return
        }
        localListener = LocalListener(queue: queue)
        localListener!.packetHandler = handleLocalPacket(packet:)
        localListener!.onReady = handleLocalReady(port:)
        localListener!.onError = handleLocalError
        localListener!.start()
    }

    func stopListener() {
        localListener?.stop()
        localListener?.packetHandler = nil
        localListener?.onReady = nil
        localListener?.onError = nil
        localListener = nil
    }

    func handleLocalReady(port: UInt16) {
        delegate?.srtlaReady(port: port)
        connectTimer?.invalidate()
    }

    func handleLocalError() {
        delegate?.srtlaError()
    }

    func handleLocalPacket(packet: Data) {
        guard let connection = findBestRemoteConnection() else {
            logger.warning("srtla: local: No remote connection found. Dropping packet.")
            return
        }
        connection.sendPacket(packet: packet)
        delegate?.srtlaPacketSent(byteCount: packet.count)
    }

    func handleRemoteConnected(connection: RemoteConnection) {
        if passThrough {
            startListener()
        } else {
            connection.sendSrtlaReg1()
        }
    }

    func handleRemotePacket(packet: Data) {
        localListener?.sendPacket(packet: packet)
        delegate?.srtlaPacketReceived(byteCount: packet.count)
    }

    func handleGroupId(groupId: Data) {
        guard self.groupId == nil else {
            return
        }
        self.groupId = groupId
        for connection in remoteConnections {
            connection.register(groupId: groupId)
        }
        startListener()
    }

    func typeString(connection: RemoteConnection?) -> String {
        return connection?.typeString ?? "None"
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
        if bestConnection !== currentConnection {
            let lastType = typeString(connection: currentConnection)
            let bestType = typeString(connection: bestConnection)
            logger
                .info(
                    "srtla: remote: Best connection changed from \(lastType) to \(bestType)"
                )
            currentConnection = bestConnection
            delegate?.srtlaConnectionTypeChanged(type: bestType)
        }
        return bestConnection
    }
}
