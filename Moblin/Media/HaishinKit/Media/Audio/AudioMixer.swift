import Accelerate
import AVFoundation

let audioMixerFramesPerBlock = 1024
private let minimumLatency: Int64 = 2400

struct AudioMixerSourceSettings {
    let id: String
    let bufferedAudio: UUID?
    let channelsMap: [Int: Int]
    let gain: Float
    let delay: Double
}

final class AudioMixerSource {
    let id: String
    let bufferedAudio: UUID?
    private(set) var delay: Int64 = 0
    private(set) var isRemoved = false
    private let startIndex: Int64
    private let channelsMap: [Int: Int]
    private var gain: Float = 0
    private var currentGain: Float = 0
    private var currentDelay: Int64 = 0
    private var numberOfInputChannels = -1
    private var leftChannel = -1
    private var rightChannel = -1
    private var isSilent = true
    private let left = makeAudioMixerSamples(count: audioMixerFramesPerBlock)
    private let right = makeAudioMixerSamples(count: audioMixerFramesPerBlock)
    private let previousLeft = makeAudioMixerSamples(count: audioMixerFadeFrames)
    private let previousRight = makeAudioMixerSamples(count: audioMixerFadeFrames)

    init(settings: AudioMixerSourceSettings, startIndex: Int64) {
        id = settings.id
        bufferedAudio = settings.bufferedAudio
        self.startIndex = startIndex
        channelsMap = settings.channelsMap
        update(settings: settings)
        currentDelay = delay
    }

    deinit {
        left.deallocate()
        right.deallocate()
        previousLeft.deallocate()
        previousRight.deallocate()
    }

    private var isStereo: Bool {
        leftChannel != rightChannel
    }

    func isSame(_ settings: AudioMixerSourceSettings) -> Bool {
        !isRemoved
            && id == settings.id
            && bufferedAudio == settings.bufferedAudio
            && channelsMap == settings.channelsMap
    }

    func update(settings: AudioMixerSourceSettings) {
        gain = settings.gain
        delay = Int64((settings.delay * audioMixerSampleRate).rounded())
    }

    func remove() {
        isRemoved = true
    }

    func reset() {
        isSilent = true
    }

    func render(_ input: AudioMixerInput, _ blockStart: Int64, _ bus: AudioMixerBus) {
        let startGain = currentGain
        let previousDelay = currentDelay
        currentGain = isRemoved ? 0 : gain
        guard startGain != 0 || currentGain != 0 else {
            isSilent = true
            return
        }
        if input.numberOfChannels != numberOfInputChannels {
            configure(input.numberOfChannels)
        }
        let lookahead = audioMixerFramesPerBlock + audioMixerFadeFrames
        var delay = delay
        if !isSilent, input.writeIndex - (blockStart - delay) < Int64(lookahead) {
            delay = previousDelay
        }
        currentDelay = delay
        let index = blockStart - delay
        let end = Int(min(max(input.writeIndex - index, 0), Int64(lookahead)))
        let isOverwritten = index < input.oldestIndex
        if isOverwritten, !isSilent {
            logger.debug("audio-mixer: Source \(id) input overwritten")
            isSilent = true
        }
        if isSilent {
            guard end == lookahead, !isOverwritten, index >= startIndex else {
                return
            }
            read(input, index, audioMixerFramesPerBlock, left, right)
            if startGain != 0 {
                fadeIn()
            }
            isSilent = false
        } else {
            read(input, index, audioMixerFramesPerBlock, left, right)
            if previousDelay != delay {
                seek(input, blockStart - previousDelay)
            }
            if end < lookahead {
                logger.debug("audio-mixer: Source \(id) stalled")
                fadeOut(min(end, audioMixerFramesPerBlock))
                isSilent = true
            }
        }
        send(to: bus, startGain)
    }

    private func configure(_ numberOfInputChannels: Int) {
        self.numberOfInputChannels = numberOfInputChannels
        leftChannel = pickChannel(0)
        rightChannel = pickChannel(1)
        isSilent = true
    }

