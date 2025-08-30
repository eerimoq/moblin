import CoreMedia
import Foundation

enum ElementaryStreamType: UInt8 {
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
}

enum ElementaryStreamDescriptiorTag: UInt8 {
    case registration = 0x05
    case `extension` = 0x7F
}

enum ElementaryStreamDescriptiorRegistration {
    static let opus = "Opus".utf8Data
}

struct ElementaryStreamSpecificData {
    static let fixedHeaderSize = 5
    var streamType: ElementaryStreamType = .unspecific
    var elementaryPacketId: UInt16 = 0
    private var esDescriptors = Data()

    init() {}

    init(reader: ByteReader) throws {
        streamType = try ElementaryStreamType(rawValue: reader.readUInt8()) ?? .unspecific
        elementaryPacketId = try reader.readUInt16() & 0x0FFF
        let esInfoLength = try reader.readUInt16() & 0x01FF
        esDescriptors = try reader.readBytes(Int(esInfoLength))
    }

    mutating func appendDescriptor(tag: ElementaryStreamDescriptiorTag, data: Data) {
        esDescriptors.append(tag.rawValue)
        esDescriptors.append(UInt8(data.count))
        esDescriptors += data
    }

    func getDescriptor(tag: ElementaryStreamDescriptiorTag) -> Data? {
        let reader = ByteReader(data: esDescriptors)
        do {
            while true {
                let rawTag = try reader.readUInt8()
                let length = try Int(reader.readUInt8())
                if ElementaryStreamDescriptiorTag(rawValue: rawTag) == tag {
                    return try reader.readBytes(length)
                } else {
                    try reader.skipBytes(length)
                }
            }
        } catch {}
        return nil
    }

    func encode() -> Data {
        let writer = ByteWriter()
        writer.writeUInt8(streamType.rawValue)
        writer.writeUInt16(elementaryPacketId | 0xE000)
        writer.writeUInt16(UInt16(esDescriptors.count) | 0xF000)
        writer.writeBytes(esDescriptors)
        return writer.data
    }
}
