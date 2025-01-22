import AVFoundation
import Collections

private let lockQueue = DispatchQueue(
    label: "com.haishinkit.HaishinKit.AudioIOUnit.lock",
    qos: .userInteractive
)

private let deltaLimit = 0.03
var audioUnitRemoveWindNoise = false

func makeChannelMap(
    numberOfInputChannels: Int,
    numberOfOutputChannels: Int,
    outputToInputChannelsMap: [Int: Int]
) -> [NSNumber] {
    var result = Array(repeating: -1, count: numberOfOutputChannels)
    for inputIndex in 0 ..< min(numberOfInputChannels, numberOfOutputChannels) {
        result[inputIndex] = inputIndex
    }
    for outputIndex in 0 ..< numberOfOutputChannels {
        if let inputIndex = outputToInputChannelsMap[outputIndex], inputIndex < numberOfInputChannels {
            result[outputIndex] = inputIndex
        }
    }
    return result.map { NSNumber(value: $0) }
}

protocol ReplaceAudioSampleBufferDelegate: AnyObject {
    func didOutputReplaceSampleBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer)
}

private class ReplaceAudio {
    private var cameraId: UUID
    private let name: String
    private weak var mixer: Mixer?
    private var sampleRate: Double = 0.0
    private var frameLength: Double = 0.0
    private var sampleBuffers: Deque<CMSampleBuffer> = []
    private var outputTimer = SimpleTimer(queue: lockQueue)
    private var isInitialized: Bool = false
    private var isOutputting: Bool = false
    private var latestSampleBuffer: CMSampleBuffer?
    private var outputCounter: Int64 = 0
    private var startPresentationTimeStamp: CMTime = .zero
    private let driftTracker: DriftTracker
    private var isInitialBuffering = true
    weak var delegate: ReplaceAudioSampleBufferDelegate?
    private var hasBufferBeenAppended = false

    init(cameraId: UUID, name: String, latency: Double, mixer: Mixer?) {
        self.cameraId = cameraId
        self.name = name
        self.mixer = mixer
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
                    replace-audio: \(name): Over 300 buffers (\(sampleBuffers.count)) buffered. Dropping \
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
                replace-audio: \(name): Duplicating buffer. \
                Output \(formatThreeDecimals(outputPresentationTimeStamp)), \
                \(formatThreeDecimals(firstPresentationTimeStamp + drift))..\
                \(formatThreeDecimals(lastPresentationTimeStamp + drift)) \
                (\(formatThreeDecimals(fillLevel))), \
                Buffers \(sampleBuffers.count)
                """)
            } else if numberOfBuffersConsumed > 1 {
                logger.debug("""
                replace-audio: \(name): Dropping \(numberOfBuffersConsumed - 1) buffer(s). \
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
                mixer?.setReplaceVideoDrift(cameraId: cameraId, drift: drift)
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
            sampleRate = formatDescription.streamBasicDescription?.pointee.mSampleRate ?? 1
        }
    }

    private func startOutput() {
        logger.info("""
        replace-audio: \(name): Start output with sample rate \(sampleRate) and \
        frame length \(frameLength)
        """)
        outputTimer.startPeriodic(interval: 1 / (sampleRate / frameLength), initial: 0.0) { [weak self] in
            self?.output()
        }
    }

    func stopOutput() {
        logger.info("replace-audio: \(name): Stopping output.")
        outputTimer.stop()
    }

    private func calcPresentationTimeStamp() -> CMTime {
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
        var presentationTimeStamp = calcPresentationTimeStamp()
        let deltaFromCalculatedToClock = presentationTimeStamp - currentPresentationTimeStamp
        if abs(deltaFromCalculatedToClock.seconds) > deltaLimit {
            if deltaFromCalculatedToClock > .zero {
                logger.info("""
                replace-audio: Adjust PTS back in time. Calculated is \
                \(presentationTimeStamp.seconds) \
                and clock is \(currentPresentationTimeStamp.seconds)
                """)
                outputCounter -= 1
                presentationTimeStamp = calcPresentationTimeStamp()
            } else {
                logger.info("""
                replace-audio: Adjust PTS forward in time. Calculated is \
                \(presentationTimeStamp.seconds) \
                and clock is \(currentPresentationTimeStamp.seconds)
                """)
                outputCounter += 1
                presentationTimeStamp = calcPresentationTimeStamp()
            }
        }
        guard let sampleBuffer = getSampleBuffer(presentationTimeStamp.seconds) else {
            return
        }
        guard let sampleBuffer = sampleBuffer.replacePresentationTimeStamp(presentationTimeStamp)
        else {
            return
        }
        delegate?.didOutputReplaceSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }
}

final class AudioUnit: NSObject {
    private var encoders = [AudioCodec(lockQueue: lockQueue)]
    private var input: AVCaptureDeviceInput?
    private var output: AVCaptureAudioDataOutput?
    var muted = false
    weak var mixer: Mixer?
    private var selectedReplaceAudioId: UUID?
    private var replaceAudios: [UUID: ReplaceAudio] = [:]
    let session = makeCaptureSession()
    private var speechToTextEnabled = false

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

