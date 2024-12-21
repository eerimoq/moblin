import CoreMedia
import Foundation

enum AVCNALUnitType: UInt8 {
    case unspec = 0
    case slice = 1 // P frame
    case dpa = 2
    case dpb = 3
    case dpc = 4
    case idr = 5 // I frame
    case sei = 6
    case sps = 7
    case pps = 8
    case aud = 9
    case eoseq = 10
    case eostream = 11
    case fill = 12
}

struct AvcNalUnit: NalUnit {
    let refIdc: UInt8
    let type: AVCNALUnitType
    let payload: Data

    init(_ data: Data) {
        refIdc = data[0] >> 5
        type = AVCNALUnitType(rawValue: data[0] & 0x1F) ?? .unspec
        payload = data.subdata(in: 1 ..< data.count)
    }

    func encode() -> Data {
        var result = Data()
        result.append(refIdc << 5 | type.rawValue)
        result.append(payload)
        return result
    }
}

extension [AvcNalUnit] {
    func makeFormatDescription() -> CMFormatDescription? {
        guard
            let pps = first(where: { $0.type == .pps }),
            let sps = first(where: { $0.type == .sps })
        else {
            return nil
        }
        return pps.encode().withUnsafeBytes { ppsBuffer in
            guard let ppsBaseAddress = ppsBuffer.baseAddress else {
                return nil
            }
            return sps.encode().withUnsafeBytes { spsBuffer in
                guard let spsBaseAddress = spsBuffer.baseAddress else {
                    return nil
                }
                let pointers = [
                    spsBaseAddress.assumingMemoryBound(to: UInt8.self),
                    ppsBaseAddress.assumingMemoryBound(to: UInt8.self),
                ]
                let sizes = [spsBuffer.count, ppsBuffer.count]
                var formatDescription: CMFormatDescription?
                _ = CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: kCFAllocatorDefault,
                    parameterSetCount: pointers.count,
                    parameterSetPointers: pointers,
                    parameterSetSizes: sizes,
                    nalUnitHeaderLength: 4,
                    formatDescriptionOut: &formatDescription
                )
                return formatDescription
            }
        }
    }
}

// vui_parameters_present_flag must be true in SPS for this to work as
// VUI parameters contains pic_struct_present_flag, which must be true.
// periphery:ignore
func packSeiPictureTiming() -> Data {
    let picStruct: UInt8 = 0
    let clockTimestampFlag = true
    let nuitFieldBasedFlag = true
    let hours: UInt8 = 1
    let minutes: UInt8 = 2
    let seconds: UInt8 = 3
    let timeOffset: UInt32 = 0xFFFF_FFFF
    let numberOfFrames: UInt8 = 0
    let writer = BitArray()
    writer.writeBits(picStruct, count: 4)
    writer.writeBit(clockTimestampFlag)
    writer.writeBits(0, count: 2)
    writer.writeBit(nuitFieldBasedFlag)
    writer.writeBits(0, count: 5)
    writer.writeBit(false)
    writer.writeBit(false)
    writer.writeBit(false)
    writer.writeBits(numberOfFrames, count: 8)
    writer.writeBits(seconds, count: 6)
    writer.writeBits(minutes, count: 6)
    writer.writeBits(hours, count: 5)
    writer.writeBits(UInt8((timeOffset >> 16) & 0xFF), count: 8)
    writer.writeBits(UInt8((timeOffset >> 8) & 0xFF), count: 8)
    writer.writeBits(UInt8((timeOffset >> 0) & 0xFF), count: 8)
    return packSei(payloadType: 1, payload: writer.data)
}

private func packSei(payloadType: UInt8, payload: Data) -> Data {
    let writer = ByteArray()
    writer.writeUInt8(payloadType)
    writer.writeUInt8(UInt8(payload.count))
    writer.writeBytes(payload)
    return writer.data
}
