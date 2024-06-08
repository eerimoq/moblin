import Collections
import Foundation

protocol AdaptiveBitrateDelegate: AnyObject {
    func adaptiveBitrateSetVideoStreamBitrate(bitrate: UInt32)
}

struct StreamStats {
    let rttMs: Double
    let packetsInFlight: Double
    let transportBitrate: Int64?
}

struct AdaptiveBitrateSettings {
    var packetsInFlight: Int64
    var rttDiffHighFactor: Double
    var rttDiffHighAllowedSpike: Double
    var rttDiffHighMinDecrease: Int64
    var pifDiffIncreaseFactor: Int64
    var minimumBitrate: Int64
}

let adaptiveBitrateFastSettings = AdaptiveBitrateSettings(
    packetsInFlight: 200,
    rttDiffHighFactor: 0.9,
    rttDiffHighAllowedSpike: 50,
    rttDiffHighMinDecrease: 250_000,
    pifDiffIncreaseFactor: 100_000,
    minimumBitrate: 50000
)

let adaptiveBitrateSlowSettings = AdaptiveBitrateSettings(
    packetsInFlight: 500,
    rttDiffHighFactor: 0.95,
    rttDiffHighAllowedSpike: 100,
    rttDiffHighMinDecrease: 100_000,
    pifDiffIncreaseFactor: 25000,
    minimumBitrate: 50000
)

private struct ActionTaken {
    let timestamp: ContinuousClock.Instant
    let message: String

    init(message: String) {
        timestamp = .now
        self.message = message
    }
}

class AdaptiveBitrate {
    private var avgRtt: Double = 0.0
    private var fastRtt: Double = 0.0
    private var currentBitrate: Int64 = 500_000
    private var previousBitrate: Int64 = 500_000
    private var targetBitrate: Int64 = 500_000
    private var currentMaximumBitrate: Int64 = 500_000
    private var smoothPif: Double = 0
    private var fastPif: Double = 0
    private weak var delegate: (any AdaptiveBitrateDelegate)!
    private var actionsTaken: Deque<ActionTaken> = []
    private var settings = adaptiveBitrateFastSettings
    private let dateFormatter = DateFormatter()

    init(targetBitrate: UInt32, delegate: AdaptiveBitrateDelegate) {
        self.targetBitrate = Int64(targetBitrate)
        self.delegate = delegate
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
    }

    func setTargetBitrate(bitrate: UInt32) {
        targetBitrate = Int64(bitrate)
    }

    func setSettings(settings: AdaptiveBitrateSettings) {
        logger.info("adaptive-bitrate: Using settings \(settings)")
        self.settings = settings
    }

    private func calcPifs(_ stats: StreamStats) {
        if stats.packetsInFlight > smoothPif {
            smoothPif *= 0.97
            smoothPif += stats.packetsInFlight * 0.03
        } else {
            smoothPif *= 0.9
            smoothPif += stats.packetsInFlight * 0.1
        }
        fastPif *= 0.67
        fastPif += stats.packetsInFlight * 0.33
    }

    private func calcRtts(_ stats: StreamStats) {
        if avgRtt < 1 {
            avgRtt = stats.rttMs
        }
        if avgRtt > stats.rttMs {
            avgRtt *= 0.60
            avgRtt += stats.rttMs * 0.40
        } else {
            avgRtt *= 0.96
            if stats.rttMs < 450 {
                avgRtt += stats.rttMs * 0.04
            } else {
                avgRtt += 450 * 0.001
            }
        }
        if fastRtt > stats.rttMs {
            fastRtt *= 0.70
            fastRtt += stats.rttMs * 0.30
        } else {
            fastRtt *= 0.90
            fastRtt += stats.rttMs * 0.10
        }
        if avgRtt > 450 {
            avgRtt = 450
        }
    }

