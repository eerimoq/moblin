import AVFoundation
import Foundation

class VideoPreviewFeed: Identifiable, ObservableObject {
    let id: UUID
    let name: String
    let previewView: PreviewView

    init(cameraId: UUID, name: String) {
        id = cameraId
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

    func addFeed(cameraId: UUID, name: String) {
        guard !feeds.contains(where: { $0.id == cameraId }) else {
            return
        }
        feeds.append(VideoPreviewFeed(cameraId: cameraId, name: name))
    }

    func removeFeed(cameraId: UUID) {
        feeds.removeAll { $0.id == cameraId }
    }

    func getFeed(cameraId: UUID) -> VideoPreviewFeed? {
        return feeds.first { $0.id == cameraId }
    }

    func removeAllFeeds() {
        feeds.removeAll()
    }
}
