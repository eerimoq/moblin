import Foundation

protocol RemoteControlServerDelegate: AnyObject {
    func getStatus(onComplete: @escaping (RemoteControlStatusTopLeft, RemoteControlStatusTopRight) -> Void)
}

class RemoteControlServer {
    private var clientUrl: URL
    private var password: String
    private weak var delegate: (any RemoteControlServerDelegate)?
    private var webSocket: URLSessionWebSocketTask
    private var task: Task<Void, Error>?
    private var clientIdentified: Bool = false

    init(clientUrl: URL, password: String, delegate: RemoteControlServerDelegate) {
        self.clientUrl = clientUrl
        self.password = password
        self.delegate = delegate
        webSocket = URLSession(configuration: .default).webSocketTask(with: clientUrl)
    }

    func start() {
        stop()
        logger.info("moblin-server: start")
        task = Task.init {
            while true {
                setupConnection()
                do {
                    try await receiveMessages()
                } catch {
                    logger.debug("moblin-server: error: \(error.localizedDescription)")
                }
                if Task.isCancelled {
                    logger.debug("moblin-server: Cancelled")
                    break
                }
                logger.debug("moblin-server: Disconnected")
                try await Task.sleep(nanoseconds: 5_000_000_000)
                logger.debug("moblin-server: Reconnecting")
            }
        }
    }

    func stop() {
        logger.info("moblin-server: stop")
        task?.cancel()
        task = nil
    }

    private func setupConnection() {
        webSocket = URLSession.shared.webSocketTask(with: clientUrl)
        webSocket.resume()
        send(message: .event(data: .hello(
            apiVersion: remoteControlApiVersion,
            authentication: .init(challenge: "test", salt: "test")
        )))
        clientIdentified = false
    }

    private func send(message: RemoteControlMessageToClient) {
        do {
            try webSocket.send(.string(message.toJson())) { _ in }
        } catch {
            logger.info("moblin-server: Encode failed")
        }
    }

    private func receiveMessages() async throws {
        while true {
            let message = try await webSocket.receive()
            if Task.isCancelled {
                break
            }
            switch message {
            case let .data(message):
                logger.debug("moblin-server: Got data \(message)")
            case let .string(message):
                do {
                    switch try RemoteControlMessageToServer.fromJson(data: message) {
                    case let .request(id: id, data: data):
                        handleRequest(id: id, data: data)
                    }
                } catch {
                    logger.info("moblin-server: Decode failed")
                }
            default:
                logger.debug("moblin-server: ???")
            }
        }
    }

    private func handleRequest(id: Int, data: RemoteControlRequest) {
        guard let delegate else {
            return
        }
        var result: RemoteControlResult?
        if clientIdentified {
            switch data {
            case .getStatus:
                delegate.getStatus { topLeft, topRight in
                    self.send(message: .response(
                        id: id,
                        result: .ok,
                        data: .getStatus(topLeft: topLeft, topRight: topRight)
                    ))
                }
            default:
                break
            }
        } else {
            switch data {
            case let .identify(authentication: authentication):
                if authentication == password {
                    clientIdentified = true
                    result = .ok
                } else {
                    result = .wrongPassword
                }
            default:
                break
            }
        }
        if let result {
            send(message: .response(id: id, result: result, data: nil))
        }
    }
}

func moblinServerTest() {
    do {
        let hello = RemoteControlMessageToClient.event(data: .hello(
            apiVersion: remoteControlApiVersion,
            authentication: .init(challenge: "hi", salt: "ho")
        ))
        try print("moblin-server:", hello.toJson())
    } catch {}
}