    private func increaseCurrentMaxBitrate(
        stats: StreamStats,
        allowedRttJitter: Double,
        allowedPifJitter: Double
    ) {
        var pifSpikeDiff = Int64(stats.packetsInFlight - smoothPif)
        if pifSpikeDiff < 0 {
            pifSpikeDiff = 0
        }
        if pifSpikeDiff > settings.packetsInFlight {
            pifSpikeDiff = settings.packetsInFlight
        }
        let pifDiffThing = settings.packetsInFlight - pifSpikeDiff
        if smoothPif < Double(settings.packetsInFlight), fastRtt <= avgRtt + allowedRttJitter {
            if stats.packetsInFlight - smoothPif < allowedPifJitter {
                currentMaximumBitrate += (settings.pifDiffIncreaseFactor * pifDiffThing) / settings
                    .packetsInFlight
                if currentMaximumBitrate > targetBitrate {
                    currentMaximumBitrate = targetBitrate
                }
            }
        }
    }

    private func decreaseMaxRateIfPifIsHigh(factor: Double, pifMax: Double, minimumDecrease: Int64) {
        guard smoothPif > pifMax else {
            return
        }
        let factorDecrease = Int64(Double(currentMaximumBitrate) * (1 - factor))
        let decrease = max(factorDecrease, minimumDecrease)
        currentMaximumBitrate -= decrease
        logAdaptiveAcion(
            actionTaken: """
            PIF: Decreasing bitrate by \(decrease / 1000)k, smooth \(Int(smoothPif)) > max \(Int(pifMax))
            """
        )
    }

    private func logAdaptiveAcion(actionTaken: String) {
        logger.debug("adaptive-bitrate: \(actionTaken)")
        let dateString = dateFormatter.string(from: Date())
        actionsTaken.append(ActionTaken(message: dateString + " " + actionTaken))
        while actionsTaken.count > 6 {
            actionsTaken.removeFirst()
        }
    }

    private func decreaseMaxRateIfRttIsHigh(factor: Double, rttMax: Double, minimumDecrease: Int64) {
        guard avgRtt > rttMax else {
            return
        }
        let factorDecrease = Int64(Double(currentMaximumBitrate) * (1 - factor))
        let decrease = max(factorDecrease, minimumDecrease)
        currentMaximumBitrate -= decrease
        logAdaptiveAcion(
            actionTaken: "RTT: Decrease bitrate by \(decrease), avg \(avgRtt) > max \(rttMax)"
        )
    }

    func getCurrentBitrate() -> UInt32 {
        return UInt32(currentBitrate)
    }

    func getCurrentBitrateInKbps() -> Int64 {
        return currentBitrate / 1000
    }

    func getCurrentMaximumBitrateInKbps() -> Int64 {
        return currentMaximumBitrate / 1000
    }

    func getActionsTaken() -> [String] {
        return actionsTaken.map { $0.message }
    }

    var getFastPif: Int64 {
        return Int64(fastPif)
    }

    var getSmoothPif: Int64 {
        return Int64(smoothPif)
    }

    private func decreaseMaxRateIfRttDiffIsHigh(
        _ stats: StreamStats,
        factor: Double,
        rttSpikeAllowed: Double,
        minimumDecrease: Int64
    ) {
        guard stats.rttMs > avgRtt + rttSpikeAllowed else {
            return
        }
        let factorDecrease = Int64(Double(currentMaximumBitrate) * (1 - factor))
        let decrease = max(factorDecrease, minimumDecrease)
        currentMaximumBitrate -= decrease
        logAdaptiveAcion(
            actionTaken: """
            RTT: Decreasing bitrate by \(decrease / 1000)k, \
            \(Int(stats.rttMs)) > avg + allow \(Int(avgRtt)) + \(Int(rttSpikeAllowed))
            """
        )
    }

