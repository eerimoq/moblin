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
                                      delegate: self)
            ingests.rist?.start()
        }
    }

    func ristServerEnabled() -> Bool {
        database.ristServer.enabled
    }

    func ristCameras() -> [Camera] {
        database.ristServer.streams.map { Camera(id: $0.id.uuidString, name: $0.camera()) }
    }

    func getRistStream(id: UUID) -> SettingsRistServerStream? {
        database.ristServer.streams.first { $0.id == id }
    }

    func getRistStream(idString: String) -> SettingsRistServerStream? {
        database.ristServer.streams.first { $0.id.uuidString == idString }
    }

    func getRistStream(virtualDestinationPort: UInt16) -> SettingsRistServerStream? {
        database.ristServer.streams.first { $0.virtualDestinationPort == virtualDestinationPort }
    }

    func isRistStreamConnected(port: UInt16) -> Bool {
        database.ristServer.streams.first { $0.virtualDestinationPort == port }?.connected == true
    }
}

extension Model: @preconcurrency RistServerDelegate {
    func ristServerOnConnected(port: UInt16) {
        DispatchQueue.main.async {
            self.ristServerOnConnectedInternal(virtualDestinationPort: port)
        }
    }

    func ristServerOnDisconnected(port: UInt16, reason: String) {
        DispatchQueue.main.async {
            self.ristServerOnDisconnectedInternal(virtualDestinationPort: port, reason: reason)
        }
    }

    func ristServerOnAudioBuffer(virtualDestinationPort: UInt16, _ sampleBuffer: CMSampleBuffer) {
        guard let cameraId = getRistStream(virtualDestinationPort: virtualDestinationPort)?.id else {
            return
        }
        media.appendBufferedAudioSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func ristServerOnVideoBuffer(virtualDestinationPort: UInt16, _ sampleBuffer: CMSampleBuffer) {
        guard let cameraId = getRistStream(virtualDestinationPort: virtualDestinationPort)?.id else {
            return
        }
        media.appendBufferedVideoSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func ristServerSetTargetLatencies(
        virtualDestinationPort: UInt16,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    ) {
        guard let cameraId = getRistStream(virtualDestinationPort: virtualDestinationPort)?.id else {
            return
        }
        media.setBufferedVideoTargetLatency(cameraId: cameraId, latency: videoTargetLatency)
        media.setBufferedAudioTargetLatency(cameraId: cameraId, latency: audioTargetLatency)
    }

    private func ristServerOnConnectedInternal(virtualDestinationPort: UInt16) {
        guard let stream = getRistStream(virtualDestinationPort: virtualDestinationPort) else {
            return
        }
        let camera = stream.camera()
        makeToast(title: String(localized: "\(camera) connected"))
        let latency = stream.latencySeconds()
        media.addBufferedVideo(cameraId: stream.id, name: camera, latency: latency)
        media.addBufferedAudio(cameraId: stream.id, name: camera, latency: latency)
    }

    private func ristServerOnDisconnectedInternal(virtualDestinationPort: UInt16, reason _: String) {
        guard let stream = getRistStream(virtualDestinationPort: virtualDestinationPort) else {
            return
        }
        makeToast(title: String(localized: "\(stream.camera()) disconnected"))
        media.removeBufferedVideo(cameraId: stream.id)
        media.removeBufferedAudio(cameraId: stream.id)
    }
}
