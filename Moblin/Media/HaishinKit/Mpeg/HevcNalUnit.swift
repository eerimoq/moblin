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

func hevcPackSeiTimeCode(clock: Date) -> Data {
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
        writer.writeBits(UInt8(calendar.component(.second, from: clock)), count: 6)
        writer.writeBits(UInt8(calendar.component(.minute, from: clock)), count: 6)
        writer.writeBits(UInt8(calendar.component(.hour, from: clock)), count: 5)
    }
    writer.writeBits(8, count: 5)
    writer.writeBits(timeOffset, count: 8)
    // more_data_in_payload()
    var padding = true
    while writer.bitOffset != 0 {
        writer.writeBit(padding)
        padding = false
    }
    // rbsp_trailing_bits()
    writer.writeBit(true)
    while writer.bitOffset != 0 {
        writer.writeBit(false)
    }
    return packSeiMessage(payloadType: 136, payload: writer.data)
}

private func packSeiMessage(payloadType: UInt8, payload: Data) -> Data {
    let writer = ByteArray()
    writer.writeUInt8(payloadType)
    writer.writeUInt8(UInt8(payload.count) - 1)
    writer.writeBytes(payload)
    return writer.data
}
