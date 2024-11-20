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
    private let targetLatency: Double
    private var estimatedLatency: Double
    private var latestEstimatedLatencyPresentationTimeStamp = 0.0
    private var latestAdjustDriftPresentationTimeStamp = 0.0
    private var drift = 0.0
    private var adjustDirection: AdjustDriftDirection = .none

    init(media: String, name: String, targetLatency: Double) {
        self.media = media
        self.name = name
        self.targetLatency = targetLatency
        estimatedLatency = targetLatency
    }

    func setDrift(drift: Double) {
        self.drift = drift
    }

    func getDrift() -> Double {
        return drift
    }

    func update(_ outputPresentationTimeStamp: Double, _ sampleBuffers: Deque<CMSampleBuffer>) {
        guard outputPresentationTimeStamp > latestEstimatedLatencyPresentationTimeStamp + 0.5 else {
            return
        }
        latestEstimatedLatencyPresentationTimeStamp = outputPresentationTimeStamp
        let lastPresentationTimeStamp = sampleBuffers.last?.presentationTimeStamp.seconds ?? 0.0
        let firstPresentationTimeStamp = sampleBuffers.first?.presentationTimeStamp.seconds ?? 0.0
        let currentLatency = lastPresentationTimeStamp - firstPresentationTimeStamp
        estimatedLatency = estimatedLatency * 0.95 + currentLatency * 0.05
        if estimatedLatency < lowWaterMark() {
            adjustDirection = .up
        } else if estimatedLatency > highWaterMark() {
            adjustDirection = .down
        }
        guard outputPresentationTimeStamp > latestAdjustDriftPresentationTimeStamp + 10.0 else {
            return
        }
        latestAdjustDriftPresentationTimeStamp = outputPresentationTimeStamp
        switch adjustDirection {
        case .up:
            drift += 0.01
            if estimatedLatency >= targetLatency {
                adjustDirection = .none
            }
        case .down:
            drift -= 0.01
            if estimatedLatency <= targetLatency {
                adjustDirection = .none
            }
        case .none:
            return
        }
        logger.debug("""
        replace-\(media): drift-tracker: \(name): Estimated latency: \(estimatedLatency), \
        Drift: \(drift), Adjust direction: \(adjustDirection)
        """)
    }

    func lowWaterMark() -> Double {
        return max(targetLatency - 0.1, 0.1)
    }

    func highWaterMark() -> Double {
        return targetLatency + 0.1
    }
}
