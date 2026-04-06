import AVFoundation
import ReplayKit

extension Model {
    func isScreenCaptureCamera(cameraId: CameraId) -> Bool {
        return cameraId == screenCaptureCameraId.uuidString
    }

    func isNoneCamera(cameraId: CameraId) -> Bool {
        return cameraId == noneCameraId.uuidString
    }

    #if targetEnvironment(macCatalyst)
    func sceneNeedsMacScreenCapture(scene: SettingsScene) -> Bool {
        if scene.videoSource.cameraPosition == .screenCapture {
            return true
        }
        var addedSceneIds: Set<UUID> = []
        if let quickSwitchGroup = scene.quickSwitchGroup {
            for otherScene in enabledScenes where otherScene.quickSwitchGroup == quickSwitchGroup {
                if otherScene.videoSource.cameraPosition == .screenCapture {
                    return true
                }
                if sceneWidgetsNeedMacScreenCapture(scene: scene, addedSceneIds: &addedSceneIds) {
                    return true
                }
            }
        }
        return sceneWidgetsNeedMacScreenCapture(scene: scene, addedSceneIds: &addedSceneIds)
    }

    private func sceneWidgetsNeedMacScreenCapture(scene: SettingsScene,
                                                  addedSceneIds: inout Set<UUID>) -> Bool
    {
        for sceneWidget in scene.widgets {
            guard let widget = findWidget(id: sceneWidget.widgetId) else {
                continue
            }
            guard widget.enabled else {
                continue
            }
            switch widget.type {
            case .videoSource:
                if widget.videoSource.videoSource.cameraPosition == .screenCapture {
                    return true
                }
            case .vTuber:
                if widget.vTuber.videoSource.cameraPosition == .screenCapture {
                    return true
                }
            case .pngTuber:
                if widget.pngTuber.videoSource.cameraPosition == .screenCapture {
                    return true
                }
            case .scene:
                if !addedSceneIds.contains(widget.scene.sceneId) {
                    addedSceneIds.insert(widget.scene.sceneId)
                    if let nestedScene = database.scenes.first(where: { $0.id == widget.scene.sceneId }) {
                        if sceneWidgetsNeedMacScreenCapture(scene: nestedScene,
                                                            addedSceneIds: &addedSceneIds)
                        {
                            return true
                        }
                    }
                }
            default:
                break
            }
        }
        return false
    }
    #else
    func sceneNeedsMacScreenCapture(scene _: SettingsScene) -> Bool {
        return false
    }
    #endif

    private func handleScreenCaptureStarted(latency: Double) {
        makeToast(title: String(localized: "Screen capture started"))
        media.addBufferedVideo(
            cameraId: screenCaptureCameraId,
            name: screenCaptureCameraName,
            latency: latency
        )
    }

    private func handleScreenCaptureStopped() {
        makeToast(title: String(localized: "Screen capture stopped"))
        media.removeBufferedVideo(cameraId: screenCaptureCameraId)
    }

    private func handleScreenCaptureSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedVideoSampleBuffer(cameraId: screenCaptureCameraId, sampleBuffer: sampleBuffer)
    }
}

extension Model: SampleBufferReceiverDelegate {
    func senderConnected() {
        DispatchQueue.main.async {
            self.handleScreenCaptureStarted(latency: screenRecordingLatency)
        }
    }

    func senderDisconnected() {
        DispatchQueue.main.async {
            self.handleScreenCaptureStopped()
        }
    }

    func handleSampleBuffer(type: RPSampleBufferType, sampleBuffer: CMSampleBuffer) {
        switch type {
        case .video:
            handleScreenCaptureSampleBuffer(sampleBuffer)
        default:
            break
        }
    }
}
