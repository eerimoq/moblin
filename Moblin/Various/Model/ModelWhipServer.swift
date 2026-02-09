import AVFoundation
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

    func getWhipStream(idString: String) -> SettingsWhipServerStream? {
        return database.whipServer.streams.first { stream in
            idString == stream.id.uuidString
        }
    }

    func getWhipStream(streamKey: String) -> SettingsWhipServerStream? {
        return database.whipServer.streams.first { stream in
            stream.streamKey == streamKey
        }
    }

    func stopAllWhipStreams() {
        for stream in database.whipServer.streams {
            stopWhipServerStream(stream: stream, showToast: false)
        }
    }

    func isWhipStreamConnected(streamKey: String) -> Bool {
        return ingests.whip?.isStreamConnected(streamKey: streamKey) ?? false
    }

    func handleWhipServerPublishStart(streamKey: String) {
        DispatchQueue.main.async {
            guard let stream = self.getWhipStream(streamKey: streamKey) else {
                return
            }
            let camera = stream.camera()
            self.makeToast(title: String(localized: "\(camera) connected"))
            // Cap latency for local WebRTC ingest. Values above 500ms cause audio buffer
            // overflow and excessive video delay. Old saved settings may still have 2000ms.
            let latency = min(Double(stream.latency) / 1000.0, 0.5)
            self.media.addBufferedVideo(cameraId: stream.id, name: camera, latency: latency)
            self.media.addBufferedAudio(cameraId: stream.id, name: camera, latency: latency)
        }
    }

    func handleWhipServerPublishStop(streamKey: String, reason: String? = nil) {
        DispatchQueue.main.async {
            guard let stream = self.getWhipStream(streamKey: streamKey) else {
                return
            }
            self.stopWhipServerStream(stream: stream, showToast: true, reason: reason)
            self.switchMicIfNeededAfterNetworkCameraChange()
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
    func whipServerOnPublishStart(streamKey: String) {
        handleWhipServerPublishStart(streamKey: streamKey)
    }

    func whipServerOnPublishStop(streamKey: String, reason: String) {
        handleWhipServerPublishStop(streamKey: streamKey, reason: reason)
    }

    func whipServerOnVideoBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        handleWhipServerFrame(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func whipServerOnAudioBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        handleWhipServerAudioBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }
}

