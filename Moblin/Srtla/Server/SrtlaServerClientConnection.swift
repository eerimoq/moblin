import Foundation
import Network

class SrtlaServerClientConnection {
    private var connection: NWConnection
    private var latestReceivedTime = ContinuousClock.now
    private var latestSentTime = ContinuousClock.now

    init(connection: NWConnection) {
        self.connection = connection
        receivePacket()
    }

    private func receivePacket() {
        connection.receiveMessage { data, _, _, error in
            if let data, !data.isEmpty {
                logger.info("srtla-server-client: Got packet \(data)")
                self.handlePacket(packet: data)
            }
            if let error {
                logger.info("srtla-server-client: Error \(error)")
                return
            }
            self.receivePacket()
        }
    }

    private func handlePacket(packet: Data) {
        guard packet.count >= 2 else {
            logger.error("srtla-server-client: Packet too short (\(packet.count) bytes.")
            return
        }
        latestReceivedTime = .now
        if isDataPacket(packet: packet) {
            handleDataPacket(packet: packet)
        } else {
            handleControlPacket(packet: packet)
        }
    }

    private func handleControlPacket(packet: Data) {
        let type = getControlPacketType(packet: packet)
        if let type = SrtlaPacketType(rawValue: type) {
            return handleSrtlaControlPacket(type: type, packet: packet)
        } else {
            if let type = SrtPacketType(rawValue: type) {
                handleSrtControlPacket(type: type, packet: packet)
            }
        }
    }

    private func handleSrtlaControlPacket(type: SrtlaPacketType, packet _: Data) {
        switch type {
        case .keepalive:
            handleSrtlaKeepalive()
        default:
            logger.info("srtla-server-client: Unexpected packet \(type)")
        }
    }

    private func handleSrtControlPacket(type: SrtPacketType, packet _: Data) {
        logger.info("srtla-server-client: Got SRT control message \(type)")
    }

    private func handleSrtlaKeepalive() {
        logger.info("srtla-server-client: Got keep alive message")
        var packet = Data(count: 2)
        packet.setUInt16Be(value: SrtlaPacketType.keepalive.rawValue | srtlaPacketTypeBit)
        sendPacket(packet: packet)
    }

    private func handleDataPacket(packet _: Data) {
        logger.info("srtla-server-client: Got data packet")
    }

    private func sendPacket(packet: Data) {
        latestSentTime = .now
        connection.send(content: packet, completion: .contentProcessed { _ in })
    }
}
