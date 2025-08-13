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
            ingests.srtla = SrtlaServer(settings: database.srtlaServer, timecodesEnabled: isTimecodesEnabled())
            ingests.srtla?.delegate = self
            ingests.srtla?.start()
        }
    }

    func srtlaServerEnabled() -> Bool {
        return database.srtlaServer.enabled
    }

    func srtlaCameras() -> [(UUID, String)] {
        return database.srtlaServer.streams.map { stream in
            (stream.id, stream.camera())
        }
    }

    func getSrtlaStream(id: UUID) -> SettingsSrtlaServerStream? {
        return database.srtlaServer.streams.first { stream in
            stream.id == id
        }
    }

    func getSrtlaStream(idString: String) -> SettingsSrtlaServerStream? {
        return database.srtlaServer.streams.first { stream in
            idString == stream.id.uuidString
        }
    }

    func getSrtlaStream(streamId: String) -> SettingsSrtlaServerStream? {
        return database.srtlaServer.streams.first { stream in
            stream.streamId == streamId
        }
    }

    func isSrtlaStreamConnected(streamId: String) -> Bool {
        return ingests.srtla?.isStreamConnected(streamId: streamId) ?? false
    }
}

extension Model: SrtlaServerDelegate {
    func srtlaServerOnClientStart(streamId: String, latency _: Double) {
        DispatchQueue.main.async {
            self.srtlaServerOnClientStartInternal(streamId: streamId)
        }
    }

    func srtlaServerOnClientStop(streamId: String) {
        DispatchQueue.main.async {
            self.srtlaServerOnClientStopInternal(streamId: streamId)
        }
    }

    private func srtlaServerOnClientStartInternal(streamId: String) {
        guard let stream = getSrtlaStream(streamId: streamId) else {
            return
        }
        let camera = stream.camera()
        makeToast(title: String(localized: "\(camera) connected"))
        media.addBufferedVideo(cameraId: stream.id, name: camera, latency: srtServerClientLatency)
        media.addBufferedAudio(cameraId: stream.id, name: camera, latency: srtServerClientLatency)
    }

    private func srtlaServerOnClientStopInternal(streamId: String) {
        guard let stream = getSrtlaStream(streamId: streamId) else {
            return
        }
        makeToast(title: String(localized: "\(stream.camera()) disconnected"))
        media.removeBufferedVideo(cameraId: stream.id)
        media.removeBufferedAudio(cameraId: stream.id)
    }

    func srtlaServerOnAudioBuffer(streamId: String, sampleBuffer: CMSampleBuffer) {
        guard let cameraId = getSrtlaStream(streamId: streamId)?.id else {
            return
        }
        media.appendBufferedAudioSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func srtlaServerOnVideoBuffer(streamId: String, sampleBuffer: CMSampleBuffer) {
        guard let cameraId = getSrtlaStream(streamId: streamId)?.id else {
            return
        }
        media.appendBufferedVideoSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func srtlaServerSetTargetLatencies(
        streamId: String,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    ) {
        guard let cameraId = getSrtlaStream(streamId: streamId)?.id else {
            return
        }
        media.setBufferedVideoTargetLatency(cameraId: cameraId, latency: videoTargetLatency)
        media.setBufferedAudioTargetLatency(cameraId: cameraId, latency: audioTargetLatency)
    }
}
