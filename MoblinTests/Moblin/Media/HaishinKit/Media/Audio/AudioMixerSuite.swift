import AVFoundation
@testable import Moblin
import Testing

private let startIndex: Int64 = 480_000
private let cameraId = UUID()
private let limiterLatency = makeAudioMixerLimiter()!.latency

struct AudioMixerSuite {
    struct FormatCase: CustomTestStringConvertible {
        let buffered: Bool
        let commonFormat: AVAudioCommonFormat
        let numberOfChannels: Int
        let interleaved: Bool

        var testDescription: String {
            let sampleFormat = commonFormat == .pcmFormatInt16 ? "Int16" : "Float32"
            return "\(buffered ? "buffered" : "builtin") \(sampleFormat), \(numberOfChannels) channels"
        }
    }

    struct GainCase: CustomTestStringConvertible {
        let sourceGain: Float
        let masterGain: Float
        let masterMuted: Bool
        let sends: (stream: Float, recording: Float)

        var testDescription: String {
            "gain \(sourceGain), master gain \(masterGain), muted \(masterMuted), sends \(sends)"
        }
    }

    struct DelayCase: CustomTestStringConvertible {
        let delay: Double
        let frame: Int
        let latency: Int64

        var testDescription: String {
            "\(delay) s"
        }
    }

    struct DelayChangeCase: CustomTestStringConvertible {
        let testDescription: String
        let delays: [Int: Double]
    }

    struct DelayedCase: CustomTestStringConvertible {
        let testDescription: String
        let ahead: Int64
        let lateTicks: Range<Int>
    }

    struct ChannelCase: CustomTestStringConvertible {
        let testDescription: String
        let channelsMap: [Int: Int]
        var channel: Int?
        let left: Int
        let right: Int
    }

    struct SendsCase: CustomTestStringConvertible {
        let testDescription: String
        let sends: (stream: Float, recording: Float)
        let recordingBuffer: Bool
        let stream: [Int]
        let recording: [Int]
    }

