import AVFoundation
@testable import Moblin
import Testing

private let startIndex: Int64 = 480_000

struct AudioMixerInputSuite {
    struct FormatCase: CustomTestStringConvertible {
        let commonFormat: AVAudioCommonFormat
        let numberOfChannels: Int
        let interleaved: Bool

        var testDescription: String {
            let sampleFormat = commonFormat == .pcmFormatInt16 ? "Int16" : "Float32"
            return "\(sampleFormat), \(numberOfChannels) channels, interleaved \(interleaved)"
        }
    }

    struct PlacementCase: CustomTestStringConvertible {
        let testDescription: String
        let kind: AudioMixerInputKind
        let offset: Int64
        let shift: Int64

        init(_ description: String, _ offset: Int64, _ shift: Int64, _ kind: AudioMixerInputKind = .buffered)
        {
            testDescription = description
            self.kind = kind
            self.offset = offset
            self.shift = shift
        }
    }

    @Test(arguments: [
        FormatCase(commonFormat: .pcmFormatInt16, numberOfChannels: 1, interleaved: true),
        FormatCase(commonFormat: .pcmFormatInt16, numberOfChannels: 4, interleaved: true),
        FormatCase(commonFormat: .pcmFormatInt16, numberOfChannels: 2, interleaved: false),
        FormatCase(commonFormat: .pcmFormatFloat32, numberOfChannels: 2, interleaved: true),
        FormatCase(commonFormat: .pcmFormatFloat32, numberOfChannels: 3, interleaved: false),
    ])
    func convertsFormats(_ testCase: FormatCase) {
        let input = AudioMixerInput(kind: .buffered)
        let format = createFormat(testCase.commonFormat, testCase.numberOfChannels, testCase.interleaved)
        let sampleBuffer = createSampleBuffers(1, format: format)[0]
        input.append(sampleBuffer, sampleBuffer.presentationTimeStamp)
        let lastChannel = testCase.numberOfChannels - 1
        var before = [Float](repeating: 1, count: 8)
        var first = [Float](repeating: 0, count: 768)
        var last = [Float](repeating: 0, count: 768)
        input.read(channel: 0, at: startIndex - 8, count: 8, into: &before)
        input.read(channel: 0, at: startIndex + 256, count: 768, into: &first)
        input.read(channel: lastChannel, at: startIndex + 256, count: 768, into: &last)
        #expect(input.numberOfChannels == testCase.numberOfChannels)
        #expect(input.writeIndex == startIndex + 1024)
        #expect(before == [Float](repeating: 0, count: 8))
        #expect(first == createNoise(0, 256 ..< 1024))
        #expect(last == createNoise(lastChannel, 256 ..< 1024))
    }

    @Test
    func convertsOtherSampleRates() {
        let input = AudioMixerInput(kind: .buffered)
        let format = createFormat(.pcmFormatInt16, 2, true, sampleRate: 44100)
        let sampleBuffers = createSampleBuffers(100, format: format) { _, frame in
            Float(0.5 * sin(2 * Double.pi * 1000 * Double(frame) / 44100))
        }
        for sampleBuffer in sampleBuffers {
            input.append(sampleBuffer, sampleBuffer.presentationTimeStamp)
        }
        var samples = [Float](repeating: 0, count: 48000)
        input.read(channel: 1, at: startIndex + 24000, count: 48000, into: &samples)
        #expect(input.numberOfResyncs == 0)
        #expect(zip(samples, createSine(24000 ..< 72000)).allSatisfy { abs($0 - $1) < 0.01 })
    }

    @Test(arguments: [
        PlacementCase("96 frames early", -96, 0),
        PlacementCase("96 frames late", 96, 0),
        PlacementCase("gap", 500, 500),
        PlacementCase("largest gap", 2400, 2400),
        PlacementCase("overlap", -300, -300),
        PlacementCase("covered buffer", -1024, -1024),
        PlacementCase("resync", 3000, 3000),
        PlacementCase("builtin resync backward", -3000, -3000, .builtin),
    ])
    func placesBuffers(_ testCase: PlacementCase) {
        let input = AudioMixerInput(kind: testCase.kind)
        for sampleBuffer in createSampleBuffers(3, offset: testCase.offset) {
            input.append(sampleBuffer, sampleBuffer.presentationTimeStamp)
        }
        var end = [Float](repeating: 0, count: 256)
        var silence = [Float](repeating: 1, count: max(Int(testCase.shift), 0))
        input.read(channel: 0, at: input.writeIndex - 256, count: 256, into: &end)
        input.read(channel: 0, at: startIndex + 1024, count: silence.count, into: &silence)
        #expect(input.writeIndex == startIndex + 3072 + testCase.shift)
        #expect(end == createNoise(0, 2816 ..< 3072))
        #expect(silence == [Float](repeating: 0, count: silence.count))
    }

