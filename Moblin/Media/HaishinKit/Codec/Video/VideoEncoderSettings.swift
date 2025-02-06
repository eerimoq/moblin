import Foundation
import VideoToolbox

var videoEncoderDataRateLimitFactor = 1.2

func createDataRateLimits(bitRate: UInt32) -> CFArray {
    var bitRate = Double(bitRate)
    if bitRate < 1_000_000 {
        bitRate *= 1.2
    } else {
        bitRate *= videoEncoderDataRateLimitFactor
    }
    let bytesLimit = (bitRate / 8) as CFNumber
    let secondsLimit = Double(1.0) as CFNumber
    return [bytesLimit, secondsLimit] as CFArray
}

struct VideoEncoderSettings {
    enum Format {
        case h264
        case hevc

        var codecType: UInt32 {
            switch self {
            case .h264:
                return kCMVideoCodecType_H264
            case .hevc:
                return kCMVideoCodecType_HEVC
            }
        }
    }

    var videoSize: CMVideoDimensions
    var bitRate: UInt32
    var maxKeyFrameIntervalDuration: Int32
    var allowFrameReordering: Bool
    var profileLevel: String {
        didSet {
            if profileLevel.contains("HEVC") {
                format = .hevc
            } else {
                format = .h264
            }
        }
    }

    var adaptiveResolution = false

    private(set) var format: Format = .h264

    init() {
        videoSize = .init(width: 854, height: 480)
        profileLevel = kVTProfileLevel_H264_Baseline_3_1 as String
        bitRate = 640 * 1000
        maxKeyFrameIntervalDuration = 2
        allowFrameReordering = false
    }

    func shouldInvalidateSession(_ other: VideoEncoderSettings) -> Bool {
        return !(videoSize == other.videoSize &&
            maxKeyFrameIntervalDuration == other.maxKeyFrameIntervalDuration &&
            allowFrameReordering == other.allowFrameReordering &&
            profileLevel == other.profileLevel)
    }

    func options(_: VideoEncoder) -> [VTSessionOption] {
        let isBaseline = profileLevel.contains("Baseline")
        var options: [VTSessionOption] = [
            .init(key: .realTime, value: kCFBooleanTrue),
            .init(key: .profileLevel, value: profileLevel as NSObject),
            .init(key: .averageBitRate, value: bitRate as CFNumber),
            .init(key: .dataRateLimits, value: createDataRateLimits(bitRate: bitRate)),
            // It seemes that VT supports the range 0 to 30?
            .init(key: .expectedFrameRate, value: VideoUnit.defaultFrameRate as CFNumber),
            .init(key: .maxKeyFrameIntervalDuration, value: maxKeyFrameIntervalDuration as CFNumber),
            .init(key: .allowFrameReordering, value: allowFrameReordering as NSObject),
            .init(key: .pixelTransferProperties, value: ["ScalingMode": "Trim"] as NSObject),
        ]
        if profileLevel.contains("Main10") {
            options += [
                .init(key: .hdrMetadataInsertionMode, value: kVTHDRMetadataInsertionMode_Auto),
                .init(key: .colorPrimaries, value: kCVImageBufferColorPrimaries_ITU_R_2020),
                .init(key: .transferFunction, value: kCVImageBufferTransferFunction_ITU_R_2100_HLG),
                .init(key: .YCbCrMatrix, value: kCVImageBufferYCbCrMatrix_ITU_R_2020),
            ]
        }
        if !isBaseline, profileLevel.contains("H264") {
            options.append(.init(key: .h264EntropyMode, value: kVTH264EntropyMode_CABAC))
        }
        return options
    }
}
