import Foundation
import VideoToolbox

struct VTSessionProperty {
    let key: VTSessionPropertyKey
    let value: AnyObject
}

// periphery:ignore
struct VTSessionPropertyKey {
    static let profileLevel = VTSessionPropertyKey(value: kVTCompressionPropertyKey_ProfileLevel)
    static let h264EntropyMode = VTSessionPropertyKey(value: kVTCompressionPropertyKey_H264EntropyMode)
    static let colorPrimaries = VTSessionPropertyKey(value: kVTCompressionPropertyKey_ColorPrimaries)
    static let transferFunction = VTSessionPropertyKey(value: kVTCompressionPropertyKey_TransferFunction)
    static let YCbCrMatrix = VTSessionPropertyKey(value: kVTCompressionPropertyKey_YCbCrMatrix)
    static let expectedDuration = VTSessionPropertyKey(value: kVTCompressionPropertyKey_ExpectedDuration)
    static let expectedFrameRate = VTSessionPropertyKey(value: kVTCompressionPropertyKey_ExpectedFrameRate)
    static let sourceFrameCount = VTSessionPropertyKey(value: kVTCompressionPropertyKey_SourceFrameCount)
    static let allowFrameReordering = VTSessionPropertyKey(value: kVTCompressionPropertyKey_AllowFrameReordering)
    static let maxKeyFrameIntervalDuration =
        VTSessionPropertyKey(value: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration)
    static let pixelTransferProperties = VTSessionPropertyKey(value: kVTCompressionPropertyKey_PixelTransferProperties)
    static let averageBitRate = VTSessionPropertyKey(value: kVTCompressionPropertyKey_AverageBitRate)
    static let dataRateLimits = VTSessionPropertyKey(value: kVTCompressionPropertyKey_DataRateLimits)
    static let realTime = VTSessionPropertyKey(value: kVTCompressionPropertyKey_RealTime)
    static let constantBitRate = VTSessionPropertyKey(value: kVTCompressionPropertyKey_ConstantBitRate)
    static let hdrMetadataInsertionMode =
        VTSessionPropertyKey(value: kVTCompressionPropertyKey_HDRMetadataInsertionMode)

    let value: CFString
}
