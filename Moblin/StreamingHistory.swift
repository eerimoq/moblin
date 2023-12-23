import AVFoundation
import Foundation
import SwiftUI

enum ThermalState: Int, Codable, Comparable {
    case nominal = 0
    case fair = 1
    case serious = 2
    case critical = 3

    init(from: ProcessInfo.ThermalState) {
        switch from {
        case .nominal:
            self = .nominal
        case .fair:
            self = .fair
        case .serious:
            self = .serious
        case .critical:
            self = .critical
        @unknown default:
            self = .nominal
        }
    }

    static func < (lhs: ThermalState, rhs: ThermalState) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    func toProcessInfo() -> ProcessInfo.ThermalState {
        switch self {
        case .nominal:
            return .nominal
        case .fair:
            return .fair
        case .serious:
            return .serious
        case .critical:
            return .critical
        }
    }
}

class StreamingHistoryStream: Identifiable, Codable {
    var id = UUID()
    var settings: SettingsStream
    var startTime: Date = .init()
    var stopTime: Date = .init()
    var totalBytes: UInt64 = 0
    var numberOfFffffs: Int? = 0
    var highestThermalState: ThermalState? = .nominal
    var lowestBatteryLevel: Double? = 1.0
    var highestBitrate: Int64? = Int64.min
    var averageBitrate: Int64? = 0

    init(settings: SettingsStream) {
        self.settings = settings
    }

    func updateBitrate(bitrate: Int64) {
        if bitrate > highestBitrate! {
            highestBitrate = bitrate
        }
    }

    func averageBitrateString() -> String {
        let bitrate = Int64(8 * totalBytes / UInt64(duration().components.seconds))
        return formatBytesPerSecond(speed: bitrate)
    }

    func highestBitrateString() -> String {
        return formatBytesPerSecond(speed: highestBitrate!)
    }

    func updateHighestThermalState(thermalState: ThermalState) {
        if thermalState > highestThermalState! {
            highestThermalState = thermalState
        }
    }

    func updateLowestBatteryLevel(level: Double) {
        if level < lowestBatteryLevel! {
            lowestBatteryLevel = level
        }
    }

    func lowestBatteryPercentageString() -> String {
        return "\(Int(100 * lowestBatteryLevel!)) %"
    }

    func duration() -> Duration {
        return .seconds(stopTime.timeIntervalSince(startTime))
    }

    func isSuccessful() -> Bool {
        return numberOfFffffs! == 0
    }
}

class StreamingHistoryDatabase: Codable {
    var totalTime: Duration? = .seconds(0)
    var totalBytes: UInt64? = 0
    var totalStreams: UInt64? = 0
    var streams: [StreamingHistoryStream]

    init() {
        streams = []
    }

    static func fromString(settings: String) throws -> StreamingHistoryDatabase {
        let database = try JSONDecoder().decode(
            StreamingHistoryDatabase.self,
            from: settings.data(using: .utf8)!
        )
        return database
    }

    func toString() throws -> String {
        return try String(decoding: JSONEncoder().encode(self), as: UTF8.self)
    }
}

final class StreamingHistory {
    private var realDatabase = StreamingHistoryDatabase()
    var database: StreamingHistoryDatabase {
        realDatabase
    }

    @AppStorage("streamingHistory") var storage = ""

    func load() {
        do {
            try tryLoadAndMigrate(settings: storage)
        } catch {
            logger.info("streaming-history: Failed to load with error \(error). Using default.")
            realDatabase = StreamingHistoryDatabase()
        }
    }

    private func tryLoadAndMigrate(settings: String) throws {
        realDatabase = try StreamingHistoryDatabase.fromString(settings: settings)
        migrateFromOlderVersions()
    }

    func store() {
        do {
            storage = try realDatabase.toString()
        } catch {
            logger.error("streaming-history: Failed to store.")
        }
    }

    private func migrateFromOlderVersions() {
        if database.totalTime == nil {
            database.totalTime = database.streams.reduce(.seconds(0)) { total, stream in
                total + stream.duration()
            }
            store()
        }
        if database.totalBytes == nil {
            database.totalBytes = database.streams.reduce(0) { total, stream in
                total + stream.totalBytes
            }
            store()
        }
        if database.totalStreams == nil {
            database.totalStreams = UInt64(database.streams.count)
            store()
        }
        for stream in database.streams where stream.numberOfFffffs == nil {
            stream.numberOfFffffs = 0
            store()
        }
        for stream in database.streams where stream.highestThermalState == nil {
            stream.highestThermalState = .nominal
            store()
        }
        for stream in database.streams where stream.lowestBatteryLevel == nil {
            stream.lowestBatteryLevel = 1.0
            store()
        }
        for stream in database.streams where stream.highestBitrate == nil {
            stream.highestBitrate = Int64.min
            store()
        }
    }

    func append(stream: StreamingHistoryStream) {
        while database.streams.count > 100 {
            database.streams.removeLast()
        }
        database.totalTime! += stream.duration()
        database.totalBytes! += stream.totalBytes
        database.totalStreams! += 1
        database.streams.insert(stream, at: 0)
    }
}
