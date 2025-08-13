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
            let virtualDestinationPorts = database.ristServer.streams.map { $0.virtualDestinationPort }
            ingests.rist = RistServer(port: database.ristServer.port,
                                      virtualDestinationPorts: virtualDestinationPorts,
                                      timecodesEnabled: isTimecodesEnabled())
            ingests.rist?.delegate = self
            ingests.rist?.start()
        }
    }

    func ristServerEnabled() -> Bool {
        return database.ristServer.enabled
    }

    func ristCameras() -> [(UUID, String)] {
        return database.ristServer.streams.map { stream in
            (stream.id, stream.camera())
        }
    }

    func getRistStream(id: UUID) -> SettingsRistServerStream? {
        return database.ristServer.streams.first { stream in
            stream.id == id
        }
    }

    func getRistStream(idString: String) -> SettingsRistServerStream? {
        return database.ristServer.streams.first { stream in
            idString == stream.id.uuidString
        }
    }

    func getRistStream(virtualDestinationPort: UInt16) -> SettingsRistServerStream? {
        return database.ristServer.streams.first { stream in
            stream.virtualDestinationPort == virtualDestinationPort
        }
    }

    func isRistStreamConnected(port: UInt16) -> Bool {
        return database.ristServer.streams.first { $0.virtualDestinationPort == port }?.connected == true
    }
}

extension Model: RistServerDelegate {
    func ristServerOnConnected(port: UInt16) {
        DispatchQueue.main.async {
            self.ristServerOnConnectedInner(virtualDestinationPort: port)
        }
    }

    func ristServerOnDisconnected(port: UInt16, reason: String) {
        DispatchQueue.main.async {
            self.ristServerOnDisconnectedInner(virtualDestinationPort: port, reason: reason)
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

    private func ristServerOnConnectedInner(virtualDestinationPort: UInt16) {
        guard let stream = getRistStream(virtualDestinationPort: virtualDestinationPort) else {
            return
        }
        let camera = stream.camera()
        makeToast(title: String(localized: "\(camera) connected"))
        media.addBufferedVideo(cameraId: stream.id, name: camera, latency: ristServerClientLatency)
        media.addBufferedAudio(cameraId: stream.id, name: camera, latency: ristServerClientLatency)
    }

    private func ristServerOnDisconnectedInner(virtualDestinationPort: UInt16, reason _: String) {
        guard let stream = getRistStream(virtualDestinationPort: virtualDestinationPort) else {
            return
        }
        makeToast(title: String(localized: "\(stream.camera()) disconnected"))
        media.removeBufferedVideo(cameraId: stream.id)
        media.removeBufferedAudio(cameraId: stream.id)
    }
}
