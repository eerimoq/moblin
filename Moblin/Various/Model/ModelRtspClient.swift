import CoreMedia
import Foundation

extension Model {
    func rtspCameras() -> [(UUID, String)] {
        return database.rtspClient.streams.map { stream in
            (stream.id, stream.camera())
        }
    }

    func getRtspStream(id: UUID) -> SettingsRtspClientStream? {
        return database.rtspClient.streams.first { stream in
            stream.id == id
        }
    }

    func getRtspStream(idString: String) -> SettingsRtspClientStream? {
        return database.rtspClient.streams.first { stream in
            idString == stream.id.uuidString
        }
    }

    func reloadRtspClient() {
        stopRtspClient()
        for stream in database.rtspClient.streams where stream.enabled {
            guard let url = URL(string: stream.url) else {
                continue
            }
            let client = RtspClient(cameraId: stream.id, url: url, latency: stream.latencySeconds())
            client.delegate = self
            client.start()
            ingests.rtsp.append(client)
        }
    }

    func stopRtspClient() {
        for client in ingests.rtsp {
            client.stop()
        }
        ingests.rtsp = []
    }

    func rtspClientConnectedInner(cameraId: UUID) {
        guard let stream = getRtspStream(id: cameraId) else {
            return
        }
        let camera = stream.camera()
        makeToast(title: String(localized: "\(camera) connected"))
        media.addBufferedVideo(cameraId: cameraId, name: camera, latency: stream.latencySeconds())
    }

    func rtspClientDisconnectedInner(cameraId: UUID) {
        guard let stream = getRtspStream(id: cameraId) else {
            return
        }
        makeToast(title: String(localized: "\(stream.camera()) disconnected"))
        media.removeBufferedVideo(cameraId: cameraId)
    }
}

extension Model: RtspClientDelegate {
    func rtspClientErrorToast(title: String) {
        makeErrorToastMain(title: title)
    }

    func rtspClientConnected(cameraId: UUID) {
        DispatchQueue.main.async {
            self.rtspClientConnectedInner(cameraId: cameraId)
        }
    }

    func rtspClientDisconnected(cameraId: UUID) {
        DispatchQueue.main.async {
            self.rtspClientDisconnectedInner(cameraId: cameraId)
        }
    }

    func rtspClientOnVideoBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedVideoSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }
}
