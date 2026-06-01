import Foundation

class EasyLogger {
    var handler: ((String) -> Void)?
    var debugEnabled: Bool = false

    private func makeTimestamp() -> String {
        Date()
            .formatted(.dateTime.hour().minute().second()
                .secondFraction(.fractional(3)))
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
