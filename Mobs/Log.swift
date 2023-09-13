import Foundation
import os
import Logboard

class EasyLogger {
    private var logger: Logger = Logger()
    private var handler: ((String) -> Void)? = nil
    private var lock = NSLock()
    
    init() {
        LBLogger.with("com.haishinkit.HaishinKit").level = .debug
        LBLogger.with("com.haishinkit.SRTHaishinKit").level = .trace
    }
    
    func debug(_ messsge: String) {
        logger.debug("\(messsge)")
    }
    
    func info(_ messsge: String) {
        logger.info("\(messsge)")
        lock.withLock {
            handler?(messsge)
        }
    }
    
    func warning(_ messsge: String) {
        logger.warning("\(messsge)")
        lock.withLock {
            handler?(messsge)
        }
    }
    
    func error(_ messsge: String) {
        logger.error("\(messsge)")
        lock.withLock {
            handler?(messsge)
        }
    }
    
    func setLogHandler(handler: @escaping (String) -> Void) {
        lock.withLock {
            self.handler = handler
        }
    }
}

let logger = EasyLogger()
