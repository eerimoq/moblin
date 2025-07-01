import Foundation

extension Model {
    func startFetchingYouTubeChatVideoId() {
        youTubeFetchVideoIdStartTime = .now
        tryToFetchYouTubeVideoId()
    }

    func stopFetchingYouTubeChatVideoId() {
        youTubeFetchVideoIdStartTime = nil
    }

    func tryToFetchYouTubeVideoId() {
        guard database.chat.enabled, !stream.youTubeHandle.isEmpty, let youTubeFetchVideoIdStartTime else {
            return
        }
        guard youTubeFetchVideoIdStartTime.duration(to: .now) < .seconds(120) else {
            stopFetchingYouTubeChatVideoId()
            makeErrorToast(title: String(localized: "Failed to fetch YouTube Video ID"),
                           subTitle: String(localized: "You must be live on YouTube for this to work."))
            return
        }
        Task { @MainActor in
            if let videoId = try? await fetchYouTubeVideoId(handle: stream.youTubeHandle) {
                self.stopFetchingYouTubeChatVideoId()
                self.stream.youTubeVideoId = videoId
                if self.stream.enabled {
                    self.youTubeVideoIdUpdated()
                }
                makeToast(title: String(localized: "Fetched YouTube Video ID (for chat)"))
            }
        }
    }
}
