import Foundation
import Logboard

private func filename(_ file: String) -> String {
    return file.components(separatedBy: "/").last ?? file
}

class LogAppender: LBLoggerAppender {
    init() {}

    func append(
        _: LBLogger,
        level: LBLogger.Level,
        message: [Any],
        file: StaticString,
        function _: StaticString,
        line: Int
    ) {
        log(
            level: level,
            file: file,
            line: line,
            message: message.map { String(describing: $0) }.joined(separator: "")
        )
    }

    func append(
        _: LBLogger,
        level: LBLogger.Level,
        format: String,
        arguments: CVarArg,
        file: StaticString,
        function _: StaticString,
        line: Int
    ) {
        log(
            level: level,
            file: file,
            line: line,
            message: String(format: format, arguments)
        )
    }

    private func log(
        level: LBLogger.Level,
        file: StaticString,
        line: Int,
        message: String
    ) {
        let message = "haishinkit: \(filename(file.description)):\(line): \(message)"
        if level == .trace {
            logger.debug(message)
        } else {
            logger.info(message)
        }
    }
}

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
