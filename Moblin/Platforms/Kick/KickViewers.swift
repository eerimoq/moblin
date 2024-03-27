import Foundation

class KickViewers {
    private var task: Task<Void, Error>?

    func start(channelId _: String) {
        task = Task.init {
            while true {
                if Task.isCancelled {
                    return
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
