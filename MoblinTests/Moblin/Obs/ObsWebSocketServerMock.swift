import CryptoKit
import Foundation
@testable import Moblin
import Network

struct ObsMockIdentify: Sendable {
    let rpcVersion: Int
    let authentication: String?
}

struct ObsMockRequest: Sendable {
    let type: String
    let id: String
    let data: String?
}

struct ObsMockRequestBatch: Sendable {
    let id: String
    let requests: [ObsMockRequest]
}

enum ObsMockResult: Sendable {
    case success(data: String? = nil)
    case failure(code: Int, comment: String? = nil)
}

private enum ObsMockMessage: Sendable {
    case identify(ObsMockIdentify)
    case reidentify(eventSubscriptions: UInt64)
    case request(ObsMockRequest)
    case requestBatch(ObsMockRequestBatch)
}

private func jsonString(_ value: Any) throws -> String {
    let data = try JSONSerialization.data(
        withJSONObject: value,
        options: [.sortedKeys, .fragmentsAllowed, .withoutEscapingSlashes]
    )
    return String.fromUtf8(data: data)
}

@MainActor
final class ObsWebSocketServerMock {
    private let listener: NWListener
    private let password: String?
    private let salt = "lM1GncleQOaCu9vsLMhnvT94j+pSHfs+aGZk0+3M8Xw="
    private let challenge = "+IxH4CnCiqpX1rM9scsNynZzbOe4KhDeYcTNS3PDaeY="
    private let ready = MessageQueue<UInt16>()
    private let connections = MessageQueue<NWConnection>()
    private let messages = MessageQueue<ObsMockMessage>()
    private var port: UInt16?
    private var connection: NWConnection?

    init(password: String? = nil) throws {
        self.password = password
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let options = NWProtocolWebSocket.Options()
        options.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(options, at: 0)
        listener = try NWListener(using: parameters)
        listener.stateUpdateHandler = { state in
            MainActor.assumeIsolated {
                self.handleListenerState(state)
            }
        }
        listener.newConnectionHandler = { connection in
            MainActor.assumeIsolated {
                self.handleNewConnection(connection)
            }
        }
        listener.start(queue: .main)
    }

    deinit {
        listener.cancel()
    }

    func url() async -> URL {
        if port == nil {
            port = await ready.get()
        }
        return URL(string: "ws://127.0.0.1:\(port!)")!
    }

    func connect() async throws {
        await acceptConnection()
        sendHello()
        let identify = try await receiveIdentify()
        guard identify.rpcVersion == 1 else {
            throw "Unsupported RPC version \(identify.rpcVersion)"
        }
        guard identify.authentication == expectedAuthentication() else {
            throw "Authentication mismatch"
        }
        sendIdentified()
    }

    func acceptConnection() async {
        connection = await connections.get()
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
    }

