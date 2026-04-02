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
    private var ingestClient: WebrtcIngestClient?
    private var answerCompletion: ((String?) -> Void)?
    weak var delegate: WhipServerClientDelegate?

    init(streamId: UUID, latency: Double, iceServers: [String], delegate: WhipServerClientDelegate) {
        self.streamId = streamId
        self.delegate = delegate
        ingestClient = WebrtcIngestClient(
            streamId: streamId,
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
    func webrtcIngestClientOnConnected(streamId: UUID) {
        delegate?.whipServerClientOnConnected(streamId: streamId)
    }

    func webrtcIngestClientOnDisconnected(streamId: UUID, reason: String) {
        delegate?.whipServerClientOnDisconnected(streamId: streamId, reason: reason)
    }

    func webrtcIngestClientOnVideoBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer) {
        delegate?.whipServerClientOnVideoBuffer(streamId: streamId, sampleBuffer)
    }

    func webrtcIngestClientOnAudioBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer) {
        delegate?.whipServerClientOnAudioBuffer(streamId: streamId, sampleBuffer)
    }

    func webrtcIngestClientSetTargetLatencies(
        streamId: UUID,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    ) {
        delegate?.whipServerClientSetTargetLatencies(
            streamId: streamId,
            videoTargetLatency,
            audioTargetLatency
        )
    }

    func webrtcIngestClientOnGatheringComplete(streamId _: UUID, localDescription: String) {
        answerCompletion?(localDescription)
        answerCompletion = nil
    }
}
