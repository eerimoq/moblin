import AVFoundation
import Foundation
import SwiftUI

struct StreamingHistoryStream: Identifiable, Codable {
    var id = UUID()
    var settings: SettingsStream
    var startTime: Date = .init()
    var stopTime: Date = .init()
    var totalBytes: UInt64 = 0

    func duration() -> Duration {
        return .seconds(stopTime.timeIntervalSince(startTime))
    }
}

class StreamingHistoryDatabase: Codable {
    var streams: [StreamingHistoryStream]

    init() {
        streams = []
    }

    func totalBytes() -> UInt64 {
        var bytes: UInt64 = 0
        for stream in streams {
            bytes += stream.totalBytes
        }
        return bytes
    }

    func totalTime() -> Duration {
        var time: Duration = .zero
        for stream in streams {
            time += stream.duration()
        }
        return time
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

    private func migrateFromOlderVersions() {}

    func append(stream: StreamingHistoryStream) {
        while database.streams.count > 100 {
            database.streams.remove(at: 0)
        }
        database.streams.append(stream)
    }
}
