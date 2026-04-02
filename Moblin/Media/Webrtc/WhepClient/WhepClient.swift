import CoreMedia
import libdatachannel

private let dispatchQueue = DispatchQueue(label: "com.eerimoq.whep-client")

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

class WhepClient {
    let streamId: UUID
    private let url: URL
    private let latency: Double
    weak var delegate: (any WhepClientDelegate)?
    private var ingestClient: WebrtcIngestClient?
    private var sessionUrl: URL?

    init(streamId: UUID, url: URL, latency: Double) {
        self.streamId = streamId
        self.url = url
        self.latency = latency
    }

    func start() {
        dispatchQueue.async {
            logger.info("whep-client: \(self.streamId): Start")
            self.startInternal()
        }
    }

    func stop() {
        dispatchQueue.async {
            logger.info("whep-client: \(self.streamId): Stop")
            self.stopInternal()
        }
    }

    func isConnected() -> Bool {
        return dispatchQueue.sync {
            ingestClient != nil
        }
    }

    private func startInternal() {
        stopInternal()
        ingestClient = WebrtcIngestClient(
            streamId: streamId,
            latency: latency,
            iceServers: [defaultStunServer],
            dispatchQueue: dispatchQueue,
            delegate: self
        )
        guard let ingestClient else {
            return
        }
        do {
            try ingestClient.createPeerConnection()
            let videoTrackId = try ingestClient.addRecvOnlyTrack(
                codec: RTC_CODEC_H264,
                payloadType: 96,
                mid: "0",
                name: "video",
                profile: "level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f"
            )
            ingestClient.setTrackCodec(trackId: videoTrackId, description: "h264")
            let audioTrackId = try ingestClient.addRecvOnlyTrack(
                codec: RTC_CODEC_OPUS,
                payloadType: 111,
                mid: "1",
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
        if let sessionUrl {
            sendDeleteRequest(url: sessionUrl)
        }
        sessionUrl = nil
        ingestClient?.stop()
        ingestClient = nil
    }

    private func sendOffer(_ offer: String) {
        logger.info("whep-client: \(streamId): Sending offer to \(url.absoluteString)")
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
            stopInternal()
            delegate?.whepClientOnPublishStop(streamId: streamId, reason: "HTTP response not ok")
            return
        }
        if let locationHeader = response.value(forHTTPHeaderField: "Location") {
            sessionUrl = URL(string: locationHeader, relativeTo: url)
        }
        logger.info("whep-client: \(streamId): Got answer \(answer)")
        do {
            try ingestClient?.setRemoteDescription(answer, type: "answer")
        } catch {
            logger.info("whep-client: \(streamId): Failed to set remote answer: \(error)")
            stopInternal()
            delegate?.whepClientOnPublishStop(
                streamId: streamId,
                reason: "Failed to set remote answer"
            )
        }
    }

    private func sendDeleteRequest(url: URL) {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
    }

    private func whepClientConnectionOnDisconnected(streamId: UUID, reason: String) {
        stopInternal()
        delegate?.whepClientOnPublishStop(streamId: streamId, reason: reason)
    }
}

extension WhepClient: WebrtcIngestClientDelegate {
    func webrtcIngestClientOnConnected(streamId: UUID) {
        delegate?.whepClientOnPublishStart(streamId: streamId)
    }

    func webrtcIngestClientOnDisconnected(streamId: UUID, reason: String) {
        delegate?.whepClientOnPublishStop(streamId: streamId, reason: reason)
    }

    func webrtcIngestClientOnVideoBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer) {
        delegate?.whepClientOnVideoBuffer(streamId: streamId, sampleBuffer)
    }

    func webrtcIngestClientOnAudioBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer) {
        delegate?.whepClientOnAudioBuffer(streamId: streamId, sampleBuffer)
    }

    func webrtcIngestClientSetTargetLatencies(
        streamId: UUID,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    ) {
        delegate?.whepClientSetTargetLatencies(
            streamId: streamId,
            videoTargetLatency,
            audioTargetLatency
        )
    }

    func webrtcIngestClientOnGatheringComplete(streamId _: UUID, localDescription: String) {
        sendOffer(localDescription)
    }
}
