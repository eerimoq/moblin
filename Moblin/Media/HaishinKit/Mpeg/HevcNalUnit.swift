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
    private var offset: UInt32

    init(clock: Date) {
        hours = UInt8(calendar.component(.hour, from: clock))
        minutes = UInt8(calendar.component(.minute, from: clock))
        seconds = UInt8(calendar.component(.second, from: clock))
        offset = UInt32((clock.timeIntervalSince1970 * 1000).truncatingRemainder(dividingBy: 1000))
    }

    init?(reader: BitReader) {
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
                logger.info("not full timestamp")
                return nil
            }
            let count = try reader.readBitsU32(count: 5)
            guard count <= 32 else {
                logger.info("too long offset")
                return nil
            }
            offset = try reader.readBitsU32(count: Int(count))
        } catch {
            return nil
        }
    }

    func encode() -> Data {
        let numClockTs: UInt8 = 1
        let clockTimestampFlag = true
        let unitFieldBasedFlag = true
        let fullTimestampFlag = true
        let numberOfFrames: UInt32 = 0
        let writer = BitWriter()
        writer.writeBits(numClockTs, count: 2)
        writer.writeBit(clockTimestampFlag)
        writer.writeBit(unitFieldBasedFlag)
        writer.writeBits(0, count: 5)
        writer.writeBit(fullTimestampFlag)
        writer.writeBit(false)
        writer.writeBit(false)
        writer.writeBitsU32(numberOfFrames, count: 9)
        if fullTimestampFlag {
            writer.writeBits(seconds, count: 6)
            writer.writeBits(minutes, count: 6)
            writer.writeBits(hours, count: 5)
        }
        writer.writeBits(10, count: 5)
        writer.writeBitsU32(offset, count: 10)
        writeMoreDataInPayload(writer: writer)
        return writer.data
    }

    func makeClock(vuiTimeScale: UInt32) -> Date {
        var clockTimestamp = Double(seconds) + Double(minutes) * 60 + Double(hours) * 3600
        clockTimestamp *= Double(vuiTimeScale)
        clockTimestamp += Double(offset) / 1000
        // Not good if close to new day
        let startOfDay = calendar.startOfDay(for: .now)
        return startOfDay.addingTimeInterval(clockTimestamp)
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
        let reader = BitReader(data: data)
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
        let writer = BitWriter()
        writer.writeBits(type.rawValue, count: 8)
        writer.writeBits(UInt8(data.count), count: 8)
        writer.writeBytes(data)
        writeRbspTrailingBits(writer: writer)
        return writer.data
    }
}

// 7.3.2.1 Video parameter set RBSP syntax
struct HevcVps {
    var vpsVideoParameterSetId: UInt8
    var vpsBaseLayerInternalFlag: Bool
    var vpsBaseLayerAvailableFlag: Bool
    var vpsMaxLayersMinus1: UInt8
    var vpsMaxSubLayersMinus1: UInt8
    var vpsTemporalIdNestingFlag: Bool
    var vpsSubLayerOrderingInfoPresentFlag: Bool
    var vpsMaxLayerId: UInt8
    var vpsNumLayerSetsMinus1: UInt32

    init?(data: Data) {
        do {
            let reader = BitReader(data: data)
            vpsVideoParameterSetId = try reader.readBits(count: 4)
            vpsBaseLayerInternalFlag = try reader.readBit()
            vpsBaseLayerAvailableFlag = try reader.readBit()
            vpsMaxLayersMinus1 = try reader.readBits(count: 6)
            vpsMaxSubLayersMinus1 = try reader.readBits(count: 3)
            vpsTemporalIdNestingFlag = try reader.readBit()
            try reader.skipBits(count: 16)
            vpsSubLayerOrderingInfoPresentFlag = try reader.readBit()
            let startLayer = vpsSubLayerOrderingInfoPresentFlag ? 0 : vpsMaxSubLayersMinus1
            for _ in startLayer ... vpsMaxLayersMinus1 {
                _ = try reader.readExponentialGolomb()
                _ = try reader.readExponentialGolomb()
                _ = try reader.readExponentialGolomb()
            }
            vpsMaxLayerId = try reader.readBits(count: 6)
            vpsNumLayerSetsMinus1 = try reader.readExponentialGolomb()
        } catch {
            return nil
        }
    }
}

// 7.3.2.2 Sequence parameter set RBSP syntax
struct HevcSps {
    var spsVideoParameterSetId: UInt8
    var spsMaxSubLayersMinus1: UInt8
    var spsTemporalIdNestingFlag: Bool
    var spsSeqParameterSetId: UInt32
    var chromaFormatIdc: UInt32
    var separateColourPlaneFlag: Bool = false
    var picWidthInLumaSamples: UInt32
    var picHeightInLumaSamples: UInt32

    init?(data: Data) {
        do {
            let reader = BitReader(data: data)
            spsVideoParameterSetId = try reader.readBits(count: 4)
            spsMaxSubLayersMinus1 = try reader.readBits(count: 3)
            spsTemporalIdNestingFlag = try reader.readBit()
            spsSeqParameterSetId = try reader.readExponentialGolomb()
            if spsSeqParameterSetId > 15 {
                throw "spsSeqParameterSetId \(spsSeqParameterSetId) is greater than 15"
            }
            chromaFormatIdc = try reader.readExponentialGolomb()
            if chromaFormatIdc > 3 {
                throw "chromaFormatIdc \(chromaFormatIdc) is greater than 3"
            }
            if chromaFormatIdc == 3 {
                separateColourPlaneFlag = try reader.readBit()
            }
            picWidthInLumaSamples = try reader.readExponentialGolomb()
            picHeightInLumaSamples = try reader.readExponentialGolomb()
        } catch {
            return nil
        }
    }
}

