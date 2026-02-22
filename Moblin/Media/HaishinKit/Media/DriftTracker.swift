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
    private var latestAdjustDriftPresentationTimeStamp = -1.0
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
        buffered-\(media): drift-tracker: \(name): Setting target fill level to \
        \(formatThreeDecimals(targetFillLevel)) (was \(formatThreeDecimals(self.targetFillLevel)))
        """)
        if targetFillLevel > self.targetFillLevel {
            estimatedFillLevel = targetFillLevel
        }
        self.targetFillLevel = targetFillLevel
    }

    func setDrift(drift: Double) {
        logger.debug("""
        buffered-\(media): drift-tracker: \(name): Other media set drift. \
        Estimated fill level \(formatThreeDecimals(estimatedFillLevel)) \
        (target \(formatThreeDecimals(targetFillLevel))), \
        Drift: \(formatThreeDecimals(self.drift)) -> \(formatThreeDecimals(drift))
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
        // Don't adjust too often to allow the moving average above to adjust.
        if latestAdjustDriftPresentationTimeStamp == -1 {
            latestAdjustDriftPresentationTimeStamp = outputPresentationTimeStamp
        }
        guard outputPresentationTimeStamp > latestAdjustDriftPresentationTimeStamp + 20.0 else {
            return nil
        }
        latestAdjustDriftPresentationTimeStamp = outputPresentationTimeStamp
        switch adjustDriftDirection {
        case .up:
            adjustDrift(adjustment: targetFillLevel - estimatedFillLevel)
        case .down:
            adjustDrift(adjustment: -(estimatedFillLevel - targetFillLevel))
        case .none:
            return nil
        }
        adjustDriftDirection = .none
        return drift
    }

    private func adjustDrift(adjustment: Double) {
        let drift = drift + adjustment
        logger.debug("""
        buffered-\(media): drift-tracker: \(name): \
        Estimated fill level \(formatThreeDecimals(estimatedFillLevel)) \
        (target \(formatThreeDecimals(targetFillLevel))), \
        Drift \(formatThreeDecimals(self.drift)) -> \(formatThreeDecimals(drift))
        """)
        self.drift = drift
    }

    private func lowWaterMark() -> Double {
        return max(targetFillLevel - 0.2, 0.1)
    }

    private func highWaterMark() -> Double {
        return targetFillLevel + 0.2
    }
}
