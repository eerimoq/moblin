import AVFoundation
/**
 - seealso: https://en.wikipedia.org/wiki/MPEG_transport_stream#Packet
 */
struct TSPacket {
    static let size = 188
    static let headerSize = 4

    var payloadUnitStartIndicator = false
    var pid: UInt16 = 0
    var continuityCounter: UInt8 = 0
    var adaptationField: TSAdaptationField?
    var payload = Data()

    private var remain: Int {
        var adaptationFieldSize = 0
        if let adaptationField {
            adaptationField.compute()
            adaptationFieldSize = Int(adaptationField.length) + 1
        }
        return TSPacket.size - TSPacket.headerSize - adaptationFieldSize - payload.count
    }

    init(pid: UInt16) {
        self.pid = pid
    }

    init?(data: Data) {
        guard TSPacket.size == data.count else {
            return nil
        }
        self.data = data
    }

    mutating func fill(_ data: Data, useAdaptationField: Bool) -> Int {
        let length = min(data.count, remain, 182)
        payload.append(data[0 ..< length])
        if remain == 0 {
            return length
        }
        if useAdaptationField {
            if adaptationField == nil {
                adaptationField = TSAdaptationField()
            }
            adaptationField?.stuffing(remain)
            adaptationField?.compute()
            return length
        }
        payload.append(Data(repeating: 0xFF, count: remain))
        return length
    }

    func fixedHeader(pointer: UnsafeMutableRawBufferPointer) {
        pointer.storeBytes(of: 0x47, toByteOffset: 0, as: UInt8.self)
        pointer.storeBytes(
            of: (payloadUnitStartIndicator ? 0x40 : 0) | UInt8(pid >> 8),
            toByteOffset: 1,
            as: UInt8.self
        )
        pointer.storeBytes(of: UInt8(pid & 0x00FF), toByteOffset: 2, as: UInt8.self)
        pointer.storeBytes(
            of: (adaptationField != nil ? 0x20 : 0) | 0x10 | continuityCounter,
            toByteOffset: 3,
            as: UInt8.self
        )
    }

    var data: Data {
        get {
            let bytes = Data([
                0x47,
                (payloadUnitStartIndicator ? 0x40 : 0) | UInt8(pid >> 8),
                UInt8(pid & 0x00FF),
                (adaptationField != nil ? 0x20 : 0) | 0x10 | continuityCounter,
            ])
            return ByteArray()
                .writeBytes(bytes)
                .writeBytes(adaptationField?.data ?? Data())
                .writeBytes(payload)
                .data
        }
        set {
            let buffer = ByteArray(data: newValue)
            do {
                let data: Data = try buffer.readBytes(4)
                payloadUnitStartIndicator = (data[1] & 0x40) == 0x40
                pid = UInt16(data[1] & 0x1F) << 8 | UInt16(data[2])
                let adaptationFieldFlag = (data[3] & 0x20) == 0x20
                continuityCounter = UInt8(data[3] & 0xF)
                if adaptationFieldFlag {
                    let length = try Int(buffer.readUInt8())
                    buffer.position -= 1
                    adaptationField = try TSAdaptationField(data: buffer.readBytes(length + 1))
                }
                payload = try buffer.readBytes(buffer.bytesAvailable)
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}

enum TSTimestamp {
    static let resolution: Double = 90 * 1000 // 90kHz
    static let dataSize: Int = 5
    static let ptsMask: UInt8 = 0x10
    static let ptsDtsMask: UInt8 = 0x30

    static func decode(_ data: Data, offset: Int = 0) -> Int64 {
        var result: Int64 = 0
        result |= Int64(data[offset + 0] & 0x0E) << 29
        result |= Int64(data[offset + 1]) << 22 | Int64(data[offset + 2] & 0xFE) << 14
        result |= Int64(data[offset + 3]) << 7 | Int64(data[offset + 3] & 0xFE) << 1
        return result
    }

    static func encode(_ b: Int64, _ m: UInt8) -> Data {
        var data = Data(count: dataSize)
        data[0] = UInt8(truncatingIfNeeded: b >> 29) | 0x01 | m
        data[1] = UInt8(truncatingIfNeeded: b >> 22)
        data[2] = UInt8(truncatingIfNeeded: b >> 14) | 0x01
        data[3] = UInt8(truncatingIfNeeded: b >> 7)
        data[4] = UInt8(truncatingIfNeeded: b << 1) | 0x01
        return data
    }
}

enum TSProgramClockReference {
    static let resolutionForBase: Int32 = 90 * 1000 // 90kHz
    static let resolutionForExtension: Int32 = 27 * 1000 * 1000 // 27MHz

    static func decode(_ data: Data) -> (UInt64, UInt16) {
        var b: UInt64 = 0
        var e: UInt16 = 0
        b |= UInt64(data[0]) << 25
        b |= UInt64(data[1]) << 17
        b |= UInt64(data[2]) << 9
        b |= UInt64(data[3]) << 1
        b |= ((data[4] & 0x80) == 0x80) ? 1 : 0
        e |= UInt16(data[4] & 0x01) << 8
        e |= UInt16(data[5])
        return (b, e)
    }

    static func encode(_ b: UInt64, _ e: UInt16) -> Data {
        var data = Data(count: 6)
        data[0] = UInt8(truncatingIfNeeded: b >> 25)
        data[1] = UInt8(truncatingIfNeeded: b >> 17)
        data[2] = UInt8(truncatingIfNeeded: b >> 9)
        data[3] = UInt8(truncatingIfNeeded: b >> 1)
        data[4] = 0xFF
        if (b & 1) == 1 {
            data[4] |= 0x80
        } else {
            data[4] &= 0x7F
        }
        if UInt16(data[4] & 0x01) >> 8 == 1 {
            data[4] |= 1
        } else {
            data[4] &= 0xFE
        }
        data[5] = UInt8(truncatingIfNeeded: e)
        return data
    }
}
