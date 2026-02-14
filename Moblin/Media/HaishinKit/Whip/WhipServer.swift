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

    func getNumberOfClients() -> Int {
        return whipServerDispatchQueue.sync {
            clients.count
        }
    }

    private func startInternal() {
        let routes = [
            HttpServerRoute(path: "/whip") { [weak self] request, response in
                whipServerDispatchQueue.async {
                    self?.handleWhipEndpoint(request: request, response: response)
                }
            },
            HttpServerRoute(path: "/whip/", prefixMatch: true) { [weak self] request, response in
                whipServerDispatchQueue.async {
                    self?.handleWhipSession(request: request, response: response)
                }
            },
        ]
        server = HttpServer(queue: whipServerDispatchQueue, routes: routes)
        server?.start(port: .init(integerLiteral: UInt16(settings.port)))
        logger.info("whip-server: Started on port \(settings.port)")
    }

    private func stopInternal() {
        for (_, client) in clients {
            client.stop()
        }
        clients.removeAll()
        server?.stop()
        server = nil
        logger.info("whip-server: Stopped")
    }

    private func handleWhipEndpoint(request: HttpServerRequest, response: HttpServerResponse) {
        guard request.method == "POST" else {
            response.send(data: Data(), status: .notFound)
            return
        }
        guard !request.body.isEmpty, let sdpOffer = String(data: request.body, encoding: .utf8) else {
            response.send(data: Data(), status: .notFound)
            return
        }
        logger.debug("whip-server: Received SDP offer")
        let client = WhipServerClient(delegate: self)
        let clientId = client.clientId
        clients[clientId] = client
        client.handleOffer(sdpOffer: sdpOffer) { [weak self] answer in
            guard let answer else {
                response.send(data: Data(), status: .notFound)
                self?.removeClient(clientId: clientId)
                return
            }
            response.send(
                data: answer.utf8Data,
                status: .created,
                contentType: "application/sdp",
                headers: [("Location", "/whip/\(clientId.uuidString)")]
            )
        }
    }

    private func handleWhipSession(request: HttpServerRequest, response: HttpServerResponse) {
        guard request.method == "DELETE" else {
            response.send(data: Data(), status: .notFound)
            return
        }
        let pathComponents = request.path.split(separator: "/")
        guard pathComponents.count >= 2,
              let clientId = UUID(uuidString: String(pathComponents.last ?? ""))
        else {
            response.send(data: Data(), status: .notFound)
            return
        }
        logger.info("whip-server: Received DELETE for client \(clientId)")
        if let client = clients[clientId] {
            client.stop()
            clients.removeValue(forKey: clientId)
            delegate?.whipServerOnPublishStop(clientId: clientId, reason: "Client disconnect")
        }
        response.send(data: Data(), status: .ok)
    }

    private func removeClient(clientId: UUID) {
        whipServerDispatchQueue.async {
            self.clients.removeValue(forKey: clientId)
        }
    }
}

extension WhipServer: WhipServerClientDelegate {
    func whipServerClientOnConnected(clientId: UUID) {
        delegate?.whipServerOnPublishStart(clientId: clientId)
    }

    func whipServerClientOnDisconnected(clientId: UUID, reason: String) {
        whipServerDispatchQueue.async {
            self.clients.removeValue(forKey: clientId)
        }
        delegate?.whipServerOnPublishStop(clientId: clientId, reason: reason)
    }

    func whipServerClientOnVideoBuffer(clientId: UUID, _ sampleBuffer: CMSampleBuffer) {
        delegate?.whipServerOnVideoBuffer(clientId: clientId, sampleBuffer)
    }

    func whipServerClientOnAudioBuffer(clientId: UUID, _ sampleBuffer: CMSampleBuffer) {
        delegate?.whipServerOnAudioBuffer(clientId: clientId, sampleBuffer)
    }
}
