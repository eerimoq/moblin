import CoreMedia
import Foundation

extension Model {
    func stopRistServer() {
        ingests.rist?.stop()
        ingests.rist = nil
    }

    func reloadRistServer() {
        stopRistServer()
        if database.ristServer.enabled {
            ingests.rist = RistServer(port: database.ristServer.port,
                                      streams: database.ristServer.streams.map { $0.clone() },
                                      softwareDecoding: database.ingestsSoftwareVideoDecoding,
                                      colorRange: stream.colorRange,
                                      delegate: self)
            ingests.rist?.start()
        }
    }

    func ristServerEnabled() -> Bool {
        database.ristServer.enabled
    }

    func updateRistVideoSources() {
        videoSources.rist = database.ristServer.streams
            .map { Camera(id: $0.id.uuidString, name: $0.camera()) }
    }

    func updateRistVideoSourcesAndMics() {
        updateRistVideoSources()
        updateRistMics()
    }

    func getRistStream(id: UUID) -> SettingsRistServerStream? {
        database.ristServer.streams.first { $0.id == id }
    }

    func getRistStream(idString: String) -> SettingsRistServerStream? {
        database.ristServer.streams.first { $0.id.uuidString == idString }
    }

    func isRistStreamConnected(port: UInt16) -> Bool {
        database.ristServer.streams.first { $0.virtualDestinationPort == port }?.connected == true
    }
}

extension Model: RistServerDelegate {
    nonisolated func ristServerOnConnected(cameraId: UUID, name: String, latency: Double) {
        DispatchQueue.main.async {
            self.makeToast(title: String(localized: "\(name) connected"))
            self.media.addBufferedVideo(cameraId: cameraId, name: name, latency: latency)
            self.media.addBufferedAudio(cameraId: cameraId, name: name, latency: latency)
        }
    }

    nonisolated func ristServerOnDisconnected(cameraId: UUID, name: String) {
        DispatchQueue.main.async {
            self.makeToast(title: String(localized: "\(name) disconnected"))
            self.media.removeBufferedVideo(cameraId: cameraId)
            self.media.removeBufferedAudio(cameraId: cameraId)
        }
    }

    nonisolated func ristServerOnAudioBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedAudioSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    nonisolated func ristServerOnVideoBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedVideoSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }
}
