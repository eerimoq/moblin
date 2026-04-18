import CoreMedia
import Foundation

extension Model {
    func rtmpCameras() -> [Camera] {
        return database.rtmpServer.streams.map { Camera(id: $0.id.uuidString, name: $0.camera()) }
    }

    func getRtmpStream(id: UUID) -> SettingsRtmpServerStream? {
        return database.rtmpServer.streams.first { $0.id == id }
    }

    func getRtmpStream(idString: String) -> SettingsRtmpServerStream? {
        return database.rtmpServer.streams.first { $0.id.uuidString == idString }
    }

    func getRtmpStream(streamKey: String) -> SettingsRtmpServerStream? {
        return database.rtmpServer.streams.first { $0.streamKey == streamKey }
    }

    func stopAllRtmpStreams() {
        for stream in database.rtmpServer.streams {
            stopRtmpServerStream(stream: stream, showToast: false)
        }
    }

    func isRtmpStreamConnected(streamKey: String) -> Bool {
        return ingests.rtmp?.isStreamConnected(streamKey: streamKey) ?? false
    }

    func handleRtmpServerPublishStart(streamKey: String) {
        DispatchQueue.main.async {
            guard let stream = self.getRtmpStream(streamKey: streamKey) else {
                return
            }
            let camera = stream.camera()
            self.makeToast(title: String(localized: "\(camera) connected"))
            let latency = stream.latencySeconds()
            self.media.addBufferedVideo(cameraId: stream.id, name: camera, latency: latency)
            self.media.addBufferedAudio(cameraId: stream.id, name: camera, latency: latency)
            self.markDjiIsStreamingIfNeeded(rtmpServerStreamId: stream.id)
        }
    }

    func handleRtmpServerPublishStop(streamKey: String, reason: String? = nil) {
        DispatchQueue.main.async {
            guard let stream = self.getRtmpStream(streamKey: streamKey) else {
                return
            }
            self.stopRtmpServerStream(stream: stream, showToast: true, reason: reason)
            self.switchMicIfNeededAfterNetworkCameraChange()
        }
    }

    private func stopRtmpServerStream(
        stream: SettingsRtmpServerStream,
        showToast: Bool,
        reason: String? = nil
    ) {
        if showToast {
            makeToast(title: String(localized: "\(stream.camera()) disconnected"), subTitle: reason)
        }
        media.removeBufferedVideo(cameraId: stream.id)
        media.removeBufferedAudio(cameraId: stream.id)
        for device in database.djiDevices.devices {
            guard device.rtmpUrlType == .server, device.serverRtmpStreamId == stream.id else {
                continue
            }
            restartDjiLiveStreamIfNeededAfterDelay(device: device)
        }
    }

    func handleRtmpServerFrame(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        media.appendBufferedVideoSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func handleRtmpServerAudioBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        media.appendBufferedAudioSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func stopRtmpServer() {
        ingests.rtmp?.stop()
        ingests.rtmp = nil
        stopAllRtmpStreams()
    }

    func reloadRtmpServer() {
        stopRtmpServer()
        if database.rtmpServer.enabled {
            ingests.rtmp = RtmpServer(settings: database.rtmpServer.clone(), delegate: self)
            ingests.rtmp?.start()
        }
    }

    func rtmpServerEnabled() -> Bool {
        return database.rtmpServer.enabled
    }
}

extension Model: RtmpServerDelegate {
    func rtmpServerOnPublishStart(streamKey: String) {
        handleRtmpServerPublishStart(streamKey: streamKey)
    }

    func rtmpServerOnPublishStop(streamKey: String, reason: String) {
        handleRtmpServerPublishStop(streamKey: streamKey, reason: reason)
    }

    func rtmpServerOnVideoBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        handleRtmpServerFrame(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func rtmpServerOnAudioBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        handleRtmpServerAudioBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func rtmpServerSetTargetLatencies(
        cameraId: UUID,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    ) {
        media.setBufferedVideoTargetLatency(cameraId: cameraId, latency: videoTargetLatency)
        media.setBufferedAudioTargetLatency(cameraId: cameraId, latency: audioTargetLatency)
    }
}
