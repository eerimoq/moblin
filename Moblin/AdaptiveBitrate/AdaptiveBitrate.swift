import Foundation

protocol AdaptiveBitrateDelegate: AnyObject {
    func adaptiveBitrateSetVideoStreamBitrate(bitrate: UInt32)
}

struct StreamStats {
    let rttMs: Double
    let packetsInFlight: Double
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

class AdaptiveBitrate {
    private var avgRtt: Double = 0.0
    private var fastRtt: Double = 0.0
    private var currentBitrate: Int64 = 250_000
    private var previousBitrate: Int64 = 250_000
    private var targetBitrate: Int64 = 250_000
    private var currentMaximumBitrate: Int64 = 250_000
    private var smoothPif: Double = 0
    private var fastPif: Double = 0
    private weak var delegate: (any AdaptiveBitrateDelegate)!
    private var adaptiveActionsTaken: [String] = []
    private var settings = adaptiveBitrateFastSettings

    init(targetBitrate: UInt32, delegate: AdaptiveBitrateDelegate) {
        self.targetBitrate = Int64(targetBitrate)
        self.delegate = delegate
    }

    func setTargetBitrate(bitrate: UInt32) {
        targetBitrate = Int64(bitrate)
    }

    func setSettings(settings: AdaptiveBitrateSettings) {
        logger.info("adaptive-bitrate: Using settings \(settings)")
        self.settings = settings
    }

