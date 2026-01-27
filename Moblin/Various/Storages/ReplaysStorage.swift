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

class ReplaysDatabase: Codable, ObservableObject {
    @Published var replays: [ReplaySettings] = []

    enum CodingKeys: CodingKey {
        case replays
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.replays, replays)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        replays = container.decode(.replays, [ReplaySettings].self, [])
    }

    static func fromString(settings: String) throws -> ReplaysDatabase {
        return try JSONDecoder().decode(
            ReplaysDatabase.self,
            from: settings.data(using: .utf8)!
        )
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

    func delete(id: UUID) {
        database.replays.removeAll { $0.id == id }
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
            logger.info("replays-storage: Failed to store.")
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

    func isFull() -> Bool {
        return database.replays.count > 499
    }

    func defaultStorageDirectory() -> URL {
        return getReplaysDirectory()
    }
}
