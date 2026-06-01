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

    func debug(_ messsge: @autoclosure () -> String) {
        if debugEnabled {
            log(messsge())
        }
    }

    func info(_ messsge: String) {
        log(messsge)
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
