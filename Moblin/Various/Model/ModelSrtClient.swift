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

    func isSrtClientStreamConnected(id _: UUID) -> Bool {
        true
    }

    func reloadSrtClient() {
        stopSrtClient()
        for stream in database.srtClient.streams where stream.enabled {
            guard let url = URL(string: stream.url) else {
                continue
            }
            let client = SrtClient(cameraId: stream.id,
                                   url: url,
                                   softwareDecoding: database.ingestsSoftwareVideoDecoding,
                                   delegate: self)
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
        media.addBufferedVideo(cameraId: cameraId, name: camera, latency: srtClientLatency)
        media.addBufferedAudio(cameraId: cameraId, name: camera, latency: srtClientLatency)
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

extension Model: SrtClientDelegate {
    nonisolated func srtClientConnected(cameraId: UUID) {
        DispatchQueue.main.async {
            self.srtClientConnectedInternal(cameraId: cameraId)
        }
    }

    nonisolated func srtClientDisconnected(cameraId: UUID) {
        DispatchQueue.main.async {
            self.srtClientDisconnectedInternal(cameraId: cameraId)
        }
    }

    nonisolated func srtClientOnVideoBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedVideoSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    nonisolated func srtClientOnAudioBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedAudioSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }
}
