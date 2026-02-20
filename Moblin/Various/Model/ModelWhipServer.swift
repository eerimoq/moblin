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

    func isWhipStreamConnected(streamId: UUID) -> Bool {
        return ingests.whip?.isStreamConnected(streamId: streamId) ?? false
    }

    func stopAllWhipStreams() {
        for stream in database.whipServer.streams {
            stopWhipServerStream(stream: stream, showToast: false)
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

    func handleWhipServerPublishStart(streamId: UUID) {
        DispatchQueue.main.async {
            guard let stream = self.getWhipStream(id: streamId) else {
                return
            }
            let camera = stream.camera()
            self.makeToast(title: String(localized: "\(camera) connected"))
            let latency = stream.latencySeconds()
            self.media.addBufferedVideo(cameraId: stream.id, name: camera, latency: latency)
            self.media.addBufferedAudio(cameraId: stream.id, name: camera, latency: latency)
        }
    }

    func handleWhipServerPublishStop(streamId: UUID, reason: String? = nil) {
        DispatchQueue.main.async {
            guard let stream = self.getWhipStream(id: streamId) else {
                return
            }
            self.stopWhipServerStream(stream: stream, showToast: true, reason: reason)
        }
    }

    func handleWhipServerFrame(streamId: UUID, sampleBuffer: CMSampleBuffer) {
        media.appendBufferedVideoSampleBuffer(cameraId: streamId, sampleBuffer: sampleBuffer)
    }

    func handleWhipServerAudioBuffer(streamId: UUID, sampleBuffer: CMSampleBuffer) {
        media.appendBufferedAudioSampleBuffer(cameraId: streamId, sampleBuffer: sampleBuffer)
    }

    func handleWhipServerSetTargetLatencies(streamId: UUID,
                                            _ videoTargetLatency: Double,
                                            _ audioTargetLatency: Double)
    {
        media.setBufferedVideoTargetLatency(cameraId: streamId, latency: videoTargetLatency)
        media.setBufferedAudioTargetLatency(cameraId: streamId, latency: audioTargetLatency)
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
}

extension Model: WhipServerDelegate {
    func whipServerOnPublishStart(streamId: UUID) {
        handleWhipServerPublishStart(streamId: streamId)
    }

    func whipServerOnPublishStop(streamId: UUID, reason: String) {
        handleWhipServerPublishStop(streamId: streamId, reason: reason)
    }

    func whipServerOnVideoBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer) {
        handleWhipServerFrame(streamId: streamId, sampleBuffer: sampleBuffer)
    }

    func whipServerOnAudioBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer) {
        handleWhipServerAudioBuffer(streamId: streamId, sampleBuffer: sampleBuffer)
    }

    func whipServerSetTargetLatencies(
        streamId: UUID,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    ) {
        handleWhipServerSetTargetLatencies(streamId: streamId, videoTargetLatency, audioTargetLatency)
    }
}
