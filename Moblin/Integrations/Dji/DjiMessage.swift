import CrcSwift
import Foundation

private func djiCrc8(data: Data) -> UInt8 {
    return CrcSwift.computeCrc8(
        data,
        initialCrc: 0xEE,
        polynom: 0x31,
        xor: 0x00,
        refIn: true,
        refOut: true
    )
}

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

private func djiRSdkCrc16(data: Data) -> UInt16 {
    return CrcSwift.computeCrc16(
        data,
        initialCrc: 0x3AA3,
        polynom: 0x8005,
        xor: 0x0000,
        refIn: true,
        refOut: true
    )
}

private func djiRSdkCrc32(data: Data) -> UInt32 {
    return CrcSwift.computeCrc32(
        data,
        initialCrc: 0x00003AA3,
        polynom: 0x04C1_1DB7,
        xor: 0x0000_0000,
        refIn: true,
        refOut: true
    )
}

func djiPackString(value: String) -> Data {
    let data = value.utf8Data
    return Data([UInt8(truncatingIfNeeded: data.count)]) + data
}

func djiPackUrl(url: String) -> Data {
    let data = url.utf8Data
    return Data([UInt8(truncatingIfNeeded: data.count), 0]) + data
}

class DjiMessage {
    var target: UInt16
    var id: UInt16
    var type: UInt32
    var payload: Data

    init(target: UInt16, id: UInt16, type: UInt32, payload: Data) {
        self.target = target
        self.id = id
        self.type = type
        self.payload = payload
    }

    init(data: Data) throws {
        let reader = ByteReader(data: data)
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
        let hedaerCrc = try reader.readUInt8()
        let calculatedHeaderCrc = djiCrc8(data: data.subdata(in: 0 ..< 3))
        guard hedaerCrc == calculatedHeaderCrc else {
            throw "Calculated CRC \(calculatedHeaderCrc) does not match received CRC \(hedaerCrc)"
        }
        target = try reader.readUInt16Le()
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
        let writer = ByteWriter()
        writer.writeUInt8(0x55)
        writer.writeUInt8(UInt8(truncatingIfNeeded: 13 + payload.count))
        writer.writeUInt8(0x04)
        writer.writeUInt8(djiCrc8(data: writer.data))
        writer.writeUInt16Le(target)
        writer.writeUInt16Le(id)
        writer.writeUInt24Le(type)
        writer.writeBytes(payload)
        let crc = djiCrc16(data: writer.data)
        writer.writeUInt16Le(crc)
        return writer.data
    }

    func format() -> String {
        return "target: \(target), id: \(id), type: \(type) \(payload.hexString())"
    }
}

class DjiRSdkMessage {
    var cmdType: UInt8
    var seq: UInt16
    var cmdSet: UInt8
    var cmdId: UInt8
    var payload: Data

    var isResponse: Bool {
        return (cmdType & 0x20) != 0
    }

    init(cmdType: UInt8, seq: UInt16, cmdSet: UInt8, cmdId: UInt8, payload: Data) {
        self.cmdType = cmdType
        self.seq = seq
        self.cmdSet = cmdSet
        self.cmdId = cmdId
        self.payload = payload
    }

    init(data: Data) throws {
        let reader = ByteReader(data: data)
        guard try reader.readUInt8() == 0xAA else {
            throw "Bad SOF byte"
        }
        let verLength = try reader.readUInt16Le()
        let expectedLength = Int(verLength & 0x03FF)
        guard data.count == expectedLength else {
            throw "Frame length mismatch: expected \(expectedLength), got \(data.count)"
        }
        guard data.count >= 16 else {
            throw "Frame too short"
        }
        cmdType = try reader.readUInt8()
        try reader.skipBytes(4)
        seq = try reader.readUInt16Le()
        let receivedCrc16 = try reader.readUInt16Le()
        let calculatedCrc16 = djiRSdkCrc16(data: data.subdata(in: 0 ..< 10))
        guard receivedCrc16 == calculatedCrc16 else {
            throw "CRC-16 mismatch: received \(receivedCrc16), calculated \(calculatedCrc16)"
        }
        cmdSet = try reader.readUInt8()
        cmdId = try reader.readUInt8()
        payload = try reader.readBytes(reader.bytesAvailable - 4)
        let receivedCrc32 = try reader.readUInt32Le()
        let calculatedCrc32 = djiRSdkCrc32(data: data.subdata(in: 0 ..< data.count - 4))
        guard receivedCrc32 == calculatedCrc32 else {
            throw "CRC-32 mismatch: received \(receivedCrc32), calculated \(calculatedCrc32)"
        }
    }

    func encode() -> Data {
        let dataPayload = Data([cmdSet, cmdId]) + payload
        let totalLength = 12 + dataPayload.count + 4
        let writer = ByteWriter()
        writer.writeUInt8(0xAA)
        let verLength = UInt16(totalLength & 0x03FF)
        writer.writeUInt16Le(verLength)
        writer.writeUInt8(cmdType)
        writer.writeUInt8(0x00)
        writer.writeUInt8(0x00)
        writer.writeUInt8(0x00)
        writer.writeUInt8(0x00)
        writer.writeUInt16Le(seq)
        let crc16 = djiRSdkCrc16(data: writer.data)
        writer.writeUInt16Le(crc16)
        writer.writeBytes(dataPayload)
        let crc32 = djiRSdkCrc32(data: writer.data)
        writer.writeUInt32Le(crc32)
        return writer.data
    }

    func format() -> String {
        let typeStr = isResponse ? "RSP" : "CMD"
        return "R-SDK [\(typeStr)] seq:\(seq) cmd:(\(String(format: "0x%02X", cmdSet))," +
            "\(String(format: "0x%02X", cmdId))) \(payload.hexString())"
    }
}
