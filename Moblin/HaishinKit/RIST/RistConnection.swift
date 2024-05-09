import Foundation

class RistConnection {
    var stream: RistStream?

    init() {
        stream = nil
    }

    func start(url: String, bonding: Bool) {
        stream?.start(url: url, bonding: bonding)
    }

    func stop() {
        stream?.stop()
    }
}
