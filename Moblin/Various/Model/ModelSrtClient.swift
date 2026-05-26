import CoreMedia
import Foundation

extension Model {
    func srtClientCameras() -> [Camera] {
        database.srtClient.streams.map { stream in
            Camera(id: stream.id.uuidString, name: stream.camera())
        }
    }

    func getSrtClientStream(id: UUID) -> SettingsSrtClientStream? {
        database.srtClient.streams.first { stream in
            stream.id == id
        }
    }

    func getSrtClientStream(idString: String) -> SettingsSrtClientStream? {
        database.srtClient.streams.first { stream in
            stream.id.uuidString == idString
        }
    }

    func reloadSrtClient() {
        stopSrtClient()
        for stream in database.srtClient.streams where stream.enabled {
            guard let url = URL(string: stream.url) else {
                continue
            }
            let client = SrtClient(
                cameraId: stream.id,
                url: url,
                latency: stream.latencySeconds(),
                delegate: self
            )
            client.start()
            ingests.srt.append(client)
        }
    }

    func stopSrtClient() {
        for client in ingests.srt {
            client.stop()
        }
        ingests.srt = []
    }

    private func srtClientConnectedInternal(cameraId: UUID) {
        guard let stream = getSrtClientStream(id: cameraId) else {
            return
        }
        let camera = stream.camera()
        makeToast(title: String(localized: "\(camera) connected"))
        media.addBufferedVideo(cameraId: cameraId, name: camera, latency: stream.latencySeconds())
        media.addBufferedAudio(cameraId: cameraId, name: camera, latency: stream.latencySeconds())
    }

    private func srtClientDisconnectedInternal(cameraId: UUID) {
        guard let stream = getSrtClientStream(id: cameraId) else {
            return
        }
        makeToast(title: String(localized: "\(stream.camera()) disconnected"))
        media.removeBufferedVideo(cameraId: cameraId)
        media.removeBufferedAudio(cameraId: cameraId)
    }
}

extension Model: @preconcurrency SrtClientDelegate {
    func srtClientConnected(cameraId: UUID) {
        DispatchQueue.main.async {
            self.srtClientConnectedInternal(cameraId: cameraId)
        }
    }

    func srtClientDisconnected(cameraId: UUID) {
        DispatchQueue.main.async {
            self.srtClientDisconnectedInternal(cameraId: cameraId)
        }
    }

    func srtClientOnVideoBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedVideoSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func srtClientOnAudioBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedAudioSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func srtClientSetTargetLatencies(
        cameraId: UUID,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    ) {
        media.setBufferedVideoTargetLatency(cameraId: cameraId, latency: videoTargetLatency)
        media.setBufferedAudioTargetLatency(cameraId: cameraId, latency: audioTargetLatency)
    }
}
