import AVFoundation
@testable import Moblin
import Testing

private func makeSampleBuffer(sampleRate: Double,
                              channels: AVAudioChannelCount,
                              numberOfFrames: AVAudioFrameCount,
                              presentationTimeStamp: CMTime,
                              amplitude: Double = 1000) throws -> CMSampleBuffer
{
    let format = try #require(AVAudioFormat(commonFormat: .pcmFormatInt16,
                                            sampleRate: sampleRate,
                                            channels: channels,
                                            interleaved: true))
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: numberOfFrames))
    buffer.frameLength = numberOfFrames
    let samples = try #require(buffer.int16ChannelData?[0])
    for index in 0 ..< Int(numberOfFrames * channels) {
        samples[index] = Int16(amplitude * sin(Double(index / Int(channels)) * 0.1))
    }
    return try #require(buffer.makeSampleBuffer(presentationTimeStamp))
}

private func readSamples(_ sampleBuffer: CMSampleBuffer) throws -> [Int16] {
    var samples: [Int16] = []
    try sampleBuffer.withAudioBufferList { list, _ in
        guard let data = list[0].mData else {
            return
        }
        samples = Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: Int16.self),
                                            count: Int(list[0].mDataByteSize) / 2))
    }
    return samples
}

private func readFormat(_ sampleBuffer: CMSampleBuffer) throws -> (Double, UInt32) {
    let description = try #require(sampleBuffer.formatDescription?.audioStreamBasicDescription)
    return (description.mSampleRate, description.mChannelsPerFrame)
}

private extension AudioPcmConverter {
    func setInputFormatAndConvert(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        setInputFormat(sampleBuffer.formatDescription?.audioStreamBasicDescription)
        return convert(sampleBuffer)
    }
}

private final class AudioEncoderOutput: AudioEncoderDelegate {
    var formats: [AVAudioFormat] = []
    var numberOfBuffers = 0

    func audioEncoderOutputFormat(_ format: AVAudioFormat) {
        formats.append(format)
    }

    func audioEncoderOutputBuffer(_: AVAudioCompressedBuffer, _: CMTime) {
        numberOfBuffers += 1
    }
}

struct AudioPcmConverterSuite {
    @Test
    func fixedOutputFormatKeepsFirstChannelsAndConvertsTo48kHz() throws {
        let converter = AudioPcmConverter(name: "test")
        converter.setOutputFormatFixed(true)
        var numberOfFrames = 0
        for index in 0 ..< 20 {
            let sampleBuffer = try makeSampleBuffer(
                sampleRate: 44100,
                channels: 2,
                numberOfFrames: 1024,
                presentationTimeStamp: CMTime(value: CMTimeValue(1024 * index), timescale: 44100)
            )
            let converted = try #require(converter.setInputFormatAndConvert(sampleBuffer))
            #expect(try readFormat(converted) == (48000, 2))
            #expect(converted.presentationTimeStamp == sampleBuffer.presentationTimeStamp)
            numberOfFrames += converted.numSamples
        }
        #expect(abs(Double(numberOfFrames) - 20 * 1024 * 48000 / 44100) < 100)
        for index in 0 ..< 20 {
            let sampleBuffer = try makeSampleBuffer(
                sampleRate: 48000,
                channels: 1,
                numberOfFrames: 1024,
                presentationTimeStamp: CMTime(value: CMTimeValue(1024 * index), timescale: 48000)
            )
            let converted = try #require(converter.setInputFormatAndConvert(sampleBuffer))
            #expect(try readFormat(converted) == (48000, 2))
            #expect(converted.numSamples == 1024)
            let samples = try readSamples(converted)
            for frame in 0 ..< converted.numSamples {
                #expect(samples[2 * frame] == samples[2 * frame + 1])
            }
        }
    }

    @Test
    func outputFormatFollowsInputWhenNotFixed() throws {
        let converter = AudioPcmConverter(name: "test")
        let stereo = try makeSampleBuffer(sampleRate: 44100,
                                          channels: 2,
                                          numberOfFrames: 1024,
                                          presentationTimeStamp: .zero)
        let mono = try makeSampleBuffer(sampleRate: 48000,
                                        channels: 1,
                                        numberOfFrames: 1024,
                                        presentationTimeStamp: .zero)
        #expect(try readFormat(#require(converter.setInputFormatAndConvert(stereo))) == (48000, 2))
        #expect(converter.setInputFormatAndConvert(mono) === mono)
        #expect(converter.outputFormat?.channelCount == 1)
        converter.setOutputFormatFixed(true)
        #expect(try readFormat(#require(converter.setInputFormatAndConvert(stereo))) == (48000, 1))
        converter.setOutputFormatFixed(false)
        #expect(converter.outputFormat == nil)
        #expect(try readFormat(#require(converter.setInputFormatAndConvert(stereo))) == (48000, 2))
    }

    @Test
    func unsupportedInputClearsOutputFormatWhenNotFixed() throws {
        let converter = AudioPcmConverter(name: "test")
        let stereo = try makeSampleBuffer(sampleRate: 44100,
                                          channels: 2,
                                          numberOfFrames: 1024,
                                          presentationTimeStamp: .zero)
        let unsupported = AudioStreamBasicDescription(
            mSampleRate: 48000,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsBigEndian | kLinearPCMFormatFlagIsSignedInteger |
                kLinearPCMFormatFlagIsPacked,
            mBytesPerPacket: 6,
            mFramesPerPacket: 1,
            mBytesPerFrame: 6,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 24,
            mReserved: 0
        )
        _ = converter.setInputFormatAndConvert(stereo)
        #expect(converter.outputFormat != nil)
        converter.setInputFormat(unsupported)
        #expect(converter.outputFormat == nil)
        _ = converter.setInputFormatAndConvert(stereo)
        converter.setOutputFormatFixed(true)
        converter.setInputFormat(unsupported)
        #expect(converter.outputFormat?.channelCount == 2)
    }

