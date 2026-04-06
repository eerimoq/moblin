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
            for device in devices.devices {
                appendVideoPreviewIfNeeded(cameraId: device.id, name: device.name(), oldFeeds: oldFeeds)
            }
            for camera in listCameras(excludeBuiltin: true) {
                guard let cameraId = UUID(uuidString: camera.id) else {
                    continue
                }
                guard activeBufferedVideoIds.contains(cameraId) else {
                    continue
                }
                guard isIngestVideoSource(cameraId: cameraId) else {
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

    private func isIngestVideoSource(cameraId: UUID) -> Bool {
        if getRtmpStream(id: cameraId) != nil {
            return true
        } else if getSrtlaStream(id: cameraId) != nil {
            return true
        } else if getRistStream(id: cameraId) != nil {
            return true
        } else if getRtspStream(id: cameraId) != nil {
            return true
        } else if getWhipStream(id: cameraId) != nil {
            return true
        } else if getWhepStream(id: cameraId) != nil {
            return true
        } else {
            return false
        }
    }
}
