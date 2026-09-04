@preconcurrency import AVFoundation
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
            logger.info("audio-unit: Failed to start talkback player engine: \(error)")
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

struct AudioUnitAttachParams: @unchecked Sendable {
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

private class FastAudioMeasurement {
    private var nSamples: Int = 0
    private var curPeak: Float = 0.0
    private var squaresum: Float = 0.0

    private var fin_ms: Float = 0.0
    private var fin_peak: Float = 0.0

    func input(samples: UnsafeMutablePointer<Float>, count: Int, time _: Double) {
        for index in 0 ..< count {
            let sample = abs(samples[index])
            curPeak = max(curPeak, sample)
            squaresum += sample * sample
        }
        nSamples += count
    }

    func input(samples: UnsafeMutablePointer<Int16>, count: Int, time _: Double) {
        for index in 0 ..< count {
            let sample = abs(Float(samples[index]) / Float(Int16.max))
            curPeak = max(curPeak, sample)
            squaresum += sample * sample
        }
        nSamples += count
    }

    func finalize() { // before displaying. can still use input afterwards
        fin_peak = curPeak
        fin_ms = nSamples != 0 ? squaresum / Float(nSamples) : 0.0
        nSamples = 0
        curPeak = 0
        squaresum = 0
    }

    func reset() {
        nSamples = 0
        curPeak = 0.0
        squaresum = 0.0
        fin_ms = 0.0
        fin_peak = 0.0
    }

    func levelRMS() -> Float {
        10 * log10(fin_ms)
    }

    func peak() -> Float {
        20 * log10(fin_peak)
    }
}

final class AudioUnit: NSObject, @unchecked Sendable {
    let encoder = AudioEncoder(lockQueue: processorPipelineQueue)
    var previewEncoder: AudioEncoder?
    private var input: AVCaptureDeviceInput?
    private var output: AVCaptureAudioDataOutput?
    var muted = false
    var gain: Float = 1.0
    private var delay = 0.0
    weak var processor: Processor?
    private var selectedBufferedAudioId: UUID?
    private var bufferedAudios: [UUID: BufferedAudio] = [:]
    let session = AVCaptureSession()
    private var speechToTextEnabled = false
    private var bufferedBuiltinAudio: BufferedAudio?
    private var measurementWindowStart: Double?
    private let measurementWindowDuration = 0.05
    private let measurementWindowInterval = 0.2
    private var talkbackCameraId: UUID?
    private var talkbackPlayer: TalkbackPlayer?
    private var latestSampleBufferAppendTime: CMTime = .zero
    private var numberOfDiscardedSampleBuffers = 0
    private var meas = FastAudioMeasurement()

    private var inputSourceFormat: AudioStreamBasicDescription? {
        didSet {
            guard inputSourceFormat != oldValue else {
                return
            }
            encoder.setInputSourceFormat(inputSourceFormat)
            previewEncoder?.setInputSourceFormat(inputSourceFormat)
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
                manualOutput: true,
                trackDrift: true
            )
        }
        if let device = params.device {
            try attachDevice(device)
        }
        measurementWindowStart = nil
        meas.reset()
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

    func startPreviewEncoding(_ delegate: any AudioEncoderDelegate, settings: AudioEncoderSettings) {
        let encoder = AudioEncoder(lockQueue: processorPipelineQueue)
        encoder.setSettings(settings: settings)
        encoder.delegate = delegate
        encoder.startRunning()
        processorPipelineQueue.async {
            if let inputSourceFormat = self.inputSourceFormat {
                encoder.setInputSourceFormat(inputSourceFormat)
            }
            self.previewEncoder = encoder
        }
    }

    func stopPreviewEncoding() {
        processorPipelineQueue.async {
            self.previewEncoder?.stopRunning()
            self.previewEncoder = nil
        }
    }

