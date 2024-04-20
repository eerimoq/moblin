import Foundation
import VideoToolbox

public struct VideoCodecSettings {
    enum Format: Codable {
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

    public var videoSize: VideoSize
    public var bitRate: UInt32
    public var maxKeyFrameIntervalDuration: Int32
    public var allowFrameReordering: Bool
    public var profileLevel: String {
        didSet {
            if profileLevel.contains("HEVC") {
                format = .hevc
            } else {
                format = .h264
            }
        }
    }

    var format: Format = .h264

    public init(
        videoSize: VideoSize = .init(width: 854, height: 480),
        profileLevel: String = kVTProfileLevel_H264_Baseline_3_1 as String,
        bitRate: UInt32 = 640 * 1000,
        maxKeyFrameIntervalDuration: Int32 = 2,
        allowFrameReordering: Bool = false
    ) {
        self.videoSize = videoSize
        self.profileLevel = profileLevel
        self.bitRate = bitRate
        self.maxKeyFrameIntervalDuration = maxKeyFrameIntervalDuration
        self.allowFrameReordering = allowFrameReordering
        if profileLevel.contains("HEVC") {
            format = .hevc
        }
    }

    func shouldInvalidateSession(_ rhs: VideoCodecSettings) -> Bool {
        return !(videoSize == rhs.videoSize &&
            maxKeyFrameIntervalDuration == rhs.maxKeyFrameIntervalDuration &&
            allowFrameReordering == rhs.allowFrameReordering &&
            profileLevel == rhs.profileLevel)
    }

    private func createDataRateLimits(bitRate: UInt32) -> CFArray {
        // Multiply with 1.5 to reach target bitrate.
        let byteLimit = (Double(bitRate) / 8) as CFNumber
        let secLimit = Double(1.0) as CFNumber
        return [byteLimit, secLimit] as CFArray
    }

    func apply(_ codec: VideoCodec) {
        let option = VTSessionOption(key: .averageBitRate, value: NSNumber(value: bitRate))
        if let status = codec.session?.setOption(option), status != noErr {
            logger.info("Failed to set option \(status) \(option)")
        }
        let optionLimit = VTSessionOption(key: .dataRateLimits, value: createDataRateLimits(bitRate: bitRate))
        if let status = codec.session?.setOption(optionLimit), status != noErr {
            logger.info("Failed to set option \(status) \(optionLimit)")
        }
    }

    func options(_ codec: VideoCodec) -> [VTSessionOption] {
        let isBaseline = profileLevel.contains("Baseline")
        var options: [VTSessionOption] = [
            .init(key: .realTime, value: kCFBooleanTrue),
            .init(key: .profileLevel, value: profileLevel as NSObject),
            .init(key: .averageBitRate, value: bitRate as CFNumber),
            .init(key: .dataRateLimits, value: createDataRateLimits(bitRate: bitRate)),
            // It seemes that VT supports the range 0 to 30?
            .init(key: .expectedFrameRate, value: codec.expectedFrameRate as CFNumber),
            .init(key: .maxKeyFrameIntervalDuration, value: maxKeyFrameIntervalDuration as CFNumber),
            .init(key: .allowFrameReordering, value: allowFrameReordering as NSObject),
            .init(key: .pixelTransferProperties, value: ["ScalingMode": "Trim"] as NSObject),
        ]
        if !isBaseline, profileLevel.contains("H264") {
            options.append(.init(key: .h264EntropyMode, value: kVTH264EntropyMode_CABAC))
        }
        return options
    }
}
