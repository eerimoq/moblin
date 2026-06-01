import CoreMedia
import Foundation

extension Model {
    func rtspCameras() -> [Camera] {
        database.rtspClient.streams.map { stream in
            Camera(id: stream.id.uuidString, name: stream.camera())
        }
    }

    func getRtspStream(id: UUID) -> SettingsRtspClientStream? {
        database.rtspClient.streams.first { stream in
            stream.id == id
        }
    }

    func getRtspStream(idString: String) -> SettingsRtspClientStream? {
        database.rtspClient.streams.first { stream in
            idString == stream.id.uuidString
        }
    }

    func reloadRtspClient() {
        stopRtspClient()
        for stream in database.rtspClient.streams where stream.enabled {
            guard let url = URL(string: stream.url) else {
                continue
            }
            let client = RtspClient(cameraId: stream.id,
                                    url: url,
                                    latency: stream.latencySeconds(),
                                    transport: stream.transport,
                                    delegate: self)
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

    func rtspClientConnectedInternal(cameraId: UUID) {
        guard let stream = getRtspStream(id: cameraId) else {
            return
        }
        let camera = stream.camera()
        makeToast(title: String(localized: "\(camera) connected"))
        media.addBufferedVideo(cameraId: cameraId, name: camera, latency: stream.latencySeconds())
    }

    func rtspClientDisconnectedInternal(cameraId: UUID) {
        guard let stream = getRtspStream(id: cameraId) else {
            return
        }
        makeToast(title: String(localized: "\(stream.camera()) disconnected"))
        media.removeBufferedVideo(cameraId: cameraId)
    }
}

extension Model: @preconcurrency RtspClientDelegate {
    func rtspClientErrorToast(title: String) {
        makeErrorToastMain(title: title)
    }

    func rtspClientConnected(cameraId: UUID) {
        DispatchQueue.main.async {
            self.rtspClientConnectedInternal(cameraId: cameraId)
        }
    }

    func rtspClientDisconnected(cameraId: UUID) {
        DispatchQueue.main.async {
            self.rtspClientDisconnectedInternal(cameraId: cameraId)
        }
    }

    func rtspClientOnVideoBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedVideoSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }
}
