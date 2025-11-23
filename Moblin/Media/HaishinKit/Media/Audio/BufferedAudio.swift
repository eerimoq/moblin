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
    private var outputCounter: Int64 = -1
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

    func numberOfBuffers() -> Int {
        return sampleBuffers.count
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

        // Compute frame duration (seconds) from frameLength and sampleRate when available.
        // Fall back to a sensible default if not initialized yet.
        let frameDuration: Double = (frameLength > 0 && sampleRate > 0) ? (frameLength / sampleRate) : 0.021

        // Keep track of the last effective input PTS we used during this call
        // Start from latestSampleBuffer (if any) so synthesized timestamps stay monotonic across calls.
        var prevInputPresentationTimeStamp = (latestSampleBuffer?.presentationTimeStamp.seconds ?? -Double.greatestFiniteMagnitude) + drift

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
                // update prevInputPresentationTimeStamp so subsequent ones are synthesized correctly
                let rawPts = inputSampleBuffer.presentationTimeStamp.seconds + drift
                prevInputPresentationTimeStamp = max(prevInputPresentationTimeStamp, rawPts)
                continue
            }

            // Raw input PTS from buffer (apply drift)
            let rawInputPresentationTimeStamp = inputSampleBuffer.presentationTimeStamp.seconds + drift

            // If raw PTS is not strictly greater than previous effective PTS, synthesize a monotonic PTS
            let inputPresentationTimeStamp: Double
            if rawInputPresentationTimeStamp <= prevInputPresentationTimeStamp {
                // synthesize by advancing one frameDuration from previous effective PTS
                inputPresentationTimeStamp = prevInputPresentationTimeStamp + frameDuration
            } else {
                inputPresentationTimeStamp = rawInputPresentationTimeStamp
            }

            // Update prev for next iteration
            prevInputPresentationTimeStamp = inputPresentationTimeStamp

            let inputOutputDelta = inputPresentationTimeStamp - outputPresentationTimeStamp
            // Break on first frame that is ahead in time.
            if hasBestBuffer(inputOutputDelta, sampleBuffer) {
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

    private func hasBestBuffer(_ inputOutputDelta: Double, _ sampleBuffer: CMSampleBuffer?) -> Bool {
        guard inputOutputDelta > 0 else {
            return false
        }
        if sampleBuffer != nil || abs(inputOutputDelta) > deltaLimit {
            return true
        }
        return false
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
