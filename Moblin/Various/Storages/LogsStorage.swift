import Foundation

class LogsStorage {
    var fileManager: FileManager
    private var logsUrl: URL

    init() {
        fileManager = FileManager.default
        logsUrl = createAndGetDirectory(name: "Logs")
    }

    func makePath(id: UUID) -> URL {
        return logsUrl.appendingPathComponent("\(id.uuidString).txt")
    }

    func ids() -> [UUID] {
        return fileManager.idsBeforeDot(directory: logsUrl.path)
    }

    func write(id: UUID, data: Data) {
        do {
            try data.write(to: makePath(id: id))
        } catch {
            logger.error("logs-storage: Write failed with error \(error)")
        }
    }

    func remove(id: UUID) {
        do {
            try fileManager.removeItem(at: makePath(id: id))
        } catch {
            logger.error("logs-storage: Remove failed with error \(error)")
        }
    }
}
