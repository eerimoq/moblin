import Foundation
@testable import Moblin
import Testing

struct ReplaysStorageSuite {
    @Test
    func staleDatabaseEntryIsPrunedOnLoad() throws {
        let directory = try TemporaryDirectory()
        let storage = ReplaysStorage(directory: directory.url)
        let stale = storage.createReplay()
        storage.append(replay: stale)
        storage.store()
        let reloaded = ReplaysStorage(directory: directory.url)
        reloaded.load()
        #expect(!reloaded.database.replays.contains {
            $0.id == stale.id
        })
    }

    @Test
    func replayWithExistingFileSurvivesLoad() throws {
        let directory = try TemporaryDirectory()
        let storage = ReplaysStorage(directory: directory.url)
        let kept = storage.createReplay()
        storage.append(replay: kept)
        storage.store()
        try Data().write(to: storage.url(replay: kept))
        let reloaded = ReplaysStorage(directory: directory.url)
        reloaded.load()
        #expect(reloaded.database.replays.contains {
            $0.id == kept.id
        })
    }

    @Test
    func orphanedFileIsRemovedAsynchronously() throws {
        let directory = try TemporaryDirectory()
        let storage = ReplaysStorage(directory: directory.url)
        storage.store()
        let orphan = storage.defaultStorageDirectory().appending(component: "orphan-\(UUID()).mp4")
        try Data().write(to: orphan)
        let reloaded = ReplaysStorage(directory: directory.url)
        reloaded.load()
        #expect(waitUntil(timeout: .seconds(2)) {
            !orphan.exists()
        })
    }

    @Test
    func appendInsertsNewestFirst() throws {
        let directory = try TemporaryDirectory()
        let storage = ReplaysStorage(directory: directory.url)
        let first = storage.createReplay()
        let second = storage.createReplay()
        storage.append(replay: first)
        storage.append(replay: second)
        #expect(storage.database.replays.map(\.id) == [second.id, first.id])
    }

    @Test
    func isFullAtFiveHundredReplays() throws {
        let directory = try TemporaryDirectory()
        let storage = ReplaysStorage(directory: directory.url)
        for _ in 0 ..< 499 {
            storage.append(replay: storage.createReplay())
        }
        #expect(!storage.isFull())
        storage.append(replay: storage.createReplay())
        #expect(storage.isFull())
    }

    @Test
    func appendWhenFullRemovesOldestReplayAndItsFile() throws {
        let directory = try TemporaryDirectory()
        let storage = ReplaysStorage(directory: directory.url)
        let oldest = storage.createReplay()
        storage.append(replay: oldest)
        try Data().write(to: storage.url(replay: oldest))
        for _ in 0 ..< 499 {
            storage.append(replay: storage.createReplay())
        }
        let newest = storage.createReplay()
        storage.append(replay: newest)
        #expect(storage.database.replays.count == 500)
        #expect(storage.database.replays.first?.id == newest.id)
        #expect(!storage.database.replays.contains {
            $0.id == oldest.id
        })
        #expect(!storage.url(replay: oldest).exists())
    }

    @Test
    func deleteRemovesOnlyThatReplay() throws {
        let directory = try TemporaryDirectory()
        let storage = ReplaysStorage(directory: directory.url)
        let kept = storage.createReplay()
        let deleted = storage.createReplay()
        storage.append(replay: kept)
        storage.append(replay: deleted)
        storage.delete(id: deleted.id)
        #expect(storage.database.replays.map(\.id) == [kept.id])
    }

    @Test
    func replaySettingsSurviveStoreAndLoad() throws {
        let directory = try TemporaryDirectory()
        let storage = ReplaysStorage(directory: directory.url)
        let replay = storage.createReplay()
        replay.duration = 31.5
        replay.start = 12.0
        replay.stop = 25.0
        storage.append(replay: replay)
        storage.store()
        try Data().write(to: storage.url(replay: replay))
        let reloaded = ReplaysStorage(directory: directory.url)
        reloaded.load()
        let loaded = try #require(reloaded.database.replays.first)
        #expect(reloaded.database.replays.count == 1)
        #expect(loaded.id == replay.id)
        #expect(loaded.duration == 31.5)
        #expect(loaded.start == 12.0)
        #expect(loaded.stop == 25.0)
    }

    @Test
    func loadOrderIsPreserved() throws {
        let directory = try TemporaryDirectory()
        let storage = ReplaysStorage(directory: directory.url)
        for _ in 0 ..< 3 {
            let replay = storage.createReplay()
            storage.append(replay: replay)
            try Data().write(to: storage.url(replay: replay))
        }
        storage.store()
        let reloaded = ReplaysStorage(directory: directory.url)
        reloaded.load()
        #expect(reloaded.database.replays.map(\.id) == storage.database.replays.map(\.id))
    }

    @Test
    func corruptDatabaseLoadsEmpty() throws {
        let directory = try TemporaryDirectory()
        let storage = ReplaysStorage(directory: directory.url)
        try "not json".write(
            to: directory.url.appending(components: "Database", "replays"),
            atomically: true,
            encoding: .utf8
        )
        storage.load()
        #expect(storage.database.replays.isEmpty)
    }

    @Test
    func missingDatabaseLoadsEmpty() throws {
        let directory = try TemporaryDirectory()
        let storage = ReplaysStorage(directory: directory.url)
        storage.load()
        #expect(storage.database.replays.isEmpty)
    }

    @Test
    func cleanupKeepsFilesOfKnownReplays() throws {
        let directory = try TemporaryDirectory()
        let storage = ReplaysStorage(directory: directory.url)
        let kept = storage.createReplay()
        storage.append(replay: kept)
        storage.store()
        try Data().write(to: storage.url(replay: kept))
        let orphan = storage.defaultStorageDirectory().appending(component: "orphan-\(UUID()).mp4")
        try Data().write(to: orphan)
        let reloaded = ReplaysStorage(directory: directory.url)
        reloaded.load()
        #expect(waitUntil(timeout: .seconds(2)) {
            !orphan.exists()
        })
        #expect(reloaded.url(replay: kept).exists())
    }
}
