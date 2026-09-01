import Foundation

let mobcamStreamProtocolVersion: UInt8 = 1

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
    case opus = 1
}

enum MobcamStreamProtocolError: Error {
    case unsupportedVersion(UInt8)
    case unknownMessageType(UInt8)
}

struct MobcamStreamDeviceInfo: Codable {
    let name: String
    let version: String
}

private func packMobcamStreamMessage(_ type: MobcamStreamMessageType,
                                     _ payloadLength: Int) -> ByteWriter
{
    let writer = ByteWriter(data: Data(capacity: 5 + payloadLength))
    writer.writeUInt8(type.rawValue)
    writer.writeUInt32(UInt32(payloadLength))
    return writer
}

func packMobcamStreamHostHello() -> Data {
    let writer = packMobcamStreamMessage(.hostHello, 1)
    writer.writeUInt8(mobcamStreamProtocolVersion)
    return writer.data
}

func unpackMobcamStreamHostHello(_ payload: Data) throws {
    let reader = ByteReader(data: payload)
    let version = try reader.readUInt8()
    guard version == mobcamStreamProtocolVersion else {
        throw MobcamStreamProtocolError.unsupportedVersion(version)
    }
}

func packMobcamStreamDeviceHello(_ info: MobcamStreamDeviceInfo) -> Data {
    let encoded = (try? JSONEncoder().encode(info)) ?? Data()
    let writer = packMobcamStreamMessage(.deviceHello, 5 + encoded.count)
    writer.writeUInt8(mobcamStreamProtocolVersion)
    writer.writeUInt32(UInt32(encoded.count))
    writer.writeBytes(encoded)
    return writer.data
}

func packMobcamStreamVideoConfig(codec: MobcamStreamVideoCodec,
                                 width: UInt16,
                                 height: UInt16,
                                 configurationRecord: Data) -> Data
{
    let writer = packMobcamStreamMessage(.videoConfig, 9 + configurationRecord.count)
    writer.writeUInt8(codec.rawValue)
    writer.writeUInt16(width)
    writer.writeUInt16(height)
    writer.writeUInt32(UInt32(configurationRecord.count))
    writer.writeBytes(configurationRecord)
    return writer.data
}

func packMobcamStreamVideoFrame(presentationTimeStamp: UInt64,
                                isSync: Bool,
                                units: UnsafeRawBufferPointer) -> Data
{
    let writer = packMobcamStreamMessage(.videoFrame, 9 + units.count)
    writer.writeUInt64(presentationTimeStamp)
    writer.writeUInt8(isSync ? 1 : 0)
    writer.writeBytes(units)
    return writer.data
}

func packMobcamStreamAudioConfig(codec: MobcamStreamAudioCodec,
                                 sampleRate: UInt32,
                                 channels: UInt8,
                                 configurationRecord: Data) -> Data
{
    let writer = packMobcamStreamMessage(.audioConfig, 10 + configurationRecord.count)
    writer.writeUInt8(codec.rawValue)
    writer.writeUInt32(sampleRate)
    writer.writeUInt8(channels)
    writer.writeUInt32(UInt32(configurationRecord.count))
    writer.writeBytes(configurationRecord)
    return writer.data
}

func packMobcamStreamOpusHead(sampleRate: UInt32, channels: UInt8) -> Data {
    let writer = ByteWriter(data: Data(capacity: 19))
    writer.writeUTF8Bytes("OpusHead")
    writer.writeUInt8(1)
    writer.writeUInt8(channels)
    writer.writeUInt16Le(0)
    writer.writeUInt32Le(sampleRate)
    writer.writeUInt16Le(0)
    writer.writeUInt8(0)
    return writer.data
}

func packMobcamStreamAudioFrame(presentationTimeStamp: UInt64, unit: UnsafeRawBufferPointer) -> Data {
    let writer = packMobcamStreamMessage(.audioFrame, 8 + unit.count)
    writer.writeUInt64(presentationTimeStamp)
    writer.writeBytes(unit)
    return writer.data
}

class MobcamStreamMessageReader {
    private var buffer = Data()

    func append(_ data: Data) {
        buffer += data
    }

    func read() throws -> (MobcamStreamMessageType, Data)? {
        guard buffer.count >= 5 else {
            return nil
        }
        let reader = ByteReader(data: buffer)
        let type = try reader.readUInt8()
        guard let type = MobcamStreamMessageType(rawValue: type) else {
            throw MobcamStreamProtocolError.unknownMessageType(type)
        }
        let length = try Int(reader.readUInt32())
        guard reader.bytesAvailable >= length else {
            return nil
        }
        let payload = try reader.readBytes(length)
        buffer.removeSubrange(0 ..< reader.position)
        return (type, payload)
    }
}
