import AVFoundation
import Collections

private let deltaLimit = 0.03
var audioUnitRemoveWindNoise = false

struct AudioUnitAttachParams {
    var device: AVCaptureDevice?
    var builtinDelay: Double
    var bufferedAudio: UUID?
}

func makeChannelMap(
    numberOfInputChannels: Int,
    numberOfOutputChannels: Int,
    outputToInputChannelsMap: [Int: Int]
) -> [NSNumber] {
    var channelMap = Array(repeating: -1, count: numberOfOutputChannels)
    for inputIndex in 0 ..< min(numberOfInputChannels, numberOfOutputChannels) {
        channelMap[inputIndex] = inputIndex
    }
    for outputIndex in 0 ..< numberOfOutputChannels {
        if let inputIndex = outputToInputChannelsMap[outputIndex], inputIndex < numberOfInputChannels {
            channelMap[outputIndex] = inputIndex
        }
    }
    return channelMap.map { NSNumber(value: $0) }
}

protocol BufferedAudioSampleBufferDelegate: AnyObject {
    func didOutputBufferedSampleBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer)
}

private class BufferedAudio {
    private var cameraId: UUID
    private let name: String
    private weak var mixer: Mixer?
    private var sampleRate: Double = 0.0
    private var frameLength: Double = 0.0
    private var sampleBuffers: Deque<CMSampleBuffer> = []
    private var outputTimer = SimpleTimer(queue: mixerLockQueue)
    private var isInitialized: Bool = false
    private var isOutputting: Bool = false
    private var latestSampleBuffer: CMSampleBuffer?
    private var outputCounter: Int64 = 0
    private var startPresentationTimeStamp: CMTime = .zero
    private let driftTracker: DriftTracker
    private var isInitialBuffering = true
    weak var delegate: BufferedAudioSampleBufferDelegate?
    private var hasBufferBeenAppended = false
    let latency: Double

    init(cameraId: UUID, name: String, latency: Double, mixer: Mixer?, manualOutput: Bool) {
        self.cameraId = cameraId
        self.name = name
        self.latency = latency
        self.mixer = mixer
        if manualOutput {
            isOutputting = true
        }
        driftTracker = DriftTracker(media: "audio", name: name, targetFillLevel: latency)
    }

    func setTargetLatency(latency: Double) {
        driftTracker.setTargetFillLevel(targetFillLevel: latency)
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        sampleBuffers.append(sampleBuffer)
        hasBufferBeenAppended = true
        if !isInitialized {
            isInitialized = true
            initialize(sampleBuffer: sampleBuffer)
        }
        if !isOutputting {
            isOutputting = true
            startOutput()
        }
    }

