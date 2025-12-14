import Foundation

class KickPlatformStatus {
    private var task: Task<Void, Error>?
    var platformStatus: PlatformStatus = .unknown

    func start(channelName: String) {
        task = Task {
            var delay = 1
            while true {
                do {
                    try await sleep(seconds: delay)
                    let info = try await getKickChannelInfo(channelName: channelName)
                    if let livestream = info.livestream {
                        await self.setNumberOfViewers(status: .live(viewerCount: livestream.viewers))
                    } else {
                        await self.setNumberOfViewers(status: .offline)
                    }
                } catch {
                    await self.setNumberOfViewers(status: .unknown)
                }
                if Task.isCancelled {
                    await self.setNumberOfViewers(status: .unknown)
                    break
                }
                delay = 30
            }
        }
    }

    private func setNumberOfViewers(status: PlatformStatus) async {
        await MainActor.run {
            self.platformStatus = status
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
