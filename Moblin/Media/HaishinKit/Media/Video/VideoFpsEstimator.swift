import Foundation

final class VideoFpsEstimator {
    weak var processor: Processor?
    private var framesCounter = 0
    private var latestReportedFps = -1
    private var nextFpsReportTime: Double = 0.0

    func update(_ presentationTimeStamp: Double, _ fps: Double) {
        if nextFpsReportTime == 0 {
            reportAndResetFps(fps: Int(fps), presentationTimeStamp)
        } else {
            framesCounter += 1
            if presentationTimeStamp > nextFpsReportTime {
                reportAndResetFps(fps: framesCounter / 2, presentationTimeStamp)
            }
        }
    }

    private func reportAndResetFps(fps: Int, _ presentationTimeStamp: Double) {
        if fps != latestReportedFps {
            processor?.delegate.streamVideoFps(fps: fps)
            latestReportedFps = fps
        }
        framesCounter = 0
        nextFpsReportTime = presentationTimeStamp + 2
    }
}
