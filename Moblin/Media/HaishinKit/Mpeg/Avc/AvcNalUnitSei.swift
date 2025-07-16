import Foundation

struct AvcSeiPayloadPictureTiming {
    private var hours: UInt8
    private var minutes: UInt8
    private var seconds: UInt8
    private var frame: UInt32

    init(clock: Date, frame: UInt32) {
        hours = UInt8(calendar.component(.hour, from: clock))
        minutes = UInt8(calendar.component(.minute, from: clock))
        seconds = UInt8(calendar.component(.second, from: clock))
        self.frame = frame
    }

    init?(reader: NalUnitReader) {
        do {
            guard try reader.readBits(count: 2) == 1 else {
                logger.info("SEI timecode: Not exactly one entry")
                return nil
            }
            guard try reader.readBit() else {
                logger.info("SEI timecode: clockTimestampFlag not set")
                return nil
            }
            try reader.skipBits(count: 1 + 5)
            let fullTimestampFlag = try reader.readBit()
            try reader.skipBits(count: 1 + 1)
            frame = try reader.readBitsU32(count: 9)
            if fullTimestampFlag {
                seconds = try reader.readBits(count: 6)
                minutes = try reader.readBits(count: 6)
                hours = try reader.readBits(count: 5)
            } else {
                logger.info("SEI timecode: Not full timestamp")
                return nil
            }
        } catch {
            return nil
        }
    }

    func encode() -> Data {
        let numClockTs: UInt8 = 1
        let clockTimestampFlag = true
        let unitFieldBasedFlag = true
        let fullTimestampFlag = true
        let writer = NalUnitWriter()
        writer.writeBits(numClockTs, count: 2)
        writer.writeBit(clockTimestampFlag)
        writer.writeBit(unitFieldBasedFlag)
        writer.writeBits(0, count: 5)
        writer.writeBit(fullTimestampFlag)
        writer.writeBit(false)
        writer.writeBit(false)
        writer.writeBitsU32(frame, count: 9)
        if fullTimestampFlag {
            writer.writeBits(seconds, count: 6)
            writer.writeBits(minutes, count: 6)
            writer.writeBits(hours, count: 5)
        }
        writer.writeBits(0, count: 5)
        writeMoreDataInPayload(writer: writer)
        return writer.data
    }

    func makeClock() -> (Date, UInt32) {
        let clockTimestamp = Double(seconds) + Double(minutes) * 60 + Double(hours) * 3600
        // Not good if close to new day
        let startOfDay = calendar.startOfDay(for: .now)
        return (startOfDay.addingTimeInterval(clockTimestamp), frame)
    }
}

enum AvcSeiPayloadType: UInt8 {
    case pictureTiming = 1
}

enum AvcNalUnitSeiPayload {
    case pictureTiming(AvcSeiPayloadPictureTiming)
}

struct AvcNalUnitSei {
    private(set) var payload: AvcNalUnitSeiPayload

    init(payload: AvcNalUnitSeiPayload) {
        self.payload = payload
    }

    init(reader: NalUnitReader) throws {
        let type = try reader.readBits(count: 8)
        guard type != 0xFF else {
            throw "SEI message type too long"
        }
        let length = try reader.readBits(count: 8)
        guard length != 0xFF else {
            throw "SEI message length too long"
        }
        switch AvcSeiPayloadType(rawValue: type) {
        case .pictureTiming:
            guard let pictureTiming = AvcSeiPayloadPictureTiming(reader: reader) else {
                throw "Failed to decode picture timing payload"
            }
            payload = .pictureTiming(pictureTiming)
        default:
            throw "Unsupported SEI payload type \(type)"
        }
    }

    func encode(writer: NalUnitWriter) {
        let type: AvcSeiPayloadType
        let data: Data
        switch payload {
        case let .pictureTiming(payload):
            type = .pictureTiming
            data = payload.encode()
        }
        writer.writeBits(type.rawValue, count: 8)
        writer.writeBits(UInt8(data.count), count: 8)
        writer.writeBytes(data)
        writeRbspTrailingBits(writer: writer)
    }
}
