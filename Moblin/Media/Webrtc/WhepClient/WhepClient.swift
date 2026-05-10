import CoreMedia
import libdatachannel

private let dispatchQueue = DispatchQueue(label: "com.eerimoq.whep-client")
private let reconnectDelay = 5.0

protocol WhepClientDelegate: AnyObject {
    func whepClientOnPublishStart(streamId: UUID)
    func whepClientOnPublishStop(streamId: UUID, reason: String)
    func whepClientOnVideoBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer)
    func whepClientOnAudioBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer)
    func whepClientSetTargetLatencies(
        streamId: UUID,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    )
}

class WhepClient: @unchecked Sendable {
    let streamId: UUID
    private let url: URL
    private let latency: Double
    private let syncTimestamps: Bool
    private let delegate: any WhepClientDelegate
    private var ingestClient: WebrtcIngestClient?
    private var sessionUrl: URL?
    private var started = false
    private var reconnectTimer = SimpleTimer(queue: dispatchQueue)
    private var connected: Bool = false
    private var bitrateStats = BitrateStats()

    init(streamId: UUID, url: URL, latency: Double, syncTimestamps: Bool, delegate: any WhepClientDelegate) {
        self.streamId = streamId
        self.url = url
        self.latency = latency
        self.syncTimestamps = syncTimestamps
        self.delegate = delegate
    }

    func start() {
        dispatchQueue.async {
            logger.info("whep-client: \(self.streamId): Start")
            self.started = true
            self.startInternal()
        }
    }

    func stop() {
        dispatchQueue.async {
            logger.info("whep-client: \(self.streamId): Stop")
            self.started = false
            self.stopInternal()
        }
    }

    func isConnected() -> Bool {
        dispatchQueue.sync {
            ingestClient != nil
        }
    }

    func updateStats() -> BitrateStatsInstant {
        dispatchQueue.sync {
            bitrateStats.update()
        }
    }

    private func startInternal() {
        guard started else {
            return
        }
        stopInternal()
        ingestClient = WebrtcIngestClient(
            streamId: streamId,
            latency: latency,
            syncTimestamps: syncTimestamps,
            iceServers: [defaultStunServer],
            dispatchQueue: dispatchQueue,
            delegate: self
        )
        guard let ingestClient else {
            return
        }
        do {
            let msid = UUID().uuidString
            try ingestClient.createPeerConnection()
            let videoTrackId = try ingestClient.addRecvOnlyTrack(
                codec: RTC_CODEC_H264,
                payloadType: Int32(h264PayloadType),
                mid: "0",
                msid: msid,
                name: "video",
                profile: ""
            )
            ingestClient.setTrackCodec(trackId: videoTrackId, description: "h264")
            let audioTrackId = try ingestClient.addRecvOnlyTrack(
                codec: RTC_CODEC_OPUS,
                payloadType: Int32(opusPayloadType),
                mid: "1",
                msid: msid,
                name: "audio",
                profile: ""
            )
            ingestClient.setTrackCodec(trackId: audioTrackId, description: "opus")
            try ingestClient.setLocalDescription("offer")
        } catch {
            logger.info("whep-client: \(streamId): Failed to create offer: \(error)")
            stopInternal()
        }
    }

    private func stopInternal() {
        reconnectTimer.stop()
        if let sessionUrl {
            sendDeleteRequest(url: sessionUrl)
        }
        sessionUrl = nil
        ingestClient?.stop()
        ingestClient = nil
        connected = false
    }

    private func reconnectSoon() {
        stopInternal()
        logger.debug("whep-client: \(streamId): Reconnecting in \(reconnectDelay) seconds")
        reconnectTimer.startSingleShot(timeout: reconnectDelay) { [weak self] in
            self?.startInternal()
        }
    }

    private func sendOffer(_ offer: String) {
        logger.debug("whep-client: \(streamId): Sending offer to \(url.absoluteString)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/sdp", forHTTPHeaderField: "Content-Type")
        request.httpBody = offer.utf8Data
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            dispatchQueue.async {
                self?.handleOfferResponse(data: data, response: response, error: error)
            }
        }.resume()
    }

    private func handleOfferResponse(data: Data?, response: URLResponse?, error: (any Error)?) {
        guard error == nil,
              let response = response?.http,
              response.isSuccessful,
              let data,
              let answer = String(data: data, encoding: .utf8)
        else {
            logger.info("whep-client: \(streamId): HTTP response not ok")
            reconnectSoon()
            return
        }
        if let locationHeader = response.value(forHTTPHeaderField: "Location") {
            sessionUrl = URL(string: locationHeader, relativeTo: url)
        }
        logger.debug("whep-client: \(streamId): Got answer \(answer)")
        do {
            try ingestClient?.setRemoteDescription(answer, type: "answer")
        } catch {
            logger.info("whep-client: \(streamId): Failed to set remote answer: \(error)")
            reconnectSoon()
        }
    }

    private func sendDeleteRequest(url: URL) {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
    }
}

extension WhepClient: WebrtcIngestClientDelegate {
    func webrtcIngestClientOnConnected(streamId: UUID) {
        connected = true
        delegate.whepClientOnPublishStart(streamId: streamId)
    }

    func webrtcIngestClientOnDisconnected(streamId: UUID, reason: String) {
        if connected {
            delegate.whepClientOnPublishStop(streamId: streamId, reason: reason)
            connected = false
        }
        reconnectSoon()
    }

    func webrtcIngestClientOnVideoBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer) {
        delegate.whepClientOnVideoBuffer(streamId: streamId, sampleBuffer)
    }

    func webrtcIngestClientOnAudioBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer) {
        delegate.whepClientOnAudioBuffer(streamId: streamId, sampleBuffer)
    }

    func webrtcIngestClientSetTargetLatencies(
        streamId: UUID,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    ) {
        delegate.whepClientSetTargetLatencies(
            streamId: streamId,
            videoTargetLatency,
            audioTargetLatency
        )
    }

    func webrtcIngestClientOnGatheringComplete(streamId _: UUID, localDescription: String) {
        sendOffer(localDescription)
    }

    func webrtcIngestClientOnDataReceived(streamId _: UUID, count: Int) {
        bitrateStats.add(bytesTransferred: count)
    }
}
