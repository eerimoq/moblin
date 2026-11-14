import AVFoundation
import Collections

class BufferedVideo {
    private var sampleBuffers: Deque<CMSampleBuffer> = []
    private var currentSampleBuffer: CMSampleBuffer?
    private var isInitialBuffering = true
    private var cameraId: UUID
    private let name: String
    private let update: Bool
    private weak let processor: Processor?
    private let driftTracker: DriftTracker?
    private var hasBufferBeenAppended = false
    private var stats = BufferedStats()
    let latency: Double

    init(
        cameraId: UUID,
        name: String,
        update: Bool,
        latency: Double,
        processor: Processor?,
        driftTracker: DriftTracker?
    ) {
        self.cameraId = cameraId
        self.name = name
        self.update = update
        self.latency = latency
        self.processor = processor
        self.driftTracker = driftTracker
        driftTracker?.addMedia(.video, targetFillLevel: latency)
    }

    deinit {
        processor?.delegate.streamVideoBufferedVideoRemoved(cameraId: cameraId)
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        hasBufferBeenAppended = true
        if let index = sampleBuffers
            .lastIndex(where: { $0.presentationTimeStamp < sampleBuffer.presentationTimeStamp })
        {
            sampleBuffers.insert(sampleBuffer, at: sampleBuffers.index(after: index))
        } else {
            sampleBuffers.prepend(sampleBuffer)
        }
    }

    func updateSampleBuffer(_ outputPresentationTimeStamp: Double, _ forceUpdate: Bool = false) {
        guard update || forceUpdate else {
            return
        }
        var sampleBuffer: CMSampleBuffer?
        var numberOfBuffersConsumed = 0
        let drift = driftTracker?.getDrift() ?? 0.0
        while let nextSampleBuffer = sampleBuffers.first {
            if sampleBuffers.count > 200 {
                sampleBuffer = nextSampleBuffer
                consumeBuffer(numberOfBuffersConsumed: &numberOfBuffersConsumed)
                continue
            }
            if hasBestBuffer(nextSampleBuffer, sampleBuffer, outputPresentationTimeStamp, drift) {
                break
            }
            sampleBuffer = nextSampleBuffer
            consumeBuffer(numberOfBuffersConsumed: &numberOfBuffersConsumed)
            markInitialBufferingComplete()
        }
        if !isInitialBuffering {
            updateStatsAndLog(outputPresentationTimeStamp,
                              sampleBuffer,
                              drift,
                              numberOfBuffersConsumed)
        }
        if sampleBuffer != nil {
            currentSampleBuffer = sampleBuffer
        }
        if !isInitialBuffering, hasBufferBeenAppended, update {
            hasBufferBeenAppended = false
            if let driftTracker, let newestSampleBuffer = sampleBuffers.last ?? currentSampleBuffer {
                driftTracker.update(media: .video,
                                    outputPresentationTimeStamp,
                                    newestSampleBuffer.presentationTimeStamp.seconds)
            }
        }
    }

    private func consumeBuffer(numberOfBuffersConsumed: inout Int) {
        sampleBuffers.removeFirst()
        numberOfBuffersConsumed += 1
    }

    private func updateStatsAndLog(_ outputPresentationTimeStamp: Double,
                                   _: CMSampleBuffer?,
                                   _ drift: Double,
                                   _ numberOfBuffersConsumed: Int)
    {
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

    // Break on first frame that is ahead in time.
    private func hasBestBuffer(_ nextSampleBuffer: CMSampleBuffer,
                               _ candidateSampleBuffer: CMSampleBuffer?,
                               _ outputPresentationTimeStamp: Double,
                               _ drift: Double) -> Bool
    {
        let nextPresentationTimeStamp = nextSampleBuffer.presentationTimeStamp.seconds + drift
        let delta = nextPresentationTimeStamp - outputPresentationTimeStamp
        guard delta > 0 else {
            return false
        }
        if candidateSampleBuffer != nil || delta > 0.01 {
            return true
        }
        return false
    }

    private func markInitialBufferingComplete() {
        if isInitialBuffering {
            processor?.delegate.streamVideoBufferedVideoReady(cameraId: cameraId)
        }
        isInitialBuffering = false
    }

    func setLatestSampleBuffer(_ sampleBuffer: CMSampleBuffer?) {
        currentSampleBuffer = sampleBuffer
    }

    func getLatestSampleBuffer() -> CMSampleBuffer? {
        currentSampleBuffer
    }

    func getSampleBuffer(_ presentationTimeStamp: CMTime) -> CMSampleBuffer? {
        currentSampleBuffer?.replacePresentationTimeStamp(presentationTimeStamp)
    }

    func numberOfBuffers() -> Int {
        sampleBuffers.count
    }
}
