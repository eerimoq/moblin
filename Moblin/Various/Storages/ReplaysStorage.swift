import Foundation
import SwiftUI

private func getReplaysDirectory() -> URL {
    return createAndGetDirectory(name: "Replays")
}

class ReplaySettings: Identifiable, Codable {
    var id: UUID = .init()
    var duration: Double = 0.0
    var start: Double = 20.0
    var stop: Double = SettingsReplay.stop

    func name() -> String {
        return "\(id).mp4"
    }

    func url() -> URL {
        return getReplaysDirectory().appending(component: name())
    }

    func thumbnailOffset() -> Double {
        return max(startFromVideoStart(), 0)
    }

    func startFromEnd() -> Double {
        return SettingsReplay.stop - start
    }

    private func stopFromEnd() -> Double {
        return SettingsReplay.stop - stop
    }

    func startFromVideoStart() -> Double {
        return duration - startFromEnd()
    }

    func stopFromVideoStart() -> Double {
        return duration - stopFromEnd()
    }
}

class ReplaysDatabase: Codable {
    var replays: [ReplaySettings] = []

    static func fromString(settings: String) throws -> ReplaysDatabase {
        let database = try JSONDecoder().decode(
            ReplaysDatabase.self,
            from: settings.data(using: .utf8)!
        )
        return database
    }

    func toString() throws -> String {
        return try String.fromUtf8(data: JSONEncoder().encode(self))
    }
}

final class ReplaysStorage {
    private var realDatabase = ReplaysDatabase()
    var database: ReplaysDatabase {
        realDatabase
    }

    @AppStorage("replays") var storage = ""

    func load() {
        do {
            try tryLoadAndMigrate(settings: storage)
        } catch {
            logger.info("replays-storage: Failed to load with error \(error). Using default.")
            realDatabase = ReplaysDatabase()
        }
        cleanup()
    }

    private func cleanup() {
        database.replays = database.replays.filter { FileManager.default.fileExists(atPath: $0.url().path()) }
        guard let enumerator = FileManager.default.enumerator(
            at: getReplaysDirectory(),
            includingPropertiesForKeys: nil
        )
        else {
            return
        }
        for case let fileUrl as URL in enumerator
            where !database.replays
            .contains(where: { fileUrl.resolvingSymlinksInPath() == $0.url().resolvingSymlinksInPath() })
        {
            logger.debug("replays-storage: Removing unused file \(fileUrl)")
            fileUrl.remove()
        }
    }

    private func tryLoadAndMigrate(settings: String) throws {
        realDatabase = try ReplaysDatabase.fromString(settings: settings)
        migrateFromOlderVersions()
    }

    func store() {
        do {
            storage = try realDatabase.toString()
        } catch {
            logger.error("replays-storage: Failed to store.")
        }
    }

    private func migrateFromOlderVersions() {}

    func createReplay() -> ReplaySettings {
        return ReplaySettings()
    }

    func append(replay: ReplaySettings) {
        while isFull() {
            database.replays.popLast()?.url().remove()
        }
        database.replays.insert(replay, at: 0)
    }

    func numberOfRecordingsString() -> String {
        return String(database.replays.count)
    }

    func isFull() -> Bool {
        return database.replays.count > 499
    }

    func defaultStorageDirectory() -> URL {
        return getReplaysDirectory()
    }
}
