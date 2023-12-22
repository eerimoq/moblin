import Foundation
import SwiftUI

private let recordingsDirectory = URL.documentsDirectory.appending(component: "Recordings")

class Recording: Identifiable, Codable {
    var id: UUID = .init()
    var settings: SettingsStream
    var startTime: Date = .init()
    var stopTime: Date = .init()

    init(settings: SettingsStream) {
        self.settings = settings
    }

    func title() -> String {
        return "\(startTime.formatted()), \(length().formatWithSeconds())"
    }

    func subTitle() -> String {
        return "\(settings.resolutionString()), \(settings.fps) FPS, \(UInt64(0).formatBytes())"
    }

    func name() -> String {
        return "\(id).mp4"
    }

    func length() -> Duration {
        return Duration(
            secondsComponent: Int64(stopTime.timeIntervalSince(startTime)),
            attosecondsComponent: 0
        )
    }

    func url() -> URL {
        return recordingsDirectory.appending(component: "\(id)")
    }
}

class RecordingsDatabase: Codable {
    var recordings: [Recording] = []

    static func fromString(settings: String) throws -> RecordingsDatabase {
        let database = try JSONDecoder().decode(
            RecordingsDatabase.self,
            from: settings.data(using: .utf8)!
        )
        return database
    }

    func toString() throws -> String {
        return try String(decoding: JSONEncoder().encode(self), as: UTF8.self)
    }
}

final class RecordingsStorage {
    private var realDatabase = RecordingsDatabase()
    var database: RecordingsDatabase {
        realDatabase
    }

    @AppStorage("recordings") var storage = ""

    init() {
        do {
            try FileManager.default.createDirectory(
                at: recordingsDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            logger.error("Failed to create recordings directory with error \(error.localizedDescription)")
        }
    }

    func load() {
        do {
            try tryLoadAndMigrate(settings: storage)
        } catch {
            logger.info("streaming-history: Failed to load with error \(error). Using default.")
            realDatabase = RecordingsDatabase()
        }
    }

    private func tryLoadAndMigrate(settings: String) throws {
        realDatabase = try RecordingsDatabase.fromString(settings: settings)
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

    func createRecording(settings: SettingsStream) -> Recording {
        return Recording(settings: settings)
    }

    func append(recording: Recording) {
        while database.recordings.count > 100 {
            database.recordings.remove(at: 0)
        }
        recording.stopTime = Date()
        database.recordings.append(recording)
    }

    func listRecordings() -> [Recording] {
        return database.recordings
    }

    func numberOfRecordingsString() -> String {
        return String(database.recordings.count)
    }

    func totalSizeString() -> String {
        return UInt64(0).formatBytes()
    }
}
