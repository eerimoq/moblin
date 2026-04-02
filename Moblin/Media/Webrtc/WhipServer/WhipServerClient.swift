import CoreMedia
import Foundation

protocol WhipServerClientDelegate: AnyObject {
    func whipServerClientOnConnected(streamId: UUID)
    func whipServerClientOnDisconnected(streamId: UUID, reason: String)
    func whipServerClientOnVideoBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer)
    func whipServerClientOnAudioBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer)
    func whipServerClientSetTargetLatencies(
        streamId: UUID,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    )
}

final class WhipServerClient {
    let streamId: UUID
    private var ingestClient: WebRTCIngestClient?
    private var answerCompletion: ((String?) -> Void)?
    weak var delegate: WhipServerClientDelegate?

    init(streamId: UUID, latency: Double, iceServers: [String], delegate: WhipServerClientDelegate) {
        self.streamId = streamId
        self.delegate = delegate
        ingestClient = WebRTCIngestClient(
            clientId: streamId,
            latency: latency,
            iceServers: iceServers,
            dispatchQueue: whipServerDispatchQueue,
            delegate: self
        )
    }

    func handleOffer(sdpOffer: String, completion: @escaping (String?) -> Void) {
        guard let ingestClient else {
            completion(nil)
            return
        }
        do {
            try ingestClient.createPeerConnection()
            try ingestClient.setRemoteDescription(sdpOffer, type: "offer")
            answerCompletion = completion
        } catch {
            completion(nil)
            stop()
        }
    }

    func stop() {
        ingestClient?.stop()
        ingestClient = nil
        answerCompletion = nil
    }
}

extension WhipServerClient: WebrtcIngestClientDelegate {
    func webRTCIngestClientOnConnected(clientId: UUID) {
        delegate?.whipServerClientOnConnected(streamId: clientId)
    }

    func webRTCIngestClientOnDisconnected(clientId: UUID, reason: String) {
        delegate?.whipServerClientOnDisconnected(streamId: clientId, reason: reason)
    }

    func webRTCIngestClientOnVideoBuffer(clientId: UUID, _ sampleBuffer: CMSampleBuffer) {
        delegate?.whipServerClientOnVideoBuffer(streamId: clientId, sampleBuffer)
    }

    func webRTCIngestClientOnAudioBuffer(clientId: UUID, _ sampleBuffer: CMSampleBuffer) {
        delegate?.whipServerClientOnAudioBuffer(streamId: clientId, sampleBuffer)
    }

    func webRTCIngestClientSetTargetLatencies(
        clientId: UUID,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    ) {
        delegate?.whipServerClientSetTargetLatencies(
            streamId: clientId,
            videoTargetLatency,
            audioTargetLatency
        )
    }

    func webRTCIngestClientOnGatheringComplete(clientId _: UUID, localDescription: String) {
        answerCompletion?(localDescription)
        answerCompletion = nil
    }
}
