import Foundation
import Logboard

class EasyLogger {
    var handler: ((String) -> Void)?
    var debugEnabled: Bool = false

    private func makeTimestamp() -> String {
        return Date()
            .formatted(.dateTime.hour().minute().second()
                .secondFraction(.fractional(3)))
    }

    func debug(_ messsge: String) {
        if debugEnabled {
            let formattedMessage = "\(makeTimestamp()) \(messsge)"
            print(formattedMessage)
            handler?(formattedMessage)
        }
    }

    func info(_ messsge: String) {
        let formattedMessage = "\(makeTimestamp()) \(messsge)"
        print(formattedMessage)
        handler?(formattedMessage)
    }

    func warning(_ messsge: String) {
        let formattedMessage = "\(makeTimestamp()) \(messsge)"
        print(formattedMessage)
        handler?(formattedMessage)
    }

    func error(_ messsge: String) {
        let formattedMessage = "\(makeTimestamp()) \(messsge)"
        print(formattedMessage)
        handler?(formattedMessage)
    }
}

let logger = EasyLogger()
