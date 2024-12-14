import AVFAudio
import Foundation

struct AudioCodecOutputSettings {
    static let maximumNumberOfChannels: UInt32 = 2

    enum Format {
        case pcm
        case aac
        case opus

        func makeAudioBuffer(_ format: AVAudioFormat) -> AVAudioBuffer? {
            switch self {
            case .pcm:
                return AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)
            case .aac:
                return AVAudioCompressedBuffer(
                    format: format,
                    packetCapacity: 1,
                    maximumPacketSize: 1024 * Int(format.channelCount)
                )
            case .opus:
                return AVAudioCompressedBuffer(
                    format: format,
                    packetCapacity: 1,
                    maximumPacketSize: 1024 * Int(format.channelCount)
                )
            }
        }

        func makeAudioFormat(_ inSourceFormat: AudioStreamBasicDescription?) -> AVAudioFormat? {
            guard let inSourceFormat else {
                return nil
            }
            switch self {
            case .pcm:
                return AVAudioFormat(
                    commonFormat: .pcmFormatFloat32,
                    sampleRate: inSourceFormat.mSampleRate,
                    channels: min(
                        inSourceFormat.mChannelsPerFrame,
                        AudioCodecOutputSettings.maximumNumberOfChannels
                    ),
                    interleaved: true
                )
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
                        AudioCodecOutputSettings.maximumNumberOfChannels
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
                        AudioCodecOutputSettings.maximumNumberOfChannels
                    ),
                    mBitsPerChannel: 0,
                    mReserved: 0
                )
                return AVAudioFormat(streamDescription: &streamDescription)
            }
        }
    }

    var bitRate = 64 * 1000
    var channelsMap: [Int: Int] = [0: 0, 1: 1]
    var format: AudioCodecOutputSettings.Format = .aac

    func apply(_ converter: AVAudioConverter, oldValue: AudioCodecOutputSettings?) {
        guard bitRate != oldValue?.bitRate else {
            return
        }
        let minAvailableBitRate = converter.applicableEncodeBitRates?.min(by: { a, b in
            a.intValue < b.intValue
        })?.intValue ?? bitRate
        let maxAvailableBitRate = converter.applicableEncodeBitRates?.max(by: { a, b in
            a.intValue < b.intValue
        })?.intValue ?? bitRate
        converter.bitRate = min(maxAvailableBitRate, max(minAvailableBitRate, bitRate))
        logger.debug("Audio bitrate: \(converter.bitRate), maximum: \(maxAvailableBitRate)")
    }
}
