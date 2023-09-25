import Foundation
import Logboard
import os

class EasyLogger {
    private var logger = Logger()
    private var handler: ((String) -> Void)?
    var debugEnabled: Bool = false

    init() {
        // LBLogger.with("com.haishinkit.HaishinKit").level = .info
        // LBLogger.with("com.haishinkit.SRTHaishinKit").level = .trace
    }

    func debug(_ messsge: String) {
        logger.debug("\(messsge)")
        if debugEnabled {
            handler?(messsge)
        }
    }

    func info(_ messsge: String) {
        logger.info("\(messsge)")
        handler?(messsge)
    }

    func warning(_ messsge: String) {
        logger.warning("\(messsge)")
        handler?(messsge)
    }

    func error(_ messsge: String) {
        logger.error("\(messsge)")
        handler?(messsge)
    }

    func setLogHandler(handler: @escaping (String) -> Void) {
        self.handler = handler
    }
}

let logger = EasyLogger()
