import AVFoundation
import Collections

private let lockQueue = DispatchQueue(
    label: "com.haishinkit.HaishinKit.AudioIOUnit.lock",
    qos: .userInteractive
)

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
    private var sampleRate: Double = 0.0
    private var frameLength: Double = 0.0
    private var sampleBuffers: Deque<CMSampleBuffer> = []
    private var outputTimer: DispatchSourceTimer?
    private var isInitialized: Bool = false
    private var isOutputting: Bool = false
    private var latestSampleBuffer: CMSampleBuffer?
    private let name: String

    weak var delegate: ReplaceAudioSampleBufferDelegate?

    init(cameraId: UUID, name: String) {
        self.cameraId = cameraId
        self.name = name
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        sampleBuffers.append(sampleBuffer)
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
        while let inputSampleBuffer = sampleBuffers.first {
            if sampleBuffers.count > 300 {
                logger.info("replace-audio: \(name): Over 300 buffers buffered. Dropping oldest buffer.")
                sampleBuffer = inputSampleBuffer
                sampleBuffers.removeFirst()
                numberOfBuffersConsumed += 1
                continue
            }
            let inputPresentationTimeStamp = inputSampleBuffer.presentationTimeStamp.seconds
            let inputOutputDelta = inputPresentationTimeStamp - outputPresentationTimeStamp
            if inputOutputDelta > 0, sampleBuffer != nil || abs(inputOutputDelta) > 0.015 {
                break
            }
            sampleBuffer = inputSampleBuffer
            sampleBuffers.removeFirst()
            numberOfBuffersConsumed += 1
        }
        if logger.debugEnabled {
            if numberOfBuffersConsumed == 0 {
                logger.debug("""
                replace-audio: \(name): Duplicating buffer. \
                Output time \(outputPresentationTimeStamp) \
                Current \(sampleBuffer?.presentationTimeStamp.seconds ?? .nan). \
                Buffers count is \(sampleBuffers.count). \
                First \(sampleBuffers.first?.presentationTimeStamp.seconds ?? .nan). \
                Last \(sampleBuffers.last?.presentationTimeStamp.seconds ?? .nan).
                """)
            } else if numberOfBuffersConsumed > 1 {
                logger.debug("""
                replace-audio: \(name): Skipping \(numberOfBuffersConsumed - 1) buffer(s). \
                Output time \(outputPresentationTimeStamp) \
                Current \(sampleBuffer?.presentationTimeStamp.seconds ?? .nan). \
                Buffers count is \(sampleBuffers.count). \
                First \(sampleBuffers.first?.presentationTimeStamp.seconds ?? .nan). \
                Last \(sampleBuffers.last?.presentationTimeStamp.seconds ?? .nan).
                """)
            }
        }
        if sampleBuffer != nil {
            latestSampleBuffer = sampleBuffer
        } else if latestSampleBuffer != nil {
            if let (buffer, size) = latestSampleBuffer?.dataBuffer?.getDataPointer() {
                buffer.initialize(repeating: 0, count: size)
            }
            sampleBuffer = latestSampleBuffer
            logger.debug("""
            replace-audio: \(name): Using latest sample buffer. \
            Output time \(outputPresentationTimeStamp) \
            Current \(sampleBuffer?.presentationTimeStamp.seconds ?? .nan). \
            Buffers count is \(sampleBuffers.count). \
            First \(sampleBuffers.first?.presentationTimeStamp.seconds ?? .nan). \
            Last \(sampleBuffers.last?.presentationTimeStamp.seconds ?? .nan).
            """)
        }
        return sampleBuffer
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
        outputTimer = DispatchSource.makeTimerSource(queue: lockQueue)
        outputTimer?.schedule(deadline: .now(), repeating: 1 / (sampleRate / frameLength))
        outputTimer?.setEventHandler { [weak self] in
            self?.output()
        }
        outputTimer?.activate()
    }

    func stopOutput() {
        logger.info("replace-audio: \(name): Stopping output.")
        outputTimer?.cancel()
        outputTimer = nil
    }

    private func output() {
        let presentationTimeStamp = currentPresentationTimeStamp()
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
    lazy var codec: AudioCodec = .init(lockQueue: lockQueue)
    private(set) var device: AVCaptureDevice?
    private var input: AVCaptureInput?
    private var output: AVCaptureAudioDataOutput?
    var muted = false
    weak var mixer: Mixer?
    private var selectedReplaceAudioId: UUID?
    private var replaceAudios: [UUID: ReplaceAudio] = [:]
    let session = makeCaptureSession()

    private var inputSourceFormat: AudioStreamBasicDescription? {
        didSet {
            guard inputSourceFormat != oldValue else {
                return
            }
            codec.inSourceFormat = inputSourceFormat
        }
    }

    func startRunning() {
        session.startRunning()
    }

    func stopRunning() {
        session.stopRunning()
    }

    func attach(_ device: AVCaptureDevice?, _ replaceAudio: UUID?) throws {
        lockQueue.sync {
            self.selectedReplaceAudioId = replaceAudio
        }
        if let device {
            output?.setSampleBufferDelegate(nil, queue: lockQueue)
            try attachDevice(device, session)
            self.device = device
            output?.setSampleBufferDelegate(self, queue: lockQueue)
            session.automaticallyConfiguresApplicationAudioSession = false
        }
    }

    func appendSampleBuffer(
        _ sampleBuffer: CMSampleBuffer,
        _ presentationTimeStamp: CMTime,
        isFirstAfterAttach _: Bool
    ) {
        guard let sampleBuffer = sampleBuffer.muted(muted) else {
            return
        }
        inputSourceFormat = sampleBuffer.formatDescription?.streamBasicDescription?.pointee
        codec.appendSampleBuffer(sampleBuffer, presentationTimeStamp)
        mixer?.recorder.appendAudio(sampleBuffer)
    }

    func startEncoding(_ delegate: any AudioCodecDelegate & VideoCodecDelegate) {
        codec.delegate = delegate
        codec.startRunning()
    }

    func stopEncoding() {
        codec.stopRunning()
        codec.delegate = nil
        inputSourceFormat = nil
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

    func addReplaceAudioSampleBuffer(id: UUID, _ sampleBuffer: CMSampleBuffer) {
        lockQueue.async {
            self.addReplaceAudioSampleBufferInner(id: id, sampleBuffer)
        }
    }

    func addReplaceAudioSampleBufferInner(id: UUID, _ sampleBuffer: CMSampleBuffer) {
        replaceAudios[id]?.appendSampleBuffer(sampleBuffer)
    }

    func addReplaceAudio(cameraId: UUID, name: String) {
        lockQueue.async {
            self.addReplaceAudioInner(cameraId: cameraId, name: name)
        }
    }

    func addReplaceAudioInner(cameraId: UUID, name: String) {
        let replaceAudio = ReplaceAudio(cameraId: cameraId, name: name)
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

    func prepareSampleBuffer(sampleBuffer: CMSampleBuffer, audioLevel: Float, numberOfAudioChannels: Int) {
        guard let mixer else {
            return
        }
        // Workaround for audio drift on iPhone 15 Pro Max running iOS 17. Probably issue on more models.
        let presentationTimeStamp = syncTimeToVideo(mixer: mixer, sampleBuffer: sampleBuffer)
        guard mixer.useSampleBuffer(presentationTimeStamp, mediaType: AVMediaType.audio) else {
            return
        }
        mixer.delegate?.mixer(
            audioLevel: audioLevel,
            numberOfAudioChannels: numberOfAudioChannels,
            presentationTimestamp: presentationTimeStamp.seconds
        )
        appendSampleBuffer(sampleBuffer, presentationTimeStamp, isFirstAfterAttach: false)
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
    if #available(iOS 16.0, *) {
        if let audioClock = mixer.audio.session.synchronizationClock,
           let videoClock = mixer.video.session.synchronizationClock
        {
            let audioTimescale = sampleBuffer.presentationTimeStamp.timescale
            let seconds = audioClock.convertTime(presentationTimeStamp, to: videoClock).seconds
            let value = CMTimeValue(seconds * Double(audioTimescale))
            presentationTimeStamp = CMTime(value: value, timescale: audioTimescale)
        }
    }
    return presentationTimeStamp
}
