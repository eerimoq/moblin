import Foundation

class KickViewers {
    private var task: Task<Void, Error>?
    var numberOfViewers: Int?

    func start(channelName: String) {
        task = Task {
            var delay = 1
            while true {
                do {
                    try await sleep(seconds: delay)
                    let info = try await getKickChannelInfo(channelName: channelName)
                    await self.setNumberOfViewers(value: info.livestream?.viewers)
                } catch {}
                if Task.isCancelled {
                    await self.setNumberOfViewers(value: nil)
                    break
                }
                delay = 30
            }
        }
    }

    private func setNumberOfViewers(value: Int?) async {
        await MainActor.run {
            self.numberOfViewers = value
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
