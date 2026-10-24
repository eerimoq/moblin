import AVFAudio
import Foundation

struct AudioEncoderSettings {
    enum Format {
        case aac
        case opus

        func makeAudioBuffer(_ format: AVAudioFormat) -> AVAudioCompressedBuffer {
            AVAudioCompressedBuffer(
                format: format,
                packetCapacity: 1,
                maximumPacketSize: 1024 * Int(format.channelCount)
            )
        }

        func makeAudioFormat(_ inputFormat: AVAudioFormat) -> AVAudioFormat? {
            var streamDescription = switch self {
            case .aac:
                AudioStreamBasicDescription(
                    mSampleRate: inputFormat.sampleRate,
                    mFormatID: kAudioFormatMPEG4AAC,
                    mFormatFlags: UInt32(MPEG4ObjectID.AAC_LC.rawValue),
                    mBytesPerPacket: 0,
                    mFramesPerPacket: 1024,
                    mBytesPerFrame: 0,
                    mChannelsPerFrame: inputFormat.channelCount,
                    mBitsPerChannel: 0,
                    mReserved: 0
                )
            case .opus:
                AudioStreamBasicDescription(
                    mSampleRate: inputFormat.sampleRate,
                    mFormatID: kAudioFormatOpus,
                    mFormatFlags: 0,
                    mBytesPerPacket: 0,
                    mFramesPerPacket: 960,
                    mBytesPerFrame: 0,
                    mChannelsPerFrame: inputFormat.channelCount,
                    mBitsPerChannel: 0,
                    mReserved: 0
                )
            }
            return AVAudioFormat(streamDescription: &streamDescription)
        }
    }

    var bitrate = 64 * 1000
    var format: AudioEncoderSettings.Format = .aac
}
