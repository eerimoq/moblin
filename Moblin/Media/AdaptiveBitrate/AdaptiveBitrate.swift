import Collections
import Foundation

let adaptiveBitrateStart: Int64 = 1_000_000
let adaptiveBitrateTransportMinimum = adaptiveBitrateStart

protocol AdaptiveBitrateDelegate: AnyObject {
    func adaptiveBitrateSetVideoStreamBitrate(bitrate: UInt32)
}

struct StreamStats {
    let rttMs: Double
    let packetsInFlight: Double
    let transportBitrate: Int64?
    let latency: Int32?
    let mbpsSendRate: Double?
    let relaxed: Bool?
}

struct AdaptiveBitrateSettings {
    var packetsInFlight: Int64
    var rttDiffHighFactor: Double
    var rttDiffHighAllowedSpike: Double
    var rttDiffHighMinDecrease: Int64
    var pifDiffIncreaseFactor: Int64
    var minimumBitrate: Int64
}

private struct ActionTaken {
    let timestamp: ContinuousClock.Instant
    let message: String

    init(message: String) {
        timestamp = .now
        self.message = message
    }
}

class AdaptiveBitrate {
    weak var delegate: (any AdaptiveBitrateDelegate)?
    private var actionsTaken: Deque<ActionTaken> = []
    private let dateFormatter = DateFormatter()

    init(delegate: AdaptiveBitrateDelegate) {
        self.delegate = delegate
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
    }

    func setTargetBitrate(bitrate _: UInt32) {}

    func setSettings(settings _: AdaptiveBitrateSettings) {}

    func getCurrentBitrate() -> UInt32 {
        return 0
    }

    func getCurrentBitrateInKbps() -> Int64 {
        return Int64(getCurrentBitrate() / 1000)
    }

    func getCurrentMaximumBitrateInKbps() -> Int64 {
        return 0
    }

    func getFastPif() -> Int64 {
        return 0
    }

    func getSmoothPif() -> Int64 {
        return 0
    }

    func update(stats _: StreamStats) {
        removeOldActionsTaken()
    }

    func getActionsTaken() -> [String] {
        return actionsTaken.map { $0.message }
    }

    func logAdaptiveAcion(actionTaken: String) {
        logger.debug("adaptive-bitrate: \(actionTaken)")
        let dateString = dateFormatter.string(from: Date())
        actionsTaken.append(ActionTaken(message: dateString + " " + actionTaken))
        while actionsTaken.count > 6 {
            actionsTaken.removeFirst()
        }
    }

    private func removeOldActionsTaken() {
        let now = ContinuousClock.now
        while let actionTaken = actionsTaken.first {
            if actionTaken.timestamp.duration(to: now) > .seconds(15) {
                actionsTaken.removeFirst()
            } else {
                break
            }
        }
    }
}
