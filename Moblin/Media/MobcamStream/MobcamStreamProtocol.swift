import Foundation

let mobcamStreamProtocolVersion: UInt8 = 1
let mobcamStreamProtocolMagic = Data("MOBL".utf8)

private let maximumMessageLength = 4 * 1024 * 1024

enum MobcamStreamMessageType: UInt8 {
    case hostHello = 0x01
    case deviceHello = 0x02
    case videoConfig = 0x03
    case videoFrame = 0x04
    case audioConfig = 0x05
    case audioFrame = 0x06
}

enum MobcamStreamVideoCodec: UInt8 {
    case h264 = 0
    case hevc = 1
}

enum MobcamStreamAudioCodec: UInt8 {
    case aac = 0
}

enum MobcamStreamProtocolError: Error {
    case badMagic
    case unsupportedVersion(UInt8)
    case unknownMessageType(UInt8)
    case badLength(Int)
}

struct MobcamStreamDeviceInfo: Codable {
    let name: String
    let version: String
}

func packMobcamStreamMessage(_ type: MobcamStreamMessageType, _ payload: Data) -> Data {
    let writer = ByteWriter()
    writer.writeUInt32(UInt32(payload.count + 1))
    writer.writeUInt8(type.rawValue)
    writer.writeBytes(payload)
    return writer.data
}

func packMobcamStreamHostHello() -> Data {
    let writer = ByteWriter()
    writer.writeBytes(mobcamStreamProtocolMagic)
    writer.writeUInt8(mobcamStreamProtocolVersion)
    return packMobcamStreamMessage(.hostHello, writer.data)
}

func unpackMobcamStreamHostHello(_ payload: Data) throws {
    let reader = ByteReader(data: payload)
    guard try reader.readBytes(mobcamStreamProtocolMagic.count) == mobcamStreamProtocolMagic else {
        throw MobcamStreamProtocolError.badMagic
    }
    let version = try reader.readUInt8()
    guard version == mobcamStreamProtocolVersion else {
        throw MobcamStreamProtocolError.unsupportedVersion(version)
    }
}

func packMobcamStreamDeviceHello(_ info: MobcamStreamDeviceInfo) -> Data {
    let writer = ByteWriter()
    writer.writeUInt8(mobcamStreamProtocolVersion)
    let encoded = (try? JSONEncoder().encode(info)) ?? Data()
    writer.writeUInt32(UInt32(encoded.count))
    writer.writeBytes(encoded)
    return packMobcamStreamMessage(.deviceHello, writer.data)
}

func packMobcamStreamVideoConfig(codec: MobcamStreamVideoCodec,
                                 width: UInt16,
                                 height: UInt16,
                                 configurationRecord: Data) -> Data
{
    let writer = ByteWriter()
    writer.writeUInt8(codec.rawValue)
    writer.writeUInt16(width)
    writer.writeUInt16(height)
    writer.writeUInt32(UInt32(configurationRecord.count))
    writer.writeBytes(configurationRecord)
    return packMobcamStreamMessage(.videoConfig, writer.data)
}

func packMobcamStreamVideoFrame(presentationTimeStamp: UInt64, isSync: Bool, units: Data) -> Data {
    let writer = ByteWriter()
    writer.writeUInt64(presentationTimeStamp)
    writer.writeUInt8(isSync ? 1 : 0)
    writer.writeBytes(units)
    return packMobcamStreamMessage(.videoFrame, writer.data)
}

func packMobcamStreamAudioConfig(codec: MobcamStreamAudioCodec,
                                 sampleRate: UInt32,
                                 channels: UInt8,
                                 configurationRecord: Data) -> Data
{
    let writer = ByteWriter()
    writer.writeUInt8(codec.rawValue)
    writer.writeUInt32(sampleRate)
    writer.writeUInt8(channels)
    writer.writeUInt32(UInt32(configurationRecord.count))
    writer.writeBytes(configurationRecord)
    return packMobcamStreamMessage(.audioConfig, writer.data)
}

func packMobcamStreamAudioFrame(presentationTimeStamp: UInt64, unit: Data) -> Data {
    let writer = ByteWriter()
    writer.writeUInt64(presentationTimeStamp)
    writer.writeBytes(unit)
    return packMobcamStreamMessage(.audioFrame, writer.data)
}

class MobcamStreamMessageReader {
    private var buffer = Data()

    func append(_ data: Data) {
        buffer += data
    }

    func read() throws -> (MobcamStreamMessageType, Data)? {
        guard buffer.count >= 4 else {
            return nil
        }
        let length = Int(buffer.getFourBytesBe())
        guard length >= 1, length <= maximumMessageLength else {
            throw MobcamStreamProtocolError.badLength(length)
        }
        guard buffer.count >= 4 + length else {
            return nil
        }
        guard let type = MobcamStreamMessageType(rawValue: buffer[4]) else {
            throw MobcamStreamProtocolError.unknownMessageType(buffer[4])
        }
        let payload = buffer.subdata(in: 5 ..< 4 + length)
        buffer.removeSubrange(0 ..< 4 + length)
        return (type, payload)
    }
}