    private func calcRtts(_ stats: StreamStats) {
        if avgRtt < 1 {
            avgRtt = stats.rttMs
        }
        if avgRtt > stats.rttMs {
            avgRtt *= 0.60
            avgRtt += stats.rttMs * 0.40
        } else {
            avgRtt *= 0.99
            if stats.rttMs < 450 {
                avgRtt += stats.rttMs * 0.01
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
        avgRtt = avgRtt * 100.rounded() / 100
        fastRtt = fastRtt * 100.rounded() / 100
    }

    private func increaseTempMaxBitrate(
        stats: StreamStats,
        pif: Double,
        allowedRttJitter: Double,
        allowedPifJitter: Int64
    ) {
        var pifDiffThing = Int64(stats.packetsInFlight - pif)
        if pifDiffThing < 0 {
            pifDiffThing = 0
        }
        if pifDiffThing > settings.packetsInFlight {
            pifDiffThing = settings.packetsInFlight
        }
        pifDiffThing = settings.packetsInFlight - pifDiffThing
        if pif < Double(settings.packetsInFlight), fastRtt <= avgRtt + allowedRttJitter {
            if Int64(stats.packetsInFlight - pif) < allowedPifJitter {
                currentMaximumBitrate += (settings.pifDiffIncreaseFactor * pifDiffThing) / settings
                    .packetsInFlight
                if currentMaximumBitrate > targetBitrate {
                    currentMaximumBitrate = targetBitrate
                }
            }
        }
    }

    private func calcSmoothedPif(_ stats: StreamStats) {
        // increase slowly
        if stats.packetsInFlight > smoothPif {
            smoothPif *= 0.98
            smoothPif += stats.packetsInFlight * 0.02
        } else {
            // decrease fast because we really want to be closer to the ideal pif
            smoothPif *= 0.90
            smoothPif += stats.packetsInFlight * 0.1
        }

        fastPif *= 0.67
        fastPif += stats.packetsInFlight * 0.33
    }

    private func decreaseMaxRateIfPifIsHigh(
        factor: Double,
        pifMax: Double,
        minimumDecrease: Int64
    ) {
        if smoothPif > pifMax {
            let newMaxBitrate = Int64(Double(currentMaximumBitrate) * factor)
            let differece = currentMaximumBitrate - newMaxBitrate
            if differece < minimumDecrease {
                currentMaximumBitrate -= minimumDecrease
                logAdaptiveAcion(
                    actionTaken: """
                    PIF: decreasing bitrate by \(minimumDecrease / 1000)k, \
                    smoothpif \(Int(smoothPif)) > pifmax \(Int(pifMax))
                    """
                )
            } else {
                currentMaximumBitrate = Int64(Double(currentMaximumBitrate) * factor)
                logAdaptiveAcion(
                    actionTaken: """
                    PIF: decreasing bitrate by \(Int((100 * (1 - factor)).rounded()))%, \
                    smoothpif \(Int(smoothPif)) > pifmax \(Int(pifMax))
                    """
                )
            }
        }
    }

    private func logAdaptiveAcion(actionTaken: String) {
        logger.debug("adaptive-bitrate: \(actionTaken)")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        let dateString = dateFormatter.string(from: Date())
        adaptiveActionsTaken.append(dateString + " " + actionTaken)
        while adaptiveActionsTaken.count > 6 {
            adaptiveActionsTaken.remove(at: 0)
        }
    }

    private func decreaseMaxRateIfRttIsHigh(
        factor: Double,
        rttMax: Double,
        minimumDecrease: Int64
    ) {
        if avgRtt > rttMax {
            let newMaxBitrate = Int64(Double(currentMaximumBitrate) * factor)
            let differece = currentMaximumBitrate - newMaxBitrate

            if differece < minimumDecrease {
                currentMaximumBitrate -= minimumDecrease
                logAdaptiveAcion(
                    actionTaken: "RTT: dec bitrate by \(minimumDecrease), avgrtt: \(avgRtt) > rttmax: \(rttMax)"
                )

            } else {
                currentMaximumBitrate = newMaxBitrate
                logAdaptiveAcion(
                    actionTaken: "RTT: dec bitrate to \(factor) %, avgrtt: \(avgRtt) > rttmax: \(rttMax)"
                )
            }
        }
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

    var getAdaptiveActions: [String] {
        return adaptiveActionsTaken
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
        if stats.rttMs > avgRtt + rttSpikeAllowed {
            let newMaxBitrate = Int64(Double(currentMaximumBitrate) * factor)
            let differece = currentMaximumBitrate - newMaxBitrate
            if differece < minimumDecrease {
                currentMaximumBitrate -= minimumDecrease
                logAdaptiveAcion(
                    actionTaken: """
                    RTT: decreasing bitrate by \(minimumDecrease / 1000)k, msrtt \
                    \(Int(stats.rttMs)) > avgrtt + allow \(Int(avgRtt)) + \(Int(rttSpikeAllowed))
                    """
                )
            } else {
                currentMaximumBitrate = newMaxBitrate
                logAdaptiveAcion(
                    actionTaken: """
                    RTT: decreasing bitrate by \(Int((100 * (1 - factor)).rounded()))%, msrtt \(Int(stats
                            .rttMs)) > \
                    avgrtt + allow \(Int(avgRtt)) + \(Int(rttSpikeAllowed))
                    """
                )
            }
        }
    }

    private func calculateCurrentBitrate() {
        var pifDiffThing = Int64(fastPif) - Int64(smoothPif)
        // lazy decrease
        if pifDiffThing > settings.packetsInFlight {
            logAdaptiveAcion(
                actionTaken: "Lazy dec pifdiff \(pifDiffThing) > limit \(settings.packetsInFlight)"
            )
            currentMaximumBitrate = Int64(Double(currentMaximumBitrate) * 0.95)
        }
        if pifDiffThing <= (settings.packetsInFlight / 5) {
            pifDiffThing = 0
        }
        if pifDiffThing < 0 {
            pifDiffThing = 0
        }
        if pifDiffThing > settings.packetsInFlight {
            pifDiffThing = settings.packetsInFlight
        }
        // harder decrease
        if pifDiffThing == settings.packetsInFlight {
            currentMaximumBitrate -= 500_000
            logAdaptiveAcion(
                actionTaken: "-500 dec pifdiff \(pifDiffThing) = limit \(settings.packetsInFlight)"
            )
        }
        pifDiffThing = settings.packetsInFlight - pifDiffThing
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
        if Int32(fastPif) - Int32(smoothPif) > settings.packetsInFlight * 2 {
            currentBitrate = settings.minimumBitrate
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
        calcSmoothedPif(stats)
        calcRtts(stats)
        increaseTempMaxBitrate(
            stats: stats,
            pif: smoothPif,
            allowedRttJitter: 15,
            allowedPifJitter: 10
        )
        // slow decreases if needed
        decreaseMaxRateIfPifIsHigh(factor: 0.9, pifMax: 100, minimumDecrease: 250_000)
        decreaseMaxRateIfRttIsHigh(factor: 0.9, rttMax: 250, minimumDecrease: 250_000)
        decreaseMaxRateIfRttDiffIsHigh(
            stats,
            factor: settings.rttDiffHighFactor,
            rttSpikeAllowed: settings.rttDiffHighAllowedSpike,
            minimumDecrease: settings.rttDiffHighMinDecrease
        )
        calculateCurrentBitrate()
        if previousBitrate != currentBitrate {
            delegate.adaptiveBitrateSetVideoStreamBitrate(bitrate: UInt32(currentBitrate))
            previousBitrate = currentBitrate
        }
    }
}
