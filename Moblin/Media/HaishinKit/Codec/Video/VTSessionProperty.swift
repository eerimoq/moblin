import Foundation
import VideoToolbox

struct VTSessionProperty {
    let key: VTSessionPropertyKey
    let value: AnyObject
}

// periphery:ignore
struct VTSessionPropertyKey {
    static let depth = VTSessionPropertyKey(value: kVTCompressionPropertyKey_Depth)
    static let profileLevel = VTSessionPropertyKey(value: kVTCompressionPropertyKey_ProfileLevel)
    static let h264EntropyMode = VTSessionPropertyKey(value: kVTCompressionPropertyKey_H264EntropyMode)
    static let numberOfPendingFrames =
        VTSessionPropertyKey(value: kVTCompressionPropertyKey_NumberOfPendingFrames)
    static let pixelBufferPoolIsShared =
        VTSessionPropertyKey(value: kVTCompressionPropertyKey_PixelBufferPoolIsShared)
    static let videoEncoderPixelBufferAttributes =
        VTSessionPropertyKey(value: kVTCompressionPropertyKey_VideoEncoderPixelBufferAttributes)
    static let aspectRatio16x9 = VTSessionPropertyKey(value: kVTCompressionPropertyKey_AspectRatio16x9)
    static let cleanAperture = VTSessionPropertyKey(value: kVTCompressionPropertyKey_CleanAperture)
    static let fieldCount = VTSessionPropertyKey(value: kVTCompressionPropertyKey_FieldCount)
    static let fieldDetail = VTSessionPropertyKey(value: kVTCompressionPropertyKey_FieldDetail)
    static let pixelAspectRatio = VTSessionPropertyKey(value: kVTCompressionPropertyKey_PixelAspectRatio)
    static let progressiveScan = VTSessionPropertyKey(value: kVTCompressionPropertyKey_ProgressiveScan)
    static let colorPrimaries = VTSessionPropertyKey(value: kVTCompressionPropertyKey_ColorPrimaries)
    static let transferFunction = VTSessionPropertyKey(value: kVTCompressionPropertyKey_TransferFunction)
    static let YCbCrMatrix = VTSessionPropertyKey(value: kVTCompressionPropertyKey_YCbCrMatrix)
    static let ICCProfile = VTSessionPropertyKey(value: kVTCompressionPropertyKey_ICCProfile)
    static let expectedDuration = VTSessionPropertyKey(value: kVTCompressionPropertyKey_ExpectedDuration)
    static let expectedFrameRate =
        VTSessionPropertyKey(value: kVTCompressionPropertyKey_ExpectedFrameRate)
    static let sourceFrameCount = VTSessionPropertyKey(value: kVTCompressionPropertyKey_SourceFrameCount)
    static let allowFrameReordering =
        VTSessionPropertyKey(value: kVTCompressionPropertyKey_AllowFrameReordering)
    static let allowTemporalCompression =
        VTSessionPropertyKey(value: kVTCompressionPropertyKey_AllowTemporalCompression)
    static let maxKeyFrameInterval =
        VTSessionPropertyKey(value: kVTCompressionPropertyKey_MaxKeyFrameInterval)
    static let maxKeyFrameIntervalDuration =
        VTSessionPropertyKey(value: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration)
    static let multiPassStorage = VTSessionPropertyKey(value: kVTCompressionPropertyKey_MultiPassStorage)
    static let forceKeyFrame = VTSessionPropertyKey(value: kVTEncodeFrameOptionKey_ForceKeyFrame)
    static let pixelTransferProperties =
        VTSessionPropertyKey(value: kVTCompressionPropertyKey_PixelTransferProperties)
    static let averageBitRate = VTSessionPropertyKey(value: kVTCompressionPropertyKey_AverageBitRate)
    static let dataRateLimits = VTSessionPropertyKey(value: kVTCompressionPropertyKey_DataRateLimits)
    static let moreFramesAfterEnd =
        VTSessionPropertyKey(value: kVTCompressionPropertyKey_MoreFramesAfterEnd)
    static let moreFramesBeforeStart =
        VTSessionPropertyKey(value: kVTCompressionPropertyKey_MoreFramesBeforeStart)
    static let quality = VTSessionPropertyKey(value: kVTCompressionPropertyKey_Quality)
    static let realTime = VTSessionPropertyKey(value: kVTCompressionPropertyKey_RealTime)
    static let maxH264SliceBytes =
        VTSessionPropertyKey(value: kVTCompressionPropertyKey_MaxH264SliceBytes)
    static let maxFrameDelayCount =
        VTSessionPropertyKey(value: kVTCompressionPropertyKey_MaxFrameDelayCount)
    static let encoderID = VTSessionPropertyKey(value: kVTVideoEncoderSpecification_EncoderID)
    static let constantBitRate = VTSessionPropertyKey(value: kVTCompressionPropertyKey_ConstantBitRate)
    static let hdrMetadataInsertionMode =
        VTSessionPropertyKey(value: kVTCompressionPropertyKey_HDRMetadataInsertionMode)

    let value: CFString
}
