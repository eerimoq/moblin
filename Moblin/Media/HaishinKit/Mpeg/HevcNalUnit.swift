import CoreMedia
import Foundation

enum HevcNalUnitType: UInt8 {
    case codedSliceTrailN = 0
    case codedSliceTrailR = 1
    case codedSliceTsaN = 2
    case codedSliceTsaR = 3
    case codedSliceStsaN = 4
    case codedSliceStsaR = 5
    case codedSliceRadlN = 6
    case codedSliceRadlR = 7
    case codedSliceRaslN = 8
    case codedSliceRsslR = 9
    /// 10...15 Reserved
    case vps = 32
    case sps = 33
    case pps = 34
    case accessUnitDelimiter = 35
    case prefixSeiNut = 39
    case unspec = 0xFF
}

struct HevcNalUnit: NalUnit {
    let type: HevcNalUnitType
    let temporalIdPlusOne: UInt8
    let payload: Data

    init(_ data: Data) {
        type = HevcNalUnitType(rawValue: (data[0] & 0x7E) >> 1) ?? .unspec
        temporalIdPlusOne = data[1] & 0b0001_1111
        payload = data.subdata(in: 2 ..< data.count)
    }

    init(type: HevcNalUnitType, temporalIdPlusOne: UInt8, payload: Data) {
        self.type = type
        self.temporalIdPlusOne = temporalIdPlusOne
        self.payload = payload
    }

    func encode() -> Data {
        var result = Data()
        result.append(type.rawValue << 1)
        result.append(temporalIdPlusOne)
        result.append(payload)
        return result
    }
}

extension [HevcNalUnit] {
    func makeFormatDescription() -> CMFormatDescription? {
        guard
            let vps = first(where: { $0.type == .vps }),
            let sps = first(where: { $0.type == .sps }),
            let pps = first(where: { $0.type == .pps })
        else {
            return nil
        }
        return vps.encode().withUnsafeBytes { vpsBuffer in
            guard let vpsBaseAddress = vpsBuffer.baseAddress else {
                return nil
            }
            return sps.encode().withUnsafeBytes { spsBuffer in
                guard let spsBaseAddress = spsBuffer.baseAddress else {
                    return nil
                }
                return pps.encode().withUnsafeBytes { ppsBuffer in
                    guard let ppsBaseAddress = ppsBuffer.baseAddress else {
                        return nil
                    }
                    let pointers = [
                        vpsBaseAddress.assumingMemoryBound(to: UInt8.self),
                        spsBaseAddress.assumingMemoryBound(to: UInt8.self),
                        ppsBaseAddress.assumingMemoryBound(to: UInt8.self),
                    ]
                    let sizes = [vpsBuffer.count, spsBuffer.count, ppsBuffer.count]
                    var formatDescription: CMFormatDescription?
                    _ = CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                        allocator: kCFAllocatorDefault,
                        parameterSetCount: pointers.count,
                        parameterSetPointers: pointers,
                        parameterSetSizes: sizes,
                        nalUnitHeaderLength: 4,
                        extensions: nil,
                        formatDescriptionOut: &formatDescription
                    )
                    return formatDescription
                }
            }
        }
    }
}

private let calendar: Calendar = {
    var utcCalender = Calendar(identifier: .iso8601)
    utcCalender.timeZone = TimeZone(abbreviation: "UTC")!
    return utcCalender
}()

struct HevcSeiPayloadTimeCode {
    private var hours: UInt8
    private var minutes: UInt8
    private var seconds: UInt8

    init(clock: Date) {
        hours = UInt8(calendar.component(.hour, from: clock))
        minutes = UInt8(calendar.component(.minute, from: clock))
        seconds = UInt8(calendar.component(.second, from: clock))
    }

