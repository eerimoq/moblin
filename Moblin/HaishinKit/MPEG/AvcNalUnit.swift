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
