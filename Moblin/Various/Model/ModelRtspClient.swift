import CoreMedia
import Foundation

extension Model {
    func rtspCameras() -> [(UUID, String)] {
        return database.rtspClient.streams.map { stream in
            (stream.id, stream.camera())
        }
    }

    func getRtspStream(id: UUID) -> SettingsRtspClientStream? {
        logger.info("xxx get stream \(id)")
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
        guard database.debug.rtspClient else {
            return
        }
        for stream in database.rtspClient.streams {
            guard let url = URL(string: stream.url) else {
                continue
            }
            let client = RtspClient(cameraId: stream.id, url: url, latency: 1)
            client.delegate = self
            client.start()
            servers.rtsp.append(client)
        }
    }

    private func stopRtspClient() {
        for client in servers.rtsp {
            client.stop()
        }
        servers.rtsp = []
    }
}

extension Model: RtspClientDelegate {
    func rtspClientConnected(cameraId: UUID) {
        media.addBufferedVideo(cameraId: cameraId, name: "RTSP", latency: 1)
    }

    func rtspClientDisconnected(cameraId: UUID) {
        media.removeBufferedVideo(cameraId: cameraId)
    }

    func rtspClientOnVideoBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedVideoSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }
}
