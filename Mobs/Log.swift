import Foundation
import Logboard
import os

class EasyLogger {
    private var logger = Logger()
    var handler: ((String) -> Void)!
    var debugEnabled: Bool = false

    func debug(_ messsge: String) {
        logger.debug("\(messsge)")
        if debugEnabled {
            handler(messsge)
        }
    }

    func info(_ messsge: String) {
        logger.info("\(messsge)")
        handler(messsge)
    }

    func warning(_ messsge: String) {
        logger.warning("\(messsge)")
        handler(messsge)
    }

    func error(_ messsge: String) {
        logger.error("\(messsge)")
        handler(messsge)
    }
}

let logger = EasyLogger()
