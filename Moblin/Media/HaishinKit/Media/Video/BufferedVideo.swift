import AVFoundation
import Collections

class BufferedVideo {
    private var sampleBuffers: Deque<CMSampleBuffer> = []
    private var currentSampleBuffer: CMSampleBuffer?
    private var isInitialBuffering = true
    private var cameraId: UUID
    private let name: String
    private let update: Bool
    private weak var processor: Processor?
    private let driftTracker: DriftTracker
    private var hasBufferBeenAppended = false
    private var stats = BufferedStats()
    let latency: Double

    init(cameraId: UUID, name: String, update: Bool, latency: Double, processor: Processor?) {
        self.cameraId = cameraId
        self.name = name
        self.update = update
        self.latency = latency
        self.processor = processor
        driftTracker = DriftTracker(media: "video", name: name, targetFillLevel: latency)
    }

    deinit {
        processor?.delegate?.streamVideoBufferedVideoRemoved(cameraId: cameraId)
    }

    func setTargetLatency(latency: Double) {
        driftTracker.setTargetFillLevel(targetFillLevel: latency)
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        hasBufferBeenAppended = true
        if let index = sampleBuffers
            .lastIndex(where: { $0.presentationTimeStamp < sampleBuffer.presentationTimeStamp })
        {
            sampleBuffers.insert(sampleBuffer, at: sampleBuffers.index(after: index))
        } else {
            sampleBuffers.append(sampleBuffer)
        }
    }

    func updateSampleBuffer(_ outputPresentationTimeStamp: Double, _ forceUpdate: Bool = false) {
        guard update || forceUpdate else {
            return
        }
        var sampleBuffer: CMSampleBuffer?
        var numberOfBuffersConsumed = 0
        let drift = driftTracker.getDrift()
        while let inputSampleBuffer = sampleBuffers.first {
            if currentSampleBuffer == nil {
                currentSampleBuffer = inputSampleBuffer
            }
            if sampleBuffers.count > 200 {
                sampleBuffer = inputSampleBuffer
                sampleBuffers.removeFirst()
                numberOfBuffersConsumed += 1
                continue
            }
            let inputPresentationTimeStamp = inputSampleBuffer.presentationTimeStamp.seconds + drift
            let inputOutputDelta = inputPresentationTimeStamp - outputPresentationTimeStamp
            // Break on first frame that is ahead in time.
            if inputOutputDelta > 0, sampleBuffer != nil || abs(inputOutputDelta) > 0.01 {
                break
            }
            sampleBuffer = inputSampleBuffer
            sampleBuffers.removeFirst()
            numberOfBuffersConsumed += 1
            markInitialBufferingComplete()
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
                buffered-video: \(name): \(duplicated) duplicated and \(dropped) dropped buffers. \
                Output \(formatThreeDecimals(outputPresentationTimeStamp)), \
                Current \(formatThreeDecimals(currentSampleBuffer?.presentationTimeStamp.seconds ?? 0.0)), \
                \(formatThreeDecimals(firstPresentationTimeStamp + drift))..\
                \(formatThreeDecimals(lastPresentationTimeStamp + drift)) \
                (\(formatThreeDecimals(fillLevel))), \
                Buffers \(sampleBuffers.count)
                """)
            }
        }
        if sampleBuffer != nil {
            currentSampleBuffer = sampleBuffer
        }
        if !isInitialBuffering, hasBufferBeenAppended, update {
            hasBufferBeenAppended = false
            if let drift = driftTracker.update(outputPresentationTimeStamp, sampleBuffers) {
                processor?.setBufferedAudioDrift(cameraId: cameraId, drift: drift)
            }
        }
    }

    private func markInitialBufferingComplete() {
        if isInitialBuffering {
            processor?.delegate?.streamVideoBufferedVideoReady(cameraId: cameraId)
        }
        isInitialBuffering = false
    }

    func setLatestSampleBuffer(_ sampleBuffer: CMSampleBuffer?) {
        currentSampleBuffer = sampleBuffer
    }

    func getSampleBuffer(_ presentationTimeStamp: CMTime) -> CMSampleBuffer? {
        return currentSampleBuffer?.replacePresentationTimeStamp(presentationTimeStamp)
    }

    func numberOfBuffers() -> Int {
        return sampleBuffers.count
    }

    func setDrift(drift: Double) {
        driftTracker.setDrift(drift: drift)
    }
}
