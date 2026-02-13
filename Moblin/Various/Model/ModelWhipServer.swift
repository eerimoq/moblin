import CoreMedia
import Foundation

extension Model {
    func whipCameras() -> [(UUID, String)] {
        return database.whipServer.streams.map { stream in
            (stream.id, stream.camera())
        }
    }

    func getWhipStream(id: UUID) -> SettingsWhipServerStream? {
        return database.whipServer.streams.first { stream in
            stream.id == id
        }
    }

    func getWhipStream(clientId: UUID) -> SettingsWhipServerStream? {
        return database.whipServer.streams.first { stream in
            ingests.whip?.isClientConnected(clientId: stream.id) ?? false
        }
    }

    func stopAllWhipStreams() {
        for stream in database.whipServer.streams {
            stopWhipServerStream(stream: stream, showToast: false)
        }
    }

    func handleWhipServerPublishStart(clientId: UUID) {
        DispatchQueue.main.async {
            guard let stream = self.getWhipStream(clientId: clientId) else {
                if let firstStream = self.database.whipServer.streams.first {
                    let camera = firstStream.camera()
                    self.makeToast(title: String(localized: "\(camera) connected"))
                    let latency = Double(firstStream.latency) / 1000.0
                    self.media.addBufferedVideo(
                        cameraId: firstStream.id,
                        name: camera,
                        latency: latency
                    )
                    self.media.addBufferedAudio(
                        cameraId: firstStream.id,
                        name: camera,
                        latency: latency
                    )
                }
                return
            }
            let camera = stream.camera()
            self.makeToast(title: String(localized: "\(camera) connected"))
            let latency = Double(stream.latency) / 1000.0
            self.media.addBufferedVideo(cameraId: stream.id, name: camera, latency: latency)
            self.media.addBufferedAudio(cameraId: stream.id, name: camera, latency: latency)
        }
    }

    func handleWhipServerPublishStop(clientId: UUID, reason: String? = nil) {
        DispatchQueue.main.async {
            guard let stream = self.getWhipStream(clientId: clientId) else {
                if let firstStream = self.database.whipServer.streams.first {
                    self.stopWhipServerStream(
                        stream: firstStream,
                        showToast: true,
                        reason: reason
                    )
                }
                return
            }
            self.stopWhipServerStream(stream: stream, showToast: true, reason: reason)
        }
    }

    private func stopWhipServerStream(
        stream: SettingsWhipServerStream,
        showToast: Bool,
        reason: String? = nil
    ) {
        if showToast {
            makeToast(title: String(localized: "\(stream.camera()) disconnected"), subTitle: reason)
        }
        media.removeBufferedVideo(cameraId: stream.id)
        media.removeBufferedAudio(cameraId: stream.id)
    }

    func handleWhipServerFrame(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        media.appendBufferedVideoSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func handleWhipServerAudioBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        media.appendBufferedAudioSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func stopWhipServer() {
        ingests.whip?.stop()
        ingests.whip = nil
        stopAllWhipStreams()
    }

    func reloadWhipServer() {
        stopWhipServer()
        if database.whipServer.enabled {
            ingests.whip = WhipServer(settings: database.whipServer.clone())
            ingests.whip?.delegate = self
            ingests.whip?.start()
        }
    }

    func whipServerEnabled() -> Bool {
        return database.whipServer.enabled
    }
}

extension Model: WhipServerDelegate {
    func whipServerOnPublishStart(clientId: UUID) {
        handleWhipServerPublishStart(clientId: clientId)
    }

    func whipServerOnPublishStop(clientId: UUID, reason: String) {
        handleWhipServerPublishStop(clientId: clientId, reason: reason)
    }

    func whipServerOnVideoBuffer(clientId: UUID, _ sampleBuffer: CMSampleBuffer) {
        if let stream = database.whipServer.streams.first {
            handleWhipServerFrame(cameraId: stream.id, sampleBuffer: sampleBuffer)
        }
    }

    func whipServerOnAudioBuffer(clientId: UUID, _ sampleBuffer: CMSampleBuffer) {
        if let stream = database.whipServer.streams.first {
            handleWhipServerAudioBuffer(cameraId: stream.id, sampleBuffer: sampleBuffer)
        }
    }
}
