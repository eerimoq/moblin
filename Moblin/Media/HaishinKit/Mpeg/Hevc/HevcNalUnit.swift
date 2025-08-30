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
    let header: HevcNalUnitHeader
    let payload: HevcNalUnitPayload

    init?(data: Data, offset: Int) {
        let reader = NalUnitReader(data: data, offset: offset)
        do {
            header = try HevcNalUnitHeader(reader: reader)
            switch header.type {
            case .vps:
                payload = try .vps(HevcNalUnitVps(reader: reader))
            case .sps:
                payload = try .sps(HevcNalUnitSps(reader: reader))
            case .pps:
                payload = try .pps(HevcNalUnitPps(reader: reader))
            case .prefixSeiNut:
                payload = try .prefixSeiNut(HevcNalUnitSei(reader: reader))
            default:
                payload = .unspec
            }
        } catch {
            logger.debug("hevc: Failed to decode NAL unit with error: \(error)")
            return nil
        }
    }

    init(type: HevcNalUnitType, temporalIdPlusOne: UInt8, payload: HevcNalUnitPayload) {
        header = HevcNalUnitHeader(type: type, nuhLayerId: 0, temporalIdPlusOne: temporalIdPlusOne)
        self.payload = payload
    }

    func encode() -> Data {
        let writer = NalUnitWriter()
        header.encode(writer: writer)
        payload.encode(writer: writer)
        return writer.data
    }
}

struct HevcNalUnitHeader {
    let type: HevcNalUnitType
    let nuhLayerId: UInt8
    let temporalIdPlusOne: UInt8

    init(reader: NalUnitReader) throws {
        try reader.skipBits(count: 1)
        type = try HevcNalUnitType(rawValue: reader.readBits(count: 6)) ?? .unspec
        nuhLayerId = try reader.readBits(count: 6)
        temporalIdPlusOne = try reader.readBits(count: 3)
    }

    init(type: HevcNalUnitType, nuhLayerId: UInt8, temporalIdPlusOne: UInt8) {
        self.type = type
        self.nuhLayerId = nuhLayerId
        self.temporalIdPlusOne = temporalIdPlusOne
    }

    func encode(writer: NalUnitWriter) {
        writer.writeBit(false)
        writer.writeBits(type.rawValue, count: 6)
        writer.writeBits(nuhLayerId, count: 6)
        writer.writeBits(temporalIdPlusOne, count: 3)
    }
}

enum HevcNalUnitPayload {
    case vps(HevcNalUnitVps)
    case sps(HevcNalUnitSps)
    case pps(HevcNalUnitPps)
    case prefixSeiNut(HevcNalUnitSei)
    case unspec

    func encode(writer: NalUnitWriter) {
        switch self {
        case let .vps(vps):
            vps.encode(writer: writer)
        case let .sps(sps):
            sps.encode(writer: writer)
        case let .pps(pps):
            pps.encode(writer: writer)
        case let .prefixSeiNut(prefixSeiNut):
            prefixSeiNut.encode(writer: writer)
        case .unspec:
            break
        }
    }
}

extension [HevcNalUnit] {
    func makeFormatDescription() -> CMFormatDescription? {
        guard
            let vps = first(where: { $0.header.type == .vps }),
            let sps = first(where: { $0.header.type == .sps }),
            let pps = first(where: { $0.header.type == .pps })
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

let calendar: Calendar = {
    var utcCalender = Calendar(identifier: .iso8601)
    utcCalender.timeZone = TimeZone(abbreviation: "UTC")!
    return utcCalender
}()

func readRbspTrailingBits(reader: NalUnitReader) throws {
    let rbspStopOneBit = try reader.readBit()
    if !rbspStopOneBit {
        throw "Trailing stop bit is false"
    }
    while !reader.isByteAligned() {
        try reader.skipBits(count: 1)
    }
}

func writeRbspTrailingBits(writer: NalUnitWriter) {
    writer.writeBit(true)
    while writer.bitOffset != 0 {
        writer.writeBit(false)
    }
}

func writeMoreDataInPayload(writer: NalUnitWriter) {
    var padding = true
    while writer.bitOffset != 0 {
        writer.writeBit(padding)
        padding = false
    }
}
