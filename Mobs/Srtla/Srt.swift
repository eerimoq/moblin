import Foundation

enum SrtPacketType: UInt16 {
    case ack = 0x0002
    case nak = 0x0003
}

func isDataPacket(packet: Data) -> Bool {
    return (packet[0] & 0x80) == 0
}

func getSequenceNumber(packet: Data) -> UInt32 {
    return packet.getUInt32Be()
}

func getControlPacketType(packet: Data) -> UInt16 {
    return packet.getUInt16Be() & 0x7FFF
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