    private func pickChannel(_ outputChannel: Int) -> Int {
        if let inputChannel = channelsMap[outputChannel], inputChannel < numberOfInputChannels {
            inputChannel
        } else {
            min(outputChannel, numberOfInputChannels - 1)
        }
    }

    private func read(_ input: AudioMixerInput,
                      _ index: Int64,
                      _ count: Int,
                      _ left: UnsafeMutablePointer<Float>,
                      _ right: UnsafeMutablePointer<Float>)
    {
        input.read(channel: leftChannel, at: index, count: count, into: left)
        if isStereo {
            input.read(channel: rightChannel, at: index, count: count, into: right)
        }
    }

    private func seek(_ input: AudioMixerInput, _ previousIndex: Int64) {
        read(input, previousIndex, audioMixerFadeFrames, previousLeft, previousRight)
        crossfadeAudioMixerSamples(from: previousLeft, to: left, output: previousLeft)
        left.update(from: previousLeft, count: audioMixerFadeFrames)
        if isStereo {
            crossfadeAudioMixerSamples(from: previousRight, to: right, output: previousRight)
            right.update(from: previousRight, count: audioMixerFadeFrames)
        }
    }

    private func fadeIn() {
        fadeInAudioMixerSamples(samples: left, position: 0, count: audioMixerFadeFrames)
        if isStereo {
            fadeInAudioMixerSamples(samples: right, position: 0, count: audioMixerFadeFrames)
        }
    }

    private func fadeOut(_ end: Int) {
        fadeOutBlock(left, end)
        if isStereo {
            fadeOutBlock(right, end)
        }
    }

    private func fadeOutBlock(_ samples: UnsafeMutablePointer<Float>, _ end: Int) {
        guard end >= audioMixerFadeFrames else {
            samples.update(repeating: 0, count: audioMixerFramesPerBlock)
            return
        }
        let fadeStart = end - audioMixerFadeFrames
        fadeOutAudioMixerSamples(samples: samples + fadeStart, position: 0, count: audioMixerFadeFrames)
        (samples + end).update(repeating: 0, count: audioMixerFramesPerBlock - end)
    }

    private func send(to bus: AudioMixerBus, _ startGain: Float) {
        var gain = startGain
        var step = (currentGain - startGain) / Float(audioMixerFramesPerBlock)
        let frames = vDSP_Length(audioMixerFramesPerBlock)
        vDSP_vrampmuladd2(left, isStereo ? right : left, 1, &gain, &step, bus.left, bus.right, 1, frames)
    }
}

final class AudioMixerBus {
    let buffer: AVAudioPCMBuffer
    let left: UnsafeMutablePointer<Float>
    let right: UnsafeMutablePointer<Float>
    private var gain: Float = 1
    private var targetGain: Float = 1
    private var isMuted = false
    private let limiter = makeAudioMixerLimiter()

    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: audioMixerSampleRate, channels: 2)!
        let frames = AVAudioFrameCount(audioMixerFramesPerBlock)
        buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = buffer.frameCapacity
        left = buffer.floatChannelData![0]
        right = buffer.floatChannelData![1]
    }

    var latency: Int64 {
        limiter?.latency ?? 0
    }

    func setGain(_ gain: Float) {
        targetGain = gain
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
    }

    func clear() {
        vDSP_vclr(left, 1, vDSP_Length(audioMixerFramesPerBlock))
        vDSP_vclr(right, 1, vDSP_Length(audioMixerFramesPerBlock))
    }

    func reset() {
        limiter?.reset()
    }

    func finish() {
        let endGain = isMuted ? 0 : targetGain
        var step = (endGain - gain) / Float(audioMixerFramesPerBlock)
        let frames = vDSP_Length(audioMixerFramesPerBlock)
        vDSP_vrampmul2(left, right, 1, &gain, &step, left, right, 1, frames)
        gain = endGain
        limiter?.process(left, right)
        var low: Float = -1
        var high: Float = 1
        vDSP_vclip(left, 1, &low, &high, left, 1, frames)
        vDSP_vclip(right, 1, &low, &high, right, 1, frames)
    }
}

