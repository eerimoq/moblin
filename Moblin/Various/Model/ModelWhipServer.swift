import CoreMedia
import Foundation

extension Model {
    func whipServerEnabled() -> Bool {
        database.whipServer.enabled
    }

    func whipCameras() -> [Camera] {
        database.whipServer.streams.map { stream in
            Camera(id: stream.id.uuidString, name: stream.camera())
        }
    }

    func getWhipStream(id: UUID) -> SettingsWhipServerStream? {
        database.whipServer.streams.first { stream in
            stream.id == id
        }
    }

    func getWhipStream(idString: String) -> SettingsWhipServerStream? {
        database.whipServer.streams.first { stream in
            idString == stream.id.uuidString
        }
    }

    func getWhipStream(streamKey: String) -> SettingsWhipServerStream? {
        database.whipServer.streams.first { stream in
            stream.streamKey == streamKey
        }
    }

    func isWhipStreamConnected(streamId: UUID) -> Bool {
        ingests.whip?.isStreamConnected(streamId: streamId) ?? false
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

    private func handleWhipServerPublishStart(streamId: UUID) {
        guard let stream = getWhipStream(id: streamId) else {
            return
        }
        let camera = stream.camera()
        makeToast(title: String(localized: "\(camera) connected"))
        let latency = stream.latencySeconds()
        media.addBufferedVideo(cameraId: stream.id, name: camera, latency: latency)
        media.addBufferedAudio(cameraId: stream.id, name: camera, latency: latency)
    }

    private func handleWhipServerPublishStop(streamId: UUID, reason: String) {
        guard let stream = getWhipStream(id: streamId) else {
            return
        }
        stopWhipServerStream(stream: stream, showToast: true, reason: reason)
    }

    func stopWhipServer() {
        ingests.whip?.stop()
        ingests.whip = nil
        stopAllWhipStreams()
    }

    func reloadWhipServer() {
        stopWhipServer()
        if database.whipServer.enabled {
            ingests.whip = WhipServer(settings: database.whipServer.clone(),
                                      softwareDecoding: database.ingestsSoftwareVideoDecoding,
                                      delegate: self)
            ingests.whip?.start()
        }
    }
}

extension Model: WhipServerDelegate {
    nonisolated func whipServerOnPublishStart(streamId: UUID) {
        DispatchQueue.main.async {
            self.handleWhipServerPublishStart(streamId: streamId)
        }
    }

    nonisolated func whipServerOnPublishStop(streamId: UUID, reason: String) {
        DispatchQueue.main.async {
            self.handleWhipServerPublishStop(streamId: streamId, reason: reason)
        }
    }

    nonisolated func whipServerOnVideoBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedVideoSampleBuffer(cameraId: streamId, sampleBuffer: sampleBuffer)
    }

    nonisolated func whipServerOnAudioBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedAudioSampleBuffer(cameraId: streamId, sampleBuffer: sampleBuffer)
    }

    nonisolated func whipServerSetTargetLatencies(
        streamId: UUID,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    ) {
        media.setBufferedVideoTargetLatency(cameraId: streamId, latency: videoTargetLatency)
        media.setBufferedAudioTargetLatency(cameraId: streamId, latency: audioTargetLatency)
    }
}
