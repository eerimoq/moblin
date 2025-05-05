import AVFAudio
import Foundation

struct AudioEncoderSettings {
    private static let maximumNumberOfChannels: UInt32 = 2

    enum Format {
        case aac
        case opus

        func makeAudioBuffer(_ format: AVAudioFormat) -> AVAudioBuffer {
            return AVAudioCompressedBuffer(
                format: format,
                packetCapacity: 1,
                maximumPacketSize: 1024 * Int(format.channelCount)
            )
        }

        func makeAudioFormat(_ inSourceFormat: AudioStreamBasicDescription) -> AVAudioFormat? {
            switch self {
            case .aac:
                var streamDescription = AudioStreamBasicDescription(
                    mSampleRate: inSourceFormat.mSampleRate,
                    mFormatID: kAudioFormatMPEG4AAC,
                    mFormatFlags: UInt32(MPEG4ObjectID.AAC_LC.rawValue),
                    mBytesPerPacket: 0,
                    mFramesPerPacket: 1024,
                    mBytesPerFrame: 0,
                    mChannelsPerFrame: min(
                        inSourceFormat.mChannelsPerFrame,
                        AudioEncoderSettings.maximumNumberOfChannels
                    ),
                    mBitsPerChannel: 0,
                    mReserved: 0
                )
                return AVAudioFormat(streamDescription: &streamDescription)
            case .opus:
                var streamDescription = AudioStreamBasicDescription(
                    mSampleRate: inSourceFormat.mSampleRate,
                    mFormatID: kAudioFormatOpus,
                    mFormatFlags: 0,
                    mBytesPerPacket: 0,
                    mFramesPerPacket: 2880,
                    mBytesPerFrame: 0,
                    mChannelsPerFrame: min(
                        inSourceFormat.mChannelsPerFrame,
                        AudioEncoderSettings.maximumNumberOfChannels
                    ),
                    mBitsPerChannel: 0,
                    mReserved: 0
                )
                return AVAudioFormat(streamDescription: &streamDescription)
            }
        }
    }

    var bitrate = 64 * 1000
    var channelsMap: [Int: Int] = [0: 0, 1: 1]
    var format: AudioEncoderSettings.Format = .aac

    func apply(_ converter: AVAudioConverter, oldValue: AudioEncoderSettings?) {
        guard bitrate != oldValue?.bitrate else {
            return
        }
        let minAvailableBitRate = converter.applicableEncodeBitRates?.min(by: {
            $0.intValue < $1.intValue
        })?.intValue ?? bitrate
        let maxAvailableBitRate = converter.applicableEncodeBitRates?.max(by: {
            $0.intValue < $1.intValue
        })?.intValue ?? bitrate
        converter.bitRate = min(maxAvailableBitRate, max(minAvailableBitRate, bitrate))
        logger.debug("Audio bitrate: \(converter.bitRate), maximum: \(maxAvailableBitRate)")
    }
}
