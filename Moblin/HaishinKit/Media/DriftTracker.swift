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
    private var targetFillLevel: Double
    private var estimatedFillLevel: Double
    private var latestEstimatedFillLevelPresentationTimeStamp = 0.0
    private var latestAdjustDriftPresentationTimeStamp = 0.0
    private var drift = 0.0
    private var adjustDriftDirection: AdjustDriftDirection = .none

    init(media: String, name: String, targetFillLevel: Double) {
        self.media = media
        self.name = name
        self.targetFillLevel = targetFillLevel
        estimatedFillLevel = targetFillLevel
    }

    func setTargetFillLevel(targetFillLevel: Double) {
        logger.debug("""
        replace-\(media): drift-tracker: \(name): Setting target fill level to \(
            targetFillLevel
        ) \
        (was \(self.targetFillLevel)
        """)
        let newMinusOldDiff = targetFillLevel - self.targetFillLevel
        if newMinusOldDiff < 0 {
            drift -= newMinusOldDiff
        }
        self.targetFillLevel = targetFillLevel
        estimatedFillLevel = targetFillLevel
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
        guard outputPresentationTimeStamp > latestEstimatedFillLevelPresentationTimeStamp + 0.5 else {
            return nil
        }
        latestEstimatedFillLevelPresentationTimeStamp = outputPresentationTimeStamp
        let lastPresentationTimeStamp = sampleBuffers.last?.presentationTimeStamp.seconds ?? 0.0
        let firstPresentationTimeStamp = sampleBuffers.first?.presentationTimeStamp.seconds ?? 0.0
        let currentFillLevel = lastPresentationTimeStamp - firstPresentationTimeStamp
        estimatedFillLevel = estimatedFillLevel * 0.95 + currentFillLevel * 0.05
        if estimatedFillLevel < lowWaterMark() {
            adjustDriftDirection = .up
        } else if estimatedFillLevel > highWaterMark() {
            adjustDriftDirection = .down
        }
        guard outputPresentationTimeStamp > latestAdjustDriftPresentationTimeStamp + 10.0 else {
            return nil
        }
        latestAdjustDriftPresentationTimeStamp = outputPresentationTimeStamp
        switch adjustDriftDirection {
        case .up:
            drift += 0.01
            if estimatedFillLevel > lowWaterMark() + 0.1 {
                adjustDriftDirection = .none
            }
        case .down:
            drift -= 0.01
            if estimatedFillLevel < highWaterMark() - 0.1 {
                adjustDriftDirection = .none
            }
        case .none:
            return nil
        }
        logger.debug("""
        replace-\(media): drift-tracker: \(name): Estimated fill level: \(estimatedFillLevel), \
        Drift: \(drift), Adjust direction: \(adjustDriftDirection)
        """)
        return drift
    }

    func lowWaterMark() -> Double {
        return max(targetFillLevel - 0.1, 0.1)
    }

    func highWaterMark() -> Double {
        return targetFillLevel + 0.3
    }
}
