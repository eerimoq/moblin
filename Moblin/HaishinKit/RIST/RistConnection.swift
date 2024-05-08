import Foundation

class RistConnection {
    var stream: RistStream?

    init() {
        stream = nil
    }

    func start(url: String) {
        stream?.start(url: url)
    }

    func stop() {
        stream?.stop()
        stream = nil
    }
}
