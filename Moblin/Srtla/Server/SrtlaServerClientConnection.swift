import Foundation
import Network

protocol SrtlaServerClientConnectionDelegate: AnyObject {
    func handlePacketFromSrtClient(_ connection: SrtlaServerClientConnection, packet: Data)
}

private let ackPacketLength = 2 + 10 * 4

struct AckPacket {
    var data: Data
    var nextSnOffset: Int

    init() {
        data = Data(count: ackPacketLength)
        data.setUInt16Be(value: SrtlaPacketType.ack.rawValue | srtControlPacketTypeBit)
        nextSnOffset = 2
    }

    mutating func appendSequenceNumber(sn: UInt32) -> Bool {
        data.setUInt32Be(value: sn, offset: nextSnOffset)
        nextSnOffset += 4
        if nextSnOffset == ackPacketLength {
            nextSnOffset = 2
            return true
        } else {
            return false
        }
    }
}

class SrtlaServerClientConnection {
    var connection: NWConnection
    var latestReceivedTime = ContinuousClock.now
    private var latestSentTime = ContinuousClock.now
    var delegate: (any SrtlaServerClientConnectionDelegate)?
    private var ackPacket = AckPacket()

    init(connection: NWConnection) {
        self.connection = connection
        receivePacket()
    }

    private func receivePacket() {
        connection.receiveMessage { data, _, _, error in
            if let data, !data.isEmpty {
                self.handlePacketFromClient(packet: data)
            }
            if let error {
                logger.info("srtla-server-client: Error \(error)")
                return
            }
            self.receivePacket()
        }
    }

    private func handlePacketFromClient(packet: Data) {
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
            handleSrtlaControlPacket(type: type, packet: packet)
        } else {
            handleSrtControlPacket(packet: packet)
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

    private func handleSrtControlPacket(packet: Data) {
        delegate?.handlePacketFromSrtClient(self, packet: packet)
    }

    private func handleSrtlaKeepalive() {
        var packet = Data(count: 2)
        packet.setUInt16Be(value: SrtlaPacketType.keepalive.rawValue | srtControlPacketTypeBit)
        sendPacket(packet: packet)
    }

    private func handleDataPacket(packet: Data) {
        if ackPacket.appendSequenceNumber(sn: getSequenceNumber(packet: packet)) {
            sendPacket(packet: ackPacket.data)
        }
        delegate?.handlePacketFromSrtClient(self, packet: packet)
    }

    func sendPacket(packet: Data) {
        latestSentTime = .now
        connection.send(content: packet, completion: .contentProcessed { _ in })
    }
}
