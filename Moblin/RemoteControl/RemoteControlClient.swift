import CryptoKit
import Foundation

private struct RemoteControlRequestResponse {
    let onSuccess: (RemoteControlResponse?) -> Void
    let onError: (String) -> Void
}

class RemoteControlClient {
    private let url: URL
    private let password: String
    private var task: Task<Void, Error>?
    private var connected: Bool = false
    private var webSocket: URLSessionWebSocketTask
    private var nextId: Int = 0
    private var requests: [Int: RemoteControlRequestResponse] = [:]
    private var onConnected: () -> Void
    var connectionErrorMessage: String = ""

    init(url: URL, password: String, onConnected: @escaping () -> Void) {
        self.url = url
        self.password = password
        self.onConnected = onConnected
        webSocket = URLSession(configuration: .default).webSocketTask(with: url)
    }

    func start() {
        stop()
        logger.info("remote-control-client: start")
        task = Task.init {
            while true {
                setupConnection()
                do {
                    try await receiveMessages()
                } catch {
                    logger.debug("remote-control-client: error: \(error.localizedDescription)")
                    connectionErrorMessage = error.localizedDescription
                }
                if Task.isCancelled {
                    logger.debug("remote-control-client: Cancelled")
                    connected = false
                    connectionErrorMessage = ""
                    break
                }
                logger.debug("remote-control-client: Disconnected")
                connected = false
                try await Task.sleep(nanoseconds: 5_000_000_000)
                logger.debug("remote-control-client: Reconnecting")
            }
        }
    }

    func stop() {
        logger.info("remote-control-client: stop")
        task?.cancel()
        task = nil
    }

    func isConnected() -> Bool {
        return connected
    }

    func getStatus() {
        performRequest(data: .getStatus) { response in
            guard let response else {
                return
            }
            switch response {
            case let .getStatus(topLeft: topLeft, topRight: topRight):
                logger.info("\(topLeft) \(topRight)")
            }
        } onError: { _ in
        }
    }

    private func setupConnection() {
        webSocket = URLSession.shared.webSocketTask(with: url)
        webSocket.resume()
    }

    private func receiveMessages() async throws {
        while true {
            let message = try await webSocket.receive()
            if Task.isCancelled {
                break
            }
            switch message {
            case let .data(message):
                logger.debug("remote-control-client: Got data \(message)")
            case let .string(message):
                let message = try RemoteControlMessageToClient.fromJson(data: message)
                switch message {
                case let .event(data: data):
                    try handleEvent(data: data)
                case let .response(id: id, result: result, data: data):
                    handleResponse(id: id, result: result, data: data)
                }
            default:
                logger.debug("remote-control-client: ???")
            }
        }
    }

    private func handleEvent(data: RemoteControlEvent) throws {
        switch data {
        case let .hello(apiVersion: apiVersion, authentication: authentication):
            try handleHelloEvent(apiVersion: apiVersion, authentication: authentication)
        }
    }

    private func handleResponse(id: Int, result: RemoteControlResult, data: RemoteControlResponse?) {
        guard let request = requests[id] else {
            logger.debug("remote-control-client: Unexpected id in response")
            return
        }
        switch result {
        case .ok:
            request.onSuccess(data)
        case .wrongPassword:
            request.onError("Wrong password")
        }
    }

    private func handleHelloEvent(apiVersion _: String, authentication: RemoteControlAuthentication) throws {
        var concatenated = "\(password)\(authentication.salt)"
        var hash = Data(SHA256.hash(data: Data(concatenated.utf8)))
        concatenated = "\(hash.base64EncodedString())\(authentication.challenge)"
        hash = Data(SHA256.hash(data: Data(concatenated.utf8)))
        performRequest(data: .identify(authentication: hash.base64EncodedString())) { _ in
            self.connected = true
            self.onConnected()
        } onError: { message in
            logger.info("remote-control-client: error: \(message)")
        }
    }

    private func performRequest(
        data: RemoteControlRequest,
        onSuccess: @escaping (RemoteControlResponse?) -> Void,
        onError: @escaping (String) -> Void
    ) {
        guard connected else {
            onError("Not connected to server")
            return
        }
        let id = getNextId()
        let request: RemoteControlMessageToServer = .request(id: id, data: data)
        guard let message = request.toJson() else {
            return
        }
        requests[id] = RemoteControlRequestResponse(onSuccess: onSuccess, onError: onError)
        webSocket.send(.string(message)) { _ in }
    }

    private func getNextId() -> Int {
        nextId += 1
        return nextId
    }
}
