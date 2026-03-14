import CoreMedia
import Foundation

let metaGlassesCameraId = UUID(uuidString: "00000000-AE7A-9145-BEEF-000000000000")!
let metaGlassesCamera = "Meta glasses"
private let metaGlassesStreamLatency = 0.1

extension Model: MetaGlassesDeviceDelegate {
    func isMetaGlassesCamera(cameraId: String) -> Bool {
        return cameraId == metaGlassesCamera
    }

    func setupMetaGlasses() {
        metaGlassesDevice.delegate = self
        if database.metaGlasses.enabled {
            metaGlassesDevice.configure()
            metaGlassesDevice.start()
        }
    }

    func reloadMetaGlasses() {
        if database.metaGlasses.enabled {
            metaGlassesDevice.configure()
            metaGlassesDevice.start()
        } else {
            metaGlassesDevice.stop()
            media.removeBufferedVideo(cameraId: metaGlassesCameraId)
        }
    }

    func startMetaGlassesStreaming() {
        media.addBufferedVideo(
            cameraId: metaGlassesCameraId,
            name: metaGlassesCamera,
            latency: metaGlassesStreamLatency
        )
        metaGlassesDevice.startStreaming(
            resolution: database.metaGlasses.resolution,
            frameRate: database.metaGlasses.frameRate
        )
    }

    func startMetaGlassesStreamingIfRegistered() {
        guard metaGlasses.registrationState == .registered,
              metaGlasses.streamingState == .stopped
        else {
            return
        }
        startMetaGlassesStreaming()
    }

    func stopMetaGlassesStreaming() {
        metaGlassesDevice.stopStreaming()
        media.removeBufferedVideo(cameraId: metaGlassesCameraId)
    }

    func stopMetaGlassesStreamingIfActive() {
        guard metaGlasses.streamingState != .stopped else {
            return
        }
        stopMetaGlassesStreaming()
    }

    func connectMetaGlasses() {
        metaGlassesDevice.connectGlasses()
    }

    func disconnectMetaGlasses() {
        metaGlassesDevice.disconnectGlasses()
        media.removeBufferedVideo(cameraId: metaGlassesCameraId)
    }

    func handleMetaGlassesUrl(_ url: URL) {
        Task {
            do {
                try await metaGlassesDevice.handleUrl(url)
            } catch {
                makeErrorToast(
                    title: String(localized: "Meta glasses"),
                    subTitle: error.localizedDescription
                )
            }
        }
    }

    // MARK: - MetaGlassesDeviceDelegate

    func metaGlassesDeviceConnected() {
        DispatchQueue.main.async {
            self.makeToast(title: String(localized: "Meta glasses connected"))
        }
    }

    func metaGlassesDeviceDisconnected() {
        DispatchQueue.main.async {
            self.makeToast(title: String(localized: "Meta glasses disconnected"))
        }
    }

    func metaGlassesDeviceVideoBuffer(_ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedVideoSampleBuffer(cameraId: metaGlassesCameraId, sampleBuffer: sampleBuffer)
    }

    func metaGlassesDeviceRegistrationStateChanged(_ state: MetaGlassesRegistrationState) {
        DispatchQueue.main.async {
            self.metaGlasses.registrationState = state
        }
    }

    func metaGlassesDeviceStreamingStateChanged(_ state: MetaGlassesStreamingState) {
        DispatchQueue.main.async {
            self.metaGlasses.streamingState = state
        }
    }

    func metaGlassesDeviceError(_ message: String) {
        DispatchQueue.main.async {
            self.makeErrorToast(title: String(localized: "Meta glasses"), subTitle: message)
        }
    }
}
