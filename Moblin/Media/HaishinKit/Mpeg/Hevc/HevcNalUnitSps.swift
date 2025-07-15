// 7.3.2.2 Sequence parameter set RBSP syntax
struct HevcNalUnitSps {
    var spsVideoParameterSetId: UInt8
    var spsMaxSubLayersMinus1: UInt8 = 0
    var spsExtOrMaxSubLayersMinus1: UInt8 = 0
    var spsTemporalIdNestingFlag: Bool = false
    var spsSeqParameterSetId: UInt32
    var chromaFormatIdc: UInt32 = 0
    var separateColourPlaneFlag: Bool = false
    var picWidthInLumaSamples: UInt32 = 0
    var picHeightInLumaSamples: UInt32 = 0
    var profileTierLevel: HevcProfileTierLevel?
    var conformanceWindowFlag: Bool
    var confWinLeftOffset: UInt32 = 0
    var confWinRightOffset: UInt32 = 0
    var confWinTopOffset: UInt32 = 0
    var confWinBottomOffset: UInt32 = 0
    var bitDepthLumaMinus8: UInt32
    var bitDepthChromaMinus8: UInt32
    var log2MaxPicOrderCntLsbMinus4: UInt32
    var spsSubLayerOrderingInfoPresentFlag: Bool
    var log2MinLumaCodingBlockSizeMinus3: UInt32
    var log2DiffMaxMinLumaCodingBlockSize: UInt32
    var log2MinLumaTransformBlockSizeMinus2: UInt32
    var log2DiffMaxMinLumaTransformBlockSize: UInt32
    var maxTransformHierarchyDepthInter: UInt32
    var maxTransformHierarchyDepthIntra: UInt32
    var scalingListEnabledFlag: Bool
    var scalingListDataPresentFlag: Bool = false
    var ampEnabledFlag: Bool
    var sampleAdaptiveOffsetEnabledFlag: Bool
    var pcmEnabledFlag: Bool
    var pcmSampleBitDepthLumaMinus1: UInt8 = 0
    var pcmSampleBitDepthChromaMinus1: UInt8 = 0
    var log2MinPcmLumaCodingBlockSizeMinus3: UInt32 = 0
    var log2DiffMaxMinPcmLumaCodingBlockSize: UInt32 = 0
    var pcmLoopFilterDisabledFlag: Bool = false
    var numShortTermRefPicSets: UInt32
    var shortTermRefPicSets: [HevcShortTermRefPicSet] = []
    var longTermRefPicsPresentFlag: Bool
    var spsTemporalMvpEnabledFlag: Bool
    var strongIntraSmoothingEnabledFlag: Bool
    var vuiParametersPresentFlag: Bool
    var vuiParameters: HevcVuiParameters?
    var spsExtensionPresentFlag: Bool
    var vps: HevcNalUnitVps?

    init(reader: NalUnitReader, header _: HevcNalUnitHeader) throws {
        spsVideoParameterSetId = try reader.readBits(count: 4)
        spsMaxSubLayersMinus1 = try reader.readBits(count: 3)
        spsTemporalIdNestingFlag = try reader.readBit()
        profileTierLevel = try HevcProfileTierLevel(profilePresentFlag: true,
                                                    maxNumSubLayersMinus1: spsMaxSubLayersMinus1,
                                                    reader: reader)
        spsSeqParameterSetId = try reader.readExponentialGolomb()
        chromaFormatIdc = try reader.readExponentialGolomb()
        if chromaFormatIdc == 3 {
            separateColourPlaneFlag = try reader.readBit()
        }
        picWidthInLumaSamples = try reader.readExponentialGolomb()
        picHeightInLumaSamples = try reader.readExponentialGolomb()
        conformanceWindowFlag = try reader.readBit()
        if conformanceWindowFlag {
            confWinLeftOffset = try reader.readExponentialGolomb()
            confWinRightOffset = try reader.readExponentialGolomb()
            confWinTopOffset = try reader.readExponentialGolomb()
            confWinBottomOffset = try reader.readExponentialGolomb()
        }
        bitDepthLumaMinus8 = try reader.readExponentialGolomb()
        bitDepthChromaMinus8 = try reader.readExponentialGolomb()
        log2MaxPicOrderCntLsbMinus4 = try reader.readExponentialGolomb()
        spsSubLayerOrderingInfoPresentFlag = try reader.readBit()
        let iStart = spsSubLayerOrderingInfoPresentFlag ? 0 : spsMaxSubLayersMinus1
        for _ in iStart ... spsMaxSubLayersMinus1 {
            try reader.skipExponentialGolomb()
            try reader.skipExponentialGolomb()
            try reader.skipExponentialGolomb()
        }
        log2MinLumaCodingBlockSizeMinus3 = try reader.readExponentialGolomb()
        log2DiffMaxMinLumaCodingBlockSize = try reader.readExponentialGolomb()
        log2MinLumaTransformBlockSizeMinus2 = try reader.readExponentialGolomb()
        log2DiffMaxMinLumaTransformBlockSize = try reader.readExponentialGolomb()
        maxTransformHierarchyDepthInter = try reader.readExponentialGolomb()
        maxTransformHierarchyDepthIntra = try reader.readExponentialGolomb()
        scalingListEnabledFlag = try reader.readBit()
        if scalingListEnabledFlag {
            scalingListDataPresentFlag = try reader.readBit()
            if scalingListDataPresentFlag {
                throw "Scaling list data not implemented."
            }
        }
        ampEnabledFlag = try reader.readBit()
        sampleAdaptiveOffsetEnabledFlag = try reader.readBit()
        pcmEnabledFlag = try reader.readBit()
        if pcmEnabledFlag {
            pcmSampleBitDepthLumaMinus1 = try reader.readBits(count: 4)
            pcmSampleBitDepthChromaMinus1 = try reader.readBits(count: 4)
            log2MinPcmLumaCodingBlockSizeMinus3 = try reader.readExponentialGolomb()
            log2DiffMaxMinPcmLumaCodingBlockSize = try reader.readExponentialGolomb()
            pcmLoopFilterDisabledFlag = try reader.readBit()
        }
        numShortTermRefPicSets = try reader.readExponentialGolomb()
        for stRpsIdx in 0 ..< numShortTermRefPicSets {
            try shortTermRefPicSets.append(HevcShortTermRefPicSet(reader: reader,
                                                                  numShortTermRefPicSets: numShortTermRefPicSets,
                                                                  stRpsIdx: stRpsIdx))
        }
        longTermRefPicsPresentFlag = try reader.readBit()
        if longTermRefPicsPresentFlag {
            throw "Long term pics not supported"
        }
        spsTemporalMvpEnabledFlag = try reader.readBit()
        strongIntraSmoothingEnabledFlag = try reader.readBit()
        vuiParametersPresentFlag = try reader.readBit()
        if vuiParametersPresentFlag {
            vuiParameters = try HevcVuiParameters(reader: reader)
        }
        spsExtensionPresentFlag = try reader.readBit()
        if spsExtensionPresentFlag {
            throw "Extensions not supported"
        }
    }

    func encode(writer _: NalUnitWriter) {}
}
