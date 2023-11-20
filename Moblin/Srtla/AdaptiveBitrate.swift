import AVFoundation
import HaishinKit
import SRTHaishinKit

protocol AdaptiveBitrateDelegate: AnyObject {
    func adaptiveBitrateSetVideoStreamBitrate(bitrate: UInt32)
}

var adaptiveBitratePacketsInFlightLimit: Int32 = 200

class AdaptiveBitrate {
    private var avgRtt: Double = 0.0
    private var fastRtt: Double = 0.0
    private var curBitrate: Int32 = 250_000
    private var prevBitrate: Int32 = 250_000
    private var targetBitrate: Int32 = 250_000
    private var tempMaxBitrate: Int32 = 250_000
    private var smoothPif: Double = 0
    private var fastPif: Double = 0
    private weak var delegate: (any AdaptiveBitrateDelegate)!
    private var adaptiveActionsTaken: [String] = []

    init(targetBitrate: UInt32, delegate: AdaptiveBitrateDelegate) {
        self.targetBitrate = Int32(targetBitrate)
        self.delegate = delegate
    }

    func setTargetBitrate(bitrate: UInt32) {
        logger.debug("srtla: adaptive-bitrate: New target bitrate \(bitrate)")
        targetBitrate = Int32(bitrate)
    }

    private func calcRtts(stats: SRTPerformanceData) {
        if avgRtt < 1 {
            avgRtt = stats.msRTT
        }
        if avgRtt > stats.msRTT {
            avgRtt *= 0.60
            avgRtt += stats.msRTT * 0.40
        } else {
            avgRtt *= 0.99
            if stats.msRTT < 450 {
                avgRtt += stats.msRTT * 0.01
            } else {
                avgRtt += 450 * 0.001
            }
        }
        if fastRtt > stats.msRTT {
            fastRtt *= 0.70
            fastRtt += stats.msRTT * 0.30
        } else {
            fastRtt *= 0.90
            fastRtt += stats.msRTT * 0.10
        }
        if avgRtt > 450 {
            avgRtt = 450
        }
        avgRtt = avgRtt * 100.rounded() / 100
        fastRtt = fastRtt * 100.rounded() / 100
    }

    private func increaseTempMaxBitrate(
        stats: SRTPerformanceData,
        pif: Double,
        avgRTT _: Double,
        fastRTT _: Double,
        allowedRttJitter: Double,
        allowedPifJitter: Int32
    ) {
        var pifDiffThing = stats.pktFlightSize - Int32(pif)
        if pifDiffThing < 0 {
            pifDiffThing = 0
        }
        if pifDiffThing > adaptiveBitratePacketsInFlightLimit {
            pifDiffThing = adaptiveBitratePacketsInFlightLimit
        }
        // statDeci just used for display on screen
        // statDeci = pifDiffThing
        pifDiffThing = adaptiveBitratePacketsInFlightLimit - pifDiffThing
        if pif < Double(adaptiveBitratePacketsInFlightLimit),
           fastRtt <= avgRtt + allowedRttJitter
        {
            if stats.pktFlightSize - Int32(pif) < allowedPifJitter {
                tempMaxBitrate += (100_000 * pifDiffThing) /
                    adaptiveBitratePacketsInFlightLimit
                if tempMaxBitrate > targetBitrate {
                    tempMaxBitrate = targetBitrate
                }
            }
        }
    }

    private func calcSmoothedPif(_ stats: SRTPerformanceData) {
        // increase slowly
        if stats.pktFlightSize > Int32(smoothPif) {
            smoothPif *= 0.98
            smoothPif += Double(stats.pktFlightSize) * 0.02
        } else {
            // decrease fast because we really want to be closer to the ideal pif
            smoothPif *= 0.90
            smoothPif += Double(stats.pktFlightSize) * 0.1
        }

        fastPif *= 0.67
        fastPif += Double(stats.pktFlightSize) * 0.33
    }

    private func decreaseMaxRateIfPifIsHigh(
        factor: Double,
        pifMax: Double,
        minimumDecrease: Int32
    ) {
        if smoothPif > pifMax {
            let newMaxBitrate = Int32(Double(tempMaxBitrate) * factor)
            let differece = tempMaxBitrate - newMaxBitrate
            if differece < minimumDecrease {
                tempMaxBitrate -= minimumDecrease
                logAdaptiveAcion(
                    actionTaken: """
                    PIF: decreasing bitrate by \(minimumDecrease), \
                    smoothpif \(smoothPif) > pifmax \(pifMax)
                    """
                )
            } else {
                tempMaxBitrate = Int32(Double(tempMaxBitrate) * factor)
                logAdaptiveAcion(
                    actionTaken: """
                    PIF: decreasing bitrate by \(100 * factor) %, \
                    smoothpif \(smoothPif) > pifmax \(pifMax)
                    """
                )
            }
        }
    }

    private func logAdaptiveAcion(actionTaken: String) {
        logger.debug("srtla: adaptive-bitrate: \(actionTaken)")
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
        minimumDecrease: Int32
    ) {
        if avgRtt > rttMax {
            let newMaxBitrate = Int32(Double(tempMaxBitrate) * factor)
            let differece = tempMaxBitrate - newMaxBitrate

            if differece < minimumDecrease {
                tempMaxBitrate -= minimumDecrease
                logAdaptiveAcion(
                    actionTaken: "RTT: dec bitrate by \(minimumDecrease), avgrtt: \(avgRtt) > rttmax: \(rttMax)"
                )

            } else {
                tempMaxBitrate = newMaxBitrate
                logAdaptiveAcion(
                    actionTaken: "RTT: dec bitrate to \(factor) %, avgrtt: \(avgRtt) > rttmax: \(rttMax)"
                )
            }
        }
    }

