import Foundation

class VTuberStorage {
    private var fileManager: FileManager
    private var vTubersUrl: URL

    init() {
        fileManager = FileManager.default
        vTubersUrl = createAndGetDirectory(name: "VTuber")
    }

    func makePath(id: UUID) -> URL {
        return vTubersUrl.appendingPathComponent(id.uuidString)
    }

    func ids() -> [UUID] {
        return fileManager.ids(directory: vTubersUrl.path)
    }

    func add(id: UUID, url: URL) {
        do {
            let path = makePath(id: id)
            try? fileManager.removeItem(at: path)
            try fileManager.moveItem(at: url, to: path)
        } catch {
            logger.info("vtuber-storage: Move failed with error \(error)")
        }
    }

    func remove(id: UUID) {
        do {
            try fileManager.removeItem(at: makePath(id: id))
        } catch {
            logger.error("vtuber-storage: Remove failed with error \(error)")
        }
    }

    func write(id: UUID, data: Data) {
        do {
            try data.write(to: makePath(id: id))
        } catch {
            logger.error("vtuber: Write failed with error \(error)")
        }
    }

    func tryRead(id: UUID) -> Data? {
        return try? Data(contentsOf: makePath(id: id))
    }
}
