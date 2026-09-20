import Collections

enum DriftTrackerMedia {
    case audio
    case video
}

private class DriftTrackerMediaState {
    let targetFillLevel: Double
    var fillLevels: Deque<Double> = []
    var latestFillLevelPresentationTimeStamp = 0.0

    init(targetFillLevel: Double) {
        self.targetFillLevel = targetFillLevel
    }

    func lowWaterMark() -> Double {
        if targetFillLevel >= 0.1 {
            max(-0.2, -targetFillLevel / 2)
        } else {
            // Should do something better. The queue is likely close to empty.
            -targetFillLevel
        }
    }
}

class DriftTracker {
    private let name: String
    private var audio: DriftTrackerMediaState?
    private var video: DriftTrackerMediaState?
    private var latestAdjustDriftPresentationTimeStamp = -1.0
    private var drift = 0.0

    init(name: String) {
        self.name = name
    }

    func addMedia(_ media: DriftTrackerMedia, targetFillLevel: Double) {
        logger.debug("""
        drift-tracker: \(name): Adding \(media) with target fill level \(formatThreeDecimals(targetFillLevel))
        """)
        switch media {
        case .audio:
            audio = DriftTrackerMediaState(targetFillLevel: targetFillLevel)
        case .video:
            video = DriftTrackerMediaState(targetFillLevel: targetFillLevel)
        }
    }

    func getDrift() -> Double {
        drift
    }

    func setDrift(drift: Double) {
        self.drift = drift
    }

    func update(media: DriftTrackerMedia,
                _ outputPresentationTimeStamp: Double,
                _ newestPresentationTimeStamp: Double)
    {
        guard let state = state(media) else {
            return
        }
        guard outputPresentationTimeStamp > state.latestFillLevelPresentationTimeStamp + 0.5 else {
            return
        }
        state.latestFillLevelPresentationTimeStamp = outputPresentationTimeStamp
        state.fillLevels.append(newestPresentationTimeStamp - outputPresentationTimeStamp)
        if state.fillLevels.count > 60 {
            state.fillLevels.removeFirst()
        }
        if latestAdjustDriftPresentationTimeStamp == -1 {
            latestAdjustDriftPresentationTimeStamp = outputPresentationTimeStamp
        }
        guard outputPresentationTimeStamp > latestAdjustDriftPresentationTimeStamp + 20.0 else {
            return
        }
        latestAdjustDriftPresentationTimeStamp = outputPresentationTimeStamp
        let deviations = [audio, video]
            .compactMap { $0 }
            .filter {
                $0.fillLevels.count >= 30
                    && outputPresentationTimeStamp - $0.latestFillLevelPresentationTimeStamp < 20.0
            }
            .map { ($0, estimateDeviations($0)) }
        guard let (state, (_, upperDeviation)) = deviations.min(by: { $0.1.upper < $1.1.upper }),
              let lowerDeviation = deviations.map(\.1.lower).min()
        else {
            return
        }
        if upperDeviation < state.lowWaterMark() {
            adjustDrift(deviation: upperDeviation)
        } else if lowerDeviation > 0.2 {
            adjustDrift(deviation: lowerDeviation)
        }
    }

    private func state(_ media: DriftTrackerMedia) -> DriftTrackerMediaState? {
        switch media {
        case .audio:
            audio
        case .video:
            video
        }
    }

    private func estimateDeviations(_ state: DriftTrackerMediaState) -> (lower: Double, upper: Double) {
        let deviations = state.fillLevels.sorted().map { $0 + drift - state.targetFillLevel }
        return (deviations[deviations.count / 4], deviations[3 * deviations.count / 4])
    }

    private func adjustDrift(deviation: Double) {
        let drift = drift - deviation
        logger.debug("""
        drift-tracker: \(name): Estimated deviation from target \(formatThreeDecimals(deviation)), \
        Drift \(formatThreeDecimals(self.drift)) -> \(formatThreeDecimals(drift))
        """)
        self.drift = drift
    }
}
