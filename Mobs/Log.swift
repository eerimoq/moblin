import Foundation
import os

class EasyLogger {
    var logger: Logger = Logger()
    private var handler: ((String) -> Void)? = nil
    
    func debug(_ messsge: String) {
        logger.debug("\(messsge)")
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
