import Foundation

class LogsStorage {
    var fileManager: FileManager
    private var logsUrl: URL

    init() {
        fileManager = FileManager.default
        let homeUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            .first!
        logsUrl = homeUrl.appendingPathComponent("Logs")
        do {
            try fileManager.createDirectory(
                at: logsUrl,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            logger.error("logs-storage: Error creating logs directory: \(error)")
        }
    }

    func makePath(id: UUID) -> URL {
        return logsUrl.appendingPathComponent("\(id.uuidString).txt")
    }

    func ids() -> [UUID] {
        do {
            var ids: [UUID] = []
            for file in try fileManager.contentsOfDirectory(atPath: logsUrl.path) {
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
