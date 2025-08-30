import CoreMedia
import Foundation

enum AvcNalUnitType: UInt8 {
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
    static let audHeader = AvcNalUnitHeader(refIdc: 0, type: .aud).encode()
    static let aud10WithStartCode = nalUnitStartCode + audHeader + [0x10]
    static let aud30WithStartCode = nalUnitStartCode + audHeader + [0x30]
    let header: AvcNalUnitHeader
    let payload: AvcNalUnitPayload

    init?(data: Data, offset: Int) {
        let reader = NalUnitReader(data: data, offset: offset)
        do {
            header = try AvcNalUnitHeader(reader: reader)
            switch header.type {
            case .pps:
                payload = try .pps(AvcNalUnitPps(reader: reader))
            case .sps:
                payload = try .sps(AvcNalUnitSps(reader: reader))
            case .sei:
                payload = try .sei(AvcNalUnitSei(reader: reader))
            default:
                payload = .unspec
            }
        } catch {
            logger.debug("avc: Failed to decode NAL unit with error: \(error)")
            return nil
        }
    }

    init(type: AvcNalUnitType, payload: AvcNalUnitPayload) {
        header = AvcNalUnitHeader(refIdc: 0, type: type)
        self.payload = payload
    }

    func encode() -> Data {
        let writer = NalUnitWriter()
        header.encode(writer: writer)
        payload.encode(writer: writer)
        return writer.data
    }
}

struct AvcNalUnitHeader {
    let refIdc: UInt8
    let type: AvcNalUnitType

    init(reader: NalUnitReader) throws {
        try reader.skipBits(count: 1)
        refIdc = try reader.readBits(count: 2)
        type = try AvcNalUnitType(rawValue: reader.readBits(count: 5)) ?? .unspec
    }

    init(refIdc: UInt8, type: AvcNalUnitType) {
        self.refIdc = refIdc
        self.type = type
    }

    func encode(writer: NalUnitWriter) {
        writer.writeBit(false)
        writer.writeBits(refIdc, count: 2)
        writer.writeBits(type.rawValue, count: 5)
    }

    func encode() -> Data {
        let writer = NalUnitWriter()
        encode(writer: writer)
        return writer.data
    }
}

enum AvcNalUnitPayload {
    case pps(AvcNalUnitPps)
    case sps(AvcNalUnitSps)
    case sei(AvcNalUnitSei)
    case unspec

    func encode(writer: NalUnitWriter) {
        switch self {
        case let .pps(pps):
            pps.encode(writer: writer)
        case let .sps(sps):
            sps.encode(writer: writer)
        case let .sei(sei):
            sei.encode(writer: writer)
        case .unspec:
            break
        }
    }
}

extension [AvcNalUnit] {
    func makeFormatDescription() -> CMFormatDescription? {
        guard
            let pps = first(where: { $0.header.type == .pps }),
            let sps = first(where: { $0.header.type == .sps })
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
    let writer = NalUnitWriter()
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
    let writer = ByteWriter()
    writer.writeUInt8(payloadType)
    writer.writeUInt8(UInt8(payload.count))
    writer.writeBytes(payload)
    return writer.data
}
