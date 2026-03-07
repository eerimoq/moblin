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

final class AudioUnit: NSObject {
    let encoder = AudioEncoder(lockQueue: processorPipelineQueue)
    private var input: AVCaptureDeviceInput?
    private var output: AVCaptureAudioDataOutput?
    var muted = false
    var gain: Float = 1.0
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
            encoder.setInputSourceFormat(inputSourceFormat)
        }
    }

    func startRunning() {
        session.startRunning()
    }

    func stopRunning() {
        session.stopRunning()
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

    private func appendNewSampleBuffer(_ processor: Processor,
                                       _ sampleBuffer: CMSampleBuffer,
                                       _ presentationTimeStamp: CMTime)
    {
        guard let mutedSampleBuffer = sampleBuffer.muted(muted) else {
            return
        }
        if shouldUpdateAudioLevel(mutedSampleBuffer) {
            let numberOfAudioChannels = Int(
                mutedSampleBuffer.formatDescription?.numberOfAudioChannels() ?? 0
            )
            let audioLevel: Float = muted ? .nan : calculateAudioLevel(mutedSampleBuffer)
            updateAudioLevel(sampleBuffer: mutedSampleBuffer,
                             audioLevel: audioLevel,
                             numberOfAudioChannels: numberOfAudioChannels)
        }
        guard let sampleBuffer = mutedSampleBuffer.withGain(gain) else {
            return
        }
        if speechToTextEnabled {
            processor.delegate?.streamAudio(sampleBuffer: sampleBuffer)
        }
        inputSourceFormat = sampleBuffer.formatDescription?.audioStreamBasicDescription
        encoder.appendSampleBuffer(sampleBuffer, presentationTimeStamp)
        processor.recorder.appendAudio(sampleBuffer, presentationTimeStamp)
    }

    private func calculateAudioLevel(_ sampleBuffer: CMSampleBuffer) -> Float {
        guard let dataBuffer = sampleBuffer.dataBuffer else {
            return .infinity
        }
        guard let audioStreamBasicDescription = sampleBuffer.formatDescription?.audioStreamBasicDescription
        else {
            return .infinity
        }
        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(
            dataBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        )
        guard status == noErr, let dataPointer else {
            return .infinity
        }
        let isFloat = audioStreamBasicDescription.mFormatFlags & kAudioFormatFlagIsFloat != 0
        var sumOfSquares: Float = 0.0
        var count = 0
        if isFloat, audioStreamBasicDescription.mBitsPerChannel == 32 {
            count = length / MemoryLayout<Float>.size
            dataPointer.withMemoryRebound(to: Float.self, capacity: count) { samples in
                for index in 0 ..< count {
                    sumOfSquares += samples[index] * samples[index]
                }
            }
        } else if audioStreamBasicDescription.mBitsPerChannel == 16 {
            count = length / MemoryLayout<Int16>.size
            dataPointer.withMemoryRebound(to: Int16.self, capacity: count) { samples in
                for index in 0 ..< count {
                    let normalized = Float(samples[index]) / Float(Int16.max)
                    sumOfSquares += normalized * normalized
                }
            }
        }
        guard count > 0 else {
            return .infinity
        }
        let rms = sqrt(sumOfSquares / Float(count))
        guard rms > 0 else {
            return -160.0
        }
        return 20.0 * log10(rms)
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
        from _: AVCaptureConnection
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
        guard selectedBufferedAudioId == nil else {
            return
        }
        appendNewSampleBuffer(processor, sampleBuffer, presentationTimeStamp)
    }
}

extension AudioUnit: BufferedAudioSampleBufferDelegate {
    func didOutputBufferedSampleBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        guard selectedBufferedAudioId == cameraId, let processor else {
            return
        }
        appendNewSampleBuffer(processor, sampleBuffer, sampleBuffer.presentationTimeStamp)
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
