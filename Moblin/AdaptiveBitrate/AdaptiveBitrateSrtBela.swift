import Collections
import Foundation

class AdaptiveBitrateSrtBela: AdaptiveBitrate {
    private var currentBitrate: Int64 = 500_000
    private var targetBitrate: Int64 = 500_000
    private var currentMaximumBitrate: Int64 = 500_000
    private var settings = adaptiveBitrateFastSettings

    private var bs_avg : Double = 0
    private var bs_jitter : Double = 0
    private var prev_bs : Double = 0
    private var rtt_avg : Double = 0
    private var rtt_avg_delta : Double = 0
    private var prev_rtt : Double = 300.0
    private var rtt_min : Double = 200.0
    private var rtt_jitter : Double = 0.0
    private var throughput : Double = 0.0
    private var next_bitrate_incr : UInt64 = 0
    private var next_bitrate_decr : UInt64 = 0
    private var cur_bitrate : Int64 = 0
    
    init(targetBitrate: UInt32, delegate: AdaptiveBitrateDelegate) {
        super.init(delegate: delegate)
        self.targetBitrate = Int64(targetBitrate)
    }

    override func setTargetBitrate(bitrate: UInt32) {
        targetBitrate = Int64(bitrate)
    }

    override func setSettings(settings: AdaptiveBitrateSettings) {
        logger.info("adaptive-bitrate: Using settings \(settings)")
        self.settings = settings
    }

    override func getCurrentBitrate() -> UInt32 {
        return UInt32(currentBitrate)
    }

    override func getCurrentMaximumBitrateInKbps() -> Int64 {
        return Int64(cur_bitrate) / 1000
    }
    
    func rtt_to_bs(rtt: Double, throughput: Double) -> Double {
        return ((throughput / 8) * (rtt) / 1316)
    }
    
    func currentTimeMillis() -> UInt64{
        let nowDouble = NSDate().timeIntervalSince1970
        return UInt64(nowDouble*1000)
    }
    
    func update_bitrate(stats: StreamStats) {
        if (stats.rttMs == 0) {
            return
        }

        if (cur_bitrate == 0) {
            cur_bitrate = settings.minimumBitrate
        }

        let srt_latency : Double = Double(stats.latency ?? 2000)
        
        let ctime : UInt64 = currentTimeMillis()
        let bs : Double = stats.packetsInFlight
        
        // Rolling average
        bs_avg = bs_avg * 0.99 + bs * 0.01

        // Update the buffer size jitter
        bs_jitter = 0.99 * bs_jitter
        let delta_bs : Double = bs - prev_bs
        if (delta_bs > bs_jitter) {
            bs_jitter = delta_bs
        }
        prev_bs = bs

        // Update the average RTT
        let rtt : Double = stats.rttMs
        if (rtt_avg == 0.0) {
            rtt_avg = rtt
        } else {
            rtt_avg = rtt_avg * 0.99 + 0.01 * rtt
        }

        // Update the average RTT delta
        let delta_rtt : Double = rtt - prev_rtt
        rtt_avg_delta = rtt_avg_delta * 0.8 + delta_rtt * 0.2
        prev_rtt = rtt
        
        // Update the minimum RTT
        rtt_min *= 1.001
        if (rtt != 100 && rtt < rtt_min && rtt_avg_delta < 1.0) {
            rtt_min = rtt
        }
        
        // Update the RTT jitter
        rtt_jitter *= 0.99
        if (delta_rtt > rtt_jitter) {
            rtt_jitter = delta_rtt
        }
        
        //Rolling average of the network throughput
        throughput *= 0.97
        throughput += (stats.mbpsSendRate! * 1000.0 * 1000.0 / 1024.0) * 0.03;
        
        var bitrate : Int64 = cur_bitrate

        let bs_th3 = (bs_avg + bs_jitter)*4
        var bs_th2 = max(50, bs_avg + max(bs_jitter*3.0, bs_avg))
        bs_th2 = min(bs_th2, rtt_to_bs(rtt: srt_latency / 2, throughput: throughput))
        let bs_th1 = max(50, bs_avg + bs_jitter*2.5)
        let rtt_th_max = rtt_avg + max(rtt_jitter*4, rtt_avg*15/100)
        let rtt_th_min = rtt_min + max(1, rtt_jitter*2)

        let bitrate_incr_min : Int64 = (100*1000)
        let bitrate_incr_int : UInt64 = 400
        let bitrate_incr_scale : Int64 = 30
        
        let bitrate_decr_min : Int64 = (100*1000)
        let bitrate_decr_int : UInt64 = 200
        let bitrate_decr_fast_int : UInt64 = 250
        let bitrate_decr_scale : Int64 = 10
        
        if (bitrate > settings.minimumBitrate && (rtt >= (srt_latency / 3) || bs > bs_th3)) {
            bitrate = settings.minimumBitrate
            next_bitrate_decr = ctime + bitrate_decr_int
            logAdaptiveAcion(actionTaken: """
                Set min: \(bitrate/1000), rtt: \(rtt) >= latency/3: \(srt_latency/3) or bs: \(bs) > bs_th3: \(String(format: "%.2f",bs_th3))
            """)
        } else if (ctime > next_bitrate_decr && (rtt > (srt_latency / 5) || bs > bs_th2)) {
            bitrate -= (bitrate_decr_min + bitrate/bitrate_decr_scale)
            next_bitrate_decr = ctime + bitrate_decr_fast_int
            logAdaptiveAcion(actionTaken: """
                Fast decr: \((bitrate_decr_min + bitrate/bitrate_decr_scale)/1000), rtt: \(rtt) > latency/5: \(srt_latency/5) or bs: \(bs) > bs_th2: \(String(format:"%.2f",bs_th2))
            """)
        } else if (ctime > next_bitrate_decr && (rtt > rtt_th_max || bs > bs_th1)) {
            bitrate -= bitrate_decr_min
            next_bitrate_decr = ctime + bitrate_decr_int
            logAdaptiveAcion(actionTaken: """
                Decr: \(bitrate_decr_min/1000), rtt: \(rtt) > rtt_th_max: \(String(format:"%.2f",rtt_th_max)) or bs: \(bs) > bs_th1: \(String(format:"%.2f",bs_th1))
            """)
        } else if (ctime > next_bitrate_incr && rtt < rtt_th_min && rtt_avg_delta < 0.01) {
            bitrate += bitrate_incr_min + bitrate / bitrate_incr_scale
            next_bitrate_incr = ctime + bitrate_incr_int
            /*logAdaptiveAcion(actionTaken: """
                Incr: \(bitrate_incr_min + bitrate / bitrate_incr_scale), rtt: \(String(format:"%.2f", rtt)) < rtt_th_min: \(String(format:"%.2f",rtt_th_min)) and rtt_avg_delta: \(String(format:"%.2f",rtt_avg_delta)) < 0.01
            """)*/
        }

        bitrate = max(min(bitrate, targetBitrate), settings.minimumBitrate)
        
        if (bitrate != cur_bitrate) {
            cur_bitrate = bitrate;
            delegate.adaptiveBitrateSetVideoStreamBitrate(bitrate: UInt32(bitrate))
         }
    }

    override func update(stats: StreamStats) {
        update_bitrate(stats: stats)

        currentBitrate = stats.transportBitrate!

        super.update(stats: stats)
    }


}

