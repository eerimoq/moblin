import Foundation

struct BitrateStatsInstant {
    var total: UInt64
    var speed: UInt64
}

struct BitrateStats {
    private(set) var totalBytes: UInt64 = 0
    private var previousTotalBytes: UInt64 = 0
    private(set) var latestSpeed: UInt64 = 0
    private let speedChangeRate: UInt64

    init(speedChangeRate: UInt64 = 100) {
        self.speedChangeRate = speedChangeRate
    }

    mutating func add(bytesTransferred: Int) {
        totalBytes += UInt64(bytesTransferred)
    }

    mutating func update() -> BitrateStatsInstant {
        let speed = totalBytes - previousTotalBytes
        latestSpeed = (speedChangeRate * speed + (100 - speedChangeRate) * latestSpeed) / 100
        previousTotalBytes = totalBytes
        return BitrateStatsInstant(total: totalBytes, speed: latestSpeed)
    }
}
