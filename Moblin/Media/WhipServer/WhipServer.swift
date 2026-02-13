import CoreMedia
import Foundation

let whipServerDispatchQueue = DispatchQueue(label: "com.eerimoq.whip-server")

protocol WhipServerDelegate: AnyObject {
    func whipServerOnPublishStart(clientId: UUID)
    func whipServerOnPublishStop(clientId: UUID, reason: String)
    func whipServerOnVideoBuffer(clientId: UUID, _ sampleBuffer: CMSampleBuffer)
    func whipServerOnAudioBuffer(clientId: UUID, _ sampleBuffer: CMSampleBuffer)
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

    func isClientConnected(clientId: UUID) -> Bool {
        return whipServerDispatchQueue.sync {
            clients[clientId] != nil
        }
    }

    // periphery:ignore
    func getNumberOfClients() -> Int {
        return whipServerDispatchQueue.sync {
            clients.count
        }
    }

    private func startInternal() {
        let routes = [
            HttpServerRoute(path: "/whip/stream/", prefixMatch: true, handler: handleWhipStream),
            HttpServerRoute(path: "/whip/session/", prefixMatch: true, handler: handleWhipSession),
        ]
        server = HttpServer(queue: whipServerDispatchQueue, routes: routes)
        server?.start(port: .init(integer: Int(settings.port)))
        logger.info("whip-server: Started on port \(settings.port)")
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
        guard let sdpOffer = String(data: request.body, encoding: .utf8) else {
            response.send(status: .badRequest)
            return
        }
        let client = WhipServerClient(delegate: self)
        let clientId = client.clientId
        clients[clientId] = client
        client.handleOffer(sdpOffer: sdpOffer) { [weak self] sdpAnswer in
            guard let sdpAnswer else {
                response.send(status: .notFound)
                self?.clients.removeValue(forKey: clientId)
                return
            }
            response.send(
                data: sdpAnswer.utf8Data,
                status: .created,
                contentType: "application/sdp",
                headers: [.init(name: "Location", value: "/whip/session/\(clientId.uuidString)")]
            )
        }
    }

    private func handleWhipSession(request: HttpServerRequest, response: HttpServerResponse) {
        guard request.method == "DELETE" else {
            response.send(status: .methodNotAllowed)
            return
        }
        let pathComponents = request.path.split(separator: "/")
        guard let clientId = UUID(uuidString: String(pathComponents.last ?? "")) else {
            response.send(status: .badRequest)
            return
        }
        if let client = clients.removeValue(forKey: clientId) {
            client.stop()
            delegate?.whipServerOnPublishStop(clientId: clientId, reason: "Client disconnect")
        }
        response.send(status: .ok)
    }
}

extension WhipServer: WhipServerClientDelegate {
    func whipServerClientOnConnected(clientId: UUID) {
        delegate?.whipServerOnPublishStart(clientId: clientId)
    }

    func whipServerClientOnDisconnected(clientId: UUID, reason: String) {
        clients.removeValue(forKey: clientId)
        delegate?.whipServerOnPublishStop(clientId: clientId, reason: reason)
    }

    func whipServerClientOnVideoBuffer(clientId: UUID, _ sampleBuffer: CMSampleBuffer) {
        delegate?.whipServerOnVideoBuffer(clientId: clientId, sampleBuffer)
    }

    func whipServerClientOnAudioBuffer(clientId: UUID, _ sampleBuffer: CMSampleBuffer) {
        delegate?.whipServerOnAudioBuffer(clientId: clientId, sampleBuffer)
    }
}
