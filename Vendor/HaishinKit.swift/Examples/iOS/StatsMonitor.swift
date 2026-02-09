import Foundation
import HaishinKit

struct Stats: Identifiable {
    let date: Date
    let currentBytesOutPerSecond: Int
    let id: Int

    init(report: NetworkMonitorReport) {
        currentBytesOutPerSecond = report.currentBytesOutPerSecond
        date = Date()
        id = Int(date.timeIntervalSince1970)
    }
}

struct StatsMonitor: StreamBitRateStrategy {
    let mamimumVideoBitRate: Int = 0
    let mamimumAudioBitRate: Int = 0

    private let callback: @Sendable (Stats) -> Void

    init(_ callback: @Sendable @escaping (Stats) -> Void) {
        self.callback = callback
    }

    func adjustBitrate(_ event: NetworkMonitorEvent, stream: some StreamConvertible) async {
        switch event {
        case .status(let report):
            callback(Stats(report: report))
        case .publishInsufficientBWOccured(let report):
            callback(Stats(report: report))
        case .reset:
            break
        }
    }
}
