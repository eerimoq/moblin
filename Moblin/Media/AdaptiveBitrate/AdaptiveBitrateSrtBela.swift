// Adaptive bitrate algorithm from Belacoder.
// Designed by rationalsa for the BELABOX projecct.
// https://github.com/BELABOX/belacoder

import Collections
import Foundation

private let bitrateIncrMin: Int64 = (100 * 1000)
private let bitrateIncrInterval: ContinuousClock.Duration = .milliseconds(400)
private let bitrateIncrScale: Int64 = 30
private let bitrateDecrMin: Int64 = (100 * 1000)
private let bitrateDecrInterval: ContinuousClock.Duration = .milliseconds(200)
private let bitrateDecrFastInterval: ContinuousClock.Duration = .milliseconds(250)
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
    private var sendBufferSizeAvg: Double = 0
    private var sendBufferSizeJitter: Double = 0
    private var prevSendBufferSize: Double = 0
    private var rttAvg: Double = 0
    private var rttAvgDelta: Double = 0
    private var prevRtt: Double = 300.0
    private var rttMin: Double = 200.0
    private var rttJitter: Double = 0.0
    private var throughput: Double = 0.0
    private var nextBitrateIncrTime: ContinuousClock.Instant = .now
    private var nextBitrateDecrTime: ContinuousClock.Instant = .now
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

    private func rttToSendBufferSize(rtt: Double, throughput: Double) -> Double {
        return (throughput / 8) * rtt / 1316
    }

    private func updateSendBufferSizeAverage(sendBufferSize: Double) {
        sendBufferSizeAvg = sendBufferSizeAvg * 0.99 + sendBufferSize * 0.01
    }

    private func updateSendBufferSizeJitter(sendBufferSize: Double) {
        sendBufferSizeJitter = 0.99 * sendBufferSizeJitter
        let deltaSendBufferSize = sendBufferSize - prevSendBufferSize
        if deltaSendBufferSize > sendBufferSizeJitter {
            sendBufferSizeJitter = deltaSendBufferSize
        }
        prevSendBufferSize = sendBufferSize
    }

    private func updateRttAverage(rtt: Double) {
        if rttAvg == 0.0 {
            rttAvg = rtt
        } else {
            rttAvg = rttAvg * 0.99 + 0.01 * rtt
        }
    }

    private func updateAverageRttDelta(rtt: Double) -> Double {
        let deltaRtt = rtt - prevRtt
        rttAvgDelta = rttAvgDelta * 0.8 + deltaRtt * 0.2
        prevRtt = rtt
        return deltaRtt
    }

    private func updateRttMin(rtt: Double) {
        rttMin *= 1.001
        if rtt != 100 && rtt < rttMin && rttAvgDelta < 1.0 {
            rttMin = rtt
        }
    }

    private func updateRttJitter(deltaRtt: Double) {
        rttJitter *= 0.99
        if deltaRtt > rttJitter {
            rttJitter = deltaRtt
        }
    }

    private func updateThroughput(mbpsSendRate: Double) {
        throughput *= 0.97
        throughput += (mbpsSendRate * 1000.0 * 1000.0 / 1024.0) * 0.03
    }

    private func updateBitrate(stats: StreamStats) {
        if stats.rttMs == 0 {
            return
        }
        if curBitrate == 0 {
            curBitrate = settings.minimumBitrate
        }
        let sendBufferSize = stats.packetsInFlight
        updateSendBufferSizeAverage(sendBufferSize: sendBufferSize)
        updateSendBufferSizeJitter(sendBufferSize: sendBufferSize)
        let rtt = stats.rttMs
        updateRttAverage(rtt: rtt)
        let deltaRtt = updateAverageRttDelta(rtt: rtt)
        updateRttMin(rtt: rtt)
        updateRttJitter(deltaRtt: deltaRtt)
        updateThroughput(mbpsSendRate: stats.mbpsSendRate!)
        let srtLatency = Double(stats.latency ?? defaultSrtLatency)
        let currentTime = ContinuousClock.now
        var bitrate = curBitrate
        let sendBufferSizeTh3 = (sendBufferSizeAvg + sendBufferSizeJitter) * 4
        var sendBufferSizeTh2 = max(50, sendBufferSizeAvg + max(sendBufferSizeJitter * 3.0, sendBufferSizeAvg))
        sendBufferSizeTh2 = min(sendBufferSizeTh2, rttToSendBufferSize(rtt: srtLatency / 2, throughput: throughput))
        let sendBufferSizeTh1 = max(50, sendBufferSizeAvg + sendBufferSizeJitter * 2.5)
        let rttThMax = rttAvg + max(rttJitter * 4, rttAvg * 15 / 100)
        let rttThMin = rttMin + max(1, rttJitter * 2)
        if bitrate > settings.minimumBitrate && (rtt >= (srtLatency / 3) || sendBufferSize > sendBufferSizeTh3) {
            bitrate = settings.minimumBitrate
            nextBitrateDecrTime = currentTime.advanced(by: bitrateDecrInterval)
            logAdaptiveAcion(
                actionTaken: """
                Set min: \(bitrate / 1000), rtt: \(rtt) >= latency / 3: \(srtLatency / 3) \
                or bs: \(sendBufferSize) > bs_th3: \(formatTwoDecimals(sendBufferSizeTh3))
                """
            )
        } else if currentTime > nextBitrateDecrTime && (rtt > (srtLatency / 5) || sendBufferSize > sendBufferSizeTh2) {
            bitrate -= (bitrateDecrMin + bitrate / bitrateDecrScale)
            nextBitrateDecrTime = currentTime.advanced(by: bitrateDecrFastInterval)
            logAdaptiveAcion(
                actionTaken: """
                Fast decr: \((bitrateDecrMin + bitrate / bitrateDecrScale) / 1000), \
                rtt: \(rtt) > latency / 5: \(srtLatency / 5) or bs: \(sendBufferSize) > bs_th2: \
                \(formatTwoDecimals(sendBufferSizeTh2))
                """
            )
        } else if currentTime > nextBitrateDecrTime && (rtt > rttThMax || sendBufferSize > sendBufferSizeTh1) {
            bitrate -= bitrateDecrMin
            nextBitrateDecrTime = currentTime.advanced(by: bitrateDecrInterval)
            logAdaptiveAcion(
                actionTaken: """
                Decr: \(bitrateDecrMin / 1000), rtt: \(rtt) > rtt_th_max: \
                \(formatTwoDecimals(rttThMax)) or bs: \(sendBufferSize) > bs_th1: \
                \(formatTwoDecimals(sendBufferSizeTh1))
                """
            )
        } else if currentTime > nextBitrateIncrTime && rtt < rttThMin && rttAvgDelta < 0.01 {
            bitrate += bitrateIncrMin + bitrate / bitrateIncrScale
            nextBitrateIncrTime = currentTime.advanced(by: bitrateIncrInterval)
            // logAdaptiveAcion(actionTaken: """
            //      Incr: \(bitrate_incr_min + bitrate / bitrate_incr_scale), \
            //      rtt: \(String(format:"%.2f", rtt)) < rtt_th_min: \(String(format:"%.2f",rtt_th_min)) \
            //      and rtt_avg_delta: \(String(format:"%.2f",rtt_avg_delta)) < 0.01
            //      """)
        }
        // To not push too high bitrate after static scene. The encoder may output way
        // lower bitrate than configured.
        if let transportBitrate = stats.transportBitrate {
            let maximumBitrate = max(transportBitrate + 1_000_000, (17 * transportBitrate) / 10)
            if bitrate > maximumBitrate {
                bitrate = maximumBitrate
            }
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
