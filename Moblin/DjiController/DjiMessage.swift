import CrcSwift
import Foundation

private func djiCrc16(data: Data) -> UInt16 {
    return CrcSwift.computeCrc16(
        data,
        initialCrc: 0x496C,
        polynom: 0x1021,
        xor: 0x0000,
        refIn: true,
        refOut: true
    )
}

class DjiMessage {
    var target: UInt32
    var id: UInt16
    var type: UInt32
    var payload: Data

    init(target: UInt32, id: UInt16, type: UInt32, payload: Data) {
        self.target = target
        self.id = id
        self.type = type
        self.payload = payload
    }

    init(data: Data) throws {
        let reader = ByteArray(data: data)
        guard try reader.readUInt8() == 0x55 else {
            throw "Bad first byte"
        }
        let length = try reader.readUInt8()
        guard data.count == length else {
            throw "Bad length"
        }
        guard try reader.readUInt8() == 0x04 else {
            throw "Bad version"
        }
        target = try reader.readUInt24Le()
        id = try reader.readUInt16Le()
        type = try reader.readUInt24Le()
        payload = try reader.readBytes(reader.bytesAvailable - 2)
        let crc = try reader.readUInt16Le()
        let data = data.subdata(in: 0 ..< data.count - 2)
        let calculatedCrc = djiCrc16(data: data)
        guard crc == calculatedCrc else {
            throw "Calculated CRC \(calculatedCrc) does not match received CRC \(crc)"
        }
    }

    func encode() -> Data {
        let writer = ByteArray()
        writer.writeUInt8(0x55)
        writer.writeUInt8(UInt8(13 + payload.count))
        writer.writeUInt8(0x04)
        writer.writeUInt24Le(target)
        writer.writeUInt16Le(id)
        writer.writeUInt24Le(type)
        writer.writeBytes(payload)
        let crc = djiCrc16(data: writer.data)
        return writer.writeUInt16Le(crc).data
    }
}