    func getSampleBuffer(_ outputPresentationTimeStamp: Double) -> CMSampleBuffer? {
        var sampleBuffer: CMSampleBuffer?
        var numberOfBuffersConsumed = 0
        let drift = driftTracker.getDrift()
        while let inputSampleBuffer = sampleBuffers.first {
            if latestSampleBuffer == nil {
                latestSampleBuffer = inputSampleBuffer
            }
            if sampleBuffers.count > 300 {
                logger.info(
                    """
                    buffered-audio: \(name): Over 300 buffers (\(sampleBuffers.count)) buffered. Dropping \
                    oldest buffer.
                    """
                )
                sampleBuffer = inputSampleBuffer
                sampleBuffers.removeFirst()
                numberOfBuffersConsumed += 1
                continue
            }
            let inputPresentationTimeStamp = inputSampleBuffer.presentationTimeStamp.seconds + drift
            let inputOutputDelta = inputPresentationTimeStamp - outputPresentationTimeStamp
            // Break on first frame that is ahead in time.
            if inputOutputDelta > 0, sampleBuffer != nil || abs(inputOutputDelta) > 0.015 {
                break
            }
            sampleBuffer = inputSampleBuffer
            sampleBuffers.removeFirst()
            numberOfBuffersConsumed += 1
            isInitialBuffering = false
        }
        if logger.debugEnabled, !isInitialBuffering {
            let lastPresentationTimeStamp = sampleBuffers.last?.presentationTimeStamp.seconds ?? 0.0
            let firstPresentationTimeStamp = sampleBuffers.first?.presentationTimeStamp.seconds ?? 0.0
            let fillLevel = lastPresentationTimeStamp - firstPresentationTimeStamp
            if numberOfBuffersConsumed == 0 {
                logger.debug("""
                buffered-audio: \(name): Duplicating buffer. \
                Output \(formatThreeDecimals(outputPresentationTimeStamp)), \
                \(formatThreeDecimals(firstPresentationTimeStamp + drift))..\
                \(formatThreeDecimals(lastPresentationTimeStamp + drift)) \
                (\(formatThreeDecimals(fillLevel))), \
                Buffers \(sampleBuffers.count)
                """)
            } else if numberOfBuffersConsumed > 1 {
                logger.debug("""
                buffered-audio: \(name): Dropping \(numberOfBuffersConsumed - 1) buffer(s). \
                Output \(formatThreeDecimals(outputPresentationTimeStamp)), \
                Current \(formatThreeDecimals(sampleBuffer?.presentationTimeStamp.seconds ?? 0.0)), \
                \(formatThreeDecimals(firstPresentationTimeStamp + drift))..\
                \(formatThreeDecimals(lastPresentationTimeStamp + drift)) \
                (\(formatThreeDecimals(fillLevel))), \
                Buffers \(sampleBuffers.count)
                """)
            }
        }
        if sampleBuffer != nil {
            latestSampleBuffer = sampleBuffer
        } else if let latestSampleBuffer {
            if let (buffer, size) = latestSampleBuffer.dataBuffer?.getDataPointer() {
                buffer.initialize(repeating: 0, count: size)
            }
            sampleBuffer = latestSampleBuffer
        }
        if !isInitialBuffering, hasBufferBeenAppended {
            hasBufferBeenAppended = false
            if let drift = driftTracker.update(outputPresentationTimeStamp, sampleBuffers) {
                mixer?.setBufferedVideoDrift(cameraId: cameraId, drift: drift)
            }
        }
        return sampleBuffer
    }

    func setDrift(drift: Double) {
        driftTracker.setDrift(drift: drift)
    }

    private func initialize(sampleBuffer: CMSampleBuffer) {
        frameLength = Double(sampleBuffer.numSamples)
        if let formatDescription = sampleBuffer.formatDescription {
            sampleRate = formatDescription.audioStreamBasicDescription?.mSampleRate ?? 1
        }
    }

    private func startOutput() {
        logger.info("""
        buffered-audio: \(name): Start output with sample rate \(sampleRate) and \
        frame length \(frameLength)
        """)
        outputTimer.startPeriodic(interval: 1 / (sampleRate / frameLength), initial: 0.0) { [weak self] in
            self?.output()
        }
    }

    func stopOutput() {
        logger.info("buffered-audio: \(name): Stopping output.")
        outputTimer.stop()
    }

    private func makePresentationTimeStamp() -> CMTime {
        return CMTime(
            value: Int64(frameLength * Double(outputCounter)),
            timescale: CMTimeScale(sampleRate)
        ) + startPresentationTimeStamp
    }

    private func output() {
        outputCounter += 1
        let currentPresentationTimeStamp = currentPresentationTimeStamp()
        if startPresentationTimeStamp == .zero {
            startPresentationTimeStamp = currentPresentationTimeStamp
        }
        var presentationTimeStamp = makePresentationTimeStamp()
        let deltaFromCalculatedToClock = presentationTimeStamp - currentPresentationTimeStamp
        if abs(deltaFromCalculatedToClock.seconds) > deltaLimit {
            if deltaFromCalculatedToClock > .zero {
                logger.info("""
                buffered-audio: Adjust PTS back in time. Calculated is \
                \(presentationTimeStamp.seconds) \
                and clock is \(currentPresentationTimeStamp.seconds)
                """)
                outputCounter -= 1
            } else {
                logger.info("""
                buffered-audio: Adjust PTS forward in time. Calculated is \
                \(presentationTimeStamp.seconds) \
                and clock is \(currentPresentationTimeStamp.seconds)
                """)
                outputCounter += 1
            }
            presentationTimeStamp = makePresentationTimeStamp()
        }
        guard let sampleBuffer = getSampleBuffer(presentationTimeStamp.seconds)?
            .replacePresentationTimeStamp(presentationTimeStamp)
        else {
            return
        }
        delegate?.didOutputBufferedSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }
}

