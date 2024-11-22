class TargetLatenciesTracker {
    private let targetLatency: Double
    private var latestAudioPresentationTimeStamp: Double?
    private var latestVideoPresentationTimeStamp: Double?
    private var currentAudioVideoDiff: Double = .infinity
    
    init(targetLatency: Double) {
        self.targetLatency = targetLatency
    }
    
    func setLatestAudioPresentationTimeStamp(_ presentationTimeStamp: Double) {
        latestAudioPresentationTimeStamp = presentationTimeStamp
    }
    
    func setLatestVideoPresentationTimeStamp(_ presentationTimeStamp: Double) {
        latestVideoPresentationTimeStamp = presentationTimeStamp
    }
    
    func hasBothAudioAndVideo() -> Bool {
        return latestAudioPresentationTimeStamp != nil && latestVideoPresentationTimeStamp != nil
    }
    
    func update() -> (Double, Double)? {
        guard let latestVideoPresentationTimeStamp, let latestAudioPresentationTimeStamp else {
            return nil
        }
        let audioVideoDiff = latestAudioPresentationTimeStamp - latestVideoPresentationTimeStamp
        guard abs(audioVideoDiff - currentAudioVideoDiff) > 0.2 else {
            return nil
        }
        currentAudioVideoDiff = audioVideoDiff
        var videoTargetLatency = targetLatency
        var audioTargetLatency = targetLatency
        if audioVideoDiff > 0.0 {
            audioTargetLatency += audioVideoDiff
        } else {
            videoTargetLatency -= audioVideoDiff
        }
        return (audioTargetLatency, videoTargetLatency)
    }
}
