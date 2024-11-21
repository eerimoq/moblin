import Collections
import CoreMedia

private enum AdjustDriftDirection {
    case up
    case down
    case none
}

class DriftTracker {
    private let media: String
    private let name: String
    private var targetLatency: Double
    private var estimatedLatency: Double
    private var latestEstimatedLatencyPresentationTimeStamp = 0.0
    private var latestAdjustDriftPresentationTimeStamp = 0.0
    private var drift = 0.0
    private var adjustDriftDirection: AdjustDriftDirection = .none

    init(media: String, name: String, targetLatency: Double) {
        self.media = media
        self.name = name
        self.targetLatency = targetLatency
        estimatedLatency = targetLatency
    }

    func setTargetLatency(targetLatency: Double) {
        logger.debug("replace-\(media): drift-tracker: \(name): Setting target latency to \(targetLatency)")
        self.targetLatency = targetLatency
        estimatedLatency = targetLatency
    }

    func setDrift(drift: Double) {
        logger.debug("""
        replace-\(media): drift-tracker: \(name): Set by other media to \(drift). \
        Drift: \(self.drift), Adjust direction: \(adjustDriftDirection)
        """)
        self.drift = drift
        adjustDriftDirection = .none
    }

    func getDrift() -> Double {
        return drift
    }

    func update(_ outputPresentationTimeStamp: Double, _ sampleBuffers: Deque<CMSampleBuffer>) -> Double? {
        guard outputPresentationTimeStamp > latestEstimatedLatencyPresentationTimeStamp + 0.5 else {
            return nil
        }
        latestEstimatedLatencyPresentationTimeStamp = outputPresentationTimeStamp
        let lastPresentationTimeStamp = sampleBuffers.last?.presentationTimeStamp.seconds ?? 0.0
        let firstPresentationTimeStamp = sampleBuffers.first?.presentationTimeStamp.seconds ?? 0.0
        let currentLatency = lastPresentationTimeStamp - firstPresentationTimeStamp
        estimatedLatency = estimatedLatency * 0.95 + currentLatency * 0.05
        if estimatedLatency < lowWaterMark() {
            adjustDriftDirection = .up
        } else if estimatedLatency > highWaterMark() {
            adjustDriftDirection = .down
        }
        guard outputPresentationTimeStamp > latestAdjustDriftPresentationTimeStamp + 10.0 else {
            return nil
        }
        latestAdjustDriftPresentationTimeStamp = outputPresentationTimeStamp
        switch adjustDriftDirection {
        case .up:
            drift += 0.01
            if estimatedLatency >= lowWaterMark() + 0.1 {
                adjustDriftDirection = .none
            }
        case .down:
            drift -= 0.01
            if estimatedLatency <= highWaterMark() - 0.1 {
                adjustDriftDirection = .none
            }
        case .none:
            return nil
        }
        logger.debug("""
        replace-\(media): drift-tracker: \(name): Estimated latency: \(estimatedLatency), \
        Drift: \(drift), Adjust direction: \(adjustDriftDirection)
        """)
        return drift
    }

    func lowWaterMark() -> Double {
        return max(targetLatency - 0.1, 0.1)
    }

    func highWaterMark() -> Double {
        return targetLatency + 0.3
    }
}
