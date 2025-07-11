import ReplayKit

extension Model {
    func isScreenCaptureCamera(cameraId: String) -> Bool {
        return cameraId == screenCaptureCamera
    }

    func isNoneCamera(cameraId: String) -> Bool {
        return cameraId == noneCamera
    }

    private func handleSampleBufferSenderConnected() {
        makeToast(title: String(localized: "Screen capture started"))
        media.addBufferedVideo(
            cameraId: screenCaptureCameraId,
            name: "Screen capture",
            latency: screenRecordingLatency
        )
    }

    private func handleSampleBufferSenderDisconnected() {
        makeToast(title: String(localized: "Screen capture stopped"))
        media.removeBufferedVideo(cameraId: screenCaptureCameraId)
    }

    private func handleSampleBufferSenderBuffer(_ type: RPSampleBufferType, _ sampleBuffer: CMSampleBuffer) {
        switch type {
        case .video:
            media.appendBufferedVideoSampleBuffer(cameraId: screenCaptureCameraId, sampleBuffer: sampleBuffer)
        default:
            break
        }
    }
}

extension Model: SampleBufferReceiverDelegate {
    func senderConnected() {
        DispatchQueue.main.async {
            self.handleSampleBufferSenderConnected()
        }
    }

    func senderDisconnected() {
        DispatchQueue.main.async {
            self.handleSampleBufferSenderDisconnected()
        }
    }

    func handleSampleBuffer(type: RPSampleBufferType, sampleBuffer: CMSampleBuffer) {
        handleSampleBufferSenderBuffer(type, sampleBuffer)
    }
}
