// 7.3.2.3 Picture parameter set RBSP syntax
struct HevcNalUnitPps {
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

    init(reader: NalUnitReader) throws {
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
    }

    func encode(writer _: NalUnitWriter) {}
}
