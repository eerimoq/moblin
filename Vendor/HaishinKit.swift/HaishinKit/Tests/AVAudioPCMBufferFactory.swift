import AVFoundation
@testable import HaishinKit

enum AVAudioPCMBufferFactory {
    static func makeSinWave(_ sampleRate: Double = 44100, numSamples: Int = 1024, channels: UInt32 = 1) -> AVAudioPCMBuffer? {
        var streamDescription = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: 0xc,
            mBytesPerPacket: 2 * channels,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2 * channels,
            mChannelsPerFrame: channels,
            mBitsPerChannel: 16,
            mReserved: 0
        )

        guard let format = AVAudioFormat(streamDescription: &streamDescription, channelLayout: AVAudioUtil.makeChannelLayout(channels)) else {
            return nil
        }

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples))!
        buffer.frameLength = buffer.frameCapacity

        let channels = Int(format.channelCount)
        let samples = buffer.int16ChannelData![0]
        for n in 0..<Int(buffer.frameLength) {
            switch channels {
            case 1:
                samples[n] = Int16(sinf(Float(2.0 * .pi) * 440.0 * Float(n) / Float(sampleRate)) * 16383.0)
            case 2:
                samples[n * 2 + 0] = Int16(sinf(Float(2.0 * .pi) * 440.0 * Float(n + 0) / Float(sampleRate)) * 16383.0)
                samples[n * 2 + 1] = Int16(sinf(Float(2.0 * .pi) * 440.0 * Float(n + 1) / Float(sampleRate)) * 16383.0)
            case 3:
                samples[n * 3 + 0] = Int16(sinf(Float(2.0 * .pi) * 440.0 * Float(n + 0) / Float(sampleRate)) * 16383.0)
                samples[n * 3 + 1] = Int16(sinf(Float(2.0 * .pi) * 440.0 * Float(n + 1) / Float(sampleRate)) * 16383.0)
                samples[n * 3 + 2] = Int16(sinf(Float(2.0 * .pi) * 440.0 * Float(n + 2) / Float(sampleRate)) * 16383.0)
            case 4:
                samples[n * 4 + 0] = Int16(sinf(Float(2.0 * .pi) * 440.0 * Float(n + 0) / Float(sampleRate)) * 16383.0)
                samples[n * 4 + 1] = Int16(sinf(Float(2.0 * .pi) * 440.0 * Float(n + 1) / Float(sampleRate)) * 16383.0)
                samples[n * 4 + 2] = Int16(sinf(Float(2.0 * .pi) * 440.0 * Float(n + 2) / Float(sampleRate)) * 16383.0)
                samples[n * 4 + 3] = Int16(sinf(Float(2.0 * .pi) * 440.0 * Float(n + 3) / Float(sampleRate)) * 16383.0)
            case 5:
                samples[n * 5 + 0] = Int16(sinf(Float(2.0 * .pi) * 440.0 * Float(n + 0) / Float(sampleRate)) * 16383.0)
                samples[n * 5 + 1] = Int16(sinf(Float(2.0 * .pi) * 440.0 * Float(n + 1) / Float(sampleRate)) * 16383.0)
                samples[n * 5 + 2] = Int16(sinf(Float(2.0 * .pi) * 440.0 * Float(n + 2) / Float(sampleRate)) * 16383.0)
                samples[n * 5 + 3] = Int16(sinf(Float(2.0 * .pi) * 440.0 * Float(n + 3) / Float(sampleRate)) * 16383.0)
                samples[n * 5 + 4] = Int16(sinf(Float(2.0 * .pi) * 440.0 * Float(n + 4) / Float(sampleRate)) * 16383.0)
            default:
                break
            }
        }

        return buffer
    }
}
