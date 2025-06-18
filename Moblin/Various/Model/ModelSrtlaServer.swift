import CoreMedia
import Foundation

extension Model {
    func stopSrtlaServer() {
        servers.srtla?.stop()
        servers.srtla = nil
    }

    func reloadSrtlaServer() {
        stopSrtlaServer()
        if database.srtlaServer.enabled {
            servers.srtla = SrtlaServer(settings: database.srtlaServer, timecodesEnabled: isTimecodesEnabled())
            servers.srtla?.delegate = self
            servers.srtla?.start()
        }
    }

    func srtlaServerEnabled() -> Bool {
        return servers.srtla != nil
    }

    func srtlaCameras() -> [String] {
        return database.srtlaServer.streams.map { stream in
            stream.camera()
        }
    }

    func getSrtlaStream(id: UUID) -> SettingsSrtlaServerStream? {
        return database.srtlaServer.streams.first { stream in
            stream.id == id
        }
    }

    func getSrtlaStream(camera: String) -> SettingsSrtlaServerStream? {
        return database.srtlaServer.streams.first { stream in
            camera == stream.camera()
        }
    }

    func getSrtlaStream(streamId: String) -> SettingsSrtlaServerStream? {
        return database.srtlaServer.streams.first { stream in
            stream.streamId == streamId
        }
    }

    func isSrtlaStreamConnected(streamId: String) -> Bool {
        return servers.srtla?.isStreamConnected(streamId: streamId) ?? false
    }
}

extension Model: SrtlaServerDelegate {
    func srtlaServerOnClientStart(streamId: String, latency _: Double) {
        DispatchQueue.main.async {
            let camera = self.getSrtlaStream(streamId: streamId)?.camera() ?? srtlaCamera(name: "Unknown")
            self.makeToast(title: String(localized: "\(camera) connected"))
            guard let stream = self.getSrtlaStream(streamId: streamId) else {
                return
            }
            let name = "SRTLA \(camera)"
            let latency = srtServerClientLatency
            self.media.addBufferedVideo(cameraId: stream.id, name: name, latency: latency)
            self.media.addBufferedAudio(cameraId: stream.id, name: name, latency: latency)
            if stream.autoSelectMic! {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self.selectMicById(id: "\(stream.id) 0")
                }
            }
        }
    }

    func srtlaServerOnClientStop(streamId: String) {
        DispatchQueue.main.async {
            let camera = self.getSrtlaStream(streamId: streamId)?.camera() ?? srtlaCamera(name: "Unknown")
            self.makeToast(title: String(localized: "\(camera) disconnected"))
            guard let stream = self.getSrtlaStream(streamId: streamId) else {
                return
            }
            self.media.removeBufferedVideo(cameraId: stream.id)
            self.media.removeBufferedAudio(cameraId: stream.id)
            if self.currentMic.id == "\(stream.id) 0" {
                self.setMicFromSettings()
            }
            self.updateAutoSceneSwitcherVideoSourceDisconnected()
        }
    }

    func srtlaServerOnAudioBuffer(streamId: String, sampleBuffer: CMSampleBuffer) {
        guard let cameraId = getSrtlaStream(streamId: streamId)?.id else {
            return
        }
        media.appendBufferedAudioSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func srtlaServerOnVideoBuffer(streamId: String, sampleBuffer: CMSampleBuffer) {
        guard let cameraId = getSrtlaStream(streamId: streamId)?.id else {
            return
        }
        media.appendBufferedVideoSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func srtlaServerSetTargetLatencies(
        streamId: String,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    ) {
        guard let cameraId = getSrtlaStream(streamId: streamId)?.id else {
            return
        }
        media.setBufferedVideoTargetLatency(cameraId: cameraId, latency: videoTargetLatency)
        media.setBufferedAudioTargetLatency(cameraId: cameraId, latency: audioTargetLatency)
    }
}
