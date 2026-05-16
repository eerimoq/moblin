import Collections
import Foundation

extension Model {
    func debugLog(message: String) {
        DispatchQueue.main.async {
            if self.log.count > self.database.debug.maximumLogLines {
                self.log.removeFirst()
            }
            self.log.append(LogEntry(id: self.logId, message: message))
            self.logId += 1
            self.remoteControlLog(entry: message)
            if self.streamLog.count >= 100_000 {
                self.streamLog.removeFirst()
            }
            self.streamLog.append(message)
        }
    }

    func makeStreamShareLogUrl(logId: UUID) -> URL {
        logsStorage.makePath(id: logId)
    }

    func clearLog() {
        log = []
    }

    func formatLog(log: Deque<LogEntry>) -> URL {
        var data = "Version: \(appVersion())\n"
        data += "Debug: \(logger.debugEnabled)\n\n"
        data += log.map { e in e.message }.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Moblin-log-\(Date())")
            .appendingPathExtension("txt")
        try? data.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
