import Foundation

class AlertMediaStorage: FileStorage {
    init() {
        super.init(directory: "Alerts")
    }
}
