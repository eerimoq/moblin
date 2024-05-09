import Foundation

class RistConnection {
    var stream: RistStream?

    init() {
        stream = nil
    }

    func start(url: String, useBonding: Bool) {
        stream?.start(url: url, useBonding: useBonding)
    }

    func stop() {
        stream?.stop()
    }
}
