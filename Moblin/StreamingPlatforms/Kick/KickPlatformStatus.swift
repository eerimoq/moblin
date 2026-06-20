import Foundation

@MainActor
class KickPlatformStatus: @unchecked Sendable {
    private var task: Task<Void, any Error>?
    var platformStatus: PlatformStatus = .unknown

    func start(channelName: String) {
        task = Task {
            var delay = 1
            while true {
                do {
                    try await sleep(seconds: delay)
                    let info = try await getKickChannelInfo(channelName: channelName)
                    if let livestream = info.livestream {
                        self.setNumberOfViewers(status: .live(viewerCount: livestream.viewers))
                    } else {
                        self.setNumberOfViewers(status: .offline)
                    }
                } catch {
                    self.setNumberOfViewers(status: .unknown)
                }
                if Task.isCancelled {
                    self.setNumberOfViewers(status: .unknown)
                    break
                }
                delay = 30
            }
        }
    }

    private func setNumberOfViewers(status: PlatformStatus) {
        platformStatus = status
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
