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

extension Model {
    func addVideoPreviewFeed(cameraId: UUID) {
        guard streamOverlay.showingVideoPreview else {
            return
        }
        let name = getBufferedVideoName(cameraId: cameraId)
        if let feed = videoPreview.addFeed(cameraId: cameraId, name: name) {
            media.setVideoPreview(cameraId: cameraId, drawable: feed.previewView)
        }
    }

    func removeVideoPreviewFeed(cameraId: UUID) {
        guard streamOverlay.showingVideoPreview else {
            return
        }
        videoPreview.removeFeed(cameraId: cameraId)
        media.removeVideoPreview(cameraId: cameraId)
    }

    func updateVideoPreviewFeeds() {
        guard streamOverlay.showingVideoPreview else {
            return
        }
        guard let scene = getSelectedScene() else {
            return
        }
        let devices = getBuiltinCameraDevices(scene: scene, sceneDevice: cameraDevice)
        let builtinDeviceIds = Set(devices.devices.map(\.id))
        for feed in videoPreview.feeds {
            if !builtinDeviceIds.contains(feed.cameraId), !activeBufferedVideoIds.contains(feed.cameraId) {
                videoPreview.removeFeed(cameraId: feed.cameraId)
                media.removeVideoPreview(cameraId: feed.cameraId)
            }
        }
        for device in devices.devices {
            if let feed = videoPreview.addFeed(cameraId: device.id, name: device.name()) {
                media.setVideoPreview(cameraId: device.id, drawable: feed.previewView)
            }
        }
    }

    private func getBufferedVideoName(cameraId: UUID) -> String {
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
        }
        return String(localized: "Unknown")
    }
}
