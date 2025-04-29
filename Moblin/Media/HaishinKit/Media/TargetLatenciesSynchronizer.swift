class TargetLatenciesSynchronizer {
    private let targetLatency: Double
    private var latestAudioPresentationTimeStamp: Double?
    private var latestVideoPresentationTimeStamp: Double?
    private var currentAudioVideoDiff: Double = .infinity
    private var estimatedAudioVideoDiff: Double = .zero

    init(targetLatency: Double) {
        self.targetLatency = targetLatency
    }

    func setLatestAudioPresentationTimeStamp(_ presentationTimeStamp: Double) {
        latestAudioPresentationTimeStamp = presentationTimeStamp
    }

    func setLatestVideoPresentationTimeStamp(_ presentationTimeStamp: Double) {
        latestVideoPresentationTimeStamp = presentationTimeStamp
    }

    func update() -> (Double, Double)? {
        guard let latestAudioPresentationTimeStamp, let latestVideoPresentationTimeStamp else {
            return nil
        }
        let audioVideoDiff = latestAudioPresentationTimeStamp - latestVideoPresentationTimeStamp
        self.latestAudioPresentationTimeStamp = nil
        self.latestVideoPresentationTimeStamp = nil
        estimatedAudioVideoDiff = estimatedAudioVideoDiff * 0.98 + audioVideoDiff * 0.02
        guard abs(estimatedAudioVideoDiff - currentAudioVideoDiff) > 0.1 else {
            return nil
        }
        currentAudioVideoDiff = estimatedAudioVideoDiff
        var videoTargetLatency = targetLatency
        var audioTargetLatency = targetLatency
        if audioVideoDiff > 0.0 {
            audioTargetLatency += currentAudioVideoDiff
        } else {
            videoTargetLatency -= currentAudioVideoDiff
        }
        return (audioTargetLatency, videoTargetLatency)
    }
}
