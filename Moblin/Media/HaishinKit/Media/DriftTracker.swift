import Collections

class DriftTracker {
    private let media: String
    private let name: String
    private var targetFillLevel: Double
    private var fillLevels: Deque<Double> = []
    private var latestFillLevelPresentationTimeStamp = 0.0
    private var latestAdjustDriftPresentationTimeStamp = -1.0
    private var drift = 0.0

    init(media: String, name: String, targetFillLevel: Double) {
        self.media = media
        self.name = name
        self.targetFillLevel = targetFillLevel
    }

    func setTargetFillLevel(targetFillLevel: Double) {
        logger.debug("""
        buffered-\(media): drift-tracker: \(name): Setting target fill level to \
        \(formatThreeDecimals(targetFillLevel)) (was \(formatThreeDecimals(self.targetFillLevel)))
        """)
        fillLevels.removeAll()
        self.targetFillLevel = targetFillLevel
    }

    func setDrift(drift: Double) {
        logger.debug("""
        buffered-\(media): drift-tracker: \(name): Other media set drift. \
        Drift: \(formatThreeDecimals(self.drift)) -> \(formatThreeDecimals(drift))
        """)
        self.drift = drift
    }

    func getDrift() -> Double {
        drift
    }

    func update(_ outputPresentationTimeStamp: Double, _ newestPresentationTimeStamp: Double) -> Double? {
        guard outputPresentationTimeStamp > latestFillLevelPresentationTimeStamp + 0.5 else {
            return nil
        }
        latestFillLevelPresentationTimeStamp = outputPresentationTimeStamp
        fillLevels.append(newestPresentationTimeStamp - outputPresentationTimeStamp)
        if fillLevels.count > 60 {
            fillLevels.removeFirst()
        }
        if latestAdjustDriftPresentationTimeStamp == -1 {
            latestAdjustDriftPresentationTimeStamp = outputPresentationTimeStamp
        }
        guard outputPresentationTimeStamp > latestAdjustDriftPresentationTimeStamp + 20.0 else {
            return nil
        }
        latestAdjustDriftPresentationTimeStamp = outputPresentationTimeStamp
        guard fillLevels.count >= 30 else {
            return nil
        }
        let estimatedFillLevel = fillLevels.sorted()[fillLevels.count / 2] + drift
        guard estimatedFillLevel < lowWaterMark() || estimatedFillLevel > highWaterMark() else {
            return nil
        }
        adjustDrift(estimatedFillLevel: estimatedFillLevel)
        return drift
    }

    private func adjustDrift(estimatedFillLevel: Double) {
        let drift = drift + targetFillLevel - estimatedFillLevel
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
