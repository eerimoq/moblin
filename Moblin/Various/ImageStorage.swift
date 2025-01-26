import Foundation

class ImageStorage {
    private var fileManager: FileManager
    private var imagesUrl: URL

    init() {
        fileManager = FileManager.default
        let homeUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            .first!
        imagesUrl = homeUrl.appendingPathComponent("Images")
        do {
            try fileManager.createDirectory(
                at: imagesUrl,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            logger.error("image-storage: Error creating images directory: \(error)")
        }
    }

    func makePath(id: UUID) -> URL {
        return imagesUrl.appendingPathComponent(id.uuidString)
    }

    func ids() -> [UUID] {
        do {
            let files = try fileManager.contentsOfDirectory(atPath: imagesUrl.path)
            return files.map { file in UUID(uuidString: file)! }
        } catch {}
        return []
    }

    func write(id: UUID, data: Data) {
        do {
            try data.write(to: makePath(id: id))
        } catch {
            logger.error("image-storage: Write failed with error \(error)")
        }
    }

    func write(id: UUID, url: URL) {
        do {
            try write(id: id, data: Data(contentsOf: url))
        } catch {
            logger.error("image-storage: Write URL failed with error \(error)")
        }
    }

    func read(id: UUID) -> Data? {
        do {
            return try Data(contentsOf: makePath(id: id))
        } catch {
            logger.error("image-storage: Read failed with error \(error)")
        }
        return nil
    }

    func tryRead(id: UUID) -> Data? {
        return try? Data(contentsOf: makePath(id: id))
    }

    func remove(id: UUID) {
        do {
            try fileManager.removeItem(at: makePath(id: id))
        } catch {
            logger.error("image-storage: Remove failed with error \(error)")
        }
    }
}
