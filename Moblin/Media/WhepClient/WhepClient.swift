import CoreMedia
import Foundation

let whepClientDispatchQueue = DispatchQueue(label: "com.eerimoq.whep-client")

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
    weak var delegate: (any WhepClientDelegate)?
    let streamId: UUID
    private let url: URL
    private let latency: Double

    init(streamId: UUID, url: URL, latency: Double) {
        self.streamId = streamId
        self.url = url
        self.latency = latency
    }

    func start() {
        whepClientDispatchQueue.async {
            self.startInternal()
        }
    }

    func stop() {
        whepClientDispatchQueue.async {
            self.stopInternal()
        }
    }

    func isConnected() -> Bool {
        return false
    }

    private func startInternal() {
        stopInternal()
    }

    private func stopInternal() {}
}
