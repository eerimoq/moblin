import Foundation
import VideoToolbox

struct VTSessionOption {
    let key: VTSessionOptionKey
    let value: AnyObject
}

// periphery:ignore
struct VTSessionOptionKey {
    static let depth = VTSessionOptionKey(value: kVTCompressionPropertyKey_Depth)
    static let profileLevel = VTSessionOptionKey(value: kVTCompressionPropertyKey_ProfileLevel)
    static let h264EntropyMode = VTSessionOptionKey(value: kVTCompressionPropertyKey_H264EntropyMode)
    static let numberOfPendingFrames =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_NumberOfPendingFrames)
    static let pixelBufferPoolIsShared =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_PixelBufferPoolIsShared)
    static let videoEncoderPixelBufferAttributes =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_VideoEncoderPixelBufferAttributes)
    static let aspectRatio16x9 = VTSessionOptionKey(value: kVTCompressionPropertyKey_AspectRatio16x9)
    static let cleanAperture = VTSessionOptionKey(value: kVTCompressionPropertyKey_CleanAperture)
    static let fieldCount = VTSessionOptionKey(value: kVTCompressionPropertyKey_FieldCount)
    static let fieldDetail = VTSessionOptionKey(value: kVTCompressionPropertyKey_FieldDetail)
    static let pixelAspectRatio = VTSessionOptionKey(value: kVTCompressionPropertyKey_PixelAspectRatio)
    static let progressiveScan = VTSessionOptionKey(value: kVTCompressionPropertyKey_ProgressiveScan)
    static let colorPrimaries = VTSessionOptionKey(value: kVTCompressionPropertyKey_ColorPrimaries)
    static let transferFunction = VTSessionOptionKey(value: kVTCompressionPropertyKey_TransferFunction)
    static let YCbCrMatrix = VTSessionOptionKey(value: kVTCompressionPropertyKey_YCbCrMatrix)
    static let ICCProfile = VTSessionOptionKey(value: kVTCompressionPropertyKey_ICCProfile)
    static let expectedDuration = VTSessionOptionKey(value: kVTCompressionPropertyKey_ExpectedDuration)
    static let expectedFrameRate =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_ExpectedFrameRate)
    static let sourceFrameCount = VTSessionOptionKey(value: kVTCompressionPropertyKey_SourceFrameCount)
    static let allowFrameReordering =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_AllowFrameReordering)
    static let allowTemporalCompression =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_AllowTemporalCompression)
    static let maxKeyFrameInterval =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_MaxKeyFrameInterval)
    static let maxKeyFrameIntervalDuration =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration)
    static let multiPassStorage = VTSessionOptionKey(value: kVTCompressionPropertyKey_MultiPassStorage)
    static let forceKeyFrame = VTSessionOptionKey(value: kVTEncodeFrameOptionKey_ForceKeyFrame)
    static let pixelTransferProperties =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_PixelTransferProperties)
    static let averageBitRate = VTSessionOptionKey(value: kVTCompressionPropertyKey_AverageBitRate)
    static let dataRateLimits = VTSessionOptionKey(value: kVTCompressionPropertyKey_DataRateLimits)
    static let moreFramesAfterEnd =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_MoreFramesAfterEnd)
    static let moreFramesBeforeStart =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_MoreFramesBeforeStart)
    static let quality = VTSessionOptionKey(value: kVTCompressionPropertyKey_Quality)
    static let realTime = VTSessionOptionKey(value: kVTCompressionPropertyKey_RealTime)
    static let maxH264SliceBytes =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_MaxH264SliceBytes)
    static let maxFrameDelayCount =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_MaxFrameDelayCount)
    static let encoderID = VTSessionOptionKey(value: kVTVideoEncoderSpecification_EncoderID)
    static let constantBitRate = VTSessionOptionKey(value: kVTCompressionPropertyKey_ConstantBitRate)

    let value: CFString
}
