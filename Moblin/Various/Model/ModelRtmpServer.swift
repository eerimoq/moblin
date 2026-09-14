import CoreMedia
import Foundation

extension Model {
    func rtmpCameras() -> [Camera] {
        database.rtmpServer.streams.map { Camera(id: $0.id.uuidString, name: $0.camera()) }
    }

    func getRtmpStream(id: UUID) -> SettingsRtmpServerStream? {
        database.rtmpServer.streams.first { $0.id == id }
    }

    func getRtmpStream(idString: String) -> SettingsRtmpServerStream? {
        database.rtmpServer.streams.first { $0.id.uuidString == idString }
    }

    func getRtmpStream(streamKey: String) -> SettingsRtmpServerStream? {
        database.rtmpServer.streams.first { $0.streamKey == streamKey }
    }

    func stopAllRtmpStreams() {
        for stream in database.rtmpServer.streams {
            stopRtmpServerStream(stream: stream, showToast: false)
        }
    }

    func isRtmpStreamConnected(streamKey: String) -> Bool {
        ingests.rtmp?.isStreamConnected(streamKey: streamKey) ?? false
    }

    private func handleRtmpServerPublishStart(streamKey: String) {
        guard let stream = getRtmpStream(streamKey: streamKey) else {
            return
        }
        let camera = stream.camera()
        makeToast(title: String(localized: "\(camera) connected"))
        let latency = stream.latencySeconds()
        media.addBufferedVideo(cameraId: stream.id,
                               name: camera,
                               latency: latency,
                               trackDrift: stream.trackDrift)
        media.addBufferedAudio(cameraId: stream.id,
                               name: camera,
                               latency: latency,
                               trackDrift: stream.trackDrift)
        markDjiIsStreamingIfNeeded(rtmpServerStreamId: stream.id)
        markGoProIsStreamingIfNeeded(rtmpServerStreamId: stream.id)
    }

    private func handleRtmpServerPublishStop(streamKey: String, reason: String) {
        guard let stream = getRtmpStream(streamKey: streamKey) else {
            return
        }
        stopRtmpServerStream(stream: stream, showToast: true, reason: reason)
        switchMicIfNeededAfterNetworkCameraChange()
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
        for device in database.goPro.devices {
            guard device.rtmpUrlType == .server, device.serverRtmpStreamId == stream.id else {
                continue
            }
            restartGoProLiveStreamIfNeededAfterDelay(device: device)
        }
    }

    func stopRtmpServer() {
        ingests.rtmp?.stop()
        ingests.rtmp = nil
        stopAllRtmpStreams()
    }

    func reloadRtmpServer() {
        stopRtmpServer()
        if database.rtmpServer.enabled {
            ingests.rtmp = RtmpServer(settings: database.rtmpServer.clone(),
                                      softwareDecoding: database.ingestsSoftwareVideoDecoding,
                                      delegate: self)
            ingests.rtmp?.start()
        }
    }

    func rtmpServerEnabled() -> Bool {
        database.rtmpServer.enabled
    }
}

extension Model: RtmpServerDelegate {
    nonisolated func rtmpServerOnPublishStart(streamKey: String) {
        DispatchQueue.main.async {
            self.handleRtmpServerPublishStart(streamKey: streamKey)
        }
    }

    nonisolated func rtmpServerOnPublishStop(streamKey: String, reason: String) {
        DispatchQueue.main.async {
            self.handleRtmpServerPublishStop(streamKey: streamKey, reason: reason)
        }
    }

    nonisolated func rtmpServerOnVideoBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedVideoSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    nonisolated func rtmpServerOnAudioBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        media.appendBufferedAudioSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    nonisolated func rtmpServerSetTargetLatencies(
        cameraId: UUID,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    ) {
        media.setBufferedVideoTargetLatency(cameraId: cameraId, latency: videoTargetLatency)
        media.setBufferedAudioTargetLatency(cameraId: cameraId, latency: audioTargetLatency)
    }
}
