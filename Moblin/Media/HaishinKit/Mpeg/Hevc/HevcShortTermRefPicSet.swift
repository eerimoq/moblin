struct HevcShortTermRefPicSet {
    var interRefPicSetPredictionFlag: Bool = false
    var deltaIdxMinus1: UInt32 = 0
    var deltaRpsSign: Bool = false
    var absDeltaRpsMinus1: UInt32 = 0
    var numNegativePics: UInt32 = 0
    var numPositivePics: UInt32 = 0
    var deltaPocS0Minus1: [UInt32] = []
    var usedByCurrPicS0Flag: [Bool] = []
    var deltaPocS1Minus1: [UInt32] = []
    var usedByCurrPicS1Flag: [Bool] = []

    init(reader: NalUnitReader, numShortTermRefPicSets: UInt32, stRpsIdx: UInt32) throws {
        if stRpsIdx != 0 {
            interRefPicSetPredictionFlag = try reader.readBit()
        }
        if interRefPicSetPredictionFlag {
            if stRpsIdx == numShortTermRefPicSets {
                deltaIdxMinus1 = try reader.readExponentialGolomb()
            }
            deltaRpsSign = try reader.readBit()
            absDeltaRpsMinus1 = try reader.readExponentialGolomb()
            throw "interRefPicSetPredictionFlag"
        } else {
            numNegativePics = try reader.readExponentialGolomb()
            numPositivePics = try reader.readExponentialGolomb()
            for _ in 0 ..< numNegativePics {
                try deltaPocS0Minus1.append(reader.readExponentialGolomb())
                try usedByCurrPicS0Flag.append(reader.readBit())
            }
            for _ in 0 ..< numPositivePics {
                try deltaPocS1Minus1.append(reader.readExponentialGolomb())
                try usedByCurrPicS1Flag.append(reader.readBit())
            }
        }
    }
}
