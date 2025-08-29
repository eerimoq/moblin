import AVFAudio
import Foundation

struct AudioEncoderSettings {
    private static let maximumNumberOfChannels: UInt32 = 2

    enum Format {
        case aac
        case opus

        func makeAudioBuffer(_ format: AVAudioFormat) -> AVAudioCompressedBuffer {
            return AVAudioCompressedBuffer(
                format: format,
                packetCapacity: 1,
                maximumPacketSize: 1024 * Int(format.channelCount)
            )
        }

        func makeAudioFormat(_ inSourceFormat: AudioStreamBasicDescription) -> AVAudioFormat? {
            let channels = min(inSourceFormat.mChannelsPerFrame, AudioEncoderSettings.maximumNumberOfChannels)
            var streamDescription: AudioStreamBasicDescription
            switch self {
            case .aac:
                streamDescription = AudioStreamBasicDescription(
                    mSampleRate: inSourceFormat.mSampleRate,
                    mFormatID: kAudioFormatMPEG4AAC,
                    mFormatFlags: UInt32(MPEG4ObjectID.AAC_LC.rawValue),
                    mBytesPerPacket: 0,
                    mFramesPerPacket: 1024,
                    mBytesPerFrame: 0,
                    mChannelsPerFrame: channels,
                    mBitsPerChannel: 0,
                    mReserved: 0
                )
            case .opus:
                streamDescription = AudioStreamBasicDescription(
                    mSampleRate: inSourceFormat.mSampleRate,
                    mFormatID: kAudioFormatOpus,
                    mFormatFlags: 0,
                    mBytesPerPacket: 0,
                    mFramesPerPacket: 960,
                    mBytesPerFrame: 0,
                    mChannelsPerFrame: channels,
                    mBitsPerChannel: 0,
                    mReserved: 0
                )
            }
            return AVAudioFormat(streamDescription: &streamDescription)
        }
    }

    var bitrate = 64 * 1000
    var channelsMap: [Int: Int] = [0: 0, 1: 1]
    var format: AudioEncoderSettings.Format = .aac
}