    var getCurrentBitrate: Int32 {
        return curBitrate / 1000
    }

    var getTempMaxBitrate: Int32 {
        return tempMaxBitrate / 1000
    }

    var getAdaptiveActions: [String] {
        return adaptiveActionsTaken
    }

    var GetFastPif: Int32 {
        return Int32(fastPif)
    }

    var GetSmoothPif: Int32 {
        return Int32(smoothPif)
    }

    private func decreaseMaxRateIfRttDiffIsHigh(
        _ stats: SRTPerformanceData,
        factor: Double,
        rttSpikeAllowed: Double, minimumDecrease: Int32
    ) {
        if stats.msRTT > avgRtt + rttSpikeAllowed {
            let newMaxBitrate = Int32(Double(tempMaxBitrate) * factor)
            let differece = tempMaxBitrate - newMaxBitrate
            if differece < minimumDecrease {
                tempMaxBitrate -= minimumDecrease
                logAdaptiveAcion(
                    actionTaken: """
                    RTT: decreasing bitrate by \(minimumDecrease), msrtt \
                    \(stats.msRTT) > avgrtt + allow \(avgRtt) + \(rttSpikeAllowed)
                    """
                )
            } else {
                tempMaxBitrate = newMaxBitrate
                logAdaptiveAcion(
                    actionTaken: """
                    RTT: decreasing bitrate by \(100 * factor) %, msrtt \(stats.msRTT) > \
                    avgrtt + allow \(avgRtt) + \(rttSpikeAllowed)
                    """
                )
            }
        }
    }

    private func calculateCurrentBitrate(_: SRTPerformanceData) {
        var pifDiffThing = Int32(fastPif) - Int32(smoothPif)
        // lazy decrease
        if pifDiffThing > adaptiveBitratePacketsInFlightLimit {
            logAdaptiveAcion(
                actionTaken: "Lazy dec pifdiff \(pifDiffThing) > limit \(adaptiveBitratePacketsInFlightLimit)"
            )
            tempMaxBitrate = Int32(Double(tempMaxBitrate) * 0.95)
        }
        if pifDiffThing <= (adaptiveBitratePacketsInFlightLimit / 5) {
            pifDiffThing = 0
        }
        if pifDiffThing < 0 {
            pifDiffThing = 0
        }
        if pifDiffThing > adaptiveBitratePacketsInFlightLimit {
            pifDiffThing = adaptiveBitratePacketsInFlightLimit
        }
        // harder decrease
        if pifDiffThing == adaptiveBitratePacketsInFlightLimit {
            tempMaxBitrate -= 500_000
            logAdaptiveAcion(
                actionTaken: "-500 dec pifdiff \(pifDiffThing) = limit \(adaptiveBitratePacketsInFlightLimit)"
            )
        }
        pifDiffThing = adaptiveBitratePacketsInFlightLimit - pifDiffThing
        if tempMaxBitrate < 250_000 {
            tempMaxBitrate = 250_000
        }
        // check for int  overflows
        var tempBitrate: Int64
        tempBitrate = Int64(tempMaxBitrate)
        tempBitrate *= Int64(pifDiffThing)
        tempBitrate /= Int64(adaptiveBitratePacketsInFlightLimit)
        curBitrate = Int32(tempBitrate)
        if curBitrate < 50000 {
            curBitrate = 50000
        }
        // pif running away do a quick lower of bitrate temporarily
        if Int32(fastPif) - Int32(smoothPif) > adaptiveBitratePacketsInFlightLimit * 2 {
            curBitrate = 50000
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
    func update(stats: SRTPerformanceData) {
        calcSmoothedPif(stats)
        calcRtts(stats: stats)
        increaseTempMaxBitrate(
            stats: stats,
            pif: smoothPif,
            avgRTT: avgRtt,
            fastRTT: fastRtt,
            allowedRttJitter: 15,
            allowedPifJitter: 10
        )
        // slow decreases if needed
        decreaseMaxRateIfPifIsHigh(factor: 0.9, pifMax: 100, minimumDecrease: 250_000)
        decreaseMaxRateIfRttIsHigh(factor: 0.9, rttMax: 250, minimumDecrease: 250_000)
        decreaseMaxRateIfRttDiffIsHigh(
            stats,
            factor: 0.9,
            rttSpikeAllowed: 50,
            minimumDecrease: 250_000
        )
        calculateCurrentBitrate(stats)
        if prevBitrate != curBitrate {
            logger.debug("srtla: adaptive-bitrate: Setting bitrate \(curBitrate)")
            delegate.adaptiveBitrateSetVideoStreamBitrate(bitrate: UInt32(curBitrate))
        }
        prevBitrate = curBitrate
    }
}

class SrtAdaptiveAction : Hashable {
    
    private var _actionTaken : String
    public var actionTaken : String {
        get {
            return _actionTaken
        }
    }
    var dateCreated : Date
    init(actionTaken : String) {
        self.dateCreated = Date.now
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        let dateString = dateFormatter.string(from: self.dateCreated)
        
        self._actionTaken = dateString + ": " + actionTaken
       
    }
    
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(dateCreated)
    }
    
    static func == (lhs: SrtAdaptiveAction, rhs: SrtAdaptiveAction) -> Bool {
        if lhs.dateCreated.timeIntervalSince1970 == rhs.dateCreated.timeIntervalSince1970 {
            return true
        }
        return false
    }
    
    public func isOld() -> Bool{
        
        
        let x = Date.now.timeIntervalSince(dateCreated)*1000
        if Int( x.rounded()) > 10000 {
            return true
        }
        return false
    }
}

