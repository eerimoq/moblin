import AVFoundation

private let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.AudioIOUnit.lock")

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
    private var latency: Double
    private var frameRate: Double = 0.0
    private var sampleBufferQueue: [CMSampleBuffer] = []
    private var startTime: Double?
    private var state: State = .initializing
    private var initializationDuration: Double = 1
    private var outputTimer: DispatchSourceTimer?
    private enum State {
        case initializing
        case buffering
        case outputting
    }

    private var maxQueueSize: Int {
        return Int((latency + 5) * frameRate)
    }

    private var minQueueSize: Int {
        return Int(latency * frameRate - 1)
    }

    weak var delegate: ReplaceAudioSampleBufferDelegate?

    init(cameraId: UUID, latency: Double) {
        self.cameraId = cameraId
        self.latency = 1 + latency
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        let currentTime = CACurrentMediaTime()
        if startTime == nil {
            startTime = currentTime
        }
        sampleBufferQueue.append(sampleBuffer)
        // logger.info("ReplaceAudio Queue Count: \(sampleBufferQueue.count)")

        switch state {
        case .initializing:
            // logger.info("ReplaceVideo initializing.")
            if currentTime - startTime! >= initializationDuration {
                initialize(sampleBuffer: sampleBuffer)
                startTime = nil
                state = .buffering
                return
            }
        case .buffering:
            // logger.info("ReplaceAudio buffering.")
            if currentTime - startTime! >= latency {
                state = .outputting
                startOutput()
            }
        case .outputting:
            // logger.info("ReplaceAudio outputting.")
            balanceQueue()
        }
    }

    private func initialize(sampleBuffer: CMSampleBuffer) {
        let frameLength = Double(CMSampleBufferGetNumSamples(sampleBuffer))
        let sampleRate = CMSampleBufferGetFormatDescription(sampleBuffer)?.streamBasicDescription?.pointee
            .mSampleRate
        frameRate = sampleRate! / frameLength
        sampleBufferQueue.removeAll()
    }

    private func startOutput() {
        logger.info("ReplaceAudio latency: \(latency)")
        logger.info("ReplaceAudio frameRate: \(frameRate)")
        outputTimer = DispatchSource.makeTimerSource(queue: lockQueue)
        outputTimer!.schedule(deadline: .now(), repeating: 1 / frameRate)
        outputTimer!.setEventHandler { [weak self] in
            self?.output()
        }
        outputTimer!.activate()
    }

    private func output() {
        guard let sampleBuffer = sampleBufferQueue.first else {
            logger.info("ReplaceAudio Queue size low. Waiting for more sampleBuffers.")
            return
        }
        let presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock())
        guard let sampleBuffer = sampleBuffer
            .replacePresentationTimeStamp(presentationTimeStamp: presentationTimeStamp)
        else {
            return
        }
        delegate?.didOutputReplaceSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
        sampleBufferQueue.removeFirst()
    }

    private func balanceQueue() {
        if sampleBufferQueue.count > maxQueueSize {
            logger.info("ReplaceAudio Queue size high. Drop oldest sampleBuffer.")
            sampleBufferQueue.removeFirst()
        }
        // if sampleBufferQueue.count < minQueueSize {
        //     logger.info("ReplaceVideo Queue size low. Duplicate oldest sampleBuffer.")
        //     sampleBufferQueue.insert(sampleBufferQueue.first!, at: 0)
        // }
    }

    func stopOutput() {
        outputTimer?.cancel()
        outputTimer = nil
        sampleBufferQueue.removeAll()
        startTime = nil
        state = .initializing
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
        output?.setSampleBufferDelegate(nil, queue: lockQueue)
        try attachDevice(device, session)
        self.device = device
        output?.setSampleBufferDelegate(self, queue: lockQueue)
        session.automaticallyConfiguresApplicationAudioSession = false
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
        guard let replaceAudio = replaceAudios[id] else {
            return
        }
        replaceAudio.appendSampleBuffer(sampleBuffer)
    }

    func addReplaceAudio(cameraId: UUID, latency: Double) {
        lockQueue.async {
            self.addReplaceAudioInner(cameraId: cameraId, latency: latency)
        }
    }

    func addReplaceAudioInner(cameraId: UUID, latency: Double) {
        let replaceAudio = ReplaceAudio(cameraId: cameraId, latency: latency)
        replaceAudio.delegate = self
        replaceAudios[cameraId] = replaceAudio
    }

    func removeReplaceAudio(cameraId: UUID) {
        lockQueue.async {
            self.removeReplaceAudioInner(cameraId: cameraId)
        }
    }

    func removeReplaceAudioInner(cameraId: UUID) {
        let replaceAudio = replaceAudios[cameraId]
        replaceAudio?.stopOutput()
        replaceAudios.removeValue(forKey: cameraId)
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
        if cameraId == selectedReplaceAudioId {
            let numberOfAudioChannels = sampleBuffer.formatDescription?.audioChannelLayout?
                .numberOfChannels ?? 0
            prepareSampleBuffer(
                sampleBuffer: sampleBuffer,
                audioLevel: .infinity,
                numberOfAudioChannels: numberOfAudioChannels
            )
        }
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
