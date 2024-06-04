import Foundation
import Network

class SrtlaServerClient {
    private var connections: [NWConnection] = []
    private var latestReceivedTime = ContinuousClock.now
    private var latestSentTime = ContinuousClock.now

    init() {
        logger.info("srtla-server-client: Created")
    }

    func addConnection(connection: NWConnection) {
        connections.append(connection)
        logger.info("srtla-server-client: Using \(connections.count) connection(s)")
        receivePacket(connection: connection)
    }

    private func receivePacket(connection: NWConnection) {
        connection.receiveMessage { data, _, _, error in
            if let data, !data.isEmpty {
                logger.info("srtla-server-client: Got packet \(data)")
                self.handlePacket(connection: connection, packet: data)
            }
            if let error {
                logger.info("srtla-server-client: Error \(error)")
                return
            }
            self.receivePacket(connection: connection)
        }
    }

    private func handlePacket(connection: NWConnection, packet: Data) {
        guard packet.count >= 2 else {
            logger.error("srtla-server-client: Packet too short (\(packet.count) bytes.")
            return
        }
        latestReceivedTime = .now
        if isDataPacket(packet: packet) {
            handleDataPacket(packet: packet)
        } else {
            handleControlPacket(connection: connection, packet: packet)
        }
    }

    private func handleControlPacket(connection: NWConnection, packet: Data) {
        let type = getControlPacketType(packet: packet)
        if let type = SrtlaPacketType(rawValue: type) {
            return handleSrtlaControlPacket(connection: connection, type: type, packet: packet)
        } else {
            if let type = SrtPacketType(rawValue: type) {
                handleSrtControlPacket(type: type, packet: packet)
            }
        }
    }

    private func handleSrtlaControlPacket(connection: NWConnection, type: SrtlaPacketType, packet _: Data) {
        switch type {
        case .keepalive:
            handleSrtlaKeepalive(connection: connection)
        default:
            logger.info("srtla-server-client: Unexpected packet \(type)")
        }
    }

    private func handleSrtControlPacket(type: SrtPacketType, packet _: Data) {
        logger.info("srtla-server-client: Got SRT control message \(type)")
    }

    private func handleSrtlaKeepalive(connection: NWConnection) {
        logger.info("srtla-server-client: Got keep alive message")
        var packet = Data(count: 2)
        packet.setUInt16Be(value: SrtlaPacketType.keepalive.rawValue | srtlaPacketTypeBit)
        sendPacket(connection: connection, packet: packet)
    }

    private func handleDataPacket(packet _: Data) {
        logger.info("srtla-server-client: Got data packet")
    }

    private func sendPacket(connection: NWConnection, packet: Data) {
        latestSentTime = .now
        connection.send(content: packet, completion: .contentProcessed { _ in })
    }
}
