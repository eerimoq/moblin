import CoreMedia
import Foundation

extension Model {
    func whipClientCameras() -> [(UUID, String)] {
        return database.whipClient.streams.map { stream in
            (stream.id, stream.camera())
        }
    }

    func getWhipClientStream(id: UUID) -> SettingsWhipClientStream? {
        return database.whipClient.streams.first { stream in
            stream.id == id
        }
    }

    func getWhipClientStream(idString: String) -> SettingsWhipClientStream? {
        return database.whipClient.streams.first { stream in
            idString == stream.id.uuidString
        }
    }

    func reloadWhipClient() {
        stopWhipClient()
        for stream in database.whipClient.streams where stream.enabled {
            let client = WhipClient(
                cameraId: stream.id,
                latency: stream.latencySeconds(),
                delegate: self
            )
            client.start(url: stream.url)
            ingests.whipClient.append(client)
        }
    }

    func stopWhipClient() {
        for client in ingests.whipClient {
            client.stop()
        }
        ingests.whipClient = []
    }

    func whipClientConnectedInternal(cameraId: UUID) {
        guard let stream = getWhipClientStream(id: cameraId) else {
            return
        }
        let camera = stream.camera()
        makeToast(title: String(localized: "\(camera) connected"))
        let latency = stream.latencySeconds()
        media.addBufferedVideo(cameraId: cameraId, name: camera, latency: latency)
        media.addBufferedAudio(cameraId: cameraId, name: camera, latency: latency)
    }

    func whipClientDisconnectedInternal(cameraId: UUID, reason: String) {
        guard let stream = getWhipClientStream(id: cameraId) else {
            return
        }
        makeToast(title: String(localized: "\(stream.camera()) disconnected"), subTitle: reason)
        media.removeBufferedVideo(cameraId: cameraId)
        media.removeBufferedAudio(cameraId: cameraId)
    }
}

extension Model: WhipClientDelegate {
    func whipClientOnConnected(cameraId: UUID) {
        DispatchQueue.main.async {
            self.whipClientConnectedInternal(cameraId: cameraId)
        }
    }

    func whipClientOnDisconnected(cameraId: UUID, reason: String) {
        DispatchQueue.main.async {
            self.whipClientDisconnectedInternal(cameraId: cameraId, reason: reason)
        }
    }

    func whipClientOnVideoBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedVideoSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func whipClientOnAudioBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedAudioSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func whipClientSetTargetLatencies(
        cameraId: UUID,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    ) {
        media.setBufferedVideoTargetLatency(cameraId: cameraId, latency: videoTargetLatency)
        media.setBufferedAudioTargetLatency(cameraId: cameraId, latency: audioTargetLatency)
    }
}