final class AudioMixer {
    private(set) var sources: [AudioMixerSource] = []
    private(set) var builtinInput: AudioMixerInput?
    private(set) var bufferedInputs: [UUID: AudioMixerInput] = [:]
    private(set) var latency = minimumLatency
    private(set) var numberOfSkips = 0
    private let bus = AudioMixerBus()
    private var nextBlockStart: Int64?

    func setSources(_ settings: [AudioMixerSourceSettings]) {
        for source in sources where !settings.contains(where: source.isSame) {
            source.remove()
        }
        for setting in settings {
            if let source = sources.first(where: { $0.isSame(setting) }) {
                source.update(settings: setting)
            } else {
                let startIndex = makeStartIndex(setting.bufferedAudio)
                sources.append(AudioMixerSource(settings: setting, startIndex: startIndex))
            }
        }
        updateInputs()
    }

    func setMasterGain(_ gain: Float) {
        bus.setGain(gain)
    }

    func setMasterMuted(_ muted: Bool) {
        bus.setMuted(muted)
    }

    func appendBuiltin(_ sampleBuffer: CMSampleBuffer, _ presentationTimeStamp: CMTime) {
        builtinInput?.append(sampleBuffer, presentationTimeStamp)
    }

    func appendBuffered(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        bufferedInputs[cameraId]?.append(sampleBuffer, sampleBuffer.presentationTimeStamp)
    }

    func renderNextBlock(now: CMTime) -> (presentationTimeStamp: CMTime, buffer: AVAudioPCMBuffer)? {
        let frames = Int64(audioMixerFramesPerBlock)
        let due = makeAudioMixerIndex(now) - latency - frames
        var blockStart = nextBlockStart ?? due
        guard blockStart <= due else {
            return nil
        }
        if due - blockStart > Int64(audioMixerSampleRate) {
            logger.info("audio-mixer: Skipping \(due - blockStart) frames")
            numberOfSkips += 1
            blockStart = due
            bus.reset()
            for source in sources {
                source.reset()
            }
        }
        render(blockStart)
        nextBlockStart = blockStart + frames
        let presentationTimeStamp = blockStart - bus.latency
        return (
            CMTime(value: presentationTimeStamp, timescale: CMTimeScale(audioMixerSampleRate)),
            bus.buffer
        )
    }

    private func render(_ blockStart: Int64) {
        bus.clear()
        for source in sources {
            if let input = input(source.bufferedAudio) {
                source.render(input, blockStart, bus)
            }
        }
        bus.finish()
        if sources.contains(where: \.isRemoved) {
            sources.removeAll { $0.isRemoved }
            updateInputs()
        }
    }

    private func makeStartIndex(_ bufferedAudio: UUID?) -> Int64 {
        guard let nextBlockStart, let input = input(bufferedAudio) else {
            return .min
        }
        return sources
            .filter { $0.isRemoved && $0.bufferedAudio == bufferedAudio }
            .map { nextBlockStart - $0.delay }
            .max() ?? input.writeIndex
    }

    private func input(_ bufferedAudio: UUID?) -> AudioMixerInput? {
        if let bufferedAudio {
            bufferedInputs[bufferedAudio]
        } else {
            builtinInput
        }
    }

    private func updateInputs() {
        if !sources.contains(where: { $0.bufferedAudio == nil }) {
            builtinInput = nil
        } else if builtinInput == nil {
            builtinInput = AudioMixerInput(kind: .builtin)
        }
        bufferedInputs = bufferedInputs.filter { cameraId, _ in
            sources.contains { $0.bufferedAudio == cameraId }
        }
        for case let cameraId? in sources.map(\.bufferedAudio) where bufferedInputs[cameraId] == nil {
            bufferedInputs[cameraId] = AudioMixerInput(kind: .buffered)
        }
        let latency = minimumLatency - min(sources.map(\.delay).min() ?? 0, 0)
        if latency != self.latency {
            logger.debug("audio-mixer: Latency \(latency) frames")
            self.latency = latency
        }
    }
}
