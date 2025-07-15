import Foundation

struct HevcSeiPayloadTimeCode {
    private var hours: UInt8
    private var minutes: UInt8
    private var seconds: UInt8
    private var frame: UInt32
    // private var offset: UInt32

    init(clock: Date, frame: UInt32) {
        hours = UInt8(calendar.component(.hour, from: clock))
        minutes = UInt8(calendar.component(.minute, from: clock))
        seconds = UInt8(calendar.component(.second, from: clock))
        self.frame = frame
    }

    init?(reader: NalUnitReader) {
        do {
            guard try reader.readBits(count: 2) == 1 else {
                logger.info("Not exactly one entry")
                return nil
            }
            guard try reader.readBit() else {
                logger.info("clockTimestampFlag not set")
                return nil
            }
            try reader.skipBits(count: 1 + 5)
            let fullTimestampFlag = try reader.readBit()
            try reader.skipBits(count: 1 + 1 + 8 + 1)
            if fullTimestampFlag {
                seconds = try reader.readBits(count: 6)
                minutes = try reader.readBits(count: 6)
                hours = try reader.readBits(count: 5)
            } else {
                logger.info("not full timestamp")
                return nil
            }
            let count = try reader.readBitsU32(count: 5)
            guard count <= 32 else {
                logger.info("too long offset")
                return nil
            }
            frame = 0
            // offset = try reader.readBitsU32(count: Int(count))
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
        // writer.writeBitsU32(offset, count: 10)
        writeMoreDataInPayload(writer: writer)
        return writer.data
    }

    func makeClock(vuiTimeScale: UInt32) -> Date {
        var clockTimestamp = Double(seconds) + Double(minutes) * 60 + Double(hours) * 3600
        clockTimestamp *= Double(vuiTimeScale)
        // Not good if close to new day
        let startOfDay = calendar.startOfDay(for: .now)
        return startOfDay.addingTimeInterval(clockTimestamp)
    }
}

enum HevcSeiPayloadType: UInt8 {
    case timeCode = 136
}

enum HevcNalUnitSeiPayload {
    case timeCode(HevcSeiPayloadTimeCode)
}

struct HevcNalUnitSei {
    private(set) var payload: HevcNalUnitSeiPayload

    init(payload: HevcNalUnitSeiPayload) {
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
        switch HevcSeiPayloadType(rawValue: type) {
        case .timeCode:
            guard let timeCode = HevcSeiPayloadTimeCode(reader: reader) else {
                throw "Failed to decode time code payload"
            }
            payload = .timeCode(timeCode)
        default:
            throw "Unsupported SEI payload type \(type)"
        }
    }

    func encode(writer: NalUnitWriter) {
        let type: HevcSeiPayloadType
        let data: Data
        switch payload {
        case let .timeCode(payload):
            type = .timeCode
            data = payload.encode()
        }
        writer.writeBits(type.rawValue, count: 8)
        writer.writeBits(UInt8(data.count), count: 8)
        writer.writeBytes(data)
        writeRbspTrailingBits(writer: writer)
    }
}
