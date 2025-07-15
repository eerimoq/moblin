struct HevcVuiParameters {
    var aspectRatioInfoPresentFlag: Bool
    var overscanInfoPresentFlag: Bool
    var videoSignalTypePresentFlag: Bool
    var videoFormat: UInt8 = 0
    var videoFullRangeFlag: Bool = false
    var colourDescriptionPresentFlag: Bool = false
    var colourPrimaries: UInt8 = 0
    var transferCharacteristics: UInt8 = 0
    var matrixCoeffs: UInt8 = 0
    var chromaLocInfoPresentFlag: Bool
    var neutralChromaIndicationFlag: Bool
    var fieldSeqFlag: Bool
    var frameFieldInfoPresentFlag: Bool
    var defaultDisplayWindowFlag: Bool
    var vuiTimingInfoPresentFlag: Bool
    var bitstreamRestrictionFlag: Bool

    init(reader: NalUnitReader) throws {
        aspectRatioInfoPresentFlag = try reader.readBit()
        if aspectRatioInfoPresentFlag {
            throw "aspectRatioInfoPresentFlag"
        }
        overscanInfoPresentFlag = try reader.readBit()
        if overscanInfoPresentFlag {
            throw "overscanInfoPresentFlag"
        }
        videoSignalTypePresentFlag = try reader.readBit()
        if videoSignalTypePresentFlag {
            videoFormat = try reader.readBits(count: 3)
            videoFullRangeFlag = try reader.readBit()
            colourDescriptionPresentFlag = try reader.readBit()
            if colourDescriptionPresentFlag {
                colourPrimaries = try reader.readBits(count: 8)
                transferCharacteristics = try reader.readBits(count: 8)
                matrixCoeffs = try reader.readBits(count: 8)
            }
        }
        chromaLocInfoPresentFlag = try reader.readBit()
        if chromaLocInfoPresentFlag {
            throw "chromaLocInfoPresentFlag"
        }
        neutralChromaIndicationFlag = try reader.readBit()
        fieldSeqFlag = try reader.readBit()
        frameFieldInfoPresentFlag = try reader.readBit()
        defaultDisplayWindowFlag = try reader.readBit()
        if defaultDisplayWindowFlag {
            throw "defaultDisplayWindowFlag"
        }
        vuiTimingInfoPresentFlag = try reader.readBit()
        if vuiTimingInfoPresentFlag {
            throw "vuiTimingInfoPresentFlag"
        }
        bitstreamRestrictionFlag = try reader.readBit()
        if bitstreamRestrictionFlag {
            throw "bitstreamRestrictionFlag"
        }
    }
}
