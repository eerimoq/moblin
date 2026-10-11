import AVFoundation
@testable import Moblin
import Testing

struct AudioMixerSuite {
    @Test
    func noSources() {
        let mixer = AudioMixer()
        let sampleBuffer = createInt16MonoSampleBuffer(value: 1000, numberOfFrames: 1024)
        #expect(mixer.mix(sampleBuffer, .zero) === sampleBuffer)
    }

    @Test
    func mixFloatStereoIntoInt16Mono() {
        let mixer = AudioMixer()
        let sourceId = UUID()
        mixer.setSources([sourceId: "source"])
        _ = mixer.mix(createInt16MonoSampleBuffer(value: 0, numberOfFrames: 1024), .zero)
        mixer.append(sourceId: sourceId, createFloatStereoSampleBuffer(value: 0.25, numberOfFrames: 4096))
        let mixed = mixer.mix(createInt16MonoSampleBuffer(value: 1000, numberOfFrames: 1024), .zero)
        let samples = readInt16Samples(mixed)
        #expect(samples.count == 1024)
        #expect(samples.allSatisfy { abs(Int($0) - 9191) <= 2 })
    }

    @Test
    func prebufferBeforeMixing() {
        let mixer = AudioMixer()
        let sourceId = UUID()
        mixer.setSources([sourceId: "source"])
        _ = mixer.mix(createInt16MonoSampleBuffer(value: 0, numberOfFrames: 1024), .zero)
        mixer.append(sourceId: sourceId, createFloatStereoSampleBuffer(value: 0.25, numberOfFrames: 1024))
        let mixed = mixer.mix(createInt16MonoSampleBuffer(value: 1000, numberOfFrames: 1024), .zero)
        #expect(readInt16Samples(mixed).allSatisfy { $0 == 1000 })
    }

    @Test
    func clampInt16() {
        let mixer = AudioMixer()
        let sourceId = UUID()
        mixer.setSources([sourceId: "source"])
        _ = mixer.mix(createInt16MonoSampleBuffer(value: 0, numberOfFrames: 1024), .zero)
        mixer.append(sourceId: sourceId, createFloatStereoSampleBuffer(value: 1, numberOfFrames: 4096))
        let mixed = mixer.mix(createInt16MonoSampleBuffer(value: 30000, numberOfFrames: 1024), .zero)
        #expect(readInt16Samples(mixed).allSatisfy { $0 == Int16.max })
    }
}

private func createInt16MonoSampleBuffer(value: Int16, numberOfFrames: Int) -> CMSampleBuffer {
    let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                               sampleRate: 48000,
                               channels: 1,
                               interleaved: true)!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numberOfFrames))!
    buffer.frameLength = AVAudioFrameCount(numberOfFrames)
    for frame in 0 ..< numberOfFrames {
        buffer.int16ChannelData![0][frame] = value
    }
    return buffer.makeSampleBuffer(.zero)!
}

private func createFloatStereoSampleBuffer(value: Float, numberOfFrames: Int) -> CMSampleBuffer {
    let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                               sampleRate: 48000,
                               channels: 2,
                               interleaved: false)!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numberOfFrames))!
    buffer.frameLength = AVAudioFrameCount(numberOfFrames)
    for channel in 0 ..< 2 {
        for frame in 0 ..< numberOfFrames {
            buffer.floatChannelData![channel][frame] = value
        }
    }
    return buffer.makeSampleBuffer(.zero)!
}

private func readInt16Samples(_ sampleBuffer: CMSampleBuffer) -> [Int16] {
    var samples: [Int16] = []
    _ = sampleBuffer.foreachAudioSample(float32: { _, _ in }, int16: { data, count in
        samples = Array(UnsafeBufferPointer(start: data, count: count))
    })
    return samples
}
