import AVFoundation
import Foundation

class VideoPreviewFeed: Identifiable, ObservableObject {
    let cameraId: UUID
    let name: String
    let previewView: PreviewView

    init(cameraId: UUID, name: String) {
        self.cameraId = cameraId
        self.name = name
        previewView = PreviewView()
        previewView.videoGravity = .resizeAspect
    }

    func enqueue(_ sampleBuffer: CMSampleBuffer, isFirstAfterAttach: Bool) {
        previewView.enqueue(sampleBuffer, isFirstAfterAttach: isFirstAfterAttach)
    }
}

class VideoPreviewProvider: ObservableObject {
    @Published var feeds: [VideoPreviewFeed] = []

    func addFeed(cameraId: UUID, name: String) -> VideoPreviewFeed? {
        guard !feeds.contains(where: { $0.cameraId == cameraId }) else {
            return nil
        }
        let feed = VideoPreviewFeed(cameraId: cameraId, name: name)
        feeds.append(feed)
        return feed
    }

    func removeFeed(cameraId: UUID) {
        feeds.removeAll { $0.cameraId == cameraId }
    }

    func getFeed(cameraId: UUID) -> VideoPreviewFeed? {
        return feeds.first { $0.cameraId == cameraId }
    }

    func removeAllFeeds() {
        feeds.removeAll()
    }
}
