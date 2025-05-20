import CoreMedia
import Foundation

extension Model {
    func rtmpCameras() -> [String] {
        return database.rtmpServer.streams.map { stream in
            stream.camera()
        }
    }

    func getRtmpStream(id: UUID) -> SettingsRtmpServerStream? {
        return database.rtmpServer.streams.first { stream in
            stream.id == id
        }
    }

    func getRtmpStream(camera: String) -> SettingsRtmpServerStream? {
        return database.rtmpServer.streams.first { stream in
            camera == stream.camera()
        }
    }

    func getRtmpStream(streamKey: String) -> SettingsRtmpServerStream? {
        return database.rtmpServer.streams.first { stream in
            stream.streamKey == streamKey
        }
    }

    func stopAllRtmpStreams() {
        for stream in database.rtmpServer.streams {
            stopRtmpServerStream(stream: stream, showToast: false)
        }
    }

    func isRtmpStreamConnected(streamKey: String) -> Bool {
        return rtmpServer?.isStreamConnected(streamKey: streamKey) ?? false
    }

    func reloadRtmpStreams() {
        for rtmpCamera in rtmpCameras() {
            guard let stream = getRtmpStream(camera: rtmpCamera) else {
                continue
            }
            if isRtmpStreamConnected(streamKey: stream.streamKey) {
                let micId = "\(stream.id.uuidString) 0"
                let isLastMic = (currentMic.id == micId)
                handleRtmpServerPublishStop(streamKey: stream.streamKey, reason: nil)
                handleRtmpServerPublishStart(streamKey: stream.streamKey)
                if currentMic.id != micId, isLastMic {
                    selectMicById(id: micId)
                }
            }
        }
    }

    func handleRtmpServerPublishStart(streamKey: String) {
        DispatchQueue.main.async {
            let camera = self.getRtmpStream(streamKey: streamKey)?.camera() ?? rtmpCamera(name: "Unknown")
            self.makeToast(title: String(localized: "\(camera) connected"))
            guard let stream = self.getRtmpStream(streamKey: streamKey) else {
                return
            }
            let name = "RTMP \(camera)"
            let latency = Double(stream.latency!) / 1000.0
            self.media.addBufferedVideo(cameraId: stream.id, name: name, latency: latency)
            self.media.addBufferedAudio(cameraId: stream.id, name: name, latency: latency)
            if stream.autoSelectMic! {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.selectMicById(id: "\(stream.id) 0")
                }
            }
            self.markDjiIsStreamingIfNeeded(rtmpServerStreamId: stream.id)
        }
    }

    func handleRtmpServerPublishStop(streamKey: String, reason: String? = nil) {
        DispatchQueue.main.async {
            guard let stream = self.getRtmpStream(streamKey: streamKey) else {
                return
            }
            self.stopRtmpServerStream(stream: stream, showToast: true, reason: reason)
            self.updateAutoSceneSwitcherVideoSourceDisconnected()
        }
    }

    private func stopRtmpServerStream(stream: SettingsRtmpServerStream, showToast: Bool, reason: String? = nil) {
        if showToast {
            makeToast(title: String(localized: "\(stream.camera()) disconnected"), subTitle: reason)
        }
        media.removeBufferedVideo(cameraId: stream.id)
        media.removeBufferedAudio(cameraId: stream.id)
        if currentMic.id == "\(stream.id) 0" {
            setMicFromSettings()
        }
        for device in database.djiDevices.devices {
            guard device.rtmpUrlType == .server, device.serverRtmpStreamId! == stream.id else {
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

    func rtmpServerInfo() {
        guard let rtmpServer, logger.debugEnabled else {
            return
        }
        for stream in database.rtmpServer.streams {
            guard let info = rtmpServer.streamInfo(streamKey: stream.streamKey) else {
                continue
            }
            let audioRate = formatTwoDecimals(info.audioSamplesPerSecond)
            let fps = formatTwoDecimals(info.videoFps)
            logger
                .debug(
                    "RTMP server stream \(stream.streamKey) has FPS \(fps) and \(audioRate) audio samples/second"
                )
        }
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
