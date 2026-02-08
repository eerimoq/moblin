import AVFoundation
import Collections

struct AudioUnitAttachParams {
    let device: AVCaptureDevice?
    let builtinDelay: Double
    let bufferedAudio: UUID?
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

private let mixerOutputSampleRate: Double = 48000
private let mixerOutputChannels: AVAudioChannelCount = 1
private let mixerOutputSamplesPerBuffer: AVAudioFrameCount = 1024

final class AudioUnit: NSObject {
    let encoder = AudioEncoder(lockQueue: processorPipelineQueue)
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
    private let builtinInputId = UUID()
    private var mixer: AudioMixer?
    private var mixerInputFormats: [UUID: AVAudioFormat] = [:]
    private var mixerProcessTimer = SimpleTimer(queue: processorPipelineQueue)
    private var mixerOutputPresentationTimeStamp: CMTime = .zero
    private var mixerStarted = false
    private var mixerSourceIds: Set<UUID> = []

    private var inputSourceFormat: AudioStreamBasicDescription? {
        didSet {
            guard inputSourceFormat != oldValue else {
                return
            }
            encoder.setInputSourceFormat(inputSourceFormat)
        }
    }

    func startRunning() {
        session.startRunning()
    }

    func stopRunning() {
        session.stopRunning()
        processorPipelineQueue.async {
            self.stopMixer()
        }
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

    func startEncoding(_ delegate: any AudioEncoderDelegate) {
        encoder.delegate = delegate
        encoder.startRunning()
    }

    func stopEncoding() {
        encoder.stopRunning()
        processorPipelineQueue.async {
            self.inputSourceFormat = nil
            self.stopMixer()
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
            self.addBufferedAudioInternal(cameraId: cameraId, name: name, latency: latency)
        }
    }

    func removeBufferedAudio(cameraId: UUID) {
        processorPipelineQueue.async {
            self.removeBufferedAudioInternal(cameraId: cameraId)
        }
    }

    func appendBufferedAudioSampleBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        processorPipelineQueue.async {
            self.appendBufferedAudioSampleBufferInternal(cameraId: cameraId, sampleBuffer)
        }
    }

    func setBufferedAudioDrift(cameraId: UUID, drift: Double) {
        processorPipelineQueue.async {
            self.setBufferedAudioDriftInternal(cameraId: cameraId, drift: drift)
        }
    }

    func setBufferedAudioTargetLatency(cameraId: UUID, latency: Double) {
        processorPipelineQueue.async {
            self.setBufferedAudioTargetLatencyInternal(cameraId: cameraId, latency: latency)
        }
    }

