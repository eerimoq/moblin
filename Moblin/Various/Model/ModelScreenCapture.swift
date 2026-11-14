import AVFoundation
import ReplayKit

extension Model {
    func isScreenCaptureCamera(cameraId: CameraId) -> Bool {
        cameraId == screenCaptureCameraId.uuidString
    }

    func isNoneCamera(cameraId: CameraId) -> Bool {
        cameraId == noneCameraId.uuidString
    }

    #if targetEnvironment(macCatalyst)
    func sceneNeedsMacScreenCapture(scene: SettingsScene, resolver: SceneResolver) -> Bool {
        if scene.videoSource.cameraPosition == .screenCapture {
            return true
        }
        if let quickSwitchGroup = scene.quickSwitchGroup {
            for otherScene in enabledScenes where otherScene.quickSwitchGroup == quickSwitchGroup {
                if otherScene.videoSource.cameraPosition == .screenCapture {
                    return true
                }
                if sceneWidgetsNeedMacScreenCapture(scene: otherScene, resolver: resolver) {
                    return true
                }
            }
        }
        return sceneWidgetsNeedMacScreenCapture(scene: scene, resolver: resolver)
    }

    private func sceneWidgetsNeedMacScreenCapture(scene: SettingsScene, resolver: SceneResolver) -> Bool {
        resolver.resolve(scene).drawnWidgets().contains { drawnWidget in
            let widget = drawnWidget.widget
            return switch widget.type {
            case .videoSource:
                widget.videoSource.videoSource.cameraPosition == .screenCapture
            case .vTuber:
                widget.vTuber.videoSource.cameraPosition == .screenCapture
            case .pngTuber:
                widget.pngTuber.videoSource.cameraPosition == .screenCapture
            default:
                false
            }
        }
    }
    #else
    func sceneNeedsMacScreenCapture(scene _: SettingsScene, resolver _: SceneResolver) -> Bool {
        false
    }
    #endif

    private func handleScreenCaptureStarted(latency: Double) {
        makeToast(title: String(localized: "Screen capture started"))
        media.addBufferedVideo(
            cameraId: screenCaptureCameraId,
            name: screenCaptureCameraName,
            latency: latency
        )
        media.addBufferedAudio(
            cameraId: screenCaptureCameraId,
            name: screenCaptureCameraName,
            latency: latency
        )
    }

    private func handleScreenCaptureStopped() {
        makeToast(title: String(localized: "Screen capture stopped"))
        media.removeBufferedVideo(cameraId: screenCaptureCameraId)
        media.removeBufferedAudio(cameraId: screenCaptureCameraId)
    }
}

extension Model: SampleBufferReceiverDelegate {
    nonisolated func senderConnected() {
        DispatchQueue.main.async {
            self.handleScreenCaptureStarted(latency: screenRecordingLatency)
        }
    }

    nonisolated func senderDisconnected() {
        DispatchQueue.main.async {
            self.handleScreenCaptureStopped()
        }
    }

    nonisolated func handleSampleBuffer(type: RPSampleBufferType, sampleBuffer: CMSampleBuffer) {
        switch type {
        case .video:
            media.appendBufferedVideoSampleBuffer(cameraId: screenCaptureCameraId, sampleBuffer: sampleBuffer)
        case .audioApp:
            media.appendBufferedAudioSampleBuffer(cameraId: screenCaptureCameraId, sampleBuffer: sampleBuffer)
        default:
            break
        }
    }
}
