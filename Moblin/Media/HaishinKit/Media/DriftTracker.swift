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
            .map { ($0, estimateDeviation($0)) }
        guard let (state, deviation) = deviations.min(by: { $0.1 < $1.1 }) else {
            return
        }
        guard deviation < state.lowWaterMark() || deviation > 0.2 else {
            return
        }
        adjustDrift(deviation: deviation)
    }

    private func state(_ media: DriftTrackerMedia) -> DriftTrackerMediaState? {
        switch media {
        case .audio:
            audio
        case .video:
            video
        }
    }

    private func estimateDeviation(_ state: DriftTrackerMediaState) -> Double {
        state.fillLevels.sorted()[state.fillLevels.count / 2] + drift - state.targetFillLevel
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
