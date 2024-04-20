import CoreMedia
import Foundation

enum ESStreamType: UInt8 {
    case unspecific = 0x00
    case mpeg1Video = 0x01
    case mpeg2Video = 0x02
    case mpeg1Audio = 0x03
    case mpeg2Audio = 0x04
    case mpeg2TabledData = 0x05
    case mpeg2PacketizedData = 0x06

    case adtsAac = 0x0F
    case h263 = 0x10

    case h264 = 0x1B
    case h265 = 0x24

    var headerSize: Int {
        switch self {
        case .adtsAac:
            return 7
        default:
            return 0
        }
    }
}

struct ESSpecificData {
    static let fixedHeaderSize: Int = 5

    var streamType: ESStreamType = .unspecific
    var elementaryPID: UInt16 = 0
    var esInfoLength: UInt16 = 0
    var esDescriptors = Data()

    init() {}

    init?(_ data: Data) {
        self.data = data
    }

    var data: Data {
        get {
            ByteArray()
                .writeUInt8(streamType.rawValue)
                .writeUInt16(elementaryPID | 0xE000)
                .writeUInt16(esInfoLength | 0xF000)
                .writeBytes(esDescriptors)
                .data
        }
        set {
            let buffer = ByteArray(data: newValue)
            do {
                streamType = try ESStreamType(rawValue: buffer.readUInt8()) ?? .unspecific
                elementaryPID = try buffer.readUInt16() & 0x0FFF
                esInfoLength = try buffer.readUInt16() & 0x01FF
                esDescriptors = try buffer.readBytes(Int(esInfoLength))
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}
