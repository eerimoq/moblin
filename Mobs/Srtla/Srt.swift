import Foundation

enum SrtPacketType: UInt16 {
    case handshake = 0x0000
    case keepAlive = 0x0001
    case ack = 0x0002
    case nak = 0x0003
    case congestionWarning = 0x0004
    case shutdown = 0x0005
    case ackAck = 0x0006
    case dropReq = 0x0007
    case peerError = 0x0008
}

func isControlPacket(packet: Data) -> Bool {
    return (packet[0] & 0x80) == 0x80
}

func isDataPacket(packet: Data) -> Bool {
    return (packet[0] & 0x80) == 0
}

func getControlPacketType(packet: Data) -> UInt16 {
    return packet.getUInt16Be() & 0x7FFF
}

func isFullAckPacket(packet: Data) -> Bool {
    if packet.count != 44 {
        return false
    }
    return packet.getUInt32Be(offset: 4) != 0
}

func getFullAckPacketRtt(packet: Data) -> UInt32 {
    return packet.getUInt32Be(offset: 20)
}

func getFullAckPacketRttVariance(packet: Data) -> UInt32 {
    return packet.getUInt32Be(offset: 24)
}

func getFullAckPacketPacketsReceivingRate(packet: Data) -> UInt32 {
    return packet.getUInt32Be(offset: 32)
}

func getSequenceNumber(packet: Data) -> UInt32 {
    return packet.getUInt32Be()
}

func isSnAcked(sn: UInt32, ackSn: UInt32) -> Bool {
    if sn < ackSn {
        return ackSn - sn < 100_000_000
    } else {
        return sn - ackSn > 100_000_000
    }
}

func isSnRange(sn: UInt32) -> Bool {
    return (sn & 0x8000_0000) == 0x8000_0000
}
