/**
 The Audio Specific Config is the global header for MPEG-4 Audio
 - seealso: http://wiki.multimedia.cx/index.php?title=MPEG-4_Audio#Audio_Specific_Config
 - seealso: http://wiki.multimedia.cx/?title=Understanding_AAC
 */
enum AudioSpecificConfig {
    enum AudioObjectType: UInt8 {
        case unknown = 0
        case aacMain = 1
        case aacLc = 2
        case aacSsr = 3
        case aacLtp = 4
        case aacSbr = 5
        case aacScalable = 6
        case twinqVQ = 7
        case celp = 8
        case hxvc = 9
    }

    enum SamplingFrequency: UInt8 {
        case hz96000 = 0
        case hz88200 = 1
        case hz64000 = 2
        case hz48000 = 3
        case hz44100 = 4
        case hz32000 = 5
        case hz24000 = 6
        case hz22050 = 7
        case hz16000 = 8
        case hz12000 = 9
        case hz11025 = 10
        case hz8000 = 11
        case hz7350 = 12

        var sampleRate: Float64 {
            switch self {
            case .hz96000:
                return 96000
            case .hz88200:
                return 88200
            case .hz64000:
                return 64000
            case .hz48000:
                return 48000
            case .hz44100:
                return 44100
            case .hz32000:
                return 32000
            case .hz24000:
                return 24000
            case .hz22050:
                return 22050
            case .hz16000:
                return 16000
            case .hz12000:
                return 12000
            case .hz11025:
                return 11025
            case .hz8000:
                return 8000
            case .hz7350:
                return 7350
            }
        }
    }

    enum ChannelConfiguration: UInt8 {
        case definedInAOTSpecificConfig = 0
        case frontCenter = 1
        case frontLeftAndFrontRight = 2
        case frontCenterAndFrontLeftAndFrontRight = 3
        case frontCenterAndFrontLeftAndFrontRightAndBackCenter = 4
        case frontCenterAndFrontLeftAndFrontRightAndBackLeftAndBackRight = 5
        case frontCenterAndFrontLeftAndFrontRightAndBackLeftAndBackRightLFE = 6
        case frontCenterAndFrontLeftAndFrontRightAndSideLeftAndSideRightAndBackLeftAndBackRightLFE = 7
    }
}