final class AudioUnit: NSObject {
    private var encoders = [AudioEncoder(lockQueue: mixerLockQueue)]
    private var input: AVCaptureDeviceInput?
    private var output: AVCaptureAudioDataOutput?
    var muted = false
    weak var mixer: Mixer?
    private var selectedBufferedAudioId: UUID?
    private var bufferedAudios: [UUID: BufferedAudio] = [:]
    let session = AVCaptureSession()
    private var speechToTextEnabled = false
    private var bufferedBuiltinAudio: BufferedAudio?

    private var inputSourceFormat: AudioStreamBasicDescription? {
        didSet {
            guard inputSourceFormat != oldValue else {
                return
            }
            for encoder in encoders {
                encoder.inSourceFormat = inputSourceFormat
            }
        }
    }

    func startRunning() {
        session.startRunning()
    }

    func stopRunning() {
        session.stopRunning()
    }

    func getEncoders() -> [AudioEncoder] {
        return encoders
    }

    func attach(params: AudioUnitAttachParams) throws {
        mixerLockQueue.async {
            self.selectedBufferedAudioId = params.bufferedAudio
            self.bufferedBuiltinAudio = BufferedAudio(
                cameraId: UUID(),
                name: "builtin",
                latency: params.builtinDelay,
                mixer: self.mixer,
                manualOutput: true
            )
        }
        if let device = params.device {
            try attachDevice(device)
        }
    }

    func startEncoding(_ delegate: any AudioCodecDelegate) {
        for encoder in encoders {
            encoder.delegate = delegate
            encoder.startRunning()
        }
    }

    func stopEncoding() {
        for encoder in encoders {
            encoder.stopRunning()
            encoder.delegate = nil
        }
        inputSourceFormat = nil
    }

    func setSpeechToText(enabled: Bool) {
        mixerLockQueue.async {
            self.speechToTextEnabled = enabled
        }
    }

    private func attachDevice(_ device: AVCaptureDevice) throws {
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        if let input, session.inputs.contains(input) {
            session.removeInput(input)
        }
        if let output, session.outputs.contains(output) {
            session.removeOutput(output)
        }
        input = try AVCaptureDeviceInput(device: device)
        if audioUnitRemoveWindNoise {
            if #available(iOS 18.0, *) {
                if input!.isWindNoiseRemovalSupported {
                    input!.multichannelAudioMode = .stereo
                    input!.isWindNoiseRemovalEnabled = true
                    logger
                        .info(
                            "audio-unit: Wind noise removal enabled is \(input!.isWindNoiseRemovalEnabled)"
                        )
                } else {
                    logger.info("audio-unit: Wind noise removal is not supported on this device")
                }
            } else {
                logger.info("audio-unit: Wind noise removal needs iOS 18+")
            }
        }
        if session.canAddInput(input!) {
            session.addInput(input!)
        }
        output = AVCaptureAudioDataOutput()
        output?.setSampleBufferDelegate(self, queue: mixerLockQueue)
        if session.canAddOutput(output!) {
            session.addOutput(output!)
        }
        session.automaticallyConfiguresApplicationAudioSession = false
    }

    func addBufferedAudio(cameraId: UUID, name: String, latency: Double) {
        mixerLockQueue.async {
            self.addBufferedAudioInner(cameraId: cameraId, name: name, latency: latency)
        }
    }

    func removeBufferedAudio(cameraId: UUID) {
        mixerLockQueue.async {
            self.removeBufferedAudioInner(cameraId: cameraId)
        }
    }

    func appendBufferedAudioSampleBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        mixerLockQueue.async {
            self.appendBufferedAudioSampleBufferInner(cameraId: cameraId, sampleBuffer)
        }
    }

    func setBufferedAudioDrift(cameraId: UUID, drift: Double) {
        mixerLockQueue.async {
            self.setBufferedAudioDriftInner(cameraId: cameraId, drift: drift)
        }
    }

    func setBufferedAudioTargetLatency(cameraId: UUID, latency: Double) {
        mixerLockQueue.async {
            self.setBufferedAudioTargetLatencyInner(cameraId: cameraId, latency: latency)
        }
    }

    private func addBufferedAudioInner(cameraId: UUID, name: String, latency: Double) {
        let bufferedAudio = BufferedAudio(
            cameraId: cameraId,
            name: name,
            latency: latency,
            mixer: mixer,
            manualOutput: false
        )
        bufferedAudio.delegate = self
        bufferedAudios[cameraId] = bufferedAudio
    }

    private func removeBufferedAudioInner(cameraId: UUID) {
        bufferedAudios.removeValue(forKey: cameraId)?.stopOutput()
    }

    private func appendBufferedAudioSampleBufferInner(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        bufferedAudios[cameraId]?.appendSampleBuffer(sampleBuffer)
    }

    private func setBufferedAudioDriftInner(cameraId: UUID, drift: Double) {
        bufferedAudios[cameraId]?.setDrift(drift: drift)
    }

    private func setBufferedAudioTargetLatencyInner(cameraId: UUID, latency: Double) {
        bufferedAudios[cameraId]?.setTargetLatency(latency: latency)
    }

    private func appendNewSampleBuffer(sampleBuffer: CMSampleBuffer, audioLevel: Float, numberOfAudioChannels: Int) {
        guard let mixer else {
            return
        }
        // Workaround for audio drift on iPhone 15 Pro Max running iOS 17. Probably issue on more models.
        let presentationTimeStamp = syncTimeToVideo(mixer: mixer, sampleBuffer: sampleBuffer)
        mixer.delegate?.mixer(audioLevel: audioLevel, numberOfAudioChannels: numberOfAudioChannels)
        guard let sampleBuffer = sampleBuffer.muted(muted) else {
            return
        }
        if speechToTextEnabled {
            mixer.delegate?.mixer(audioSampleBuffer: sampleBuffer)
        }
        inputSourceFormat = sampleBuffer.formatDescription?.audioStreamBasicDescription
        for encoder in encoders {
            encoder.appendSampleBuffer(sampleBuffer, presentationTimeStamp)
        }
        mixer.recorder.appendAudio(sampleBuffer)
    }

    private func appendBufferedBuiltinAudio(sampleBuffer: CMSampleBuffer) -> BufferedAudio? {
        guard let bufferedBuiltinAudio, bufferedBuiltinAudio.latency > 0,
              let sampleBuffer = sampleBuffer.deepCopyAudioSampleBuffer()
        else {
            return nil
        }
        let latency = CMTime(seconds: bufferedBuiltinAudio.latency, preferredTimescale: 1000)
        guard let sampleBuffer = sampleBuffer
            .replacePresentationTimeStamp(sampleBuffer.presentationTimeStamp + latency)
        else {
            return nil
        }
        bufferedBuiltinAudio.appendSampleBuffer(sampleBuffer)
        return bufferedBuiltinAudio
    }
}

