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
        feeds.sort {
            $0.cameraId.uuidString < $1.cameraId.uuidString
        }
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

extension Model {
    func addVideoPreviewFeed(cameraId: UUID) {
        guard streamOverlay.showingVideoPreview,
              let name = getBufferedVideoName(cameraId: cameraId),
              let feed = videoPreview.addFeed(cameraId: cameraId, name: name)
        else {
            return
        }
        media.setVideoPreview(cameraId: cameraId, drawable: feed.previewView)
    }

    func removeVideoPreviewFeed(cameraId: UUID) {
        guard streamOverlay.showingVideoPreview else {
            return
        }
        videoPreview.removeFeed(cameraId: cameraId)
        media.removeVideoPreview(cameraId: cameraId)
    }

    private func getBufferedVideoName(cameraId: UUID) -> String? {
        if let stream = getRtmpStream(id: cameraId) {
            return stream.camera()
        } else if let stream = getSrtlaStream(id: cameraId) {
            return stream.camera()
        } else if let stream = getRistStream(id: cameraId) {
            return stream.camera()
        } else if let stream = getRtspStream(id: cameraId) {
            return stream.camera()
        } else if let stream = getWhipStream(id: cameraId) {
            return stream.camera()
        } else if let stream = getWhepStream(id: cameraId) {
            return stream.camera()
        } else {
            return nil
        }
    }
}
