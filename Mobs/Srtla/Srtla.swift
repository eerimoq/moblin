import Foundation
import Network

protocol SrtlaDelegate: AnyObject {
    func listenerReady(port: UInt16)
    func listenerError()
    func packetSent(byteCount: Int)
    func packetReceived(byteCount: Int)
}

class Srtla {
    private var queue = DispatchQueue(label: "com.eerimoq.network", qos: .userInitiated)
    private var remoteConnections: [RemoteConnection] = []
    private var localListener: LocalListener
    private weak var delegate: (any SrtlaDelegate)?
    
    init(delegate: SrtlaDelegate, passThrough: Bool) {
        self.delegate = delegate
        localListener = LocalListener(queue: queue, delegate: delegate)
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
            logger.error("srtla: Failed to start srtla")
            return
        }
        localListener.packetHandler = handleLocalPacket(packet:)
        localListener.start()
        for connection in remoteConnections {
            connection.packetHandler = handleRemotePacket(packet:)
            connection.start(host: host, port: UInt16(port))
        }
    }

    func stop() {
        for connection in remoteConnections {
            connection.stop()
        }
        localListener.stop()
    }

    func handleLocalPacket(packet: Data) {
        guard let connection = findBestRemoteConnection() else {
            logger.warning("srtla: No connection found. Dropping packet.")
            return
        }
        connection.sendPacket(packet: packet)
        delegate?.packetSent(byteCount: packet.count)
    }

    func handleRemotePacket(packet: Data) {
        localListener.sendPacket(packet: packet)
        delegate?.packetReceived(byteCount: packet.count)
    }

    func findBestRemoteConnection() -> RemoteConnection? {
        var bestConnection: RemoteConnection?
        var bestScore = -1
        for connection in remoteConnections where connection.score() > bestScore {
            bestConnection = connection
            bestScore = connection.score()
        }
        return bestConnection
    }
}
