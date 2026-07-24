import Foundation

@MainActor
class VkVideoLivePlatformStatus {
    private var api: VkVideoLiveApi?
    private var channelUrl: String = ""
    private let timer = SimpleTimer(queue: .main)
    var platformStatus: PlatformStatus = .unknown

    func start(channelUrl: String, accessToken: String) {
        self.channelUrl = channelUrl
        api = VkVideoLiveApi(accessToken: accessToken)
        timer.startPeriodic(interval: 30, initial: 1) { [weak self] in
            self?.update()
        }
    }

    func stop() {
        timer.stop()
        api = nil
        platformStatus = .unknown
    }

    private func update() {
        api?.getChannel(channelUrl: channelUrl) { [weak self] data in
            guard let self else {
                return
            }
            guard let data else {
                platformStatus = .unknown
                return
            }
            if let stream = data.stream, stream.ended_at == nil || stream.ended_at == 0 {
                platformStatus = .live(viewerCount: stream.counters?.viewers ?? 0)
            } else {
                platformStatus = .offline
            }
        }
    }
}
