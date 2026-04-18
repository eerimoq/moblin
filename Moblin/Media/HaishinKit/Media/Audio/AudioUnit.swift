import AVFoundation
import Collections
import CoreAudio

private class TalkbackPlayer {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private(set) var isRunning = false

    func start(format: AVAudioFormat) {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
            playerNode.play()
            isRunning = true
        } catch {
            logger.info("talk-back-audio-player: Failed to start engine: \(error)")
        }
    }

    func stop() {
        playerNode.stop()
        engine.stop()
        engine.detach(playerNode)
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let pcmBuffer = makePcmBuffer(from: sampleBuffer) else {
            return
        }
        playerNode.scheduleBuffer(pcmBuffer)
    }

    private func makePcmBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = sampleBuffer.formatDescription,
              var asbd = formatDescription.audioStreamBasicDescription
        else {
            return nil
        }
        guard let format = AVAudioFormat(streamDescription: &asbd) else {
            return nil
        }
        let frameCount = AVAudioFrameCount(sampleBuffer.numSamples)
        guard frameCount > 0,
              let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else {
            return nil
        }
        pcmBuffer.frameLength = frameCount
        do {
            try sampleBuffer.withAudioBufferList { srcList, _ in
                let dstList = UnsafeMutableAudioBufferListPointer(pcmBuffer.mutableAudioBufferList)
                for i in 0 ..< min(srcList.count, dstList.count) {
                    guard let src = srcList[i].mData, let dst = dstList[i].mData else {
                        continue
                    }
                    let byteCount = Int(min(srcList[i].mDataByteSize, dstList[i].mDataByteSize))
                    dst.copyMemory(from: src, byteCount: byteCount)
                }
            }
        } catch {
            return nil
        }
        return pcmBuffer
    }
}

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
    unowned var processor: Processor?
    private var selectedBufferedAudioId: UUID?
    private var bufferedAudios: [UUID: BufferedAudio] = [:]
    let session = AVCaptureSession()
    private var speechToTextEnabled = false
    private var bufferedBuiltinAudio: BufferedAudio?
    private var latestAudioStatusTime = 0.0
    private var talkbackCameraId: UUID?
    private var talkbackPlayer: TalkbackPlayer?

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

    func setTalkback(cameraId: UUID?) {
        processorPipelineQueue.async {
            self.setTalkbackInternal(cameraId: cameraId)
        }
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

    private func setTalkbackInternal(cameraId: UUID?) {
        talkbackCameraId = cameraId
        if talkbackCameraId == nil {
            talkbackPlayer?.stop()
            talkbackPlayer = nil
        } else {
            talkbackPlayer = TalkbackPlayer()
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
        guard let sampleBuffer = sampleBuffer.muted(muted)?.withGain(gain) else {
            return
        }
        if shouldUpdateAudioLevel(sampleBuffer) {
            let numberOfAudioChannels = Int(
                sampleBuffer.formatDescription?.numberOfAudioChannels() ?? 0
            )
            let audioLevel: Float = muted ? .nan : sampleBuffer.audioLevel()
            updateAudioLevel(sampleBuffer: sampleBuffer,
                             audioLevel: audioLevel,
                             numberOfAudioChannels: numberOfAudioChannels)
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

    private func appendTalkback(sampleBuffer: CMSampleBuffer) {
        guard let talkbackPlayer else {
            return
        }
        if !talkbackPlayer.isRunning {
            guard let format = audioFormat(sampleBuffer: sampleBuffer) else {
                return
            }
            talkbackPlayer.start(format: format)
        }
        talkbackPlayer.appendSampleBuffer(sampleBuffer)
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

func audioFormat(sampleBuffer: CMSampleBuffer) -> AVAudioFormat? {
    guard var description = sampleBuffer.formatDescription?.audioStreamBasicDescription else {
        return nil
    }
    return AVAudioFormat(streamDescription: &description)
}

extension AudioUnit: BufferedAudioSampleBufferDelegate {
    func didOutputBufferedSampleBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        if cameraId == talkbackCameraId {
            appendTalkback(sampleBuffer: sampleBuffer)
        }
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