    @Test
    func passthroughOnlyWhenNothingToConvert() throws {
        let converter = AudioPcmConverter(name: "test")
        converter.setOutputFormatFixed(true)
        let stereo = try makeSampleBuffer(sampleRate: 48000,
                                          channels: 2,
                                          numberOfFrames: 1024,
                                          presentationTimeStamp: .zero)
        #expect(converter.setInputFormatAndConvert(stereo) === stereo)
        #expect(converter.isPassthrough)
        converter.setChannelsMap([0: 1, 1: 0])
        #expect(converter.setInputFormatAndConvert(stereo) !== stereo)
        #expect(!converter.isPassthrough)
        converter.setChannelsMap([0: 0, 1: 1])
        let mono = try makeSampleBuffer(sampleRate: 48000,
                                        channels: 1,
                                        numberOfFrames: 1024,
                                        presentationTimeStamp: .zero)
        converter.setInputFormat(mono.formatDescription?.audioStreamBasicDescription)
        #expect(!converter.isPassthrough)
        converter.setInputFormat(stereo.formatDescription?.audioStreamBasicDescription)
        #expect(converter.isPassthrough)
        let resampled = try makeSampleBuffer(sampleRate: 44100,
                                             channels: 2,
                                             numberOfFrames: 1024,
                                             presentationTimeStamp: .zero)
        converter.setInputFormat(resampled.formatDescription?.audioStreamBasicDescription)
        #expect(!converter.isPassthrough)
    }

    @Test
    func convertedSampleBuffersDoNotShareData() throws {
        let converter = AudioPcmConverter(name: "test")
        converter.setChannelsMap([0: 1, 1: 0])
        let first = try #require(converter.setInputFormatAndConvert(makeSampleBuffer(sampleRate: 48000,
                                                                                     channels: 2,
                                                                                     numberOfFrames: 1024,
                                                                                     presentationTimeStamp: .zero,
                                                                                     amplitude: 1000)))
        let firstSamples = try readSamples(first)
        let second = try #require(converter.setInputFormatAndConvert(makeSampleBuffer(sampleRate: 48000,
                                                                                      channels: 2,
                                                                                      numberOfFrames: 1024,
                                                                                      presentationTimeStamp: .zero,
                                                                                      amplitude: 5000)))
        #expect(try readSamples(first) == firstSamples)
        #expect(try readSamples(second) != firstSamples)
    }

    @Test
    func audioEncoderEncodesConvertedAudio() throws {
        let queue = DispatchQueue(label: "test")
        let encoder = AudioEncoder(lockQueue: queue)
        let output = AudioEncoderOutput()
        encoder.delegate = output
        let converter = AudioPcmConverter(name: "test")
        converter.setOutputFormatFixed(true)
        var presentationTimeStamp = 0.0
        var sampleBuffers: [CMSampleBuffer] = []
        for (sampleRate, channels) in [(44100.0, AVAudioChannelCount(2)), (48000, 1)] {
            for _ in 0 ..< 20 {
                try sampleBuffers.append(makeSampleBuffer(sampleRate: sampleRate,
                                                          channels: channels,
                                                          numberOfFrames: 1024,
                                                          presentationTimeStamp: CMTime(
                                                              seconds: presentationTimeStamp
                                                          )))
                presentationTimeStamp += 1024 / sampleRate
            }
        }
        converter.setInputFormat(sampleBuffers[0].formatDescription?.audioStreamBasicDescription)
        queue.sync {
            encoder.setInputFormat(converter.outputFormat)
        }
        encoder.startRunning()
        queue.sync {
            for sampleBuffer in sampleBuffers {
                guard let converted = converter.setInputFormatAndConvert(sampleBuffer) else {
                    continue
                }
                encoder.appendSampleBuffer(converted, sampleBuffer.presentationTimeStamp)
            }
        }
        #expect(output.formats.count == 2)
        for format in output.formats {
            #expect(format.sampleRate == 48000)
            #expect(format.channelCount == 2)
        }
        #expect(output.numberOfBuffers > 38)
        #expect(encoder.getSampleRate() == 48000)
    }

    @Test
    func audioEncoderIgnoresUnchangedInputFormat() throws {
        let queue = DispatchQueue(label: "test")
        let encoder = AudioEncoder(lockQueue: queue)
        let output = AudioEncoderOutput()
        encoder.delegate = output
        let makeFormat = {
            try #require(AVAudioFormat(commonFormat: .pcmFormatInt16,
                                       sampleRate: 48000,
                                       channels: 2,
                                       interleaved: true))
        }
        let format = try makeFormat()
        queue.sync {
            encoder.setInputFormat(format)
        }
        encoder.startRunning()
        let sameFormat = try makeFormat()
        queue.sync {
            encoder.setInputFormat(sameFormat)
        }
        #expect(output.formats.count == 2)
        #expect(encoder.getSampleRate() == 48000)
        queue.sync {
            encoder.setInputFormat(nil)
        }
        #expect(encoder.getSampleRate() == nil)
    }
}
