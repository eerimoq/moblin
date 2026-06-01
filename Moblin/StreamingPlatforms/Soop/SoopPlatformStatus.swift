import Foundation

struct SoopChannelInfo: Codable {
    let currentSumViewer: Int
}

private let baseUrl = "https://api-channel.sooplive.com"

class SoopPlatformStatus: @unchecked Sendable {
    private var task: Task<Void, any Error>?
    var platformStatus: PlatformStatus = .unknown

    func start(userId: String) {
        platformStatus = .unknown
        guard let url = URL(string: "\(baseUrl)/v1.1/channel/\(userId)/home/section/broad") else {
            return
        }
        task = Task { @MainActor in
            var delay = 5
            while true {
                do {
                    try await sleep(seconds: delay)
                    let channelInfo = try await getChannelInfo(url: url)
                    self.platformStatus = .live(viewerCount: channelInfo.currentSumViewer)
                } catch {
                    self.platformStatus = .unknown
                }
                if Task.isCancelled {
                    self.platformStatus = .unknown
                    break
                }
                delay = 60
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func getChannelInfo(url: URL) async throws -> SoopChannelInfo {
        let (data, _) = try await httpGet(from: url)
        return try JSONDecoder().decode(SoopChannelInfo.self, from: data)
    }
}
