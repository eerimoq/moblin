import Foundation

class FileStorage {
    private var fileManager: FileManager
    private var directory: URL

    init(directory: String) {
        fileManager = FileManager.default
        self.directory = createAndGetDirectory(name: directory)
    }

    func makePath(id: UUID) -> URL {
        return directory.appendingPathComponent(id.uuidString)
    }

    func ids() -> [UUID] {
        return fileManager.ids(directory: directory.path)
    }

    func add(id: UUID, url: URL) {
        do {
            let path = makePath(id: id)
            try? fileManager.removeItem(at: path)
            try fileManager.moveItem(at: url, to: path)
        } catch {
            logger.info("file-storage: \(directory): Move failed with error \(error)")
        }
    }

    func remove(id: UUID) {
        do {
            try fileManager.removeItem(at: makePath(id: id))
        } catch {
            logger.error("file-storage: \(directory): Remove failed with error \(error)")
        }
    }

    func write(id: UUID, data: Data) {
        do {
            try data.write(to: makePath(id: id))
        } catch {
            logger.error("file-storage: \(directory): Write failed with error \(error)")
        }
    }

    func write(id: UUID, url: URL) {
        do {
            try write(id: id, data: Data(contentsOf: url))
        } catch {
            logger.error("file-storage: \(directory): Write URL failed with error \(error)")
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
}
