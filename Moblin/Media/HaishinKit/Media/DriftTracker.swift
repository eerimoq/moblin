import Foundation

class DriftTracker {
    private let media: String
    private let name: String
    private var targetFillLevel: Double
    private var estimatedFillLevel: Double
    private var latestEstimatedFillLevelPresentationTimeStamp = 0.0
    private var latestAdjustDriftPresentationTimeStamp = -1.0
    private var drift = 0.0

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
        let estimatedFillLevel = estimatedFillLevel + drift - self.drift
        logger.debug("""
        buffered-\(media): drift-tracker: \(name): Other media set drift. \
        Estimated fill level \(formatThreeDecimals(self.estimatedFillLevel)) -> \
        \(formatThreeDecimals(estimatedFillLevel)) \
        (target \(formatThreeDecimals(targetFillLevel))), \
        Drift: \(formatThreeDecimals(self.drift)) -> \(formatThreeDecimals(drift))
        """)
        self.estimatedFillLevel = estimatedFillLevel
        self.drift = drift
    }

    func getDrift() -> Double {
        drift
    }

    func update(_ outputPresentationTimeStamp: Double, _ newestPresentationTimeStamp: Double) -> Double? {
        guard outputPresentationTimeStamp > latestEstimatedFillLevelPresentationTimeStamp + 0.5 else {
            return nil
        }
        latestEstimatedFillLevelPresentationTimeStamp = outputPresentationTimeStamp
        let currentFillLevel = newestPresentationTimeStamp + drift - outputPresentationTimeStamp
        estimatedFillLevel = estimatedFillLevel * 0.95 + currentFillLevel * 0.05
        // Don't adjust too often to allow the moving average above to adjust.
        if latestAdjustDriftPresentationTimeStamp == -1 {
            latestAdjustDriftPresentationTimeStamp = outputPresentationTimeStamp
        }
        guard outputPresentationTimeStamp > latestAdjustDriftPresentationTimeStamp + 20.0 else {
            return nil
        }
        latestAdjustDriftPresentationTimeStamp = outputPresentationTimeStamp
        guard estimatedFillLevel < lowWaterMark() || estimatedFillLevel > highWaterMark() else {
            return nil
        }
        adjustDrift(adjustment: targetFillLevel - estimatedFillLevel)
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
        if targetFillLevel >= 0.1 {
            max(targetFillLevel - 0.2, targetFillLevel / 2)
        } else {
            // Should do something better. The queue is likely close to empty.
            0
        }
    }

    private func highWaterMark() -> Double {
        targetFillLevel + 0.2
    }
}
