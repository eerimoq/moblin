import AVFoundation
import ReplayKit

extension Model {
    func isScreenRecordingCamera(cameraId: CameraId) -> Bool {
        return cameraId == screenRecordingCameraId.uuidString
    }

    func isNoneCamera(cameraId: CameraId) -> Bool {
        return cameraId == noneCameraId.uuidString
    }

    #if targetEnvironment(macCatalyst)
    func sceneNeedsMacScreenRecording(scene: SettingsScene) -> Bool {
        if scene.videoSource.cameraPosition == .screenCapture {
            return true
        }
        var addedSceneIds: Set<UUID> = []
        if let quickSwitchGroup = scene.quickSwitchGroup {
            for otherScene in enabledScenes where otherScene.quickSwitchGroup == quickSwitchGroup {
                if otherScene.videoSource.cameraPosition == .screenCapture {
                    return true
                }
                if sceneWidgetsNeedMacScreenRecording(scene: scene, addedSceneIds: &addedSceneIds) {
                    return true
                }
            }
        }
        return sceneWidgetsNeedMacScreenRecording(scene: scene, addedSceneIds: &addedSceneIds)
    }

    private func sceneWidgetsNeedMacScreenRecording(scene: SettingsScene,
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
                        if sceneWidgetsNeedMacScreenRecording(scene: nestedScene,
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
    func sceneNeedsMacScreenRecording(scene _: SettingsScene) -> Bool {
        return false
    }
    #endif

    private func handleScreenRecordingStarted(latency: Double) {
        makeToast(title: String(localized: "Screen recording started"))
        media.addBufferedVideo(
            cameraId: screenRecordingCameraId,
            name: screenRecordingCameraName,
            latency: latency
        )
    }

    private func handleScreenRecordingStopped() {
        makeToast(title: String(localized: "Screen recording stopped"))
        media.removeBufferedVideo(cameraId: screenRecordingCameraId)
    }

    private func handleScreenRecordingSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedVideoSampleBuffer(cameraId: screenRecordingCameraId, sampleBuffer: sampleBuffer)
    }
}

extension Model: SampleBufferReceiverDelegate {
    func senderConnected() {
        DispatchQueue.main.async {
            self.handleScreenRecordingStarted(latency: screenRecordingLatency)
        }
    }

    func senderDisconnected() {
        DispatchQueue.main.async {
            self.handleScreenRecordingStopped()
        }
    }

    func handleSampleBuffer(type: RPSampleBufferType, sampleBuffer: CMSampleBuffer) {
        switch type {
        case .video:
            handleScreenRecordingSampleBuffer(sampleBuffer)
        default:
            break
        }
    }
}
