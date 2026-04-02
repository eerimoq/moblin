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
    private var ingestClient: WebRTCIngestClient?
    private var sessionUrl: URL?

    init(streamId: UUID, url: URL, latency: Double) {
        self.streamId = streamId
        self.url = url
        self.latency = latency
    }

    func start() {
        dispatchQueue.async {
            self.startInternal()
        }
    }

    func stop() {
        dispatchQueue.async {
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
        ingestClient = WebRTCIngestClient(
            clientId: streamId,
            latency: latency,
            iceServers: ["stun:stun.l.google.com:19302"],
            dispatchQueue: dispatchQueue,
            delegate: self
        )
        connect2()
    }

    private func stopInternal() {
        stop2()
    }

    private func connect2() {
        guard let ingestClient else {
            return
        }
        do {
            try ingestClient.createPeerConnection()
            _ = try ingestClient.addRecvOnlyTrack(
                codec: RTC_CODEC_OPUS,
                payloadType: 111,
                mid: "1",
                name: "audio",
                profile: ""
            )
            try ingestClient.setLocalDescription("offer")
        } catch {
            logger.info("whep-client: Failed to create offer: \(error)")
            stop2()
        }
    }

    private func stop2() {
        if let sessionUrl {
            sendDeleteRequest(url: sessionUrl)
        }
        sessionUrl = nil
        ingestClient?.stop()
        ingestClient = nil
    }

    private func sendOffer(_ offer: String) {
        logger.debug("whep-client: Sending offer to \(url.absoluteString)")
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
        if let error {
            logger.info("whep-client: Offer request failed: \(error.localizedDescription)")
            stop2()
            delegate?.whepClientOnPublishStop(
                streamId: streamId,
                reason: "Offer request failed: \(error.localizedDescription)"
            )
            return
        }
        guard let response = response as? HTTPURLResponse else {
            logger.info("whep-client: Bad server response")
            stop2()
            delegate?.whepClientOnPublishStop(
                streamId: streamId,
                reason: "Bad server response"
            )
            return
        }
        guard (200 ... 299).contains(response.statusCode) else {
            logger.info("whep-client: Server returned HTTP status \(response.statusCode)")
            stop2()
            delegate?.whepClientOnPublishStop(
                streamId: streamId,
                reason: "Server returned HTTP status \(response.statusCode)"
            )
            return
        }
        if let locationHeader = response.value(forHTTPHeaderField: "Location") {
            sessionUrl = URL(string: locationHeader, relativeTo: url)
        }
        guard let data, let answer = String(data: data, encoding: .utf8) else {
            logger.info("whep-client: Answer missing in response")
            stop2()
            delegate?.whepClientOnPublishStop(
                streamId: streamId,
                reason: "Answer missing in response"
            )
            return
        }
        logger.debug("whep-client: Got answer")
        do {
            try ingestClient?.setRemoteDescription(answer, type: "answer")
        } catch {
            logger.info("whep-client: Failed to set remote answer: \(error)")
            stop2()
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
        stop2()
        delegate?.whepClientOnPublishStop(streamId: streamId, reason: reason)
    }
}

extension WhepClient: WebRTCIngestClientDelegate {
    func webRTCIngestClientOnConnected(clientId: UUID) {
        delegate?.whepClientOnPublishStart(streamId: clientId)
    }

    func webRTCIngestClientOnDisconnected(clientId: UUID, reason: String) {
        delegate?.whepClientOnPublishStop(streamId: clientId, reason: reason)
    }

    func webRTCIngestClientOnVideoBuffer(clientId: UUID, _ sampleBuffer: CMSampleBuffer) {
        delegate?.whepClientOnVideoBuffer(streamId: clientId, sampleBuffer)
    }

    func webRTCIngestClientOnAudioBuffer(clientId: UUID, _ sampleBuffer: CMSampleBuffer) {
        delegate?.whepClientOnAudioBuffer(streamId: clientId, sampleBuffer)
    }

    func webRTCIngestClientSetTargetLatencies(
        clientId: UUID,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    ) {
        delegate?.whepClientSetTargetLatencies(
            streamId: clientId,
            videoTargetLatency,
            audioTargetLatency
        )
    }

    func webRTCIngestClientOnGatheringComplete(clientId _: UUID, localDescription: String) {
        sendOffer(localDescription)
    }
}
