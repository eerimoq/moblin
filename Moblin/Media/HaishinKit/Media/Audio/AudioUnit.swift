import AVFoundation
import Collections

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

final class AudioUnit: NSObject {
    private var encoders = [AudioEncoder(lockQueue: processorPipelineQueue)]
    private var input: AVCaptureDeviceInput?
    private var output: AVCaptureAudioDataOutput?
    var muted = false
    weak var processor: Processor?
    private var selectedBufferedAudioId: UUID?
    private var bufferedAudios: [UUID: BufferedAudio] = [:]
    let session = AVCaptureSession()
    private var speechToTextEnabled = false
    private var bufferedBuiltinAudio: BufferedAudio?
    private var latestAudioStatusTime = 0.0

    private var inputSourceFormat: AudioStreamBasicDescription? {
        didSet {
            guard inputSourceFormat != oldValue else {
                return
            }
            for encoder in encoders {
                encoder.setInSourceFormat(inputSourceFormat)
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
        processorPipelineQueue.async {
            self.selectedBufferedAudioId = params.bufferedAudio
            self.bufferedBuiltinAudio = BufferedAudio(
                cameraId: UUID(),
                name: "builtin",
                latency: params.builtinDelay,
                processor: self.processor,
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
        processorPipelineQueue.async {
            self.inputSourceFormat = nil
        }
    }

    func setSpeechToText(enabled: Bool) {
        processorPipelineQueue.async {
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
                    logger.info("audio-unit: Wind noise removal enabled is \(input!.isWindNoiseRemovalEnabled)")
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
        output?.setSampleBufferDelegate(self, queue: processorPipelineQueue)
        if session.canAddOutput(output!) {
            session.addOutput(output!)
        }
        session.automaticallyConfiguresApplicationAudioSession = false
    }

    func addBufferedAudio(cameraId: UUID, name: String, latency: Double) {
        processorPipelineQueue.async {
            self.addBufferedAudioInner(cameraId: cameraId, name: name, latency: latency)
        }
    }

    func removeBufferedAudio(cameraId: UUID) {
        processorPipelineQueue.async {
            self.removeBufferedAudioInner(cameraId: cameraId)
        }
    }

    func appendBufferedAudioSampleBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        processorPipelineQueue.async {
            self.appendBufferedAudioSampleBufferInner(cameraId: cameraId, sampleBuffer)
        }
    }

    func setBufferedAudioDrift(cameraId: UUID, drift: Double) {
        processorPipelineQueue.async {
            self.setBufferedAudioDriftInner(cameraId: cameraId, drift: drift)
        }
    }

    func setBufferedAudioTargetLatency(cameraId: UUID, latency: Double) {
        processorPipelineQueue.async {
            self.setBufferedAudioTargetLatencyInner(cameraId: cameraId, latency: latency)
        }
    }

    private func addBufferedAudioInner(cameraId: UUID, name: String, latency: Double) {
        let bufferedAudio = BufferedAudio(
            cameraId: cameraId,
            name: name,
            latency: latency,
            processor: processor,
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

    private func appendNewSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let processor else {
            return
        }
        // Workaround for audio drift on iPhone 15 Pro Max running iOS 17. Probably issue on more models.
        let presentationTimeStamp = syncTimeToVideo(processor: processor, sampleBuffer: sampleBuffer)
        guard let sampleBuffer = sampleBuffer.muted(muted) else {
            return
        }
        if speechToTextEnabled {
            processor.delegate?.streamAudio(sampleBuffer: sampleBuffer)
        }
        inputSourceFormat = sampleBuffer.formatDescription?.audioStreamBasicDescription
        for encoder in encoders {
            encoder.appendSampleBuffer(sampleBuffer, presentationTimeStamp)
        }
        processor.recorder.appendAudio(sampleBuffer)
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

    private func shouldUpdateAudioLevel(_ sampleBuffer: CMSampleBuffer) -> Bool {
        let now = sampleBuffer.presentationTimeStamp.seconds
        if now - latestAudioStatusTime > 0.2 {
            latestAudioStatusTime = now
            return true
        } else {
            return false
        }
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
        if shouldUpdateAudioLevel(sampleBuffer) {
            var audioLevel: Float
            if muted {
                audioLevel = .nan
            } else if let channel = connection.audioChannels.first {
                audioLevel = channel.averagePowerLevel
            } else {
                audioLevel = 0.0
            }
            processor?.delegate?.stream(audioLevel: audioLevel,
                                        numberOfAudioChannels: connection.audioChannels.count,
                                        sampleRate: sampleBuffer.formatDescription?.audioStreamBasicDescription?
                                            .mSampleRate ?? 0)
        }
        appendNewSampleBuffer(sampleBuffer)
    }
}

extension AudioUnit: BufferedAudioSampleBufferDelegate {
    func didOutputBufferedSampleBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        guard selectedBufferedAudioId == cameraId else {
            return
        }
        if shouldUpdateAudioLevel(sampleBuffer) {
            let numberOfAudioChannels = Int(sampleBuffer.formatDescription?.numberOfAudioChannels() ?? 0)
            processor?.delegate?.stream(audioLevel: .infinity,
                                        numberOfAudioChannels: numberOfAudioChannels,
                                        sampleRate: sampleBuffer.formatDescription?.audioStreamBasicDescription?
                                            .mSampleRate ?? 0)
        }
        appendNewSampleBuffer(sampleBuffer)
    }
}

private func syncTimeToVideo(processor: Processor, sampleBuffer: CMSampleBuffer) -> CMTime {
    var presentationTimeStamp = sampleBuffer.presentationTimeStamp
    if let audioClock = processor.audio.session.synchronizationClock,
       let videoClock = processor.video.session.synchronizationClock
    {
        let audioTimescale = sampleBuffer.presentationTimeStamp.timescale
        let seconds = audioClock.convertTime(presentationTimeStamp, to: videoClock).seconds
        let value = CMTimeValue(seconds * Double(audioTimescale))
        presentationTimeStamp = CMTime(value: value, timescale: audioTimescale)
    }
    return presentationTimeStamp
}
