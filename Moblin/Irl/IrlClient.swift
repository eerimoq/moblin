import AVFAudio
import CoreMedia
import Foundation

private let lockQueue = DispatchQueue(label: "com.eerimoq.moblin.irl", qos: .userInteractive)

// periphery:ignore
struct IrlClientStats {
    let rtt: Double
    let packetsInFlight: Double
}

// periphery:ignore
class IrlClient {
    init() {}

    func start() {
        lockQueue.async {
            logger.info("irl: client: Should start")
        }
    }

    func stop() {
        lockQueue.async {
            logger.info("irl: client: Should stop")
        }
    }

    func writeVideo(sampleBuffer: CMSampleBuffer) {
        lockQueue.async {
            logger.info("irl: client: Should write video \(sampleBuffer.presentationTimeStamp.seconds)")
        }
    }

    func writeAudio(buffer _: AVAudioBuffer, presentationTimeStamp: CMTime) {
        lockQueue.async {
            logger.info("irl: client: Should write audio \(presentationTimeStamp.seconds)")
        }
    }

    func writeVideoFormat(formatDescription: CMFormatDescription) {
        lockQueue.async {
            logger.info("irl: client: Should write video format \(formatDescription)")
        }
    }

    func writeAudioFormat(audioFormat: AVAudioFormat) {
        lockQueue.async {
            logger.info("irl: client: Should write audio format \(audioFormat)")
        }
    }

    func getStats() -> IrlClientStats {
        logger.info("irl: client: Should get stats")
        return IrlClientStats(rtt: 0, packetsInFlight: 0)
    }
}