extension AudioUnit: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        var sampleBuffer = sampleBuffer
        if let bufferedAudio = appendBufferedBuiltinAudio(sampleBuffer: sampleBuffer) {
            sampleBuffer = bufferedAudio.getSampleBuffer(sampleBuffer.presentationTimeStamp.seconds) ?? sampleBuffer
        }
        guard selectedBufferedAudioId == nil else {
            return
        }
        var audioLevel: Float
        if muted {
            audioLevel = .nan
        } else if let channel = connection.audioChannels.first {
            audioLevel = channel.averagePowerLevel
        } else {
            audioLevel = 0.0
        }
        appendNewSampleBuffer(
            sampleBuffer: sampleBuffer,
            audioLevel: audioLevel,
            numberOfAudioChannels: connection.audioChannels.count
        )
    }
}

extension AudioUnit: BufferedAudioSampleBufferDelegate {
    func didOutputBufferedSampleBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        guard selectedBufferedAudioId == cameraId else {
            return
        }
        let numberOfAudioChannels = Int(sampleBuffer.formatDescription?.numberOfAudioChannels() ?? 0)
        appendNewSampleBuffer(
            sampleBuffer: sampleBuffer,
            audioLevel: .infinity,
            numberOfAudioChannels: numberOfAudioChannels
        )
    }
}

private func syncTimeToVideo(mixer: Mixer, sampleBuffer: CMSampleBuffer) -> CMTime {
    var presentationTimeStamp = sampleBuffer.presentationTimeStamp
    if let audioClock = mixer.audio.session.synchronizationClock,
       let videoClock = mixer.video.session.synchronizationClock
    {
        let audioTimescale = sampleBuffer.presentationTimeStamp.timescale
        let seconds = audioClock.convertTime(presentationTimeStamp, to: videoClock).seconds
        let value = CMTimeValue(seconds * Double(audioTimescale))
        presentationTimeStamp = CMTime(value: value, timescale: audioTimescale)
    }
    return presentationTimeStamp
}