    init?(reader: BitArray) {
        do {
            guard try reader.readBits(count: 2) == 1 else {
                logger.info("Not exactly one entry")
                return nil
            }
            guard try reader.readBit() else {
                logger.info("clockTimestampFlag not set")
                return nil
            }
            _ = try reader.readBit()
            _ = try reader.readBits(count: 5)
            let fullTimestampFlag = try reader.readBit()
            _ = try reader.readBit()
            _ = try reader.readBit()
            _ = try reader.readBits(count: 8)
            _ = try reader.readBits(count: 1)
            if fullTimestampFlag {
                seconds = try reader.readBits(count: 6)
                minutes = try reader.readBits(count: 6)
                hours = try reader.readBits(count: 5)
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }

    func makeClock(vuiTimeScale: UInt32) -> Date {
        var clockTimestamp = Double(seconds) + Double(minutes) * 60 + Double(hours) * 3600
        clockTimestamp *= Double(vuiTimeScale)
        // Not good if close to new day
        let startOfDay = calendar.startOfDay(for: .now)
        return startOfDay.addingTimeInterval(clockTimestamp)
    }

    func encode() -> Data {
        let numClockTs: UInt8 = 1
        let clockTimestampFlag = true
        let unitFieldBasedFlag = true
        let fullTimestampFlag = true
        let timeOffset: UInt8 = 5
        let numberOfFrames: UInt32 = 30
        let writer = BitArray()
        writer.writeBits(numClockTs, count: 2)
        writer.writeBit(clockTimestampFlag)
        writer.writeBit(unitFieldBasedFlag)
        writer.writeBits(0, count: 5)
        writer.writeBit(fullTimestampFlag)
        writer.writeBit(false)
        writer.writeBit(false)
        writer.writeBits(UInt8((numberOfFrames >> 8) & 0xFF), count: 8)
        writer.writeBits(UInt8((numberOfFrames >> 0) & 0xFF), count: 1)
        if fullTimestampFlag {
            writer.writeBits(seconds, count: 6)
            writer.writeBits(minutes, count: 6)
            writer.writeBits(hours, count: 5)
        }
        writer.writeBits(8, count: 5)
        writer.writeBits(timeOffset, count: 8)
        writeMoreDataInPayload(writer: writer)
        return writer.data
    }
}

enum HevcSeiPayloadType: UInt8 {
    case timeCode = 136
}

enum HevcSeiPayload {
    case timeCode(HevcSeiPayloadTimeCode)
}

struct HevcSei {
    private(set) var payload: HevcSeiPayload

    init(payload: HevcSeiPayload) {
        self.payload = payload
    }

    init?(data: Data) {
        let reader = BitArray(data: data)
        do {
            let type = try reader.readBits(count: 8)
            guard type != 0xFF else {
                logger.info("nal: SEI message type too long")
                return nil
            }
            let length = try reader.readBits(count: 8)
            guard length != 0xFF else {
                logger.info("nal: SEI message length too long")
                return nil
            }
            switch HevcSeiPayloadType(rawValue: type) {
            case .timeCode:
                guard let timeCode = HevcSeiPayloadTimeCode(reader: reader) else {
                    logger.info("nal: failed to decode time code payload")
                    return nil
                }
                payload = .timeCode(timeCode)
            default:
                return nil
            }
        } catch {
            return nil
        }
    }

    func encode() -> Data {
        let type: HevcSeiPayloadType
        let data: Data
        switch payload {
        case let .timeCode(payload):
            type = .timeCode
            data = payload.encode()
        }
        let writer = BitArray()
        writer.writeBits(type.rawValue, count: 8)
        writer.writeBits(UInt8(data.count), count: 8)
        writer.writeBytes(data)
        writeRbspTrailingBits(writer: writer)
        return writer.data
    }
}

private func writeRbspTrailingBits(writer: BitArray) {
    writer.writeBit(true)
    while writer.bitOffset != 0 {
        writer.writeBit(false)
    }
}

private func writeMoreDataInPayload(writer: BitArray) {
    var padding = true
    while writer.bitOffset != 0 {
        writer.writeBit(padding)
        padding = false
    }
}