// 7.3.2.3 Picture parameter set RBSP syntax
struct HevcPps {
    var ppsPicParameterSetId: UInt32
    var ppsSeqParameterSetId: UInt32
    var dependentSliceSegmentsEnabledFlag: Bool
    var outputFlagPresentFlag: Bool
    var numExtraSliceHeaderBits: UInt8
    var signDataHidingEnabledFlag: Bool
    var cabacInitPresentFlag: Bool
    var numRefIdxL0DefaultActiveMinus1: UInt32
    var numRefIdxL1DefaultActiveMinus1: UInt32
    var initQpMinus26: UInt32
    var constrainedIntraPredFlag: Bool
    var transformSkipEnabledFlag: Bool
    var cuQpDeltaEnabledFlag: Bool
    var diffCuQpDeltaDepth: UInt32 = 0
    var ppsCbQpOffset: UInt32
    var ppsCrQpOffset: UInt32
    var ppsSliceChromaQpOffsetsPresentFlag: Bool
    var weightedPredFlag: Bool
    var weightedBipredFlag: Bool
    var transquantBypassEnabledFlag: Bool
    var tilesEnabledFlag: Bool
    var entropyCodingSyncEnabledFlag: Bool
    var numTileColumnsMinus1: UInt32 = 0
    var numTileRowsMinus1: UInt32 = 0
    var uniformSpacingFlag: Bool = false
    var loopFilterAcrossTilesEnabledFlag: Bool = true
    var ppsLoopFilterAcrossSlicesEnabledFlag: Bool
    var deblockingFilterControlPresentFlag: Bool
    var deblockingFilterOverrideEnabledFlag: Bool = false
    var ppsDeblockingFilterDisabledFlag: Bool = false
    var ppsBetaOffsetDiv2: UInt32 = 0
    var ppsTcOffsetDiv2: UInt32 = 0
    var ppsScalingListDataPresentFlag: Bool
    var listsModificationPresentFlag: Bool
    var log2ParallelMergeLevelMinus2: UInt32
    var sliceSegmentHeaderExtensionPresentFlag: Bool
    var ppsExtensionPresentFlag: Bool

    init?(data: Data) {
        do {
            let reader = BitReader(data: data)
            ppsPicParameterSetId = try reader.readExponentialGolomb()
            ppsSeqParameterSetId = try reader.readExponentialGolomb()
            dependentSliceSegmentsEnabledFlag = try reader.readBit()
            outputFlagPresentFlag = try reader.readBit()
            numExtraSliceHeaderBits = try reader.readBits(count: 3)
            signDataHidingEnabledFlag = try reader.readBit()
            cabacInitPresentFlag = try reader.readBit()
            numRefIdxL0DefaultActiveMinus1 = try reader.readExponentialGolomb()
            numRefIdxL1DefaultActiveMinus1 = try reader.readExponentialGolomb()
            initQpMinus26 = try reader.readExponentialGolomb()
            constrainedIntraPredFlag = try reader.readBit()
            transformSkipEnabledFlag = try reader.readBit()
            cuQpDeltaEnabledFlag = try reader.readBit()
            if cuQpDeltaEnabledFlag {
                diffCuQpDeltaDepth = try reader.readExponentialGolomb()
            }
            ppsCbQpOffset = try reader.readExponentialGolomb()
            ppsCrQpOffset = try reader.readExponentialGolomb()
            ppsSliceChromaQpOffsetsPresentFlag = try reader.readBit()
            weightedPredFlag = try reader.readBit()
            weightedBipredFlag = try reader.readBit()
            transquantBypassEnabledFlag = try reader.readBit()
            tilesEnabledFlag = try reader.readBit()
            entropyCodingSyncEnabledFlag = try reader.readBit()
            if tilesEnabledFlag {
                numTileColumnsMinus1 = try reader.readExponentialGolomb()
                numTileRowsMinus1 = try reader.readExponentialGolomb()
                uniformSpacingFlag = try reader.readBit()
                if !uniformSpacingFlag {
                    throw "not implemented"
                }
                loopFilterAcrossTilesEnabledFlag = try reader.readBit()
            }
            ppsLoopFilterAcrossSlicesEnabledFlag = try reader.readBit()
            deblockingFilterControlPresentFlag = try reader.readBit()
            if deblockingFilterControlPresentFlag {
                deblockingFilterOverrideEnabledFlag = try reader.readBit()
                ppsDeblockingFilterDisabledFlag = try reader.readBit()
                if !ppsDeblockingFilterDisabledFlag {
                    ppsBetaOffsetDiv2 = try reader.readExponentialGolomb()
                    ppsTcOffsetDiv2 = try reader.readExponentialGolomb()
                }
            }
            ppsScalingListDataPresentFlag = try reader.readBit()
            if ppsScalingListDataPresentFlag {
                throw "scaling"
            }
            listsModificationPresentFlag = try reader.readBit()
            log2ParallelMergeLevelMinus2 = try reader.readExponentialGolomb()
            sliceSegmentHeaderExtensionPresentFlag = try reader.readBit()
            ppsExtensionPresentFlag = try reader.readBit()
            if ppsExtensionPresentFlag {
                throw "extension"
            }
        } catch {
            return nil
        }
    }
}

private func writeRbspTrailingBits(writer: BitWriter) {
    writer.writeBit(true)
    while writer.bitOffset != 0 {
        writer.writeBit(false)
    }
}

private func writeMoreDataInPayload(writer: BitWriter) {
    var padding = true
    while writer.bitOffset != 0 {
        writer.writeBit(padding)
        padding = false
    }
}
