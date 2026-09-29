import Foundation
import SwiftUI

class ReplaySettings: Identifiable, Codable {
    var id: UUID = .init()
    var duration: Double = 0.0
    var start: Double = 20.0
    var stop: Double = SettingsReplay.stop

    func name() -> String {
        "\(id).mp4"
    }

    func thumbnailOffset() -> Double {
        max(startFromVideoStart(), 0)
    }

    func startFromEnd() -> Double {
        SettingsReplay.stop - start
    }

    private func stopFromEnd() -> Double {
        SettingsReplay.stop - stop
    }

    func startFromVideoStart() -> Double {
        duration - startFromEnd()
    }

    func stopFromVideoStart() -> Double {
        duration - stopFromEnd()
    }
}

class ReplaysDatabase: Codable, ObservableObject {
    @Published var replays: [ReplaySettings] = []

    enum CodingKeys: CodingKey {
        case replays
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.replays, replays)
    }

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        replays = container.decode(.replays, [ReplaySettings].self, [])
    }

    static func fromString(settings: String) throws -> ReplaysDatabase {
        try JSONDecoder().decode(
            ReplaysDatabase.self,
            from: settings.data(using: .utf8)!
        )
    }

    func toString() throws -> String {
        try String.fromUtf8(data: JSONEncoder().encode(self))
    }
}

private let defaultStorage = SimpleStringStorage(key: "replays")

final class ReplaysStorage {
    private let storage: SimpleStringStorage
    private let directory: URL
    private var realDatabase = ReplaysDatabase()
    var database: ReplaysDatabase {
        realDatabase
    }

    init(directory: URL? = nil) {
        if let directory {
            storage = SimpleStringStorage(
                key: "replays",
                directory: createAndGetDirectory(root: directory, name: "Database")
            )
            self.directory = createAndGetDirectory(root: directory, name: "Replays")
        } else {
            storage = defaultStorage
            self.directory = createAndGetDirectory(name: "Replays")
        }
    }

    func load() {
        do {
            try tryLoadAndMigrate(settings: storage.get())
        } catch {
            logger.info("replays-storage: Failed to load with error \(error). Using default.")
            realDatabase = ReplaysDatabase()
        }
        cleanup()
    }

    func delete(id: UUID) {
        database.replays.removeAll { $0.id == id }
    }

    func store() {
        do {
            try storage.set(realDatabase.toString())
        } catch {
            logger.info("replays-storage: Failed to store.")
        }
    }

    func createReplay() -> ReplaySettings {
        ReplaySettings()
    }

    func append(replay: ReplaySettings) {
        while isFull() {
            url(replay: database.replays.removeLast()).remove()
        }
        database.replays.insert(replay, at: 0)
    }

    func isFull() -> Bool {
        database.replays.count > 499
    }

    func defaultStorageDirectory() -> URL {
        directory
    }

    func url(replay: ReplaySettings) -> URL {
        directory.appending(component: replay.name())
    }
    
    private func cleanup() {
        database.replays = database.replays.filter { url(replay: $0).exists() }
        let knownNames = Set(database.replays.map { $0.name() })
        let directory = directory
        DispatchQueue.global(qos: .utility).async {
            guard let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: nil
            ) else {
                return
            }
            for case let fileUrl as URL in enumerator where !knownNames.contains(fileUrl.lastPathComponent) {
                logger.debug("replays-storage: Removing unused file \(fileUrl)")
                fileUrl.remove()
            }
        }
    }

    private func tryLoadAndMigrate(settings: String) throws {
        realDatabase = try ReplaysDatabase.fromString(settings: settings)
        migrateFromOlderVersions()
    }
    
    private func migrateFromOlderVersions() {}
}
