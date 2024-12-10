import AVFoundation

enum FlvAacPacketType: UInt8 {
    case seq = 0
    case raw = 1
}

enum FlvAvcPacketType: UInt8 {
    case seq = 0
    case nal = 1
}

enum FlvFrameType: UInt8 {
    case key = 1
    case inter = 2
}

enum FlvSoundRate: UInt8 {
    case kHz5_5 = 0
    case kHz11 = 1
    case kHz22 = 2
    case kHz44 = 3

    var floatValue: Float64 {
        switch self {
        case .kHz5_5:
            return 5500
        case .kHz11:
            return 11025
        case .kHz22:
            return 22050
        case .kHz44:
            return 44100
        }
    }
}

enum FlvSoundSize: UInt8 {
    case snd8bit = 0
    case snd16bit = 1
}

enum FlvSoundType: UInt8 {
    case mono = 0
    case stereo = 1
}

enum FlvTagType: UInt8 {
    case audio = 8
    case video = 9
    case data = 18

    var streamId: UInt16 {
        switch self {
        case .audio, .video:
            return UInt16(rawValue)
        case .data:
            return 0
        }
    }

    var headerSize: Int {
        switch self {
        case .audio:
            return 2
        case .video:
            return 5
        case .data:
            return 0
        }
    }
}

enum FlvVideoCodec: UInt8 {
    case avc = 7
}

enum FlvVideoFourCC: UInt32 {
    case hevc = 0x6876_6331 // { 'h', 'v', 'c', '1' }
}

enum FlvVideoPacketType: UInt8 {
    case sequenceStart = 0
    case codedFrames = 1
}

enum FlvAudioCodec: UInt8 {
    case pcm = 0
    case adpcm = 1
    case mp3 = 2
    case pcmle = 3
    case aac = 10
    case speex = 11
    case mp3_8k = 14
    case device = 15
    case unknown = 0xFF

    var isSupported: Bool {
        switch self {
        case .aac:
            return true
        default:
            return false
        }
    }

    var formatID: AudioFormatID {
        switch self {
        case .pcm:
            return kAudioFormatLinearPCM
        case .mp3:
            return kAudioFormatMPEGLayer3
        case .pcmle:
            return kAudioFormatLinearPCM
        case .aac:
            return kAudioFormatMPEG4AAC
        case .mp3_8k:
            return kAudioFormatMPEGLayer3
        default:
            return 0
        }
    }

    var formatFlags: AudioFormatFlags {
        switch self {
        case .aac:
            return AudioFormatFlags(MpegTsAudioConfig.AudioObjectType.aacMain.rawValue)
        default:
            return 0
        }
    }

    var headerSize: Int {
        switch self {
        case .aac:
            return 2
        default:
            return 1
        }
    }

    func audioStreamBasicDescription(_ rate: FlvSoundRate, size _: FlvSoundSize,
                                     type: FlvSoundType) -> AudioStreamBasicDescription?
    {
        guard isSupported else {
            return nil
        }
        return AudioStreamBasicDescription(
            mSampleRate: rate.floatValue,
            mFormatID: formatID,
            mFormatFlags: formatFlags,
            mBytesPerPacket: 0,
            mFramesPerPacket: 1024,
            mBytesPerFrame: 0,
            mChannelsPerFrame: type == .stereo ? 2 : 1,
            mBitsPerChannel: 0,
            mReserved: 0
        )
    }
}
