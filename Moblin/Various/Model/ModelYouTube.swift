import Foundation

extension Model {
    func startFetchingYouTubeChatVideoId() {
        youTubeFetchVideoIdStartTime = .now
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
                stopFetchingYouTubeChatVideoId()
                guard videoId != stream.youTubeVideoId else {
                    return
                }
                stream.youTubeVideoId = videoId
                if stream.enabled {
                    youTubeVideoIdUpdated()
                }
            }
        }
    }
}
