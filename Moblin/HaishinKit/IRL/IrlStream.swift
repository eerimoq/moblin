import Foundation

class IrlStream: NetStream {
    var client: IrlClient?
    private var muxer = IrlMuxer()

    override init() {
        client = IrlClient()
        super.init()
    }

    func start() {
        client?.start()
        lockQueue.async {
            self.mixer.startEncoding(self.muxer)
            self.mixer.startRunning()
        }
    }

    func stop() {
        client?.stop()
        client = nil
        lockQueue.async {
            self.mixer.stopRunning()
            self.mixer.stopEncoding()
        }
    }
}