    func close(code: UInt16) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .close)
        metadata.closeCode = .privateCode(code)
        let context = NWConnection.ContentContext(identifier: "close", metadata: [metadata])
        connection?.send(content: nil, contentContext: context, isComplete: true, completion: .idempotent)
    }

    func expectedAuthentication() -> String? {
        guard let password else {
            return nil
        }
        let secret = Data(SHA256.hash(data: Data("\(password)\(salt)".utf8))).base64EncodedString()
        return Data(SHA256.hash(data: Data("\(secret)\(challenge)".utf8))).base64EncodedString()
    }

    func sendHello() {
        var authentication = ""
        if password != nil {
            authentication = ",\"authentication\":{\"challenge\":\"\(challenge)\",\"salt\":\"\(salt)\"}"
        }
        send(op: 0, data: "{\"obsWebSocketVersion\":\"5.5.2\",\"rpcVersion\":1\(authentication)}")
    }

    func sendIdentified() {
        send(op: 2, data: "{\"negotiatedRpcVersion\":1}")
    }

    func sendEvent(type: String, intent: Int, data: String? = nil) {
        var eventData = ""
        if let data {
            eventData = ",\"eventData\":\(data)"
        }
        send(op: 5, data: "{\"eventType\":\"\(type)\",\"eventIntent\":\(intent)\(eventData)}")
    }

    func respond(to request: ObsMockRequest, data: String? = nil) {
        send(op: 7, data: responseJson(request, .success(data: data)))
    }

    func respond(to request: ObsMockRequest, errorCode: Int, comment: String? = nil) {
        send(op: 7, data: responseJson(request, .failure(code: errorCode, comment: comment)))
    }

    func respond(to batch: ObsMockRequestBatch, results: [ObsMockResult]) {
        let results = zip(batch.requests, results).map { responseJson($0, $1) }
        send(op: 9, data: "{\"requestId\":\(batch.id),\"results\":[\(results.joined(separator: ","))]}")
    }

    func send(op: Int, data: String) {
        send(text: "{\"op\":\(op),\"d\":\(data)}")
    }

    func send(text: String) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "text", metadata: [metadata])
        connection?.send(
            content: text.utf8Data,
            contentContext: context,
            isComplete: true,
            completion: .idempotent
        )
    }

    func receiveIdentify() async throws -> ObsMockIdentify {
        guard case let .identify(identify) = await messages.get() else {
            throw "Expected identify"
        }
        return identify
    }

    func receiveReidentify() async throws -> UInt64 {
        guard case let .reidentify(eventSubscriptions) = await messages.get() else {
            throw "Expected reidentify"
        }
        return eventSubscriptions
    }

    func receiveRequest() async throws -> ObsMockRequest {
        guard case let .request(request) = await messages.get() else {
            throw "Expected request"
        }
        return request
    }

    func receiveRequestBatch() async throws -> ObsMockRequestBatch {
        guard case let .requestBatch(batch) = await messages.get() else {
            throw "Expected request batch"
        }
        return batch
    }

    private func responseJson(_ request: ObsMockRequest, _ result: ObsMockResult) -> String {
        var status: String
        var responseData = ""
        switch result {
        case let .success(data):
            status = "{\"result\":true,\"code\":100}"
            if let data {
                responseData = ",\"responseData\":\(data)"
            }
        case let .failure(code, comment):
            status = "{\"result\":false,\"code\":\(code)"
            if let comment {
                status += ",\"comment\":\"\(comment)\""
            }
            status += "}"
        }
        return """
        {"requestType":"\(request.type)","requestId":"\(request.id)","requestStatus":\(status)\(responseData)}
        """
    }

    private func handleListenerState(_ state: NWListener.State) {
        if state == .ready, let port = listener.port {
            ready.put(port.rawValue)
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            MainActor.assumeIsolated {
                if state == .ready {
                    self.connections.put(connection)
                    self.receive(connection: connection)
                }
            }
        }
        connection.start(queue: .main)
    }

    private func receive(connection: NWConnection) {
        connection.receiveMessage { content, context, isComplete, error in
            MainActor.assumeIsolated {
                guard error == nil, context?.isFinal != true else {
                    return
                }
                if let content, isComplete {
                    let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition)
                    if let metadata = metadata as? NWProtocolWebSocket.Metadata, metadata.opcode == .text {
                        do {
                            try self.handleMessage(String.fromUtf8(data: content))
                        } catch {
                            logger.info("obs-mock: Failed to handle message: \(error)")
                        }
                    }
                }
                self.receive(connection: connection)
            }
        }
    }

    private func handleMessage(_ text: String) throws {
        guard let message = try JSONSerialization.jsonObject(with: text.utf8Data) as? [String: Any],
              let op = message["op"] as? Int,
              let data = message["d"] as? [String: Any]
        else {
            throw "Malformed message"
        }
        switch op {
        case 1:
            guard let rpcVersion = data["rpcVersion"] as? Int else {
                throw "Missing rpcVersion"
            }
            messages.put(.identify(ObsMockIdentify(rpcVersion: rpcVersion,
                                                   authentication: data["authentication"] as? String)))
        case 3:
            guard let eventSubscriptions = data["eventSubscriptions"] as? UInt64 else {
                throw "Missing eventSubscriptions"
            }
            messages.put(.reidentify(eventSubscriptions: eventSubscriptions))
        case 6:
            try messages.put(.request(parseRequest(data)))
        case 8:
            guard let id = data["requestId"], let requests = data["requests"] as? [[String: Any]] else {
                throw "Malformed request batch"
            }
            try messages.put(.requestBatch(ObsMockRequestBatch(id: jsonString(id),
                                                               requests: requests.map(parseRequest))))
        default:
            throw "Unexpected op \(op)"
        }
    }

    private func parseRequest(_ data: [String: Any]) throws -> ObsMockRequest {
        guard let type = data["requestType"] as? String, let id = data["requestId"] as? String else {
            throw "Malformed request"
        }
        return try ObsMockRequest(type: type, id: id, data: data["requestData"].map(jsonString))
    }
}
