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

    func isWhepStreamConnected(streamId: UUID) -> Bool {
        return ingests.whep.first(where: { $0.streamId == streamId })?.isConnected() ?? false
    }

    func reloadWhepClient() {
        stopWhepClient()
        for stream in database.whepClient.streams where stream.enabled {
            guard let url = URL(string: stream.url) else {
                continue
            }
            let client = WhepClient(streamId: stream.id, url: url, latency: stream.latencySeconds())
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
        for stream in database.whepClient.streams {
            media.removeBufferedVideo(cameraId: stream.id)
            media.removeBufferedAudio(cameraId: stream.id)
        }
    }
}

extension Model: WhepClientDelegate {
    func whepClientOnPublishStart(streamId: UUID) {
        DispatchQueue.main.async {
            guard let stream = self.getWhepStream(id: streamId) else {
                return
            }
            let camera = stream.camera()
            self.makeToast(title: String(localized: "\(camera) connected"))
            let latency = stream.latencySeconds()
            self.media.addBufferedVideo(cameraId: stream.id, name: camera, latency: latency)
            self.media.addBufferedAudio(cameraId: stream.id, name: camera, latency: latency)
        }
    }

    func whepClientOnPublishStop(streamId: UUID, reason: String) {
        DispatchQueue.main.async {
            guard let stream = self.getWhepStream(id: streamId) else {
                return
            }
            self.makeToast(
                title: String(localized: "\(stream.camera()) disconnected"),
                subTitle: reason
            )
            self.media.removeBufferedVideo(cameraId: stream.id)
            self.media.removeBufferedAudio(cameraId: stream.id)
        }
    }

    func whepClientOnVideoBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedVideoSampleBuffer(cameraId: streamId, sampleBuffer: sampleBuffer)
    }

    func whepClientOnAudioBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedAudioSampleBuffer(cameraId: streamId, sampleBuffer: sampleBuffer)
    }

    func whepClientSetTargetLatencies(streamId: UUID,
                                      _ videoTargetLatency: Double,
                                      _ audioTargetLatency: Double)
    {
        media.setBufferedVideoTargetLatency(cameraId: streamId, latency: videoTargetLatency)
        media.setBufferedAudioTargetLatency(cameraId: streamId, latency: audioTargetLatency)
    }
}