    func setDelay(delay: Double) {
        processorPipelineQueue.async {
            self.delay = delay
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

    func addBufferedAudio(cameraId: UUID, name: String, latency: Double, trackDrift: Bool) {
        processorPipelineQueue.async {
            self.addBufferedAudioInternal(cameraId: cameraId,
                                          name: name,
                                          latency: latency,
                                          trackDrift: trackDrift)
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
        talkbackPlayer?.stop()
        talkbackPlayer = nil
        if talkbackCameraId != nil {
            talkbackPlayer = TalkbackPlayer()
        }
    }

    private func addBufferedAudioInternal(cameraId: UUID,
                                          name: String,
                                          latency: Double,
                                          trackDrift: Bool)
    {
        let bufferedAudio = BufferedAudio(
            cameraId: cameraId,
            name: name,
            latency: latency,
            processor: processor,
            manualOutput: false,
            trackDrift: trackDrift
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
        let presentationTimeStamp = presentationTimeStamp + CMTime(
            seconds: delay,
            preferredTimescale: presentationTimeStamp.timescale
        )
        guard presentationTimeStamp > latestSampleBufferAppendTime else {
            numberOfDiscardedSampleBuffers += 1
            return
        }
        if numberOfDiscardedSampleBuffers > 0 {
            logger.info(
                """
                audio-unit: Discarded \(numberOfDiscardedSampleBuffers) old buffers before \
                \(presentationTimeStamp.seconds)
                """
            )
            numberOfDiscardedSampleBuffers = 0
        }

        latestSampleBufferAppendTime = presentationTimeStamp
        let now = sampleBuffer.presentationTimeStamp.seconds

        let measurementWindowStart = measurementWindowStart ?? now
        self.measurementWindowStart = measurementWindowStart

        if now >= measurementWindowStart {
            let numberOfAudioChannels = Int(
                sampleBuffer.formatDescription?.numberOfAudioChannels() ?? 0
            )
            performMeasurement(sampleBuffer)
            if now >= measurementWindowStart + measurementWindowDuration {
                self.measurementWindowStart = measurementWindowStart + measurementWindowInterval
                meas.finalize()
                let audioLevel: Float = muted ? .nan : meas.peak()
                updateAudioLevel(
                    sampleBuffer: sampleBuffer,
                    audioLevel: audioLevel,
                    numberOfAudioChannels: numberOfAudioChannels
                )
            }
        }

        if speechToTextEnabled {
            processor.delegate.streamAudio(sampleBuffer: sampleBuffer)
        }
        inputSourceFormat = sampleBuffer.formatDescription?.audioStreamBasicDescription
        encoder.appendSampleBuffer(sampleBuffer, presentationTimeStamp)
        processor.recorder.appendAudio(sampleBuffer, presentationTimeStamp)
        previewEncoder?.appendSampleBuffer(sampleBuffer, presentationTimeStamp)
    }

    private func performMeasurement(_ sampleBuffer: CMSampleBuffer) {
        _ = sampleBuffer.foreachAudioSample(float32: {
            samples, count in
            meas.input(samples: samples, count: count, time: sampleBuffer.presentationTimeStamp.seconds)
        }, int16: {
            samples, count in
            meas.input(samples: samples, count: count, time: sampleBuffer.presentationTimeStamp.seconds)
        })
    }

    private func appendBufferedBuiltinAudio(_ sampleBuffer: CMSampleBuffer,
                                            _ presentationTimeStamp: CMTime) -> BufferedAudio?
    {
        guard let bufferedBuiltinAudio, bufferedBuiltinAudio.latency > 0 else {
            return nil
        }
        let sampleBufferCopy: CMSampleBuffer = if bufferedBuiltinAudio.numberOfBuffers() > 4 {
            sampleBuffer.deepCopyAudioSampleBuffer() ?? sampleBuffer
        } else {
            sampleBuffer
        }
        let presentationTimeStamp = presentationTimeStamp + CMTime(seconds: bufferedBuiltinAudio.latency)
        guard let sampleBuffer = sampleBufferCopy.replacePresentationTimeStamp(presentationTimeStamp) else {
            return nil
        }
        bufferedBuiltinAudio.appendSampleBuffer(sampleBuffer)
        return bufferedBuiltinAudio
    }

    private func updateAudioLevel(
        sampleBuffer: CMSampleBuffer,
        audioLevel: Float,
        numberOfAudioChannels: Int
    ) {
        let sampleRate = sampleBuffer.formatDescription?.audioStreamBasicDescription?.mSampleRate ?? 0
        processor?.delegate.streamAudioLevel(audioLevel: audioLevel,
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

// private var baseTimestamp: Double = .nan
// private var previousTimestamp: Double = 0.0
// private var previousSyncedTimestamp: Double = 0.0
// private var sampleCounter: Double = 0.0
// private var nowStart: ContinuousClock.Instant?

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
        let presentationTimeStamp = syncTimeToHost(processor: processor, sampleBuffer: sampleBuffer)
        // if baseTimestamp.isNaN {
        //     baseTimestamp = sampleBuffer.presentationTimeStamp.seconds
        // }
        // if nowStart == nil {
        //     nowStart = .now
        // }
        // let timestamp = sampleBuffer.presentationTimeStamp.seconds - baseTimestamp
        // let syncedTimestamp = presentationTimeStamp.seconds - baseTimestamp
        // let delta = timestamp - previousTimestamp
        // let deltaSynced = syncedTimestamp - previousSyncedTimestamp
        // let sampleRate = sampleBuffer.formatDescription?.audioStreamBasicDescription?.mSampleRate ?? 0
        // let numSamples = sampleBuffer.numSamples
        // let hostTime = currentPresentationTimeStamp().seconds - baseTimestamp
        // let sampleTime = sampleCounter / sampleRate
        // let now = nowStart!.duration(to: .now).seconds
        // logger.info("""
        // xxx audio \
        // r: \(sampleRate) ns: \(numSamples) \
        // t: \(formatFourDecimals(timestamp)) ts: \(formatFourDecimals(syncedTimestamp)) \
        // d: \(formatFourDecimals(delta)) ds: \(formatFourDecimals(deltaSynced)) \
        // c: \(formatFourDecimals(sampleTime)) \
        // h: \(formatFourDecimals(hostTime)) n: \(formatFourDecimals(now))
        // """)
        // if delta > 0.03 || delta < 0.01 || deltaSynced > 0.03 || deltaSynced < 0.01 {
        //     logger.info("""
        //     xxx audio abnormal \
        //     r: \(sampleRate) ns: \(numSamples) \
        //     t: \(formatFourDecimals(timestamp)) ts: \(formatFourDecimals(syncedTimestamp)) \
        //     d: \(formatFourDecimals(delta)) ds: \(formatFourDecimals(deltaSynced)) \
        //     c: \(formatFourDecimals(sampleTime)) \
        //     h: \(formatFourDecimals(hostTime)) n: \(formatFourDecimals(now))
        //     """)
        // }
        // sampleCounter += Double(numSamples)
        // previousTimestamp = timestamp
        // previousSyncedTimestamp = syncedTimestamp
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

private func syncTimeToHost(processor: Processor, sampleBuffer: CMSampleBuffer) -> CMTime {
    var presentationTimeStamp = sampleBuffer.presentationTimeStamp
    if let audioClock = processor.audio.session.synchronizationClock {
        let audioTimescale = sampleBuffer.presentationTimeStamp.timescale
        let seconds = audioClock.convertTime(presentationTimeStamp, to: CMClockGetHostTimeClock()).seconds
        let value = CMTimeValue(seconds * Double(audioTimescale))
        presentationTimeStamp = CMTime(value: value, timescale: audioTimescale)
    }
    return presentationTimeStamp
}