    @Test(arguments: [
        FormatCase(buffered: false, commonFormat: .pcmFormatFloat32, numberOfChannels: 2, interleaved: false),
        FormatCase(buffered: true, commonFormat: .pcmFormatInt16, numberOfChannels: 2, interleaved: true),
        FormatCase(buffered: true, commonFormat: .pcmFormatInt16, numberOfChannels: 1, interleaved: true),
    ])
    func passesThrough(_ testCase: FormatCase) {
        let mixer = AudioMixer()
        let format = createFormat(testCase.commonFormat, testCase.numberOfChannels, testCase.interleaved)
        mixer.setSources([createSettings(bufferedAudio: testCase.buffered ? cameraId : nil)])
        let output = Output()
        for tick in 0 ..< 60 {
            if testCase.buffered {
                mixer.appendBuffered(cameraId: cameraId, createSampleBuffer(format, tick))
            } else {
                mixer.appendBuiltin(createSampleBuffer(format, tick), createTime(tick))
            }
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let frames = 256 ..< output.end
        #expect(output.isContinuous)
        #expect(output.presentationTimeStamps.first == startIndex - 2400 - limiterLatency)
        #expect(output.samples(0, -2400 ..< 0) == [Float](repeating: 0, count: 2400))
        #expect(output.samples(0, frames) == createNoise(0, frames))
        #expect(output.samples(1, frames) == createNoise(testCase.numberOfChannels - 1, frames))
    }

    @Test
    func sumsSources() {
        let mixer = AudioMixer()
        let builtinFormat = createFormat(.pcmFormatFloat32, 2, false)
        let bufferedFormat = createFormat(.pcmFormatInt16, 2, true)
        mixer.setSources([
            createSettings(id: "builtin"),
            createSettings(id: "buffered", bufferedAudio: cameraId, gain: 0.25),
        ])
        let output = Output()
        for tick in 0 ..< 40 {
            mixer.appendBuiltin(createSampleBuffer(builtinFormat, tick), createTime(tick))
            mixer.appendBuffered(
                cameraId: cameraId,
                createSampleBuffer(bufferedFormat, tick) { createNoise($0 + 2, $1) }
            )
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let frames = 256 ..< output.end
        let left = zip(createNoise(0, frames), createNoise(2, frames)).map { $0 + 0.25 * $1 }
        let right = zip(createNoise(1, frames), createNoise(3, frames)).map { $0 + 0.25 * $1 }
        #expect(output.isContinuous)
        #expect(output.samples(0, frames) == left)
        #expect(output.samples(1, frames) == right)
    }

    @Test(arguments: [
        GainCase(sourceGain: 0.25, masterGain: 1, masterMuted: false, sends: (1, 1)),
        GainCase(sourceGain: 1, masterGain: 0.25, masterMuted: false, sends: (1, 0)),
        GainCase(sourceGain: 1, masterGain: 1, masterMuted: true, sends: (1, 1)),
        GainCase(sourceGain: 1, masterGain: 1, masterMuted: false, sends: (1, 0)),
        GainCase(sourceGain: 1, masterGain: 1, masterMuted: false, sends: (0, 1)),
    ], [false, true])
    func rampsGainChanges(_ testCase: GainCase, _ recording: Bool) {
        let mixer = AudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings()])
        let output = Output()
        for tick in 0 ..< 40 {
            if tick == 10 {
                mixer.setMasterGain(testCase.masterGain)
                mixer.setMasterMuted(testCase.masterMuted)
            } else if tick == 20 {
                mixer.setSources([createSettings(gain: testCase.sourceGain, sends: testCase.sends)])
            }
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, _ in 0.5 }, createTime(tick))
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block, recording: recording)
            }
        }
        let send = recording ? testCase.sends.recording : testCase.sends.stream
        let gain = testCase.masterMuted ? 0 : 0.5 * testCase.sourceGain * testCase.masterGain * send
        let samples = output.samples(1, 4096 ..< output.end)
        #expect(output.isContinuous)
        #expect(output.presentationTimeStamps.count == 40)
        #expect(samples.first == 0.5)
        #expect(samples.last == gain)
        #expect(calcMaximumStep(samples) < (0.5 - gain) / 1024 + 1e-6)
    }

    @Test(arguments: [
        DelayCase(delay: 0, frame: 30000, latency: 2400),
        DelayCase(delay: 0.0001, frame: 30005, latency: 2400),
        DelayCase(delay: 2, frame: 126_000, latency: 2400),
        DelayCase(delay: -0.2, frame: 20400, latency: 12000),
        DelayCase(delay: -0.5, frame: 6000, latency: 26400),
    ])
    func delaysContent(_ testCase: DelayCase) {
        let mixer = AudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings(delay: testCase.delay)])
        let output = Output()
        for tick in 0 ..< 130 {
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, frame in frame == 30000 ? 0.5 : 0 },
                                createTime(tick))
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        #expect(mixer.latency == testCase.latency)
        #expect(output.isContinuous)
        #expect(output.presentationTimeStamps.first == startIndex - testCase.latency - limiterLatency)
        #expect(output.frames { $0 != 0 } == [testCase.frame])
        #expect(output.samples(0, testCase.frame ..< testCase.frame + 1) == [0.5])
        #expect(output.samples(1, testCase.frame ..< testCase.frame + 1) == [0.5])
    }

    @Test
    func negativeDelayPausesDelivery() {
        let mixer = AudioMixer()
        let format = createFormat(.pcmFormatFloat32, 2, false)
        mixer.setSources([createSettings()])
        let output = Output()
        var blocksPerTick: [Int] = []
        for tick in 0 ..< 60 {
            if tick == 20 {
                mixer.setSources([createSettings(delay: -0.2)])
            } else if tick == 40 {
                mixer.setSources([createSettings()])
            }
            mixer.appendBuiltin(createSampleBuffer(format, tick), createTime(tick))
            var blocks = 0
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
                blocks += 1
            }
            blocksPerTick.append(blocks)
        }
        let early = 20 * 1024 - 2400 + 256 ..< 30 * 1024 - 2400
        let late = 30 * 1024 - 2400 + 256 ..< output.end
        let earlyContent = createNoise(0, early.lowerBound + 9600 ..< early.upperBound + 9600)
        #expect(mixer.latency == 2400)
        #expect(output.isContinuous)
        #expect(output.presentationTimeStamps.count == 60)
        #expect(blocksPerTick[20 ..< 30].allSatisfy { $0 == 0 })
        #expect(output.samples(0, early) == earlyContent)
        #expect(output.samples(1, late) == createNoise(1, late))
    }

    @Test(arguments: [
        DelayChangeCase(testDescription: "half a period", delays: [20: 0.0105]),
        DelayChangeCase(
            testDescription: "slider drag",
            delays: Dictionary(uniqueKeysWithValues: (20 ..< 40).map { ($0, Double($0 - 19) * 0.0123) })
        ),
    ], [false, true])
    func delayChangesCrossfade(_ testCase: DelayChangeCase, _ voice: Bool) throws {
        let mixer = AudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings(voice: voice)])
        let output = Output()
        for tick in 0 ..< 80 {
            if let delay = testCase.delays[tick] {
                mixer.setSources([createSettings(delay: delay, voice: voice)])
            }
            mixer.appendBuiltin(createSampleBuffer(format, tick, createSine), createTime(tick))
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let samples = output.samples(0, 2048 ..< output.end)
        let peak = try #require(samples.map { abs($0) }.max())
        #expect(output.isContinuous)
        #expect(voice || peak <= 0.5)
        #expect(calcMaximumStep(samples) < peak * (2 * maximumSineStep + 2 * Float.pi / 512))
    }

    @Test
    func delayChangesSeekOnceToNewest() {
        let mixer = AudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings()])
        let output = Output()
        for tick in 0 ..< 40 {
            if tick == 20 {
                mixer.setSources([createSettings(delay: 0.0123)])
                mixer.setSources([createSettings(delay: 0.0246)])
                mixer.setSources([createSettings(delay: 0.0369)])
            }
            mixer.appendBuiltin(createSampleBuffer(format, tick, createSine), createTime(tick))
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let seek = 20 * 1024 - 2400
        let frames = seek + 256 ..< output.end
        let crossfade = output.samples(0, seek - 1 ..< seek + 257)
        let delayed = createSine(frames.lowerBound - 1771 ..< frames.upperBound - 1771)
        #expect(output.isContinuous)
        #expect(output.samples(0, 256 ..< seek) == createSine(256 ..< seek))
        #expect(output.samples(0, frames) == delayed)
        #expect(calcMaximumStep(crossfade) < maximumSineStep + Float.pi / 512)
    }

    @Test
    func delayChangeToUnwrittenInputFadesOut() {
        let mixer = AudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings()])
        let output = Output()
        for tick in 0 ..< 60 {
            if tick < 20 {
                mixer.appendBuiltin(createSampleBuffer(format, tick) { _, _ in 0.5 }, createTime(tick))
            }
            if tick == 20 {
                mixer.setSources([createSettings(delay: -0.2)])
            }
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let end = 20 * 1024
        #expect(output.isContinuous)
        #expect(output.samples(0, 4096 ..< end - 256).allSatisfy { $0 == 0.5 })
        #expect(output.samples(0, end - 256 ..< end) == createFallingFade().map { 0.5 * $0 })
        #expect(output.samples(0, end ..< output.end).allSatisfy { $0 == 0 })
    }

    @Test
    func channelsMapChangeCrossfades() {
        let mixer = AudioMixer()
        let format = createFormat(.pcmFormatFloat32, 2, false)
        mixer.setSources([createSettings(channelsMap: [0: 0, 1: 0])])
        let output = Output()
        for tick in 0 ..< 40 {
            if tick == 20 {
                mixer.setSources([createSettings(channelsMap: [0: 1, 1: 1])])
            }
            mixer.appendBuiltin(createSampleBuffer(format, tick) { channel, _ in channel == 0 ? 0.5 : 0.25 },
                                createTime(tick))
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let samples = output.samples(1, 4096 ..< output.end)
        #expect(output.isContinuous)
        #expect(samples.first == 0.5)
        #expect(samples.last == 0.25)
        #expect(calcMaximumStep(samples) < 0.25 / 1024 + 1e-6)
        #expect(mixer.sources.count == 1)
    }

    @Test
    func removedSourcesFadeOut() {
        let mixer = AudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([
            createSettings(id: "builtin"),
            createSettings(id: "buffered", bufferedAudio: cameraId),
        ])
        let output = Output()
        for tick in 0 ..< 50 {
            if tick == 20 {
                mixer.setSources([createSettings(id: "builtin")])
            } else if tick == 30 {
                mixer.setSources([])
            }
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, _ in 0.25 }, createTime(tick))
            mixer.appendBuffered(cameraId: cameraId, createSampleBuffer(format, tick) { _, _ in 0.5 })
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let samples = output.samples(0, 4096 ..< output.end)
        #expect(output.isContinuous)
        #expect(output.presentationTimeStamps.count == 50)
        #expect(samples.first == 0.75)
        #expect(output.samples(0, 20 * 1024 ..< 27 * 1024).allSatisfy { $0 == 0.25 })
        #expect(samples.suffix(15 * 1024).allSatisfy { $0 == 0 })
        #expect(calcMaximumStep(samples) < 0.5 / 1024 + 1e-6)
        #expect(mixer.sources.isEmpty)
        #expect(mixer.builtinInput == nil)
        #expect(mixer.bufferedInputs.isEmpty)
    }

    @Test
    func replacedSourceDoesNotReplay() {
        let mixer = AudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings(id: "usb")])
        let output = Output()
        for tick in 0 ..< 160 {
            if tick == 60 {
                mixer.setSources([createSettings(id: "builtin", delay: 1.5)])
            }
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, frame in
                frame == 30000 || frame == 70000 ? 0.5 : 0
            }, createTime(tick))
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        #expect(output.isContinuous)
        #expect(output.frames { $0 != 0 } == [30000, 142_000])
        #expect(output.samples(0, 142_000 ..< 142_001) == [0.5])
    }

    @Test(arguments: [600, 672, 928])
    func stalledSourceFadesOut(_ lastFrameLength: Int) {
        let mixer = AudioMixer()
        let format = createFormat(.pcmFormatFloat32, 2, false)
        mixer.setSources([createSettings()])
        let output = Output()
        for tick in 0 ..< 40 {
            if tick < 20 {
                let frameLength = tick == 19 ? lastFrameLength : 1024
                let sampleBuffer = createSampleBuffer(format, tick, frameLength: frameLength) { _, _ in 0.5 }
                mixer.appendBuiltin(sampleBuffer, createTime(tick))
            }
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let end = 19 * 1024 + lastFrameLength
        #expect(output.isContinuous)
        #expect(output.presentationTimeStamps.count == 40)
        #expect(output.samples(0, 4096 ..< end - 256).allSatisfy { $0 == 0.5 })
        #expect(output.samples(0, end - 256 ..< end) == createFallingFade().map { 0.5 * $0 })
        #expect(output.samples(1, end ..< output.end).allSatisfy { $0 == 0 })
    }

    @Test
    func backwardResyncSilencesSource() {
        let mixer = AudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings()])
        let output = Output()
        for tick in 0 ..< 40 {
            let early = CMTime(value: tick == 20 ? 3300 : 0, timescale: 48000)
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, _ in 0.5 }, createTime(tick) - early)
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let cut = 20 * 1024 - 2400
        let resync = 21 * 1024
        #expect(output.isContinuous)
        #expect(output.samples(0, 4096 ..< cut).allSatisfy { $0 == 0.5 })
        #expect(output.samples(0, cut ..< resync).allSatisfy { $0 == 0 })
        #expect(output.samples(0, resync ..< resync + 256) == createRisingFade().map { 0.5 * $0 })
        #expect(output.samples(0, resync + 256 ..< output.end).allSatisfy { $0 == 0.5 })
    }

    @Test(arguments: [false, true])
    func stalledSourceFadesBackIn(_ lateInput: Bool) {
        let mixer = AudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings()])
        let output = Output()
        for tick in 0 ..< 50 {
            if tick < 20 || tick >= 30 {
                mixer.appendBuiltin(createSampleBuffer(format, tick) { _, _ in 0.5 }, createTime(tick))
            } else if lateInput, tick == 29 {
                for lateTick in 20 ..< 30 {
                    mixer.appendBuiltin(createSampleBuffer(format, lateTick) { _, _ in 0.5 },
                                        createTime(lateTick))
                }
            }
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let samples = output.samples(0, 4096 ..< output.end)
        #expect(output.isContinuous)
        #expect(samples.contains(0))
        #expect(samples.suffix(5 * 1024).allSatisfy { $0 == 0.5 })
        #expect(calcMaximumStep(samples) < 0.5 * Float.pi / 512 + 1e-6)
    }

    @Test
    func skipsForwardWhenOneSecondBehind() {
        let mixer = AudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings()])
        let output = Output()
        var blocksPerTick: [Int] = []
        for tick in 0 ..< 100 {
            mixer.appendBuiltin(createSampleBuffer(format, tick, createSine), createTime(tick))
            guard tick < 20 || tick >= 90 else {
                continue
            }
            var blocks = 0
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
                blocks += 1
            }
            blocksPerTick.append(blocks)
        }
        let steps = zip(output.presentationTimeStamps, output.presentationTimeStamps.dropFirst())
            .map { $1 - $0 }
        let skipped = 91 * 1024 - 3424
        let latency = Int(limiterLatency)
        let samples = Array(output.left.suffix(10 * 1024))
        let fade = skipped ..< skipped + 256
        let frames = skipped + 256 ..< skipped + 10 * 1024 - latency
        #expect(blocksPerTick.allSatisfy { $0 == 1 })
        #expect(steps.filter { $0 != 1024 } == [Int64(71 * 1024)])
        #expect(output.presentationTimeStamps[20] == startIndex + Int64(skipped) - limiterLatency)
        #expect(mixer.numberOfSkips == 1)
        #expect(samples.prefix(latency).allSatisfy { $0 == 0 })
        #expect(Array(samples[latency ..< latency + 256]) == zip(createSine(fade), createRisingFade()).map(*))
        #expect(samples.suffix(frames.count) == createSine(frames))
    }

    @Test(arguments: [
        DelayedCase(testDescription: "across a late tick", ahead: 0, lateTicks: 150 ..< 160),
        DelayedCase(testDescription: "written 4 s ahead", ahead: 192_000, lateTicks: 0 ..< 0),
    ])
    func delayedInputIsKept(_ testCase: DelayedCase) {
        let mixer = AudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([
            createSettings(id: "delayed", bufferedAudio: cameraId, delay: 2),
            createSettings(id: "early", delay: -0.5),
        ])
        let output = Output()
        for tick in 0 ..< 320 {
            let presentationTimeStamp = createTime(tick) + CMTime(value: testCase.ahead, timescale: 48000)
            let sampleBuffer = createSampleBuffer(format, 1024 * tick, presentationTimeStamp) { _, _ in 0.5 }
            mixer.appendBuffered(cameraId: cameraId, sampleBuffer)
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, _ in 0 }, createTime(tick))
            guard !testCase.lateTicks.contains(tick) else {
                continue
            }
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let start = 96000 + Int(testCase.ahead)
        #expect(mixer.latency == 26400)
        #expect(output.isContinuous)
        #expect(output.samples(0, -26400 ..< start).allSatisfy { $0 == 0 })
        #expect(output.samples(0, start + 256 ..< output.end).allSatisfy { $0 == 0.5 })
        #expect(mixer.numberOfSkips == 0)
    }

    @Test
    func overwrittenInputIsSilent() {
        let mixer = AudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings(delay: 2)])
        let output = Output()
        for tick in 0 ..< 250 {
            let ahead = CMTime(value: tick < 150 ? 0 : 432_000, timescale: 48000)
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, _ in 0.5 }, createTime(tick) + ahead)
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let overwritten = 150 * 1024 - 2400
        #expect(output.isContinuous)
        #expect(output.samples(0, 96256 ..< overwritten).allSatisfy { $0 == 0.5 })
        #expect(output.samples(0, overwritten ..< output.end).allSatisfy { $0 == 0 })
    }

    @Test(arguments: [
        ChannelCase(testDescription: "channels 3 and 4", channelsMap: [0: 2, 1: 3], left: 2, right: 3),
        ChannelCase(testDescription: "channel 2 on both sides", channelsMap: [0: 1, 1: 1], left: 1, right: 1),
        ChannelCase(testDescription: "silent left", channelsMap: [0: -1, 1: 2], left: -1, right: 2),
        ChannelCase(testDescription: "missing device channels", channelsMap: [0: 4, 1: 7], left: 0, right: 1),
        ChannelCase(testDescription: "channel mic 3", channelsMap: [:], channel: 2, left: 2, right: 2),
        ChannelCase(testDescription: "missing channel 5", channelsMap: [:], channel: 4, left: -1, right: -1),
    ])
    func picksChannels(_ testCase: ChannelCase) {
        let mixer = AudioMixer()
        let format = createFormat(.pcmFormatFloat32, 4, false)
        mixer.setSources([createSettings(channelsMap: testCase.channelsMap, channel: testCase.channel)])
        let output = Output()
        for tick in 0 ..< 20 {
            mixer.appendBuiltin(createSampleBuffer(format, tick), createTime(tick))
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let frames = 256 ..< output.end
        #expect(output.samples(0, frames) == createNoise(testCase.left, frames))
        #expect(output.samples(1, frames) == createNoise(testCase.right, frames))
    }

    @Test
    func sharesOneInputPerDevice() {
        let mixer = AudioMixer()
        mixer.setSources([
            createSettings(id: "1", channelsMap: [0: 0, 1: 0]),
            createSettings(id: "2", channelsMap: [0: 1, 1: 1]),
            createSettings(id: "3", bufferedAudio: cameraId, channelsMap: [0: 0, 1: 0]),
            createSettings(id: "4", bufferedAudio: cameraId, channelsMap: [0: 1, 1: 1]),
        ])
        #expect(mixer.sources.count == 4)
        #expect(mixer.builtinInput != nil)
        #expect(Array(mixer.bufferedInputs.keys) == [cameraId])
    }

    @Test
    func voiceLatencyIsCompensated() throws {
        let effects = makeAudioMixerVoiceEffects()
        try #require(effects.count == 2)
        let mixer = AudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([
            createSettings(id: "dry"),
            createSettings(id: "voice", bufferedAudio: cameraId, delay: -0.1, voice: true),
        ])
        let output = Output()
        for tick in 0 ..< 60 {
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, frame in frame == 30000 ? 0.5 : 0 },
                                createTime(tick))
            mixer.appendBuffered(
                cameraId: cameraId,
                createSampleBuffer(format, tick) { _, frame in frame == 44800 ? 0.5 : 0 }
            )
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let voice = output.samples(0, 35000 ..< 45000).map { abs($0) }
        #expect(mixer.latency == 2400 + 4800 + effects.reduce(0) { $0 + $1.latency })
        #expect(output.isContinuous)
        #expect(output.frames { $0 != 0 }.filter { $0 < 35000 } == [30000])
        #expect(output.samples(0, 30000 ..< 30001) == [0.5])
        #expect(try voice.firstIndex(of: #require(voice.max())) == 5000)
    }

    @Test
    func voiceStartsWithoutClick() throws {
        let mixer = AudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings()])
        let output = Output()
        for tick in 0 ..< 80 {
            if tick == 20 {
                mixer.setSources([createSettings(voice: true)])
            }
            if tick < 40 || tick >= 50 {
                mixer.appendBuiltin(createSampleBuffer(format, tick, createSine), createTime(tick))
            } else if tick == 49 {
                for lateTick in 40 ..< 50 {
                    mixer.appendBuiltin(
                        createSampleBuffer(format, lateTick, createSine),
                        createTime(lateTick)
                    )
                }
            }
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block)
            }
        }
        let samples = output.samples(0, 4096 ..< output.end)
        let peak = try #require(samples.map { abs($0) }.max())
        #expect(output.isContinuous)
        #expect(samples.contains(0))
        #expect(try #require(output.samples(0, 60 * 1024 ..< output.end).map { abs($0) }.max()) > 0.1)
        #expect(calcMaximumStep(samples) < peak * (2 * maximumSineStep + Float.pi / 512))
        #expect(mixer.sources.count == 1)
    }

    @Test(arguments: [
        SendsCase(testDescription: "stream and recording",
                  sends: (1, 1),
                  recordingBuffer: false,
                  stream: [30000, 31000],
                  recording: [30000, 31000]),
        SendsCase(testDescription: "stream",
                  sends: (1, 0),
                  recordingBuffer: true,
                  stream: [30000, 31000],
                  recording: [30000]),
        SendsCase(testDescription: "recording",
                  sends: (0, 1),
                  recordingBuffer: true,
                  stream: [30000],
                  recording: [30000, 31000]),
    ])
    func sendsToBuses(_ testCase: SendsCase) {
        let mixer = AudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([
            createSettings(id: "voice"),
            createSettings(id: "music", bufferedAudio: cameraId, sends: testCase.sends),
        ])
        let stream = Output()
        let recording = Output()
        var recordingTimeStamps: [Int64] = []
        for tick in 0 ..< 40 {
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, frame in frame == 30000 ? 0.5 : 0 },
                                createTime(tick))
            mixer.appendBuffered(
                cameraId: cameraId,
                createSampleBuffer(format, tick) { _, frame in frame == 31000 ? 0.5 : 0 }
            )
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                stream.append(block)
                recording.append(block, recording: true)
                if block.recordingBuffer != nil {
                    recordingTimeStamps.append(block.presentationTimeStamp.value)
                }
            }
        }
        #expect(stream.frames { $0 != 0 } == testCase.stream)
        #expect(recording.frames { $0 != 0 } == testCase.recording)
        #expect(recordingTimeStamps == (testCase.recordingBuffer ? stream.presentationTimeStamps : []))
    }

    @Test
    func sendsChangeBackWithoutClick() {
        let mixer = AudioMixer()
        let format = createFormat(.pcmFormatFloat32, 1, false)
        mixer.setSources([createSettings(sends: (1, 0))])
        let output = Output()
        var numberOfRecordingBuffers = 0
        for tick in 0 ..< 40 {
            if tick == 20 {
                mixer.setSources([createSettings()])
            }
            mixer.appendBuiltin(createSampleBuffer(format, tick) { _, _ in 0.5 }, createTime(tick))
            while let block = mixer.renderNextBlock(now: createTime(tick + 1)) {
                output.append(block, recording: true)
                if block.recordingBuffer != nil {
                    numberOfRecordingBuffers += 1
                }
            }
        }
        let samples = output.samples(0, 4096 ..< output.end)
        #expect(samples.first == 0)
        #expect(samples.last == 0.5)
        #expect(calcMaximumStep(samples) < 0.5 / 1024 + 1e-6)
        #expect(numberOfRecordingBuffers == 22)
    }
}

