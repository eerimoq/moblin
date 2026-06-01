import Foundation

class EasyLogger {
    var handler: ((String) -> Void)?
    var debugEnabled: Bool = false

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private func makeTimestamp() -> String {
        EasyLogger.timestampFormatter.string(from: Date())
    }

    func debug(_ message: @autoclosure () -> String) {
        if debugEnabled {
            log(message())
        }
    }

    func info(_ message: String) {
        log(message)
    }

    private func log(_ message: String) {
        let message = "\(makeTimestamp()) \(message)"
        #if DEBUG
        print(message)
        #endif
        handler?(message)
    }
}

nonisolated(unsafe) let logger = EasyLogger()
