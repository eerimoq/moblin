// Adaptive bitrate algorithm from Belacoder.
// Designed by rationalsa for the BELABOX projecct.
// https://github.com/BELABOX/belacoder

import Collections
import Foundation

class AdaptiveBitrateSrtBela: AdaptiveBitrate {
    private var targetBitrate: Int64
    private var settings = adaptiveBitrateFastSettings
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
        let nowDouble = NSDate().timeIntervalSince1970
        return UInt64(nowDouble * 1000)
    }

    private func updateBitrate(stats: StreamStats) {
        if stats.rttMs == 0 {
            return
        }

        if curBitrate == 0 {
            curBitrate = settings.minimumBitrate
        }

        let srt_latency = Double(stats.latency ?? 2000)

        let ctime: UInt64 = currentTimeMillis()
        let bs: Double = stats.packetsInFlight

        // Rolling average
        bsAvg = bsAvg * 0.99 + bs * 0.01

        // Update the buffer size jitter
        bsJitter = 0.99 * bsJitter
        let delta_bs: Double = bs - prevBs
        if delta_bs > bsJitter {
            bsJitter = delta_bs
        }
        prevBs = bs

        // Update the average RTT
        let rtt: Double = stats.rttMs
        if rttAvg == 0.0 {
            rttAvg = rtt
        } else {
            rttAvg = rttAvg * 0.99 + 0.01 * rtt
        }

        // Update the average RTT delta
        let delta_rtt: Double = rtt - prevRtt
        rttAvgDelta = rttAvgDelta * 0.8 + delta_rtt * 0.2
        prevRtt = rtt

        // Update the minimum RTT
        rttMin *= 1.001
        if rtt != 100 && rtt < rttMin && rttAvgDelta < 1.0 {
            rttMin = rtt
        }

        // Update the RTT jitter
        rttJitter *= 0.99
        if delta_rtt > rttJitter {
            rttJitter = delta_rtt
        }

        // Rolling average of the network throughput
        throughput *= 0.97
        throughput += (stats.mbpsSendRate! * 1000.0 * 1000.0 / 1024.0) * 0.03

        var bitrate: Int64 = curBitrate

        let bs_th3 = (bsAvg + bsJitter) * 4
        var bs_th2 = max(50, bsAvg + max(bsJitter * 3.0, bsAvg))
        bs_th2 = min(bs_th2, rttToBs(rtt: srt_latency / 2, throughput: throughput))
        let bs_th1 = max(50, bsAvg + bsJitter * 2.5)
        let rtt_th_max = rttAvg + max(rttJitter * 4, rttAvg * 15 / 100)
        let rtt_th_min = rttMin + max(1, rttJitter * 2)

        let bitrate_incr_min: Int64 = (100 * 1000)
        let bitrate_incr_int: UInt64 = 400
        let bitrate_incr_scale: Int64 = 30

        let bitrate_decr_min: Int64 = (100 * 1000)
        let bitrate_decr_int: UInt64 = 200
        let bitrate_decr_fast_int: UInt64 = 250
        let bitrate_decr_scale: Int64 = 10

        if bitrate > settings.minimumBitrate && (rtt >= (srt_latency / 3) || bs > bs_th3) {
            bitrate = settings.minimumBitrate
            nextBitrateDecr = ctime + bitrate_decr_int
            logAdaptiveAcion(
                actionTaken: """
                Set min: \(bitrate / 1000), rtt: \(rtt) >= latency / 3: \(srt_latency / 3) \
                or bs: \(bs) > bs_th3: \(formatTwoDecimals(value: bs_th3))
                """
            )
        } else if ctime > nextBitrateDecr && (rtt > (srt_latency / 5) || bs > bs_th2) {
            bitrate -= (bitrate_decr_min + bitrate / bitrate_decr_scale)
            nextBitrateDecr = ctime + bitrate_decr_fast_int
            logAdaptiveAcion(
                actionTaken: """
                Fast decr: \((bitrate_decr_min + bitrate / bitrate_decr_scale) / 1000), \
                rtt: \(rtt) > latency / 5: \(srt_latency / 5) or bs: \(bs) > bs_th2: \
                \(formatTwoDecimals(value: bs_th2))
                """
            )
        } else if ctime > nextBitrateDecr && (rtt > rtt_th_max || bs > bs_th1) {
            bitrate -= bitrate_decr_min
            nextBitrateDecr = ctime + bitrate_decr_int
            logAdaptiveAcion(
                actionTaken: """
                Decr: \(bitrate_decr_min / 1000), rtt: \(rtt) > rtt_th_max: \
                \(formatTwoDecimals(value: rtt_th_max)) or bs: \(bs) > bs_th1: \
                \(formatTwoDecimals(value: bs_th1))
                """
            )
        } else if ctime > nextBitrateIncr && rtt < rtt_th_min && rttAvgDelta < 0.01 {
            bitrate += bitrate_incr_min + bitrate / bitrate_incr_scale
            nextBitrateIncr = ctime + bitrate_incr_int
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