    @Test(arguments: [
        PlacementCase("gap", 500, 500),
        PlacementCase("overlap", -300, -300),
        PlacementCase("resync", 3000, 3000),
        PlacementCase("builtin resync", 3000, 3000, .builtin),
    ])
    func fadesJoins(_ testCase: PlacementCase) {
        let input = AudioMixerInput(kind: testCase.kind)
        for sampleBuffer in createSampleBuffers(2, offset: testCase.offset) {
            input.append(sampleBuffer, sampleBuffer.presentationTimeStamp)
        }
        let join = 1024 + max(Int(testCase.shift), 0)
        let first = join - Int(testCase.shift)
        var fadeOut = [Float](repeating: 0, count: 256)
        var fadeIn = [Float](repeating: 0, count: 256)
        input.read(channel: 0, at: startIndex + 768, count: 256, into: &fadeOut)
        input.read(channel: 0, at: startIndex + Int64(join), count: 256, into: &fadeIn)
        #expect(fadeOut == zip(createNoise(0, 768 ..< 1024), createFallingFade()).map(*))
        #expect(fadeIn == zip(createNoise(0, first ..< first + 256), createRisingFade()).map(*))
    }

    @Test
    func fadesInAcrossSmallBuffers() {
        let input = AudioMixerInput(kind: .buffered)
        for sampleBuffer in createSampleBuffers(3, frameLength: 100) {
            input.append(sampleBuffer, sampleBuffer.presentationTimeStamp)
        }
        var samples = [Float](repeating: 0, count: 256)
        input.read(channel: 0, at: startIndex, count: 256, into: &samples)
        #expect(samples == zip(createNoise(0, 0 ..< 256), createRisingFade()).map(*))
    }

    @Test(arguments: [97, 700, -97, -700])
    func builtinAbsorbsTimestampSteps(_ step: Int) {
        let input = AudioMixerInput(kind: .builtin)
        let sampleBuffers = createSampleBuffers(3)
        let offset = CMTime(value: CMTimeValue(step), timescale: 48000)
        input.append(sampleBuffers[0], sampleBuffers[0].presentationTimeStamp)
        input.append(sampleBuffers[1], sampleBuffers[1].presentationTimeStamp + offset)
        input.append(sampleBuffers[2], sampleBuffers[2].presentationTimeStamp)
        var samples = [Float](repeating: 0, count: 2816)
        input.read(channel: 0, at: startIndex + 256, count: 2816, into: &samples)
        #expect(samples == createNoise(0, 256 ..< 3072))
        #expect(input.writeIndex == startIndex + 3072)
        #expect(input.numberOfSlips == 0)
    }

    @Test(arguments: [200.0, -200])
    func slipsFollowTimestamps(_ ppm: Double) throws {
        let input = AudioMixerInput(kind: .builtin)
        let format = createFormat(.pcmFormatFloat32, 1, false)
        let sampleBuffers = createSampleBuffers(940, format: format, ppm: ppm, createSine)
        for sampleBuffer in sampleBuffers {
            input.append(sampleBuffer, sampleBuffer.presentationTimeStamp)
        }
        let last = try #require(sampleBuffers.last)
        let lastIndex = makeAudioMixerIndex(last.presentationTimeStamp) + 1024
        var samples = [Float](repeating: 0, count: 96000)
        input.read(channel: 0, at: input.writeIndex - 96000, count: 96000, into: &samples)
        #expect(input.numberOfResyncs == 0)
        #expect(abs(input.writeIndex - lastIndex) < 96)
        #expect(calcMaximumStep(samples) < maximumSineStep * (1 + Float.pi / 512))
    }

    @Test(arguments: [2000.0, -2000])
    func builtinDoesNotSlipSmallBuffers(_ ppm: Double) {
        let input = AudioMixerInput(kind: .builtin)
        for sampleBuffer in createSampleBuffers(400, frameLength: 256, ppm: ppm) {
            input.append(sampleBuffer, sampleBuffer.presentationTimeStamp)
        }
        var samples = [Float](repeating: 0, count: 1024)
        input.read(channel: 0, at: startIndex + 101_376, count: 1024, into: &samples)
        #expect(samples == createNoise(0, 101_376 ..< 102_400))
        #expect(input.writeIndex == startIndex + 102_400)
        #expect(input.numberOfSlips == 0)
    }

