import AVFAudio
import CoreMedia
import Foundation

private let lockQueue = DispatchQueue(label: "com.eerimoq.moblin.moblink", qos: .userInteractive)

// periphery:ignore
struct MoblinkClientStats {
    let rtt: Double
    let packetsInFlight: Double
}

// periphery:ignore
class MoblinkClient {
    init() {}

    func start() {
        lockQueue.async {
            logger.info("moblink: client: Should start")
        }
    }

    func stop() {
        lockQueue.async {
            logger.info("moblink: client: Should stop")
        }
    }

    func writeVideo(sampleBuffer: CMSampleBuffer) {
        lockQueue.async {
            logger.info("moblink: client: Should write video \(sampleBuffer.presentationTimeStamp.seconds)")
        }
    }

    func writeAudio(buffer _: AVAudioBuffer, presentationTimeStamp: CMTime) {
        lockQueue.async {
            logger.info("moblink: client: Should write audio \(presentationTimeStamp.seconds)")
        }
    }

    func writeVideoFormat(formatDescription: CMFormatDescription) {
        lockQueue.async {
            logger.info("moblink: client: Should write video format \(formatDescription)")
        }
    }

    func writeAudioFormat(audioFormat: AVAudioFormat) {
        lockQueue.async {
            logger.info("moblink: client: Should write audio format \(audioFormat)")
        }
    }

    func getStats() -> MoblinkClientStats {
        logger.info("moblink: client: Should get stats")
        return MoblinkClientStats(rtt: 0, packetsInFlight: 0)
    }
}
