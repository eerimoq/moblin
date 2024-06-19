// Adaptive bitrate algorithm from Belacoder.
// Designed by rationalsa for the BELABOX projecct.
// https://github.com/BELABOX/belacoder

import Collections
import Foundation

private let bitrateIncrMin: Int64 = (100 * 1000)
private let bitrateIncrInt: UInt64 = 400
private let bitrateIncrScale: Int64 = 30
private let bitrateDecrMin: Int64 = (100 * 1000)
private let bitrateDecrInt: UInt64 = 200
private let bitrateDecrFastInt: UInt64 = 250
private let bitrateDecrScale: Int64 = 10

let adaptiveBitrateBelaboxSettings = AdaptiveBitrateSettings(
    packetsInFlight: 200,
    rttDiffHighFactor: 0.9,
    rttDiffHighAllowedSpike: 50,
    rttDiffHighMinDecrease: 250_000,
    pifDiffIncreaseFactor: 100_000,
    minimumBitrate: 250_000
)

class AdaptiveBitrateSrtBela: AdaptiveBitrate {
    private var targetBitrate: Int64
    private var settings = adaptiveBitrateBelaboxSettings
    private var bsAvg: Double = 0
    private var bsJitter: Double = 0
    private var prevBs: Double = 0
    private var rttAvg: Double = 0
    private var rttAvgDelta: Double = 0
    private var prevRtt: Double = 300.0
    private var rttMin: Double = 200.0
    private var rttJitter: Double = 0.0
    private var throughput: Double = 0.0
    private var nextBitrateIncr: UInt64 = 0
    private var nextBitrateDecr: UInt64 = 0
    private var curBitrate: Int64 = 0

    init(targetBitrate: UInt32, delegate: AdaptiveBitrateDelegate) {
        self.targetBitrate = Int64(targetBitrate)
        super.init(delegate: delegate)
    }

    override func setTargetBitrate(bitrate: UInt32) {
        targetBitrate = Int64(bitrate)
    }

    override func setSettings(settings: AdaptiveBitrateSettings) {
        logger.info("adaptive-bitrate: Using settings \(settings)")
        self.settings = settings
    }

    override func getCurrentBitrate() -> UInt32 {
        return UInt32(curBitrate)
    }

    override func getCurrentMaximumBitrateInKbps() -> Int64 {
        return Int64(curBitrate) / 1000
    }

    private func rttToBs(rtt: Double, throughput: Double) -> Double {
        return (throughput / 8) * rtt / 1316
    }

    private func currentTimeMillis() -> UInt64 {
        return UInt64(NSDate().timeIntervalSince1970 * 1000)
    }

    private func updateBitrate(stats: StreamStats) {
        if stats.rttMs == 0 {
            return
        }
        if curBitrate == 0 {
            curBitrate = settings.minimumBitrate
        }
        let srtLatency = Double(stats.latency ?? 2000)
        let currentTimeMs = currentTimeMillis()
        let bs = stats.packetsInFlight
        // Rolling average
        bsAvg = bsAvg * 0.99 + bs * 0.01
        // Update the buffer size jitter
        bsJitter = 0.99 * bsJitter
        let deltaBs = bs - prevBs
        if deltaBs > bsJitter {
            bsJitter = deltaBs
        }
        prevBs = bs
        // Update the average RTT
        let rtt = stats.rttMs
        if rttAvg == 0.0 {
            rttAvg = rtt
        } else {
            rttAvg = rttAvg * 0.99 + 0.01 * rtt
        }
        // Update the average RTT delta
        let deltaRtt = rtt - prevRtt
        rttAvgDelta = rttAvgDelta * 0.8 + deltaRtt * 0.2
        prevRtt = rtt
        // Update the minimum RTT
        rttMin *= 1.001
        if rtt != 100 && rtt < rttMin && rttAvgDelta < 1.0 {
            rttMin = rtt
        }
        // Update the RTT jitter
        rttJitter *= 0.99
        if deltaRtt > rttJitter {
            rttJitter = deltaRtt
        }
        // Rolling average of the network throughput
        throughput *= 0.97
        throughput += (stats.mbpsSendRate! * 1000.0 * 1000.0 / 1024.0) * 0.03
        var bitrate = curBitrate
        let bsTh3 = (bsAvg + bsJitter) * 4
        var bsTh2 = max(50, bsAvg + max(bsJitter * 3.0, bsAvg))
        bsTh2 = min(bsTh2, rttToBs(rtt: srtLatency / 2, throughput: throughput))
        let bsTh1 = max(50, bsAvg + bsJitter * 2.5)
        let rttThMax = rttAvg + max(rttJitter * 4, rttAvg * 15 / 100)
        let rttThMin = rttMin + max(1, rttJitter * 2)
        if bitrate > settings.minimumBitrate && (rtt >= (srtLatency / 3) || bs > bsTh3) {
            bitrate = settings.minimumBitrate
            nextBitrateDecr = currentTimeMs + bitrateDecrInt
            logAdaptiveAcion(
                actionTaken: """
                Set min: \(bitrate / 1000), rtt: \(rtt) >= latency / 3: \(srtLatency / 3) \
                or bs: \(bs) > bs_th3: \(formatTwoDecimals(value: bsTh3))
                """
            )
        } else if currentTimeMs > nextBitrateDecr && (rtt > (srtLatency / 5) || bs > bsTh2) {
            bitrate -= (bitrateDecrMin + bitrate / bitrateDecrScale)
            nextBitrateDecr = currentTimeMs + bitrateDecrFastInt
            logAdaptiveAcion(
                actionTaken: """
                Fast decr: \((bitrateDecrMin + bitrate / bitrateDecrScale) / 1000), \
                rtt: \(rtt) > latency / 5: \(srtLatency / 5) or bs: \(bs) > bs_th2: \
                \(formatTwoDecimals(value: bsTh2))
                """
            )
        } else if currentTimeMs > nextBitrateDecr && (rtt > rttThMax || bs > bsTh1) {
            bitrate -= bitrateDecrMin
            nextBitrateDecr = currentTimeMs + bitrateDecrInt
            logAdaptiveAcion(
                actionTaken: """
                Decr: \(bitrateDecrMin / 1000), rtt: \(rtt) > rtt_th_max: \
                \(formatTwoDecimals(value: rttThMax)) or bs: \(bs) > bs_th1: \
                \(formatTwoDecimals(value: bsTh1))
                """
            )
        } else if currentTimeMs > nextBitrateIncr && rtt < rttThMin && rttAvgDelta < 0.01 {
            bitrate += bitrateIncrMin + bitrate / bitrateIncrScale
            nextBitrateIncr = currentTimeMs + bitrateIncrInt
            // logAdaptiveAcion(actionTaken: """
            //      Incr: \(bitrate_incr_min + bitrate / bitrate_incr_scale), \
            //      rtt: \(String(format:"%.2f", rtt)) < rtt_th_min: \(String(format:"%.2f",rtt_th_min)) \
            //      and rtt_avg_delta: \(String(format:"%.2f",rtt_avg_delta)) < 0.01
            //      """)
        }
        bitrate = max(min(bitrate, targetBitrate), settings.minimumBitrate)
        if bitrate != curBitrate {
            curBitrate = bitrate
            delegate.adaptiveBitrateSetVideoStreamBitrate(bitrate: UInt32(bitrate))
        }
    }

    override func update(stats: StreamStats) {
        updateBitrate(stats: stats)
        super.update(stats: stats)
    }
}
