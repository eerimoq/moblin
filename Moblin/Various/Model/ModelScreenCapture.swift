import AVFoundation
import ReplayKit

extension Model {
    func isScreenCaptureCamera(cameraId: String) -> Bool {
        return cameraId == screenCaptureCamera
    }

    func isNoneCamera(cameraId: String) -> Bool {
        return cameraId == noneCamera
    }

    private func handleScreenCaptureStarted(latency: Double) {
        makeToast(title: String(localized: "Screen capture started"))
        media.addBufferedVideo(
            cameraId: screenCaptureCameraId,
            name: "Screen capture",
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

#if targetEnvironment(macCatalyst)
extension Model: MacScreenCaptureDelegate {
    func macScreenCaptureDidStart() {
        DispatchQueue.main.async {
            // No latency needed since ScreenCaptureKit delivers frames in-process
            self.handleScreenCaptureStarted(latency: 0.0)
        }
    }

    func macScreenCaptureDidStop() {
        DispatchQueue.main.async {
            self.handleScreenCaptureStopped()
        }
    }

    func macScreenCaptureDidOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        handleScreenCaptureSampleBuffer(sampleBuffer)
    }
}
#else
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
#endif
