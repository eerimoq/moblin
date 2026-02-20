import CoreMedia
import Foundation

let whipServerDispatchQueue = DispatchQueue(label: "com.eerimoq.whip-server")

protocol WhipServerDelegate: AnyObject {
    func whipServerOnPublishStart(streamId: UUID)
    func whipServerOnPublishStop(streamId: UUID, reason: String)
    func whipServerOnVideoBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer)
    func whipServerOnAudioBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer)
    func whipServerSetTargetLatencies(
        streamId: UUID,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    )
}

class WhipServer {
    private var server: HttpServer?
    private var clients: [UUID: WhipServerClient] = [:]
    weak var delegate: (any WhipServerDelegate)?
    var settings: SettingsWhipServer

    init(settings: SettingsWhipServer) {
        self.settings = settings
    }

    func start() {
        whipServerDispatchQueue.async {
            self.startInternal()
        }
    }

    func stop() {
        whipServerDispatchQueue.async {
            self.stopInternal()
        }
    }

    func getNumberOfClients() -> Int {
        return whipServerDispatchQueue.sync {
            clients.count
        }
    }

    func isStreamConnected(streamId: UUID) -> Bool {
        return whipServerDispatchQueue.sync {
            clients[streamId] != nil
        }
    }

    private func startInternal() {
        let routes = [
            HttpServerRoute(path: "/whip/stream/", prefixMatch: true, handler: handleWhipStream),
            HttpServerRoute(path: "/whip/session/", prefixMatch: true, handler: handleWhipSession),
        ]
        server = HttpServer(queue: whipServerDispatchQueue, routes: routes)
        server?.start(port: .init(integer: Int(settings.port)))
        logger.info("whip-server: Listening on port \(settings.port)")
    }

    private func stopInternal() {
        for client in clients.values {
            client.stop()
        }
        clients.removeAll()
        server?.stop()
        server = nil
        logger.info("whip-server: Stopped")
    }

    private func handleWhipStream(request: HttpServerRequest, response: HttpServerResponse) {
        guard request.method == "POST" else {
            response.send(status: .methodNotAllowed)
            return
        }
        guard let streamKey = request.path.split(separator: "/").last,
              let stream = settings.streams.first(where: { $0.streamKey == streamKey }),
              let sdpOffer = String(data: request.body, encoding: .utf8)
        else {
            response.send(status: .badRequest)
            return
        }
        let client = WhipServerClient(streamId: stream.id,
                                      latency: stream.latencySeconds(),
                                      delegate: self)
        let streamId = client.streamId
        clients[streamId] = client
        client.handleOffer(sdpOffer: sdpOffer) { [weak self] sdpAnswer in
            guard let sdpAnswer else {
                response.send(status: .notFound)
                self?.clients.removeValue(forKey: streamId)
                return
            }
            response.send(
                data: sdpAnswer.utf8Data,
                status: .created,
                contentType: "application/sdp",
                headers: [.init(name: "Location", value: "/whip/session/\(streamId.uuidString)")]
            )
        }
    }

    private func handleWhipSession(request: HttpServerRequest, response: HttpServerResponse) {
        guard request.method == "DELETE" else {
            response.send(status: .methodNotAllowed)
            return
        }
        guard let lastComponent = request.path.split(separator: "/").last,
              let streamId = UUID(uuidString: String(lastComponent))
        else {
            response.send(status: .badRequest)
            return
        }
        if let client = clients.removeValue(forKey: streamId) {
            client.stop()
            delegate?.whipServerOnPublishStop(streamId: streamId, reason: "Client disconnect")
        }
        response.send(status: .ok)
    }
}

extension WhipServer: WhipServerClientDelegate {
    func whipServerClientOnConnected(streamId: UUID) {
        delegate?.whipServerOnPublishStart(streamId: streamId)
    }

    func whipServerClientOnDisconnected(streamId: UUID, reason: String) {
        clients.removeValue(forKey: streamId)
        delegate?.whipServerOnPublishStop(streamId: streamId, reason: reason)
    }

    func whipServerClientOnVideoBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer) {
        delegate?.whipServerOnVideoBuffer(streamId: streamId, sampleBuffer)
    }

    func whipServerClientOnAudioBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer) {
        delegate?.whipServerOnAudioBuffer(streamId: streamId, sampleBuffer)
    }

    func whipServerClientSetTargetLatencies(
        streamId: UUID,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    ) {
        delegate?.whipServerSetTargetLatencies(streamId: streamId, videoTargetLatency, audioTargetLatency)
    }
}
