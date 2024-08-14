import Foundation

class AlertMediaStorage {
    private var fileManager: FileManager
    private var mediasUrl: URL

    init() {
        fileManager = FileManager.default
        let homeUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            .first!
        mediasUrl = homeUrl.appendingPathComponent("Alerts")
        do {
            try fileManager.createDirectory(
                at: mediasUrl,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            logger.error("alert-media-storage: Error creating images directory: \(error)")
        }
    }

    func makePath(id: UUID) -> URL {
        return mediasUrl.appendingPathComponent(id.uuidString)
    }

    func ids() -> [UUID] {
        do {
            var ids: [UUID] = []
            for file in try fileManager.contentsOfDirectory(atPath: mediasUrl.path) {
                if let id = UUID(uuidString: file) {
                    ids.append(id)
                }
            }
            return ids
        } catch {}
        return []
    }

    func add(id: UUID, url: URL) {
        do {
            let path = makePath(id: id)
            try? fileManager.removeItem(at: path)
            try fileManager.moveItem(at: url, to: path)
        } catch {
            logger.info("alert-media-storage: Move failed with error \(error)")
        }
    }

    func remove(id: UUID) {
        do {
            try fileManager.removeItem(at: makePath(id: id))
        } catch {
            logger.error("alert-media-storage: Remove failed with error \(error)")
        }
    }

    func tryRead(id: UUID) -> Data? {
        return try? Data(contentsOf: makePath(id: id))
    }
}
