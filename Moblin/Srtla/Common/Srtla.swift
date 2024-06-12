import Foundation

enum SrtlaPacketType: UInt16 {
    case keepalive = 0x1000
    case ack = 0x1100
    case reg1 = 0x1200
    case reg2 = 0x1201
    case reg3 = 0x1202
    case regErr = 0x1210
    case regNgp = 0x1211
    case regNak = 0x1212
}

func createSrtlaPacket(type: SrtlaPacketType, length: Int) -> Data {
    var packet = Data(count: length)
    packet.setUInt16Be(value: type.rawValue | srtControlPacketTypeBit)
    return packet
}
