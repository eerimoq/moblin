import CoreMedia
import Foundation

// periphery:ignore
struct IrlClientStats {
    let rtt: Double
    let packetsInFlight: Double
}

// periphery:ignore
class IrlClient {
    init() {}

    func start() {
        logger.info("irl: Should start")
    }

    func stop() {
        logger.info("irl: Should stop")
    }

    func writeVideo(sampleBuffer: CMSampleBuffer) {
        logger.info("irl: Should write video \(sampleBuffer)")
    }

    func writeAudio(sampleBuffer: CMSampleBuffer) {
        logger.info("irl: Should write audio \(sampleBuffer)")
    }

    func getStats() -> IrlClientStats {
        logger.info("irl: Should get stats")
        return IrlClientStats(rtt: 0, packetsInFlight: 0)
    }
}