    private func addBufferedAudioInternal(cameraId: UUID, name: String, latency: Double) {
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

    private func removeBufferedAudioInternal(cameraId: UUID) {
        bufferedAudios.removeValue(forKey: cameraId)?.stopOutput()
        removeMixerSourceInternal(sourceId: cameraId)
    }

    private func appendBufferedAudioSampleBufferInternal(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        bufferedAudios[cameraId]?.appendSampleBuffer(sampleBuffer)
    }

    private func setBufferedAudioDriftInternal(cameraId: UUID, drift: Double) {
        bufferedAudios[cameraId]?.setDrift(drift: drift)
    }

    private func setBufferedAudioTargetLatencyInternal(cameraId: UUID, latency: Double) {
        bufferedAudios[cameraId]?.setTargetLatency(latency: latency)
    }

    func addMixerSource(sourceId: UUID) {
        processorPipelineQueue.async {
            self.addMixerSourceInternal(sourceId: sourceId)
        }
    }

    func removeMixerSource(sourceId: UUID) {
        processorPipelineQueue.async {
            self.removeMixerSourceInternal(sourceId: sourceId)
        }
    }

    func addMixerBuiltinSource() {
        processorPipelineQueue.async {
            self.addMixerSourceInternal(sourceId: self.builtinInputId)
        }
    }

    func removeMixerBuiltinSource() {
        processorPipelineQueue.async {
            self.removeMixerSourceInternal(sourceId: self.builtinInputId)
        }
    }

    private func addMixerSourceInternal(sourceId: UUID) {
        mixerSourceIds.insert(sourceId)
        if mixerSourceIds.count > 1 {
            ensureMixerStarted()
        }
    }

    private func removeMixerSourceInternal(sourceId: UUID) {
        mixerSourceIds.remove(sourceId)
        mixer?.remove(inputId: sourceId)
        mixerInputFormats.removeValue(forKey: sourceId)
        if mixerSourceIds.count <= 1 {
            stopMixer()
        }
    }

    private func shouldUseMixer() -> Bool {
        return mixerSourceIds.count > 1
    }

    private func ensureMixerStarted() {
        guard !mixerStarted else {
            return
        }
        mixerStarted = true
        mixer = AudioMixer(
            outputSampleRate: mixerOutputSampleRate,
            outputChannels: mixerOutputChannels,
            outputSamplesPerBuffer: mixerOutputSamplesPerBuffer
        )
        mixerInputFormats = [:]
        mixerOutputPresentationTimeStamp = currentPresentationTimeStamp()
        let interval = Double(mixerOutputSamplesPerBuffer) / mixerOutputSampleRate
        mixerProcessTimer.startPeriodic(interval: interval) { [weak self] in
            self?.processMixerOutput()
        }
        logger.info("audio-unit: Mixer started")
    }

    private func stopMixer() {
        guard mixerStarted else {
            return
        }
        mixerStarted = false
        mixerProcessTimer.stop()
        mixer = nil
        mixerInputFormats = [:]
        logger.info("audio-unit: Mixer stopped")
    }

    private func ensureMixerInput(inputId: UUID, sampleBuffer: CMSampleBuffer) {
        guard let mixer else {
            return
        }
        guard let formatDescription = sampleBuffer.formatDescription,
              let asbd = formatDescription.audioStreamBasicDescription
        else {
            return
        }
        let format = AVAudioFormat(
            standardFormatWithSampleRate: asbd.mSampleRate,
            channels: AVAudioChannelCount(asbd.mChannelsPerFrame)
        )!
        if mixerInputFormats[inputId] == nil {
            mixer.add(inputId: inputId, format: format)
            mixerInputFormats[inputId] = format
        }
    }

    private func appendToMixer(inputId: UUID, sampleBuffer: CMSampleBuffer) {
        guard let mixer else {
            return
        }
        ensureMixerInput(inputId: inputId, sampleBuffer: sampleBuffer)
        try? sampleBuffer.withAudioBufferList { audioBufferList, _ in
            guard let format = mixerInputFormats[inputId],
                  let pcmBuffer = AVAudioPCMBuffer(
                      pcmFormat: format,
                      bufferListNoCopy: audioBufferList.unsafePointer
                  )
            else {
                return
            }
            mixer.append(inputId: inputId, buffer: pcmBuffer)
        }
    }

    private func processMixerOutput() {
        guard let mixer, let processor else {
            return
        }
        guard let outputBuffer = mixer.process() else {
            return
        }
        let presentationTimeStamp = mixerOutputPresentationTimeStamp
        mixerOutputPresentationTimeStamp = presentationTimeStamp + CMTime(
            value: CMTimeValue(mixerOutputSamplesPerBuffer),
            timescale: CMTimeScale(mixerOutputSampleRate)
        )
        guard let sampleBuffer = outputBuffer.makeSampleBuffer(presentationTimeStamp) else {
            return
        }
        appendNewSampleBuffer(processor, sampleBuffer, presentationTimeStamp)
    }

    private func appendNewSampleBuffer(_ processor: Processor,
                                       _ sampleBuffer: CMSampleBuffer,
                                       _ presentationTimeStamp: CMTime)
    {
        guard let sampleBuffer = sampleBuffer.muted(muted) else {
            return
        }
        if speechToTextEnabled {
            processor.delegate?.streamAudio(sampleBuffer: sampleBuffer)
        }
        inputSourceFormat = sampleBuffer.formatDescription?.audioStreamBasicDescription
        encoder.appendSampleBuffer(sampleBuffer, presentationTimeStamp)
        processor.recorder.appendAudio(sampleBuffer, presentationTimeStamp)
    }

    private func appendBufferedBuiltinAudio(_ sampleBuffer: CMSampleBuffer,
                                            _ presentationTimeStamp: CMTime) -> BufferedAudio?
    {
        guard let bufferedBuiltinAudio, bufferedBuiltinAudio.latency > 0 else {
            return nil
        }
        var sampleBufferCopy: CMSampleBuffer
        if bufferedBuiltinAudio.numberOfBuffers() > 4 {
            sampleBufferCopy = sampleBuffer.deepCopyAudioSampleBuffer() ?? sampleBuffer
        } else {
            sampleBufferCopy = sampleBuffer
        }
        let presentationTimeStamp = presentationTimeStamp + CMTime(seconds: bufferedBuiltinAudio.latency)
        guard let sampleBuffer = sampleBufferCopy.replacePresentationTimeStamp(presentationTimeStamp) else {
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

    private func updateAudioLevel(
        sampleBuffer: CMSampleBuffer,
        audioLevel: Float,
        numberOfAudioChannels: Int
    ) {
        let sampleRate = sampleBuffer.formatDescription?.audioStreamBasicDescription?.mSampleRate ?? 0
        processor?.delegate?.stream(audioLevel: audioLevel,
                                    numberOfAudioChannels: numberOfAudioChannels,
                                    sampleRate: sampleRate)
    }
}

extension AudioUnit: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let processor else {
            return
        }
        // Workaround for audio drift on iPhone 15 Pro Max running iOS 17. Probably issue on more models.
        let presentationTimeStamp = syncTimeToVideo(processor: processor, sampleBuffer: sampleBuffer)
        var sampleBuffer = sampleBuffer
        if let bufferedAudio = appendBufferedBuiltinAudio(sampleBuffer, presentationTimeStamp) {
            sampleBuffer = bufferedAudio.getSampleBuffer(presentationTimeStamp.seconds) ?? sampleBuffer
        }
        if shouldUseMixer(), mixerSourceIds.contains(builtinInputId) {
            appendToMixer(inputId: builtinInputId, sampleBuffer: sampleBuffer)
        } else if selectedBufferedAudioId == nil, !shouldUseMixer() {
            if shouldUpdateAudioLevel(sampleBuffer) {
                var audioLevel: Float
                if muted {
                    audioLevel = .nan
                } else if let channel = connection.audioChannels.first {
                    audioLevel = channel.averagePowerLevel
                } else {
                    audioLevel = 0.0
                }
                updateAudioLevel(sampleBuffer: sampleBuffer,
                                 audioLevel: audioLevel,
                                 numberOfAudioChannels: connection.audioChannels.count)
            }
            appendNewSampleBuffer(processor, sampleBuffer, presentationTimeStamp)
        }
    }
}

extension AudioUnit: BufferedAudioSampleBufferDelegate {
    func didOutputBufferedSampleBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        guard let processor else {
            return
        }
        if shouldUseMixer(), mixerSourceIds.contains(cameraId) {
            appendToMixer(inputId: cameraId, sampleBuffer: sampleBuffer)
        } else if selectedBufferedAudioId == cameraId, !shouldUseMixer() {
            if shouldUpdateAudioLevel(sampleBuffer) {
                let numberOfAudioChannels = Int(
                    sampleBuffer.formatDescription?.numberOfAudioChannels() ?? 0
                )
                updateAudioLevel(sampleBuffer: sampleBuffer,
                                 audioLevel: .infinity,
                                 numberOfAudioChannels: numberOfAudioChannels)
            }
            appendNewSampleBuffer(processor, sampleBuffer, sampleBuffer.presentationTimeStamp)
        }
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
