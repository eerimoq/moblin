import Foundation
import Logboard

private func filename(_ file: String) -> String {
    return file.components(separatedBy: "/").last ?? file
}

class LogAppender: LBLoggerAppender {
    init() {}

    func append(
        _: LBLogger,
        level _: LBLogger.Level,
        message: [Any],
        file: StaticString,
        function _: StaticString,
        line: Int
    ) {
        log(
            file: file,
            line: line,
            message: message.map { String(describing: $0) }.joined(separator: "")
        )
    }

    func append(
        _: LBLogger,
        level _: LBLogger.Level,
        format: String,
        arguments: CVarArg,
        file: StaticString,
        function _: StaticString,
        line: Int
    ) {
        log(
            file: file,
            line: line,
            message: String(format: format, arguments)
        )
    }

    private func log(file: StaticString, line: Int, message: String) {
        logger.debug("haishinkit: \(filename(file.description)):\(line): \(message)")
    }
}

class EasyLogger {
    var handler: ((String) -> Void)?
    var debugEnabled: Bool = true

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
