// 7.3.2.1 Video parameter set RBSP syntax
struct HevcNalUnitVps {
    var vpsVideoParameterSetId: UInt8
    var vpsBaseLayerInternalFlag: Bool
    var vpsBaseLayerAvailableFlag: Bool
    var vpsMaxLayersMinus1: UInt8
    var vpsMaxSubLayersMinus1: UInt8
    var vpsTemporalIdNestingFlag: Bool
    var profileTierLevel: HevcProfileTierLevel
    var vpsSubLayerOrderingInfoPresentFlag: Bool
    var vpsMaxLayerId: UInt8
    var vpsNumLayerSetsMinus1: UInt32
    var vpsTimingInfoPresentFlag: Bool
    var vpsNumUnitsInTick: UInt32 = 0
    var vpsTimeScale: UInt32 = 0

    init(reader: NalUnitReader) throws {
        vpsVideoParameterSetId = try reader.readBits(count: 4)
        vpsBaseLayerInternalFlag = try reader.readBit()
        vpsBaseLayerAvailableFlag = try reader.readBit()
        vpsMaxLayersMinus1 = try reader.readBits(count: 6)
        vpsMaxSubLayersMinus1 = try reader.readBits(count: 3)
        vpsTemporalIdNestingFlag = try reader.readBit()
        try reader.skipBits(count: 16)
        profileTierLevel = try HevcProfileTierLevel(profilePresentFlag: true,
                                                    maxNumSubLayersMinus1: vpsMaxSubLayersMinus1,
                                                    reader: reader)
        vpsSubLayerOrderingInfoPresentFlag = try reader.readBit()
        let startLayer = vpsSubLayerOrderingInfoPresentFlag ? 0 : vpsMaxSubLayersMinus1
        for _ in startLayer ... vpsMaxLayersMinus1 {
            try reader.skipExponentialGolomb()
            try reader.skipExponentialGolomb()
            try reader.skipExponentialGolomb()
        }
        vpsMaxLayerId = try reader.readBits(count: 6)
        vpsNumLayerSetsMinus1 = try reader.readExponentialGolomb()
        try reader.skipBits(count: (Int(vpsMaxLayerId) + 1) * Int(vpsNumLayerSetsMinus1))
        vpsTimingInfoPresentFlag = try reader.readBit()
        if vpsTimingInfoPresentFlag {
            vpsNumUnitsInTick = try reader.readBitsU32(count: 32)
            vpsTimeScale = try reader.readBitsU32(count: 32)
            if try reader.readBit() {
                try reader.skipExponentialGolomb()
            }
            let vpsNumHrdParameters = try reader.readExponentialGolomb()
            for i in 0 ..< vpsNumHrdParameters {
                try reader.skipExponentialGolomb()
                let cprmsPresentFlag: Bool
                if i > 0 {
                    cprmsPresentFlag = try reader.readBit()
                } else {
                    cprmsPresentFlag = true
                }
                throw "Should skip hrd_parameters \(cprmsPresentFlag)"
            }
        }
        if try reader.readBit() {
            throw "Extension not supported"
        }
    }

    func encode(writer _: NalUnitWriter) {}
}
