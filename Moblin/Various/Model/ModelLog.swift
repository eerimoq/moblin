import Collections
import Foundation

private let maximumFileLogLines = 100

func createFileLog() -> [String] {
    var log = ["", "Version: \(appVersion())", ""]
    log.reserveCapacity(maximumFileLogLines)
    return log
}

extension Model {
    func setupLogging() {
        logger.handler = debugLog(message:)
        logger.debugEnabled = database.debug.debugLogging
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

    func writeFileLogToFile() {
        logsStorage.write(lines: fileLog)
        fileLog.removeAll(keepingCapacity: true)
    }

    func flushFileLogToFile() {
        logsStorage.flush()
    }

    private func debugLog(message: String) {
        DispatchQueue.main.async {
            if self.log.count > self.database.debug.maximumLogLines {
                self.log.removeFirst()
            }
            self.log.append(LogEntry(id: self.logId, message: message))
            self.logId += 1
            self.remoteControlLog(entry: message)
            if self.fileLog.count >= maximumFileLogLines {
                self.writeFileLogToFile()
            }
            self.fileLog.append(message)
        }
    }
}
