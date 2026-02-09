import CoreMedia
import Foundation

extension Model {
    func whepCameras() -> [(UUID, String)] {
        return database.whepClient.streams.map { stream in
            (stream.id, stream.camera())
        }
    }

    func getWhepStream(id: UUID) -> SettingsWhepClientStream? {
        return database.whepClient.streams.first { stream in
            stream.id == id
        }
    }

    func getWhepStream(idString: String) -> SettingsWhepClientStream? {
        return database.whepClient.streams.first { stream in
            idString == stream.id.uuidString
        }
    }

    func reloadWhepClient() {
        stopWhepClient()
        for stream in database.whepClient.streams where stream.enabled {
            guard let url = URL(string: stream.url) else {
                continue
            }
            let client = WhepClient(cameraId: stream.id, url: url, latency: stream.latencySeconds())
            client.delegate = self
            client.start()
            ingests.whep.append(client)
        }
    }

    func stopWhepClient() {
        for client in ingests.whep {
            client.stop()
        }
        ingests.whep = []
    }

    func whepClientConnectedInternal(cameraId: UUID) {
        guard let stream = getWhepStream(id: cameraId) else {
            return
        }
        let camera = stream.camera()
        makeToast(title: String(localized: "\(camera) connected"))
        media.addBufferedVideo(cameraId: cameraId, name: camera, latency: stream.latencySeconds())
        media.addBufferedAudio(cameraId: cameraId, name: camera, latency: stream.latencySeconds())
    }

    func whepClientDisconnectedInternal(cameraId: UUID, reason: String) {
        guard let stream = getWhepStream(id: cameraId) else {
            return
        }
        makeToast(title: String(localized: "\(stream.camera()) disconnected"), subTitle: reason)
        media.removeBufferedVideo(cameraId: cameraId)
        media.removeBufferedAudio(cameraId: cameraId)
        switchMicIfNeededAfterNetworkCameraChange()
    }
}

extension Model: WhepClientDelegate {
    func whepClientErrorToast(title: String) {
        makeErrorToastMain(title: title)
    }

    func whepClientConnected(cameraId: UUID) {
        DispatchQueue.main.async {
            self.whepClientConnectedInternal(cameraId: cameraId)
        }
    }

    func whepClientDisconnected(cameraId: UUID, reason: String) {
        DispatchQueue.main.async {
            self.whepClientDisconnectedInternal(cameraId: cameraId, reason: reason)
        }
    }

    func whepClientOnVideoBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedVideoSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func whepClientOnAudioBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedAudioSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }
}

