import AVFoundation
import ReplayKit

extension Model {
    func isScreenCaptureCamera(cameraId: String) -> Bool {
        return cameraId == screenCaptureCamera
    }

    func isNoneCamera(cameraId: String) -> Bool {
        return cameraId == noneCamera
    }

    func reloadMacScreenCapture() {
        #if targetEnvironment(macCatalyst)
        if #available(macCatalyst 18.2, *) {
            MacScreenCapture.shared.stop()
            guard database.debug.macScreenCapture else {
                return
            }
            MacScreenCapture.shared.start()
        }
        #endif
    }

    private func handleScreenCaptureStarted(latency: Double) {
        #if !targetEnvironment(macCatalyst)
        makeToast(title: String(localized: "Screen capture started"))
        #endif
        media.addBufferedVideo(
            cameraId: screenCaptureCameraId,
            name: "Screen capture",
            latency: latency
        )
    }

    private func handleScreenCaptureStopped() {
        #if !targetEnvironment(macCatalyst)
        makeToast(title: String(localized: "Screen capture stopped"))
        #endif
        media.removeBufferedVideo(cameraId: screenCaptureCameraId)
    }

    private func handleScreenCaptureSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedVideoSampleBuffer(cameraId: screenCaptureCameraId, sampleBuffer: sampleBuffer)
    }

    private func handleScreenCaptureSampleBufferInternal(_ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedVideoSampleBufferInternal(
            cameraId: screenCaptureCameraId,
            sampleBuffer: sampleBuffer
        )
    }
}

#if targetEnvironment(macCatalyst)

extension Model: MacScreenCaptureDelegate {
    func macScreenCaptureDidStart(latency: Double) {
        DispatchQueue.main.async {
            self.handleScreenCaptureStarted(latency: latency)
        }
    }

    func macScreenCaptureDidStop() {
        DispatchQueue.main.async {
            self.handleScreenCaptureStopped()
        }
    }

    func macScreenCaptureDidOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        handleScreenCaptureSampleBufferInternal(sampleBuffer)
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
