import Foundation
import Network

enum SrtPacketType: UInt16 {
    case ack = 0x0002
    case nak = 0x0003
}

enum SrtlaPacketType: UInt16 {
    case keepalive = 0x1000
    case ack = 0x1100
    case reg_1 = 0x1200
    case reg_2 = 0x1201
    case reg_3 = 0x1202
    case reg_err = 0x1210
    case reg_ngp = 0x1211
    case reg_nak = 0x1212
}

let groupIdLength = 256
let connectionTimeout = 4
let headerSize = 16

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
    guard packet.count >= headerSize else {
        logger.error("srtla: \(direction): Packet too short.")
        return
    }
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

    private var group_id = Data.random(length: groupIdLength)

    // Send to create a connection group. Contains our (unique) id.
    func sendSrtlaReg1() {
        logger.info("srtla: send register 1")
    }

    // Send once on each connection to register it.
    func sendSrtlaReg2() {
        logger.info("srtla: send register 2")
    }

    func handleSrtAck() {
        logger.info("srtla: srt ack")
    }

    func handleSrtNak() {
        logger.info("srtla: srt nak")
    }

    func handleSrtlaKeepalive() {
        logger.info("srtla: keep alive")
    }

    func handleSrtlaAck() {
        logger.info("srtla: ack")
    }

    // Received as response to reg_1. Contains group id (our id +
    // server id).
    func handleSrtlaReg2() {
        logger.info("srtla: register 2")
    }

    // Received as response to reg_2. A connection has been
    // established.
    func handleSrtlaReg3() {
        logger.info("srtla: register 3")
    }

    func handleSrtlaRegErr() {
        logger.info("srtla: register error")
    }

    func handleSrtlaRegNgp() {
        logger.info("srtla: register no group")
    }

    func handleSrtlaRegNak() {
        logger.info("srtla: register nak")
    }

    func handleControlPacket(packet: Data) {
        let type = getControlPacketType(packet: packet)
        if let type = SrtPacketType(rawValue: type) {
            switch type {
            case .ack:
                handleSrtAck()
            case .nak:
                handleSrtNak()
            }
        } else if let type = SrtlaPacketType(rawValue: type) {
            switch type {
            case .keepalive:
                handleSrtlaKeepalive()
            case .ack:
                handleSrtlaAck()
            case .reg_1:
                logger.error("srtla: Received register 1 packet")
            case .reg_2:
                handleSrtlaReg2()
            case .reg_3:
                handleSrtlaReg3()
            case .reg_err:
                handleSrtlaRegErr()
            case .reg_ngp:
                handleSrtlaRegNgp()
            case .reg_nak:
                handleSrtlaRegNak()
            }
        } else {
            logger.info("srtla: Received unhandled control packet")
        }
    }

    func handleDataPacket(packet _: Data) {
        logger.info("srtla: data packet")
    }

    func handleSrtAndSrtla(packet: Data) {
        guard packet.count >= headerSize else {
            logger.error("srtla: Packet too short.")
            return
        }
        if isDataPacket(packet: packet) {
            handleDataPacket(packet: packet)
        } else {
            handleControlPacket(packet: packet)
        }
    }
}
