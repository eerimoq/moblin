import Foundation

private struct SendTiming {
    var timestamp: ContinuousClock.Instant
    var sequence: Int64
}

struct RtmpStreamStats {
    var rttMs: Double = 0
    var packetsInFlight: UInt32 = 0
}

class RtmpStreamInfo {
    var byteCount: Atomic<Int64> = .init(0)
    private(set) var currentBytesPerSecond: Atomic<Int64> = .init(0)
    private(set) var stats: Atomic<RtmpStreamStats> = .init(RtmpStreamStats())
    private var previousByteCount: Int64 = 0
    private var sendTimings: [SendTiming] = []
    private var latestWrittenSequence: Int64 = 0
    private var latestAckedSequenceLow: UInt32 = 0
    private var latestAckedSequenceHigh: Int64 = 0

    func clear() {
        byteCount.mutate { $0 = 0 }
        currentBytesPerSecond.mutate { $0 = 0 }
        stats.mutate { $0 = RtmpStreamStats() }
        previousByteCount = 0
        sendTimings.removeAll()
        latestWrittenSequence = 0
        latestAckedSequenceLow = 0
        latestAckedSequenceHigh = 0
    }

    func onTimeout() {
        let byteCount = self.byteCount.value
        let speed = byteCount - previousByteCount
        currentBytesPerSecond.mutate { $0 = Int64(Double($0) * 0.7 + Double(speed) * 0.3) }
        previousByteCount = byteCount
    }

    func onWritten(sequence: Int64) {
        latestWrittenSequence = sequence
        // Just for safety
        if sendTimings.count < 500 {
            sendTimings.append(SendTiming(timestamp: .now, sequence: sequence))
        }
        let packetsInFlight = packetsInFlight()
        stats.mutate {
            $0.packetsInFlight = packetsInFlight
        }
    }

    func onAck(sequence: UInt32) {
        if sequence < latestAckedSequenceLow {
            // Twitch rolls over at Int32.max. Bug?
            if latestAckedSequenceLow <= Int32.max {
                latestAckedSequenceHigh += Int64(Int32.max)
            } else {
                latestAckedSequenceHigh += Int64(UInt32.max)
            }
        }
        latestAckedSequenceLow = sequence
        var ackedSendTiming: SendTiming?
        while let sendTiming = sendTimings.first {
            if latestAckedSequence() > sendTiming.sequence {
                ackedSendTiming = sendTiming
                sendTimings.remove(at: 0)
            } else {
                break
            }
        }
        if let ackedSendTiming {
            let rttMs = Double(ackedSendTiming.timestamp.duration(to: .now).milliseconds)
            let packetsInFlight = packetsInFlight()
            stats.mutate {
                $0.rttMs = rttMs
                $0.packetsInFlight = packetsInFlight
            }
        }
    }

    private func latestAckedSequence() -> Int64 {
        return latestAckedSequenceHigh + Int64(latestAckedSequenceLow)
    }

    private func packetsInFlight() -> UInt32 {
        // Max just not to crash if server acks data that is not yet sent.
        return UInt32(min(max(latestWrittenSequence - latestAckedSequence(), 0), Int64(UInt32.max)) / 1400)
    }
}
