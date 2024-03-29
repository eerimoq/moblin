import Foundation

class KickViewers {
    private var task: Task<Void, Error>?
    var numberOfViewers: Int?

    func start(channelName: String) {
        task = Task.init {
            var delay = 1
            while true {
                do {
                    try await sleep(seconds: delay)
                    let info = try await getKickChannelInfo(channelName: channelName)
                    self.numberOfViewers = info.livestream?.viewers
                } catch {}
                if Task.isCancelled {
                    self.numberOfViewers = nil
                    break
                }
                delay = 30
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
