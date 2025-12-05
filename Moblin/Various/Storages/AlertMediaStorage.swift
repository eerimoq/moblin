import Foundation

class AlertVideoMediaStorage {
    private var fileManager: FileManager
    private var mediasUrl: URL

    init() {
        fileManager = FileManager.default
        mediasUrl = createAndGetDirectory(name: "Alerts", "Videos")
    }

    func makePath(filename: String) -> URL {
        return mediasUrl.appendingPathComponent(filename)
    }

    func add(filename: String, url: URL) {
        try? fileManager.moveItem(at: url, to: makePath(filename: filename))
    }

    func remove(filename: String) {
        try? fileManager.removeItem(at: makePath(filename: filename))
    }
}

class AlertMediaStorage: FileStorage {
    let videos = AlertVideoMediaStorage()

    init() {
        super.init(directory: "Alerts")
    }
}
