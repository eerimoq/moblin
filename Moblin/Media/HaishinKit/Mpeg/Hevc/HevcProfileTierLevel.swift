struct HevcProfileTierLevel {
    var generalProfileSpace: UInt8 = 0
    var generalTierFlag: Bool = false
    var generalProfileIdc: UInt8 = 0
    var generalProfileCompatibilityFlags: UInt32 = 0
    var generalProgressiveSourceFlag: Bool = false
    var generalInterlacedSourceFlag: Bool = false
    var generalNonPackedConstraintFlag: Bool = false
    var generalFrameOnlyConstraintFlag: Bool = false
    var generalLevelIdc: UInt8

    init(profilePresentFlag: Bool, maxNumSubLayersMinus1: UInt8, reader: NalUnitReader) throws {
        if profilePresentFlag {
            generalProfileSpace = try reader.readBits(count: 2)
            generalTierFlag = try reader.readBit()
            generalProfileIdc = try reader.readBits(count: 5)
            generalProfileCompatibilityFlags = try reader.readBitsU32(count: 32)
            generalProgressiveSourceFlag = try reader.readBit()
            generalInterlacedSourceFlag = try reader.readBit()
            generalNonPackedConstraintFlag = try reader.readBit()
            generalFrameOnlyConstraintFlag = try reader.readBit()
            try reader.skipBits(count: 43 + 1)
        }
        generalLevelIdc = try reader.readBits(count: 8)
        var subLayerProfilePresentFlags: [Bool] = []
        var subLayerLevelPresentFlags: [Bool] = []
        for _ in 0 ..< maxNumSubLayersMinus1 {
            try subLayerProfilePresentFlags.append(reader.readBit())
            try subLayerLevelPresentFlags.append(reader.readBit())
        }
        if maxNumSubLayersMinus1 > 0 {
            for _ in maxNumSubLayersMinus1 ..< 8 {
                try reader.skipBits(count: 2)
            }
        }
        for i in 0 ..< Int(maxNumSubLayersMinus1) {
            if subLayerProfilePresentFlags[i] {
                try reader.skipBits(count: 8 + 4 + 32 + 43 + 1)
            }
            if subLayerLevelPresentFlags[i] {
                try reader.skipBits(count: 8)
            }
        }
    }
}
