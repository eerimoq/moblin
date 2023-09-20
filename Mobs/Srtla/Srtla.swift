import Foundation
import Network

protocol SrtlaDelegate: AnyObject {
    func srtlaReady(port: UInt16)
    func srtlaError()
    func srtlaPacketSent(byteCount: Int)
    func srtlaPacketReceived(byteCount: Int)
    func srtlaConnectionTypeChanged(type: String)
}

func isDataPacket(packet: Data) -> Bool {
    return (packet[0] & 0x80) == 0
}

func getDataPacketSn(packet: Data) -> UInt32 {
    return packet.uint32.bigEndian
}

func getControlPacketType(packet: Data) -> UInt16 {
    return packet.uint16.bigEndian & 0x7FFF
}

enum ControlType: UInt16 {
    case handshake = 0
    case keepalive = 1
    case ack = 2
    case nak = 3
    case congestion_warning = 4
    case shutdown = 5
    case ackack = 6
    case dropreq = 7
    case peererror = 8
}

func logPacket(packet: Data, direction: String) {
    if packet.count >= 16 {
        if isDataPacket(packet: packet) {
            logger
                .debug(
                    "srtla: \(direction): Data packet SN \(getDataPacketSn(packet: packet))"
                )
        } else {
            let controlType = getControlPacketType(packet: packet)
            if let controlType = ControlType(rawValue: controlType) {
                logger.debug("srtla: \(direction): Control packet type \(controlType)")
            } else {
                logger.warning("srtla: \(direction): Unknown control type \(controlType)")
            }
        }
    } else {
        logger.error("srtla: \(direction): Packet too short.")
    }
}

class Srtla {
    private var queue = DispatchQueue(label: "com.eerimoq.network", qos: .userInitiated)
    private var remoteConnections: [RemoteConnection] = []
    private var localListener: LocalListener
    private weak var delegate: (any SrtlaDelegate)?
    private var currentConnection: RemoteConnection?

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
            connection.packetHandler = nil
        }
        localListener.stop()
        localListener.packetHandler = nil
    }

    func handleLocalPacket(packet: Data) {
        // logPacket(packet: packet, direction: "local")
        guard let connection = findBestRemoteConnection() else {
            logger.warning("srtla: local: No remote connection found. Dropping packet.")
            return
        }
        connection.sendPacket(packet: packet)
        delegate?.srtlaPacketSent(byteCount: packet.count)
    }

    func handleRemotePacket(packet: Data) {
        // logPacket(packet: packet, direction: "remote")
        localListener.sendPacket(packet: packet)
        delegate?.srtlaPacketReceived(byteCount: packet.count)
    }

    func type(connection: RemoteConnection?) -> String {
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
            let lastType = type(connection: currentConnection)
            let bestType = type(connection: bestConnection)
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