private final class Output {
    private(set) var presentationTimeStamps: [Int64] = []
    private(set) var left: [Float] = []
    private(set) var right: [Float] = []
    private var timescales: Set<CMTimeScale> = []

    var isContinuous: Bool {
        timescales == [48000]
            && zip(presentationTimeStamps, presentationTimeStamps.dropFirst()).allSatisfy { $1 - $0 == 1024 }
    }

    var end: Int {
        left.count - offset
    }

    private var offset: Int {
        Int(startIndex - (presentationTimeStamps.first ?? startIndex))
    }

    func append(
        _ block: (
            presentationTimeStamp: CMTime,
            buffer: AVAudioPCMBuffer,
            recordingBuffer: AVAudioPCMBuffer?
        ),
        recording: Bool = false
    ) {
        presentationTimeStamps.append(block.presentationTimeStamp.value)
        timescales.insert(block.presentationTimeStamp.timescale)
        let buffer = recording ? block.recordingBuffer ?? block.buffer : block.buffer
        let count = Int(buffer.frameLength)
        left += UnsafeBufferPointer(start: buffer.floatChannelData![0], count: count)
        right += UnsafeBufferPointer(start: buffer.floatChannelData![1], count: count)
    }

    func samples(_ channel: Int, _ frames: Range<Int>) -> [Float] {
        Array((channel == 0 ? left : right)[frames.lowerBound + offset ..< frames.upperBound + offset])
    }

    func frames(where predicate: (Float) -> Bool) -> [Int] {
        left.indices.filter { predicate(left[$0]) }.map { $0 - offset }
    }
}

private func createSettings(id: String = "mic",
                            bufferedAudio: UUID? = nil,
                            channelsMap: [Int: Int] = [0: 0, 1: 1],
                            channel: Int? = nil,
                            gain: Float = 1,
                            delay: Double = 0,
                            voice: Bool = false,
                            sends: (stream: Float, recording: Float) = (1, 1)) -> AudioMixerSourceSettings
{
    AudioMixerSourceSettings(id: id,
                             bufferedAudio: bufferedAudio,
                             channelsMap: channelsMap,
                             channel: channel,
                             gain: gain,
                             delay: delay,
                             voice: voice,
                             sends: sends)
}

private func createTime(_ tick: Int) -> CMTime {
    CMTime(value: startIndex + Int64(1024 * tick), timescale: 48000)
}

private func createSampleBuffer(_ format: AVAudioFormat,
                                _ tick: Int,
                                frameLength: Int = 1024,
                                _ value: (Int, Int) -> Float = createNoise) -> CMSampleBuffer
{
    createSampleBuffer(format, 1024 * tick, createTime(tick), frameLength: frameLength, value)
}
