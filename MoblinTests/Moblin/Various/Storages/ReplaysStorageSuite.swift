import Foundation
@testable import Moblin
import Testing

private func waitUntil(timeout: Double, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
        if condition() {
            return true
        }
        Thread.sleep(forTimeInterval: 0.02)
    } while Date() < deadline
    return condition()
}

@Suite(.serialized)
struct ReplaysStorageSuite {
    @Test
    func staleDatabaseEntryIsPrunedOnLoad() {
        let storage = ReplaysStorage()
        let stale = storage.createReplay()
        storage.append(replay: stale)
        storage.store()

        let reloaded = ReplaysStorage()
        reloaded.load()

        #expect(!reloaded.database.replays.contains { $0.id == stale.id })
    }

    @Test
    func replayWithExistingFileSurvivesLoad() throws {
        let storage = ReplaysStorage()
        let kept = storage.createReplay()
        storage.append(replay: kept)
        storage.store()
        try Data().write(to: kept.url())
        defer { kept.url().remove() }

        let reloaded = ReplaysStorage()
        reloaded.load()

        #expect(reloaded.database.replays.contains { $0.id == kept.id })
    }

    @Test
    func orphanedFileIsRemovedAsynchronously() throws {
        let storage = ReplaysStorage()
        storage.store()
        let orphan = storage.defaultStorageDirectory().appending(component: "orphan-\(UUID()).mp4")
        try Data().write(to: orphan)
        defer { orphan.remove() }

        let reloaded = ReplaysStorage()
        reloaded.load()

        #expect(waitUntil(timeout: 2) { !orphan.exists() })
    }
}
