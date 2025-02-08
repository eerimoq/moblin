import Foundation

class MediaPlayerStorage {
    private var fileManager: FileManager
    private var mediasUrl: URL

    init() {
        fileManager = FileManager.default
        let homeUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            .first!
        mediasUrl = homeUrl.appendingPathComponent("Medias")
        do {
            try fileManager.createDirectory(
                at: mediasUrl,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            logger.error("media-player-storage: Error creating images directory: \(error)")
        }
    }

    func makePath(id: UUID) -> URL {
        return mediasUrl.appendingPathComponent("\(id).mp4")
    }

    func ids() -> [UUID] {
        do {
            var ids: [UUID] = []
            for file in try fileManager.contentsOfDirectory(atPath: mediasUrl.path) {
                let parts = file.components(separatedBy: ".")
                guard parts.count > 1, let id = UUID(uuidString: parts[0]) else {
                    continue
                }
                ids.append(id)
            }
            return ids
        } catch {}
        return []
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
