import AVFoundation

/**
 - see: https://en.wikipedia.org/wiki/MPEG_transport_stream#Packet
 */
struct MpegTsPacket {
    static let size = 188
    static let fixedHeaderSize = 4
    static let syncByte: UInt8 = 0x47
    var payloadUnitStartIndicator = false
    var id: UInt16 = 0
    var continuityCounter: UInt8 = 0
    var adaptationField: MpegTsAdaptationField?
    var payload = Data()

    private func unusedSize() -> Int {
        let adaptationFieldSize = Int(adaptationField?.calcLength() ?? 0)
        return MpegTsPacket.size - MpegTsPacket.fixedHeaderSize - adaptationFieldSize - payload.count
    }

    init(id: UInt16) {
        self.id = id
    }

    init(reader: ByteArray) throws {
        let startPosition = reader.position
        guard try reader.readUInt8() == MpegTsPacket.syncByte else {
            throw "Invalid sync byte"
        }
        var byte = try reader.readUInt8()
        payloadUnitStartIndicator = (byte & 0x40) == 0x40
        id = UInt16(byte & 0x1F) << 8
        try id |= UInt16(reader.readUInt8())
        byte = try reader.readUInt8()
        continuityCounter = (byte & 0xF)
        let hasAdaptationField = (byte & 0x20) == 0x20
        if hasAdaptationField {
            let length = try reader.readUInt8()
            adaptationField = try MpegTsAdaptationField(reader: reader, length: length)
        }
        let hasPayload = (byte & 0x10) == 0x10
        if hasPayload {
            payload = try reader.readBytes(MpegTsPacket.size - (reader.position - startPosition))
        }
    }

    mutating func setPayload(_ data: Data) -> Int {
        let payloadSize = min(data.count, unusedSize())
        payload = data[0 ..< payloadSize]
        let unusedSize = unusedSize()
        if unusedSize > 0 {
            adaptationField!.setStuffing(unusedSize)
        }
        return payloadSize
    }

    mutating func setPayloadNoAdaptation(_ data: Data) {
        payload = data
        payload.append(Data(repeating: 0xFF, count: unusedSize()))
    }

    func encodeFixedHeaderInto(pointer: UnsafeMutableRawBufferPointer) {
        pointer.storeBytes(of: MpegTsPacket.syncByte, toByteOffset: 0, as: UInt8.self)
        pointer.storeBytes(
            of: (payloadUnitStartIndicator ? 0x40 : 0) | UInt8(id >> 8),
            toByteOffset: 1,
            as: UInt8.self
        )
        pointer.storeBytes(of: UInt8(id & 0x00FF), toByteOffset: 2, as: UInt8.self)
        pointer.storeBytes(
            of: (adaptationField != nil ? 0x20 : 0) | 0x10 | continuityCounter,
            toByteOffset: 3,
            as: UInt8.self
        )
    }

    func encode() -> Data {
        var header = Data(count: 4)
        header.withUnsafeMutableBytes { pointer in
            encodeFixedHeaderInto(pointer: pointer)
        }
        return header + (adaptationField?.encode() ?? Data()) + payload
    }
}

enum TSTimestamp {
    static let resolution: Double = 90 * 1000 // 90kHz
    static let dataSize: Int = 5

    static func encode(_ b: Int64, _ m: UInt8) -> Data {
        var encoded = Data(count: dataSize)
        encoded[0] = UInt8(truncatingIfNeeded: b >> 29) | 0x01 | m
        encoded[1] = UInt8(truncatingIfNeeded: b >> 22)
        encoded[2] = UInt8(truncatingIfNeeded: b >> 14) | 0x01
        encoded[3] = UInt8(truncatingIfNeeded: b >> 7)
        encoded[4] = UInt8(truncatingIfNeeded: b << 1) | 0x01
        return encoded
    }

    static func decode(_ data: Data, offset: Int = 0) -> Int64 {
        var result: Int64 = 0
        result |= Int64(data[offset + 0] & 0x0E) << 29
        result |= Int64(data[offset + 1]) << 22 | Int64(data[offset + 2] & 0xFE) << 14
        result |= Int64(data[offset + 3]) << 7 | Int64(data[offset + 3] & 0xFE) << 1
        return result
    }
}

enum TSProgramClockReference {
    static func encode(_ b: UInt64, _ e: UInt16) -> Data {
        var encoded = Data(count: 6)
        encoded[0] = UInt8(truncatingIfNeeded: b >> 25)
        encoded[1] = UInt8(truncatingIfNeeded: b >> 17)
        encoded[2] = UInt8(truncatingIfNeeded: b >> 9)
        encoded[3] = UInt8(truncatingIfNeeded: b >> 1)
        encoded[4] = 0xFF
        if (b & 1) == 1 {
            encoded[4] |= 0x80
        } else {
            encoded[4] &= 0x7F
        }
        if UInt16(encoded[4] & 0x01) >> 8 == 1 {
            encoded[4] |= 1
        } else {
            encoded[4] &= 0xFE
        }
        encoded[5] = UInt8(truncatingIfNeeded: e)
        return encoded
    }
}
