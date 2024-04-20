import Foundation
import VideoToolbox

public struct VTSessionOption {
    let key: VTSessionOptionKey
    let value: AnyObject
}

public struct VTSessionOptionKey {
    public static let depth = VTSessionOptionKey(value: kVTCompressionPropertyKey_Depth)
    public static let profileLevel = VTSessionOptionKey(value: kVTCompressionPropertyKey_ProfileLevel)
    public static let h264EntropyMode = VTSessionOptionKey(value: kVTCompressionPropertyKey_H264EntropyMode)
    public static let numberOfPendingFrames =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_NumberOfPendingFrames)
    public static let pixelBufferPoolIsShared =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_PixelBufferPoolIsShared)
    public static let videoEncoderPixelBufferAttributes =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_VideoEncoderPixelBufferAttributes)
    public static let aspectRatio16x9 = VTSessionOptionKey(value: kVTCompressionPropertyKey_AspectRatio16x9)
    public static let cleanAperture = VTSessionOptionKey(value: kVTCompressionPropertyKey_CleanAperture)
    public static let fieldCount = VTSessionOptionKey(value: kVTCompressionPropertyKey_FieldCount)
    public static let fieldDetail = VTSessionOptionKey(value: kVTCompressionPropertyKey_FieldDetail)
    public static let pixelAspectRatio = VTSessionOptionKey(value: kVTCompressionPropertyKey_PixelAspectRatio)
    public static let progressiveScan = VTSessionOptionKey(value: kVTCompressionPropertyKey_ProgressiveScan)
    public static let colorPrimaries = VTSessionOptionKey(value: kVTCompressionPropertyKey_ColorPrimaries)
    public static let transferFunction = VTSessionOptionKey(value: kVTCompressionPropertyKey_TransferFunction)
    public static let YCbCrMatrix = VTSessionOptionKey(value: kVTCompressionPropertyKey_YCbCrMatrix)
    public static let ICCProfile = VTSessionOptionKey(value: kVTCompressionPropertyKey_ICCProfile)
    public static let expectedDuration = VTSessionOptionKey(value: kVTCompressionPropertyKey_ExpectedDuration)
    public static let expectedFrameRate =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_ExpectedFrameRate)
    public static let sourceFrameCount = VTSessionOptionKey(value: kVTCompressionPropertyKey_SourceFrameCount)
    public static let allowFrameReordering =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_AllowFrameReordering)
    public static let allowTemporalCompression =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_AllowTemporalCompression)
    public static let maxKeyFrameInterval =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_MaxKeyFrameInterval)
    public static let maxKeyFrameIntervalDuration =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration)
    public static let multiPassStorage = VTSessionOptionKey(value: kVTCompressionPropertyKey_MultiPassStorage)
    public static let forceKeyFrame = VTSessionOptionKey(value: kVTEncodeFrameOptionKey_ForceKeyFrame)
    public static let pixelTransferProperties =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_PixelTransferProperties)
    public static let averageBitRate = VTSessionOptionKey(value: kVTCompressionPropertyKey_AverageBitRate)
    public static let dataRateLimits = VTSessionOptionKey(value: kVTCompressionPropertyKey_DataRateLimits)
    public static let moreFramesAfterEnd =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_MoreFramesAfterEnd)
    public static let moreFramesBeforeStart =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_MoreFramesBeforeStart)
    public static let quality = VTSessionOptionKey(value: kVTCompressionPropertyKey_Quality)
    public static let realTime = VTSessionOptionKey(value: kVTCompressionPropertyKey_RealTime)
    public static let maxH264SliceBytes =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_MaxH264SliceBytes)
    public static let maxFrameDelayCount =
        VTSessionOptionKey(value: kVTCompressionPropertyKey_MaxFrameDelayCount)
    public static let encoderID = VTSessionOptionKey(value: kVTVideoEncoderSpecification_EncoderID)
    @available(iOS 16.0, tvOS 16.0, macOS 13.0, *)
    public static let constantBitRate = VTSessionOptionKey(value: kVTCompressionPropertyKey_ConstantBitRate)

    let value: CFString
}
