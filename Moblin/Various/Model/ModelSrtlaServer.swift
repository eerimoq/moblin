import CoreMedia
import Foundation

extension Model {
    func stopSrtlaServer() {
        ingests.srtla?.stop()
        ingests.srtla = nil
    }

    func reloadSrtlaServer() {
        stopSrtlaServer()
        if database.srtlaServer.enabled {
            ingests.srtla = SrtlaServer(
                settings: database.srtlaServer,
                delegate: self,
                timecodesEnabled: isTimecodesEnabled()
            )
            ingests.srtla?.start()
        }
    }

    func srtlaServerEnabled() -> Bool {
        database.srtlaServer.enabled
    }

    func srtlaCameras() -> [Camera] {
        database.srtlaServer.streams.map { Camera(id: $0.id.uuidString, name: $0.camera()) }
    }

    func getSrtlaStream(id: UUID) -> SettingsSrtlaServerStream? {
        database.srtlaServer.streams.first { $0.id == id }
    }

    func getSrtlaStream(idString: String) -> SettingsSrtlaServerStream? {
        database.srtlaServer.streams.first { $0.id.uuidString == idString }
    }

    func getSrtlaStream(streamId: String) -> SettingsSrtlaServerStream? {
        database.srtlaServer.streams.first { $0.streamId == streamId }
    }

    func isSrtlaStreamConnected(streamId: String) -> Bool {
        ingests.srtla?.isStreamConnected(streamId: streamId) ?? false
    }
}

extension Model: @preconcurrency SrtlaServerDelegate {
    func srtlaServerOnClientStart(cameraId: UUID, name: String) {
        DispatchQueue.main.async {
            self.srtlaServerOnClientStartInternal(cameraId: cameraId, name: name)
        }
    }

    func srtlaServerOnClientStop(cameraId: UUID, name: String) {
        DispatchQueue.main.async {
            self.srtlaServerOnClientStopInternal(cameraId: cameraId, name: name)
        }
    }

    private func srtlaServerOnClientStartInternal(cameraId: UUID, name: String) {
        makeToast(title: String(localized: "\(name) connected"))
        media.addBufferedVideo(cameraId: cameraId, name: name, latency: srtServerClientLatency)
        media.addBufferedAudio(cameraId: cameraId, name: name, latency: srtServerClientLatency)
    }

    private func srtlaServerOnClientStopInternal(cameraId: UUID, name: String) {
        makeToast(title: String(localized: "\(name) disconnected"))
        media.removeBufferedVideo(cameraId: cameraId)
        media.removeBufferedAudio(cameraId: cameraId)
    }

    func srtlaServerOnAudioBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        media.appendBufferedAudioSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func srtlaServerOnVideoBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        media.appendBufferedVideoSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func srtlaServerSetTargetLatencies(
        cameraId: UUID,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    ) {
        media.setBufferedVideoTargetLatency(cameraId: cameraId, latency: videoTargetLatency)
        media.setBufferedAudioTargetLatency(cameraId: cameraId, latency: audioTargetLatency)
    }
}
