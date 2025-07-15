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

    init(reader: NalUnitReader, header: HevcNalUnitHeader) throws {
        spsVideoParameterSetId = try reader.readBits(count: 4)
        if header.nuhLayerId == 0 {
            spsMaxSubLayersMinus1 = try reader.readBits(count: 3)
        } else {
            spsExtOrMaxSubLayersMinus1 = try reader.readBits(count: 3)
        }
        let multiLayerExtSpsFlag = header.nuhLayerId != 0 && spsExtOrMaxSubLayersMinus1 == 7
        if !multiLayerExtSpsFlag {
            spsTemporalIdNestingFlag = try reader.readBit()
            profileTierLevel = try HevcProfileTierLevel(profilePresentFlag: true,
                                                        maxNumSubLayersMinus1: spsMaxSubLayersMinus1,
                                                        reader: reader)
        }
        spsSeqParameterSetId = try reader.readExponentialGolomb()
        if multiLayerExtSpsFlag {
            if try reader.readBit() {
                try reader.skipBits(count: 8)
            }
        } else {
            chromaFormatIdc = try reader.readExponentialGolomb()
            if chromaFormatIdc == 3 {
                separateColourPlaneFlag = try reader.readBit()
            }
            picWidthInLumaSamples = try reader.readExponentialGolomb()
            picHeightInLumaSamples = try reader.readExponentialGolomb()
        }
    }

    func encode(writer _: NalUnitWriter) {}
}
