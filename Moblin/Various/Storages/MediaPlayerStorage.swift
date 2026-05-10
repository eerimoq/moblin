import Foundation

let mediaPlayerStorageDirectory = "Medias"

class MediaPlayerStorage {
    private var fileManager: FileManager
    private var mediasUrl: URL

    init() {
        fileManager = FileManager.default
        mediasUrl = createAndGetDirectory(name: mediaPlayerStorageDirectory)
    }

    func makePath(id: UUID) -> URL {
        mediasUrl.appendingPathComponent("\(id).mp4")
    }

    func ids() -> [UUID] {
        fileManager.idsBeforeDot(directory: mediasUrl.path)
    }

    func add(id: UUID, url: URL) {
        try? fileManager.moveItem(at: url, to: makePath(id: id))
    }

    func remove(id: UUID) {
        do {
            try fileManager.removeItem(at: makePath(id: id))
        } catch {
            logger.info("media-player-storage: Remove failed with error \(error)")
        }
    }
}
