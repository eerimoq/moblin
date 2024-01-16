import Foundation

private let apiVersion = "0.1"

private enum MoblinRequest: Codable {
    case identify(authentication: String)
    case setTorch(on: Bool)
    case setMute(on: Bool)
    case getStatus
}

private enum MoblinResponse: Codable {
    case getStatus(isLive: Bool, bitrate: Float)
}

private enum MoblinEvent: Codable {
    case hello(apiVersion: String, authentication: MoblinAuthentication)
}

private enum MoblinResult: Codable {
    case ok
    case wrongPassword
}

private struct MoblinAuthentication: Codable {
    var challenge: String
    var salt: String
}

private enum MoblinMessageToServer: Codable {
    case request(id: Int, data: MoblinRequest)

    func toJson() -> String? {
        do {
            return try String(bytes: JSONEncoder().encode(self), encoding: .utf8)
        } catch {
            return nil
        }
    }

    static func fromJson(data: String) throws -> MoblinMessageToServer {
        guard let data = data.data(using: .utf8) else {
            throw "Not a UTF-8 string"
        }
        return try JSONDecoder().decode(MoblinMessageToServer.self, from: data)
    }
}

private enum MoblinMessageToClient: Codable {
    case response(id: Int, result: MoblinResult, data: MoblinResponse?)
    case event(data: MoblinEvent)

    func toJson() throws -> String {
        guard let encoded = try String(bytes: JSONEncoder().encode(self), encoding: .utf8) else {
            throw "Encode failed"
        }
        return encoded
    }

    static func fromJson(data: String) throws -> MoblinMessageToClient {
        guard let data = data.data(using: .utf8) else {
            throw "Not a UTF-8 string"
        }
        return try JSONDecoder().decode(MoblinMessageToClient.self, from: data)
    }
}

protocol RemoteControlServerDelegate: AnyObject {
    func setTorch(on: Bool)
    func setMute(on: Bool)
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
            apiVersion: apiVersion,
            authentication: .init(challenge: "test", salt: "test")
        )))
        clientIdentified = false
    }

    private func send(message: MoblinMessageToClient) {
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
                    switch try MoblinMessageToServer.fromJson(data: message) {
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

    private func handleRequest(id: Int, data: MoblinRequest) {
        var result: MoblinResult = .ok
        if clientIdentified {
            switch data {
            case let .setTorch(on: on):
                delegate?.setTorch(on: on)
            case let .setMute(on: on):
                delegate?.setMute(on: on)
            default:
                return
            }
        } else {
            switch data {
            case let .identify(authentication: authentication):
                if authentication == password {
                    clientIdentified = true
                } else {
                    result = .wrongPassword
                }
            default:
                return
            }
        }
        send(message: .response(id: id, result: result, data: nil))
    }
}

func moblinServerTest() {
    do {
        let hello = MoblinMessageToClient.event(data: .hello(
            apiVersion: apiVersion,
            authentication: .init(challenge: "hi", salt: "ho")
        ))
        try print("moblin-server:", hello.toJson())
    } catch {}
}
