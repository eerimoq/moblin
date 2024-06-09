import Foundation
import Network

protocol SrtlaServerClientConnectionDelegate: AnyObject {
    func handleSrtClientPacket(packet: Data)
}

class SrtlaServerClientConnection {
    var connection: NWConnection
    private var latestReceivedTime = ContinuousClock.now
    private var latestSentTime = ContinuousClock.now
    var delegate: (any SrtlaServerClientConnectionDelegate)?

    init(connection: NWConnection) {
        self.connection = connection
        receivePacket()
    }

    private func receivePacket() {
        connection.receiveMessage { data, _, _, error in
            if let data, !data.isEmpty {
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

    private func handleSrtControlPacket(type _: SrtPacketType, packet: Data) {
        delegate?.handleSrtClientPacket(packet: packet)
    }

    private func handleSrtlaKeepalive() {
        var packet = Data(count: 2)
        packet.setUInt16Be(value: SrtlaPacketType.keepalive.rawValue | srtlaPacketTypeBit)
        sendPacket(packet: packet)
    }

    private func handleDataPacket(packet: Data) {
        delegate?.handleSrtClientPacket(packet: packet)
    }

    func sendPacket(packet: Data) {
        latestSentTime = .now
        connection.send(content: packet, completion: .contentProcessed { _ in })
    }
}
