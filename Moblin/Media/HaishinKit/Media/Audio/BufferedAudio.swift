import AVFoundation
import Collections

private let deltaLimit = 0.03

protocol BufferedAudioSampleBufferDelegate: AnyObject {
    func didOutputBufferedSampleBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer)
}

class BufferedAudio {
    private var cameraId: UUID
    private let name: String
    private weak var processor: Processor?
    private var sampleRate: Double = 0.0
    private var frameLength: Double = 0.0
    private var sampleBuffers: Deque<CMSampleBuffer> = []
    private var outputTimer = SimpleTimer(queue: processorPipelineQueue)
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
    private var stats = BufferedStats()
    private let manualOutput: Bool

    init(cameraId: UUID, name: String, latency: Double, processor: Processor?, manualOutput: Bool) {
        self.cameraId = cameraId
        self.name = name
        self.latency = latency
        self.processor = processor
        self.manualOutput = manualOutput
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
        if !isInitialBuffering {
            if numberOfBuffersConsumed == 0 {
                stats.incrementDuplicated()
            } else if numberOfBuffersConsumed > 1 {
                stats.incrementDropped(count: numberOfBuffersConsumed - 1)
            }
            if logger.debugEnabled, let (duplicated, dropped) = stats.getStats(outputPresentationTimeStamp) {
                let lastPresentationTimeStamp = sampleBuffers.last?.presentationTimeStamp.seconds ?? 0.0
                let firstPresentationTimeStamp = sampleBuffers.first?.presentationTimeStamp.seconds ?? 0.0
                let fillLevel = lastPresentationTimeStamp - firstPresentationTimeStamp
                logger.debug("""
                buffered-audio: \(name): \(duplicated) duplicated and \(dropped) dropped buffers. \
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
        if !isInitialBuffering, hasBufferBeenAppended, !manualOutput {
            hasBufferBeenAppended = false
            if let drift = driftTracker.update(outputPresentationTimeStamp, sampleBuffers) {
                processor?.setBufferedVideoDrift(cameraId: cameraId, drift: drift)
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
