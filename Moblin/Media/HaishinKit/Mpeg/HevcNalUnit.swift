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

// periphery:ignore
func packSeiTimeCode() -> Data {
    let numClockTs: UInt8 = 1
    let clockTimestampFlag = true
    let unitFieldBasedFlag = true
    let fullTimestampFlag = true
    let hours: UInt8 = 1
    let minutes: UInt8 = 2
    let seconds: UInt8 = 3
    let timeOffset: UInt8 = 0xFF
    let numberOfFrames: UInt32 = 0
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
    } else {
        // To do...
    }
    writer.writeBits(8, count: 5)
    writer.writeBits(timeOffset, count: 8)
    return packSei(payloadType: 136, payload: writer.data)
}

private func packSei(payloadType: UInt8, payload: Data) -> Data {
    let writer = ByteArray()
    writer.writeUInt8(payloadType)
    writer.writeUInt8(UInt8(payload.count))
    writer.writeBytes(payload)
    return writer.data
}