    func getEncoders() -> [AudioCodec] {
        return encoders
    }

    func attach(_ device: AVCaptureDevice?, _ replaceAudio: UUID?) throws {
        lockQueue.sync {
            self.selectedReplaceAudioId = replaceAudio
        }
        if let device {
            output?.setSampleBufferDelegate(nil, queue: lockQueue)
            try attachDevice(device, session)
            output?.setSampleBufferDelegate(self, queue: lockQueue)
            session.automaticallyConfiguresApplicationAudioSession = false
        }
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, _ presentationTimeStamp: CMTime) {
        guard let sampleBuffer = sampleBuffer.muted(muted) else {
            return
        }
        if speechToTextEnabled {
            mixer?.delegate?.mixer(audioSampleBuffer: sampleBuffer)
        }
        inputSourceFormat = sampleBuffer.formatDescription?.streamBasicDescription?.pointee
        for encoder in encoders {
            encoder.appendSampleBuffer(sampleBuffer, presentationTimeStamp)
        }
        mixer?.recorder.appendAudio(sampleBuffer)
    }

    func startEncoding(_ delegate: any AudioCodecDelegate & VideoCodecDelegate) {
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
        lockQueue.async {
            self.speechToTextEnabled = enabled
        }
    }

    private func attachDevice(_ device: AVCaptureDevice?, _ captureSession: AVCaptureSession) throws {
        captureSession.beginConfiguration()
        defer {
            captureSession.commitConfiguration()
        }
        if let input, captureSession.inputs.contains(input) {
            captureSession.removeInput(input)
        }
        if let output, captureSession.outputs.contains(output) {
            captureSession.removeOutput(output)
        }
        if let device {
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
            if captureSession.canAddInput(input!) {
                captureSession.addInput(input!)
            }
            output = AVCaptureAudioDataOutput()
            if captureSession.canAddOutput(output!) {
                captureSession.addOutput(output!)
            }
        } else {
            input = nil
            output = nil
        }
    }

    func addReplaceAudioSampleBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        lockQueue.async {
            self.addReplaceAudioSampleBufferInner(cameraId: cameraId, sampleBuffer)
        }
    }

    func addReplaceAudioSampleBufferInner(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        replaceAudios[cameraId]?.appendSampleBuffer(sampleBuffer)
    }

    func addReplaceAudio(cameraId: UUID, name: String, latency: Double) {
        lockQueue.async {
            self.addReplaceAudioInner(cameraId: cameraId, name: name, latency: latency)
        }
    }

    func addReplaceAudioInner(cameraId: UUID, name: String, latency: Double) {
        let replaceAudio = ReplaceAudio(cameraId: cameraId, name: name, latency: latency, mixer: mixer)
        replaceAudio.delegate = self
        replaceAudios[cameraId] = replaceAudio
    }

    func removeReplaceAudio(cameraId: UUID) {
        lockQueue.async {
            self.removeReplaceAudioInner(cameraId: cameraId)
        }
    }

    func removeReplaceAudioInner(cameraId: UUID) {
        replaceAudios.removeValue(forKey: cameraId)?.stopOutput()
    }

    func setReplaceAudioDrift(cameraId: UUID, drift: Double) {
        lockQueue.async {
            self.setReplaceAudioDriftInner(cameraId: cameraId, drift: drift)
        }
    }

    private func setReplaceAudioDriftInner(cameraId: UUID, drift: Double) {
        replaceAudios[cameraId]?.setDrift(drift: drift)
    }

    func setReplaceAudioTargetLatency(cameraId: UUID, latency: Double) {
        lockQueue.async {
            self.setReplaceAudioTargetLatencyInner(cameraId: cameraId, latency: latency)
        }
    }

    private func setReplaceAudioTargetLatencyInner(cameraId: UUID, latency: Double) {
        replaceAudios[cameraId]?.setTargetLatency(latency: latency)
    }

    func prepareSampleBuffer(sampleBuffer: CMSampleBuffer, audioLevel: Float, numberOfAudioChannels: Int) {
        guard let mixer else {
            return
        }
        // Workaround for audio drift on iPhone 15 Pro Max running iOS 17. Probably issue on more models.
        let presentationTimeStamp = syncTimeToVideo(mixer: mixer, sampleBuffer: sampleBuffer)
        mixer.delegate?.mixer(
            audioLevel: audioLevel,
            numberOfAudioChannels: numberOfAudioChannels,
            presentationTimestamp: presentationTimeStamp.seconds
        )
        appendSampleBuffer(sampleBuffer, presentationTimeStamp)
    }
}

extension AudioUnit: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard selectedReplaceAudioId == nil else {
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
        prepareSampleBuffer(
            sampleBuffer: sampleBuffer,
            audioLevel: audioLevel,
            numberOfAudioChannels: connection.audioChannels.count
        )
    }
}

extension AudioUnit: ReplaceAudioSampleBufferDelegate {
    func didOutputReplaceSampleBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        guard selectedReplaceAudioId == cameraId else {
            return
        }
        let numberOfAudioChannels = sampleBuffer.formatDescription?.audioChannelLayout?.numberOfChannels ?? 0
        prepareSampleBuffer(
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
