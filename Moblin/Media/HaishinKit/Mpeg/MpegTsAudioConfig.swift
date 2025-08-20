import AVFoundation

struct MpegTsAudioConfig: Equatable {
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
        case hvxc = 9
        case opus = 10

        init(objectID: MPEG4ObjectID) {
            switch objectID {
            case .aac_Main:
                self = .aacMain
            case .AAC_LC:
                self = .aacLc
            case .AAC_SSR:
                self = .aacSsr
            case .AAC_LTP:
                self = .aacLtp
            case .AAC_SBR:
                self = .aacSbr
            case .aac_Scalable:
                self = .aacScalable
            case .twinVQ:
                self = .twinqVQ
            case .CELP:
                self = .celp
            case .HVXC:
                self = .hvxc
            @unknown default:
                self = .unknown
            }
        }
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

        init(sampleRate: Float64) {
            switch Int(sampleRate) {
            case 96000:
                self = .hz96000
            case 88200:
                self = .hz88200
            case 64000:
                self = .hz64000
            case 48000:
                self = .hz48000
            case 44100:
                self = .hz44100
            case 32000:
                self = .hz32000
            case 24000:
                self = .hz24000
            case 22050:
                self = .hz22050
            case 16000:
                self = .hz16000
            case 12000:
                self = .hz12000
            case 11025:
                self = .hz11025
            case 8000:
                self = .hz8000
            case 7350:
                self = .hz7350
            default:
                self = .hz44100
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

    let type: AudioObjectType
    let frequency: SamplingFrequency
    let channel: ChannelConfiguration
    let frameLengthFlag = false

    var bytes: [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 2)
        bytes[0] = type.rawValue << 3 | (frequency.rawValue >> 1)
        bytes[1] = (frequency.rawValue & 0x1) << 7 | (channel.rawValue & 0xF) << 3
        return bytes
    }

    init?(bytes: [UInt8]) {
        guard
            let type = AudioObjectType(rawValue: bytes[0] >> 3),
            let frequency = SamplingFrequency(rawValue: (bytes[0] & 0b0000_0111) << 1 | (bytes[1] >> 7)),
            let channel = ChannelConfiguration(rawValue: (bytes[1] & 0b0111_1000) >> 3)
        else {
            return nil
        }
        self.type = type
        self.frequency = frequency
        self.channel = channel
    }

    init(formatDescription: CMFormatDescription) {
        let streamBasicDescription = formatDescription.audioStreamBasicDescription!
        switch streamBasicDescription.mFormatID {
        case kAudioFormatOpus:
            type = .opus
        default:
            type = AudioObjectType(objectID: MPEG4ObjectID(rawValue: Int(streamBasicDescription.mFormatFlags))!)
        }
        frequency = SamplingFrequency(sampleRate: streamBasicDescription.mSampleRate)
        channel = ChannelConfiguration(rawValue: UInt8(streamBasicDescription.mChannelsPerFrame))!
    }

    func makeHeader(_ length: Int) -> Data {
        switch type {
        case .opus:
            return makeOpusHeader(length)
        default:
            return makeAacHeader(length)
        }
    }

    private func makeAacHeader(_ length: Int) -> Data {
        let size = 7
        let fullSize = size + length
        var adts = Data(count: size)
        adts[0] = 0xFF
        adts[1] = 0xF9
        adts[2] = (type.rawValue - 1) << 6 | (frequency.rawValue << 2) | (channel.rawValue >> 2)
        adts[3] = (channel.rawValue & 3) << 6 | UInt8(fullSize >> 11)
        adts[4] = UInt8((fullSize & 0x7FF) >> 3)
        adts[5] = (UInt8(fullSize & 7) << 5) + 0x1F
        adts[6] = 0xFC
        return adts
    }

    private func makeOpusHeader(_ length: Int) -> Data {
        let writer = ByteWriter()
        writer.writeUInt16(0x3FF << 5)
        var length = length
        while length >= 0 {
            writer.writeUInt8(length < 255 ? UInt8(length) : 255)
            length -= 255
        }
        return writer.data
    }

    func audioStreamBasicDescription() -> AudioStreamBasicDescription {
        AudioStreamBasicDescription(
            mSampleRate: frequency.sampleRate,
            mFormatID: kAudioFormatMPEG4AAC,
            mFormatFlags: UInt32(type.rawValue),
            mBytesPerPacket: 0,
            mFramesPerPacket: frameLengthFlag ? 960 : 1024,
            mBytesPerFrame: 0,
            mChannelsPerFrame: UInt32(channel.rawValue),
            mBitsPerChannel: 0,
            mReserved: 0
        )
    }
}
