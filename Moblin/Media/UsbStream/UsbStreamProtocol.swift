import Foundation

let usbStreamProtocolVersion: UInt8 = 1
let usbStreamProtocolMagic = Data("MOBL".utf8)

private let maximumMessageLength = 4 * 1024 * 1024

enum UsbStreamMessageType: UInt8 {
    case hostHello = 0x01
    case deviceHello = 0x02
    case videoConfig = 0x03
    case videoFrame = 0x04
    case audioConfig = 0x05
    case audioFrame = 0x06
}

enum UsbStreamVideoCodec: UInt8 {
    case h264 = 0
    case hevc = 1
}

enum UsbStreamAudioCodec: UInt8 {
    case aac = 0
}

enum UsbStreamProtocolError: Error {
    case badMagic
    case unsupportedVersion(UInt8)
    case unknownMessageType(UInt8)
    case badLength(Int)
}

struct UsbStreamDeviceInfo: Codable {
    let name: String
    let version: String
}

func packUsbStreamMessage(_ type: UsbStreamMessageType, _ payload: Data) -> Data {
    let writer = ByteWriter()
    writer.writeUInt32(UInt32(payload.count + 1))
    writer.writeUInt8(type.rawValue)
    writer.writeBytes(payload)
    return writer.data
}

func packUsbStreamHostHello() -> Data {
    let writer = ByteWriter()
    writer.writeBytes(usbStreamProtocolMagic)
    writer.writeUInt8(usbStreamProtocolVersion)
    return packUsbStreamMessage(.hostHello, writer.data)
}

func unpackUsbStreamHostHello(_ payload: Data) throws {
    let reader = ByteReader(data: payload)
    guard try reader.readBytes(usbStreamProtocolMagic.count) == usbStreamProtocolMagic else {
        throw UsbStreamProtocolError.badMagic
    }
    let version = try reader.readUInt8()
    guard version == usbStreamProtocolVersion else {
        throw UsbStreamProtocolError.unsupportedVersion(version)
    }
}

func packUsbStreamDeviceHello(_ info: UsbStreamDeviceInfo) -> Data {
    let writer = ByteWriter()
    writer.writeUInt8(usbStreamProtocolVersion)
    let encoded = (try? JSONEncoder().encode(info)) ?? Data()
    writer.writeUInt32(UInt32(encoded.count))
    writer.writeBytes(encoded)
    return packUsbStreamMessage(.deviceHello, writer.data)
}

func packUsbStreamVideoConfig(codec: UsbStreamVideoCodec,
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
    return packUsbStreamMessage(.videoConfig, writer.data)
}

func packUsbStreamVideoFrame(presentationTimeStamp: UInt64, isSync: Bool, units: Data) -> Data {
    let writer = ByteWriter()
    writer.writeUInt64(presentationTimeStamp)
    writer.writeUInt8(isSync ? 1 : 0)
    writer.writeBytes(units)
    return packUsbStreamMessage(.videoFrame, writer.data)
}

func packUsbStreamAudioConfig(codec: UsbStreamAudioCodec,
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
    return packUsbStreamMessage(.audioConfig, writer.data)
}

func packUsbStreamAudioFrame(presentationTimeStamp: UInt64, unit: Data) -> Data {
    let writer = ByteWriter()
    writer.writeUInt64(presentationTimeStamp)
    writer.writeBytes(unit)
    return packUsbStreamMessage(.audioFrame, writer.data)
}

class UsbStreamMessageReader {
    private var buffer = Data()

    func append(_ data: Data) {
        buffer += data
    }

    func read() throws -> (UsbStreamMessageType, Data)? {
        guard buffer.count >= 4 else {
            return nil
        }
        let length = Int(buffer.getFourBytesBe())
        guard length >= 1, length <= maximumMessageLength else {
            throw UsbStreamProtocolError.badLength(length)
        }
        guard buffer.count >= 4 + length else {
            return nil
        }
        guard let type = UsbStreamMessageType(rawValue: buffer[4]) else {
            throw UsbStreamProtocolError.unknownMessageType(buffer[4])
        }
        let payload = buffer.subdata(in: 5 ..< 4 + length)
        buffer.removeSubrange(0 ..< 4 + length)
        return (type, payload)
    }
}
