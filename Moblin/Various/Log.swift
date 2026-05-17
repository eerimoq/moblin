import Foundation

class EasyLogger {
    var handler: ((String) -> Void)?
    var debugEnabled: Bool = false

    private func makeTimestamp() -> String {
        Date()
            .formatted(.dateTime.hour().minute().second()
                .secondFraction(.fractional(3)))
    }

    func debug(_ messsge: String) {
        if debugEnabled {
            log(messsge)
        }
    }

    func info(_ messsge: String) {
        log(messsge)
    }

    private func log(_ messsge: String) {
        #if DEBUG
        print(messsge)
        #endif
        handler?("\(makeTimestamp()) \(messsge)")
    }
}

nonisolated(unsafe) let logger = EasyLogger()
