import Foundation

class PngTuberStorage {
    private var fileManager: FileManager
    private var pngTubersUrl: URL

    init() {
        fileManager = FileManager.default
        pngTubersUrl = createAndGetDirectory(name: "PNGTuber")
    }

    func makePath(id: UUID) -> URL {
        return pngTubersUrl.appendingPathComponent(id.uuidString)
    }

    func ids() -> [UUID] {
        return fileManager.ids(directory: pngTubersUrl.path)
    }

    func add(id: UUID, url: URL) {
        do {
            let path = makePath(id: id)
            try? fileManager.removeItem(at: path)
            try fileManager.moveItem(at: url, to: path)
        } catch {
            logger.info("pngtuber-storage: Move failed with error \(error)")
        }
    }

    func remove(id: UUID) {
        do {
            try fileManager.removeItem(at: makePath(id: id))
        } catch {
            logger.error("pngtuber-storage: Remove failed with error \(error)")
        }
    }

    func write(id: UUID, data: Data) {
        do {
            try data.write(to: makePath(id: id))
        } catch {
            logger.error("pngtuber: Write failed with error \(error)")
        }
    }

    func tryRead(id: UUID) -> Data? {
        return try? Data(contentsOf: makePath(id: id))
    }
}