    private func calculateCurrentBitrate(_ stats: StreamStats) {
        var pifSpikeDiff = Int64(fastPif) - Int64(smoothPif)
        // lazy decrease
        if pifSpikeDiff > settings.packetsInFlight {
            logAdaptiveAcion(
                actionTaken: "PIF: Lazy decrease diff \(pifSpikeDiff) > \(settings.packetsInFlight)"
            )
            currentMaximumBitrate = Int64(Double(currentMaximumBitrate) * 0.95)
        }
        if pifSpikeDiff <= (settings.packetsInFlight / 5) {
            pifSpikeDiff = 0
        }
        if pifSpikeDiff < 0 {
            pifSpikeDiff = 0
        }
        if pifSpikeDiff > settings.packetsInFlight {
            pifSpikeDiff = settings.packetsInFlight
        }
        // harder decrease
        if pifSpikeDiff == settings.packetsInFlight {
            currentMaximumBitrate -= 500_000
            logAdaptiveAcion(
                actionTaken: "PIF: -500 dec diff \(pifSpikeDiff) == \(settings.packetsInFlight)"
            )
        }
        let pifDiffThing = settings.packetsInFlight - pifSpikeDiff
        // To not push too high bitrate after static scene. The encoder may output way
        // lower bitrate than configured.
        if let transportBitrate = stats.transportBitrate {
            let maximumBitrate = max(transportBitrate + 1_000_000, (17 * transportBitrate) / 10)
            if currentMaximumBitrate > maximumBitrate {
                currentMaximumBitrate = maximumBitrate
            }
        }
        if currentMaximumBitrate < 250_000 {
            currentMaximumBitrate = 250_000
        }
        var tempBitrate = Int64(currentMaximumBitrate)
        tempBitrate *= Int64(pifDiffThing)
        tempBitrate /= Int64(settings.packetsInFlight)
        currentBitrate = Int64(tempBitrate)
        if currentBitrate < settings.minimumBitrate {
            currentBitrate = settings.minimumBitrate
        }
        // pif running away do a quick lower of bitrate temporarily
        if Int32(fastPif - smoothPif) > settings.packetsInFlight * 2 {
            currentBitrate = settings.minimumBitrate
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

    // NB:To be called every 200ms when live
    // Tested to 15000 sane bitrate, 2000ms latency, rtt generally under 100
    // Assuming rtt is generally < 100 under normal conditions means avg PIF < 100 up
    // to 15000 bitrate
    // rtt > 450 is unacceptable, 4 x 450 = 1800 just under 2000 ms for resend
    // latency
    // avg PIF can spike up to 200 but generally should be < 100
    // actual bitrate will bounce around quite a bit but should be moderately
    // invisible to viewer, the tempmax is the real calculated bitrate but conditions
    // fluctuate so much in IRL that we kind of bounce from 0 to tempmax this gives us
    // a higher overall bitrate and stops us from dropping the bitrate very low and
    // then taking forever to go back up
    func update(stats: StreamStats) {
        calcPifs(stats)
        calcRtts(stats)
        increaseCurrentMaxBitrate(stats: stats, allowedRttJitter: 15, allowedPifJitter: 10)
        // slow decreases if needed
        decreaseMaxRateIfPifIsHigh(factor: 0.9, pifMax: 100, minimumDecrease: 250_000)
        decreaseMaxRateIfRttIsHigh(factor: 0.9, rttMax: 250, minimumDecrease: 250_000)
        decreaseMaxRateIfRttDiffIsHigh(
            stats,
            factor: settings.rttDiffHighFactor,
            rttSpikeAllowed: settings.rttDiffHighAllowedSpike,
            minimumDecrease: settings.rttDiffHighMinDecrease
        )
        calculateCurrentBitrate(stats)
        if previousBitrate != currentBitrate {
            delegate.adaptiveBitrateSetVideoStreamBitrate(bitrate: UInt32(currentBitrate))
            previousBitrate = currentBitrate
        }
        removeOldActionsTaken()
    }
}