    @Test
    func gapAfterWraparoundIsSilent() {
        let input = AudioMixerInput(kind: .buffered)
        let sampleBuffers = createSampleBuffers(601)
        for sampleBuffer in sampleBuffers.dropLast() {
            input.append(sampleBuffer, sampleBuffer.presentationTimeStamp)
        }
        let last = sampleBuffers[600]
        input.append(last, last.presentationTimeStamp + CMTime(value: 500, timescale: 48000))
        var silence = [Float](repeating: 1, count: 500)
        input.read(channel: 0, at: startIndex + 600 * 1024, count: 500, into: &silence)
        #expect(silence == [Float](repeating: 0, count: 500))
        #expect(input.writeIndex == startIndex + 601 * 1024 + 500)
    }

    @Test(arguments: [AudioMixerInputKind.builtin, .buffered])
    func backwardResyncClearsRing(_ kind: AudioMixerInputKind) {
        let input = AudioMixerInput(kind: kind)
        let sampleBuffers = createSampleBuffers(601)
        for sampleBuffer in sampleBuffers.dropLast() {
            input.append(sampleBuffer, sampleBuffer.presentationTimeStamp)
        }
        let last = sampleBuffers[600]
        input.append(last, last.presentationTimeStamp - CMTime(value: 3000, timescale: 48000))
        var abandoned = [Float](repeating: 1, count: 1976)
        input.read(channel: 0, at: input.oldestIndex, count: 1976, into: &abandoned)
        #expect(abandoned == [Float](repeating: 0, count: 1976))
        #expect(input.writeIndex == startIndex + 601 * 1024 - 3000)
        #expect(input.numberOfResyncs == 1)
    }

    @Test
    func readsAcrossRingWraparound() {
        let input = AudioMixerInput(kind: .buffered)
        for sampleBuffer in createSampleBuffers(600) {
            input.append(sampleBuffer, sampleBuffer.presentationTimeStamp)
        }
        var wrapped = [Float](repeating: 0, count: 8)
        var oldest = [Float](repeating: 1, count: 8)
        input.read(channel: 0, at: (1 << 20) - 4, count: 8, into: &wrapped)
        input.read(channel: 0, at: input.oldestIndex - 4, count: 8, into: &oldest)
        #expect(input.writeIndex == startIndex + 600 * 1024)
        #expect(input.oldestIndex == startIndex + 600 * 1024 - (1 << 19))
        #expect(wrapped == createNoise(0, 568_572 ..< 568_580))
        #expect(oldest == [0, 0, 0, 0] + createNoise(0, 90112 ..< 90116))
    }

    @Test
    func readsZerosOutsideInput() {
        let input = AudioMixerInput(kind: .buffered)
        let sampleBuffer = createSampleBuffers(1)[0]
        input.append(sampleBuffer, sampleBuffer.presentationTimeStamp)
        var end = [Float](repeating: 1, count: 8)
        var missingChannel = [Float](repeating: 1, count: 8)
        input.read(channel: 0, at: startIndex + 1020, count: 8, into: &end)
        input.read(channel: 1, at: startIndex + 300, count: 8, into: &missingChannel)
        #expect(end == createNoise(0, 1020 ..< 1024) + [0, 0, 0, 0])
        #expect(missingChannel == [Float](repeating: 0, count: 8))
    }

    @Test
    func crossfadesFromFirstToSecond() {
        let ones = [Float](repeating: 1, count: audioMixerFadeFrames)
        let zeros = [Float](repeating: 0, count: audioMixerFadeFrames)
        var fadeOut = [Float](repeating: 0, count: audioMixerFadeFrames)
        var fadeIn = [Float](repeating: 0, count: audioMixerFadeFrames)
        crossfadeAudioMixerSamples(from: ones, to: zeros, output: &fadeOut)
        crossfadeAudioMixerSamples(from: zeros, to: ones, output: &fadeIn)
        #expect(fadeOut == createFallingFade())
        #expect(fadeIn == createRisingFade())
    }
}

private func createSampleBuffers(_ count: Int,
                                 format: AVAudioFormat = createFormat(.pcmFormatInt16, 1, true),
                                 frameLength: Int = 1024,
                                 offset: Int64 = 0,
                                 ppm: Double = 0,
                                 _ value: (Int, Int) -> Float = createNoise) -> [CMSampleBuffer]
{
    let start = startIndex * Int64(format.sampleRate) / 48000
    return (0 ..< count).map { index in
        var timestamp = start + Int64((Double(frameLength * index) * (1 + ppm / 1_000_000)).rounded())
        if index > 0 {
            timestamp += offset
        }
        let time = CMTime(value: timestamp, timescale: CMTimeScale(format.sampleRate))
        return createSampleBuffer(format, frameLength * index, time, frameLength: frameLength, value)
    }
}
