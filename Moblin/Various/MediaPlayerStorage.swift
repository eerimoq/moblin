import Foundation

class MediaPlayerStorage {
    private var fileManager: FileManager
    private var mediasUrl: URL

    init() {
        fileManager = FileManager.default
        mediasUrl = createAndGetDirectory(name: "Medias")
    }

    func makePath(id: UUID) -> URL {
        return mediasUrl.appendingPathComponent("\(id).mp4")
    }

    func ids() -> [UUID] {
        return fileManager.idsBeforeDot(directory: mediasUrl.path)
    }

    func add(id: UUID, url: URL) {
        try? fileManager.moveItem(at: url, to: makePath(id: id))
    }

    func remove(id: UUID) {
        do {
            try fileManager.removeItem(at: makePath(id: id))
        } catch {
            logger.error("media-player-storage: Remove failed with error \(error)")
        }
    }
}
