import Foundation

class ReplayTransitionsStorage {
    private var fileManager: FileManager
    private var mediasUrl: URL

    init() {
        fileManager = FileManager.default
        mediasUrl = createAndGetDirectory(name: "ReplayTransitions")
    }

    func makePath(filename: String) -> URL {
        return mediasUrl.appendingPathComponent(filename)
    }

    func add(filename: String, url: URL) {
        try? fileManager.moveItem(at: url, to: makePath(filename: filename))
    }

    func remove(filename: String) {
        do {
            try fileManager.removeItem(at: makePath(filename: filename))
        } catch {
            logger.debug("media-player-storage: Remove failed with error \(error)")
        }
    }
}
