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
}

extension Model {
    func updateVideoPreviews() {
        let oldFeeds = videoPreview.feeds
        videoPreview.feeds.removeAll()
        if streamOverlay.showingVideoPreview {
            guard let scene = getSelectedScene() else {
                return
            }
            let devices = getBuiltinCameraDevices(scene: scene, sceneDevice: cameraDevice)
            for camera in listCameras() {
                if let device = devices.devices.first(where: { $0.device.uniqueID == camera.id }) {
                    appendVideoPreviewIfNeeded(cameraId: device.id,
                                               name: device.device.name(),
                                               oldFeeds: oldFeeds)
                    continue
                }
                guard let cameraId = UUID(uuidString: camera.id) else {
                    continue
                }
                guard activeBufferedVideoIds.contains(cameraId) else {
                    continue
                }
                appendVideoPreviewIfNeeded(cameraId: cameraId, name: camera.name, oldFeeds: oldFeeds)
            }
        } else {
            media.removeAllVideoPreviews()
        }
    }

    private func appendVideoPreviewIfNeeded(cameraId: UUID, name: String, oldFeeds: [VideoPreviewFeed]) {
        if let feed = oldFeeds.first(where: { $0.cameraId == cameraId }) {
            videoPreview.feeds.append(feed)
        } else {
            let feed = VideoPreviewFeed(cameraId: cameraId, name: name)
            videoPreview.feeds.append(feed)
            media.setVideoPreview(cameraId: cameraId, drawable: feed.previewView)
        }
    }
}
