import AVFAudio
import CoreMedia
import Foundation

private let lockQueue = DispatchQueue(label: "com.eerimoq.moblin.mirl", qos: .userInteractive)

// periphery:ignore
struct MirlClientStats {
    let rtt: Double
    let packetsInFlight: Double
}

// periphery:ignore
class MirlClient {
    init() {}

    func start() {
        lockQueue.async {
            logger.info("mirl: client: Should start")
        }
    }

    func stop() {
        lockQueue.async {
            logger.info("mirl: client: Should stop")
        }
    }

    func writeVideo(sampleBuffer: CMSampleBuffer) {
        lockQueue.async {
            logger.info("mirl: client: Should write video \(sampleBuffer.presentationTimeStamp.seconds)")
        }
    }

    func writeAudio(buffer _: AVAudioBuffer, presentationTimeStamp: CMTime) {
        lockQueue.async {
            logger.info("mirl: client: Should write audio \(presentationTimeStamp.seconds)")
        }
    }

    func writeVideoFormat(formatDescription: CMFormatDescription) {
        lockQueue.async {
            logger.info("mirl: client: Should write video format \(formatDescription)")
        }
    }

    func writeAudioFormat(audioFormat: AVAudioFormat) {
        lockQueue.async {
            logger.info("mirl: client: Should write audio format \(audioFormat)")
        }
    }

    func getStats() -> MirlClientStats {
        logger.info("mirl: client: Should get stats")
        return MirlClientStats(rtt: 0, packetsInFlight: 0)
    }
}
