import AVFoundation
@testable import Moblin
import Testing

struct AudioUnitSuite {
    @Test
    func calcAudioLevelPeakFloat32() {
        var samples: [Float32] = [0.1, -0.75, 0.5, -0.2]
        let peak = samples.withUnsafeMutableBufferPointer {
            Moblin.calcAudioLevelPeakFloat32(samples: $0.baseAddress!, count: $0.count)
        }
        #expect(peak == 0.75)
    }

    @Test
    func calcAudioLevelPeakFloat32Empty() {
        var samples: [Float32] = [1.0]
        let peak = samples.withUnsafeMutableBufferPointer {
            Moblin.calcAudioLevelPeakFloat32(samples: $0.baseAddress!, count: 0)
        }
        #expect(peak == 0.0)
    }

    @Test
    func calcAudioLevelPeakInt16() {
        var samples: [Int16] = [100, -3000, 2000, -50]
        let peak = samples.withUnsafeMutableBufferPointer {
            Moblin.calcAudioLevelPeakInt16(samples: $0.baseAddress!, count: $0.count)
        }
        #expect(peak == 0.091552734)
    }

    @Test
    func calcAudioLevelPeakInt16Min() {
        var samples: [Int16] = [Int16.min, Int16.max]
        let peak = samples.withUnsafeMutableBufferPointer {
            Moblin.calcAudioLevelPeakInt16(samples: $0.baseAddress!, count: $0.count)
        }
        #expect(peak == 1.0)
    }

    @Test
    func calcAudioLevelPeakInt16Empty() {
        var samples: [Int16] = [1000]
        let peak = samples.withUnsafeMutableBufferPointer {
            Moblin.calcAudioLevelPeakInt16(samples: $0.baseAddress!, count: 0)
        }
        #expect(peak == 0.0)
    }

    @Test
    func makeChannelMapMonoToStereo() {
        let channelMap = makeChannelMap(numberOfInputChannels: 1,
                                        numberOfOutputChannels: 2,
                                        outputToInputChannelsMap: [0: 0, 1: 1])
        #expect(channelMap == [0, 0])
    }

    @Test
    func makeChannelMapStereoToMono() {
        let channelMap = makeChannelMap(numberOfInputChannels: 2,
                                        numberOfOutputChannels: 1,
                                        outputToInputChannelsMap: [0: 0, 1: 1])
        #expect(channelMap == [0])
    }

    @Test
    func makeChannelMapStereoToStereo() {
        let channelMap = makeChannelMap(numberOfInputChannels: 2,
                                        numberOfOutputChannels: 2,
                                        outputToInputChannelsMap: [0: 1, 1: 0])
        #expect(channelMap == [1, 0])
    }

    @Test
    func makeChannelMapFourToStereo() {
        let channelMap = makeChannelMap(numberOfInputChannels: 4,
                                        numberOfOutputChannels: 2,
                                        outputToInputChannelsMap: [0: 2, 1: 3])
        #expect(channelMap == [2, 3])
    }

    @Test
    func convertMonoToStereo() throws {
        let inputFormat = try #require(AVAudioFormat(commonFormat: .pcmFormatInt16,
                                                     sampleRate: 48000,
                                                     channels: 1,
                                                     interleaved: true))
        let outputFormat = try #require(AVAudioFormat(commonFormat: .pcmFormatInt16,
                                                      sampleRate: 48000,
                                                      channels: 2,
                                                      interleaved: true))
        let converter = try #require(AVAudioConverter(from: inputFormat, to: outputFormat))
        converter.channelMap = makeChannelMap(numberOfInputChannels: 1,
                                              numberOfOutputChannels: 2,
                                              outputToInputChannelsMap: [0: 0, 1: 1])
        let inputBuffer = try #require(AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 4))
        inputBuffer.frameLength = 4
        for (index, sample) in [Int16(100), -200, 300, -400].enumerated() {
            inputBuffer.int16ChannelData?[0][index] = sample
        }
        let outputBuffer = try #require(AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: 4))
        try converter.convert(to: outputBuffer, from: inputBuffer)
        let samples = try Array(UnsafeBufferPointer(
            start: #require(outputBuffer.int16ChannelData?[0]),
            count: 8
        ))
        #expect(samples == [100, 100, -200, -200, 300, 300, -400, -400])
    }
}
