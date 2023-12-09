import CryptoKit
import Foundation

private enum OpCode: Int, Codable {
    case hello = 0
    case identify = 1
    case identified = 2
    case reidentify = 3
    case event = 5
    case request = 6
    case requestResponse = 7
    case requestBatch = 8
    case requestBatchResponse = 9
}

private enum CloseCode: Int, Codable {
    case dontClose = 0
    case unknownReason = 4000
    case messageDecodeError = 4002
    case missingDataField = 4003
    case invalidDataFieldType = 4004
    case invalidDataFieldValue = 4005
    case unknownOpCode = 4006
    case notIdentified = 4007
    case alreadyIdentified = 4008
    case authenticationFailed = 4009
    case unsupportedRpcVersion = 4010
    case sessionInvalidated = 4011
    case unsupportedFeature = 4012
}

private enum RequestStatus: Int, Codable {
    case unknown = 0
    case noError = 10
    case success = 100
    case missingRequestType = 203
    case unknownRequestType = 204
    case genericError = 205
    case unsupportedRequestBatchExecutionType = 206
    case notReady = 207
    case missingRequestField = 300
    case missingRequestData = 301
    case invalidRequestField = 400
    case invalidRequestFieldType = 401
    case requestFieldOutOfRange = 402
    case requestFieldEmpty = 403
    case tooManyRequestFields = 404
    case outputRunning = 500
    case outputNotRunning = 501
    case outputPaused = 502
    case outputNotPaused = 503
    case outputDisabled = 504
    case studioModeActive = 505
    case studioModeNotActive = 506
    case resourceNotFound = 600
    case resourceAlreadyExists = 601
    case invalidResourceType = 602
    case notEnoughResources = 603
    case invalidResourceState = 604
    case invalidInputKind = 605
    case resourceNotConfigurable = 606
    case invalidFilterKind = 607
    case resourceCreationFailed = 700
    case resourceActionFailed = 701
    case requestProcessingFailed = 702
    case cannotAct = 703
}

private struct ResponseRequestStatus: Codable {
    let result: Bool
    let code: Int
}

private enum RequestType: String, Codable {
    case getSceneList = "GetSceneList"
    case setCurrentProgramScene = "SetCurrentProgramScene"
    case startStream = "StartStream"
    case stopStream = "StopStream"
    case startRecord = "StartRecord"
    case stopRecord = "StopRecord"
}

private enum EventType: String, Codable {
    case mediaInputPlaybackStarted = "MediaInputPlaybackStarted"
    case mediaInputPlaybackEnded = "MediaInputPlaybackEnded"
}

private struct Identify: Codable {
    let rpcVersion: Int
    let authentication: String?
}

private struct Identified: Codable {
    let negotiatedRpcVersion: Int
}

private struct HelloAuthentication: Decodable {
    let challenge: String
    let salt: String
}

private struct Hello: Decodable {
    let obsWebSocketVersion: String
    let rpcVersion: Int
    let authentication: HelloAuthentication?
}

struct ObsSceneList {
    let currnet: String
    let scenes: [String]
}

struct GetSceneListResponseScene: Decodable {
    let sceneName: String
}

struct GetSceneListResponse: Decodable {
    let currentProgramSceneName: String
    let scenes: [GetSceneListResponseScene]
}

struct SetCurrentProgramSceneRequest: Codable {
    let sceneName: String
}

private let rpcVersion = 1

private func packMessage(op: OpCode, data: Data) -> String {
    let data = String(decoding: data, as: UTF8.self)
    return "{\"op\": \(op.rawValue), \"d\": \(data)}"
}

private func unpackMessage(message: String) throws -> (OpCode?, Data) {
    guard let jsonData = message.data(using: String.Encoding.utf8) else {
        throw "JSON decode failed"
    }
    let data = try JSONSerialization.jsonObject(
        with: jsonData,
        options: JSONSerialization.ReadingOptions.mutableContainers
    )
    guard let jsonResult = data as? NSDictionary else {
        throw "Not a dictionary"
    }
    guard let op = jsonResult["op"] as? Int else {
        throw "OP not an integer"
    }
    guard let op = OpCode(rawValue: op) else {
        return (nil, Data())
    }
    guard let data = jsonResult["d"] as? NSDictionary else {
        throw "No data"
    }
    return try (op, JSONSerialization.data(withJSONObject: data))
}

private func unpackEvent(data: Data) throws -> (EventType?, Int, Data?) {
    let event = try JSONSerialization.jsonObject(
        with: data,
        options: JSONSerialization.ReadingOptions.mutableContainers
    )
    guard let jsonResult = event as? NSDictionary else {
        throw "Not a dictionary"
    }
    guard let type = jsonResult["eventType"] as? String else {
        throw "Event type not a string"
    }
    guard let type = EventType(rawValue: type) else {
        return (nil, 0, nil)
    }
    guard let intent = jsonResult["eventIntent"] as? Int else {
        throw "Event intent not an integer"
    }
    var data: Data?
    if let eventData = jsonResult["eventData"] {
        guard let dataDict = eventData as? NSDictionary else {
            throw "Event data not a dictionary"
        }
        data = try JSONSerialization.data(withJSONObject: dataDict)
    }
    return (type, intent, data)
}

private func unpackRequestResponse(data: Data) throws -> (String, ResponseRequestStatus, Data?) {
    let response = try JSONSerialization.jsonObject(
        with: data,
        options: JSONSerialization.ReadingOptions.mutableContainers
    )
    guard let jsonResult = response as? NSDictionary else {
        throw "Not a dictionary"
    }
    guard let requestId = jsonResult["requestId"] as? String else {
        throw "Request response request id not a string"
    }
    guard let statusDict = jsonResult["requestStatus"] as? NSDictionary else {
        throw "Request response status not an object"
    }
    let status = try JSONDecoder().decode(
        ResponseRequestStatus.self,
        from: JSONSerialization.data(withJSONObject: statusDict)
    )
    var responseData: Data?
    if let dataJson = jsonResult["responseData"] {
        guard let dataDict = dataJson as? NSDictionary else {
            throw "Request response data not an object"
        }
        responseData = try JSONSerialization.data(withJSONObject: dataDict)
    }
    return (requestId, status, responseData)
}

struct Request {
    let onSuccess: (Data?) -> Void
}

class ObsWebSocket {
    private let url: URL
    private let password: String
    private var task: Task<Void, Error>?
    private var connected: Bool = false
    private var webSocket: URLSessionWebSocketTask
    private var nextId: Int = 0
    private var requests: [String: Request] = [:]

    init(url: URL, password: String) {
        self.url = url
        self.password = password
        webSocket = URLSession(configuration: .default).webSocketTask(with: url)
    }

    func start() {
        stop()
        logger.info("obs-websocket-control: start")
        task = Task.init {
            while true {
                setupConnection()
                do {
                    try await receiveMessages()
                } catch {
                    logger.error("obs-websocket-control: error: \(error)")
                }
                if Task.isCancelled {
                    logger.info("obs-websocket-control: Cancelled")
                    connected = false
                    break
                }
                logger.info("obs-websocket-control: Disconencted")
                connected = false
                try await Task.sleep(nanoseconds: 5_000_000_000)
                logger.info("obs-websocket-control: Reconnecting")
            }
        }
    }

    func stop() {
        logger.info("obs-websocket-control: stop")
        task?.cancel()
        task = nil
    }

    func isConnected() -> Bool {
        return connected
    }

    func getSceneList(onSuccess: @escaping (ObsSceneList) -> Void) {
        performRequest(type: .getSceneList, data: nil, onSuccess: { data in
            guard let data else {
                return
            }
            do {
                let decoded = try JSONDecoder().decode(GetSceneListResponse.self, from: data)
                onSuccess(ObsSceneList(
                    currnet: decoded.currentProgramSceneName,
                    scenes: decoded.scenes.map { $0.sceneName }
                ))
            } catch {}
        })
    }

    func setCurrentProgramScene(name: String, onSuccess _: () -> Void) {
        let data = SetCurrentProgramSceneRequest(sceneName: name)
        do {
            let data = try JSONEncoder().encode(data)
            performRequest(type: .setCurrentProgramScene, data: data, onSuccess: { _ in })
        } catch {}
    }

    func startStream() {
        performRequest(type: .startStream, data: nil, onSuccess: { _ in
            logger.info("obs-websocket-control: stream started")
        })
    }

    func stopStream() {
        performRequest(type: .stopStream, data: nil, onSuccess: { _ in
            logger.info("obs-websocket-control: stream stopped")
        })
    }

    func startRecord() {
        performRequest(type: .startRecord, data: nil, onSuccess: { _ in
            logger.info("obs-websocket-control: recording started")
        })
    }

    func stopRecord() {
        performRequest(type: .stopRecord, data: nil, onSuccess: { _ in
            logger.info("obs-websocket-control: recording stopped")
        })
    }

    private func performRequest(type: RequestType, data: Data?, onSuccess: @escaping (Data?) -> Void) {
        let requestId = getNextId()
        requests[requestId] = Request(onSuccess: onSuccess)
        var request: Data
        if let data {
            let data = String(bytes: data, encoding: .utf8)!
            request =
                Data("""
                    {
                       \"requestType\": \"\(type.rawValue)\",
                       \"requestId\": \"\(requestId)\",
                       \"requestData\": \(data)}
                    """
                    .utf8)
        } else {
            request = Data("""
            {
               \"requestType\": \"\(type.rawValue)\",
               \"requestId\": \"\(requestId)\"
            }
            """.utf8)
        }
        let message = packMessage(op: .request, data: request)
        webSocket.send(.string(message)) { _ in }
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
                logger.info("obs-websocket-control: Got data \(message)")
            case let .string(message):
                let (op, data) = try unpackMessage(message: message)
                switch op {
                case .hello:
                    try handleHello(data: data)
                case .identified:
                    try handleIdentified(data: data)
                case .event:
                    try handleEvent(data: data)
                case .requestResponse:
                    try handleRequestResponse(data: data)
                case nil:
                    logger.info("obs-websocket-control: Ignoring message nil")
                default:
                    logger.info("obs-websocket-control: Ignoring message \(op!)")
                }
            default:
                logger.info("obs-websocket-control: ???")
            }
        }
    }

    private func handleHello(data: Data) throws {
        let hello = try JSONDecoder().decode(Hello.self, from: data)
        var authentication: String?
        if let helloAuthentication = hello.authentication {
            var concatenated = "\(password)\(helloAuthentication.salt)"
            var hash = Data(SHA256.hash(data: Data(concatenated.utf8)))
            concatenated = "\(hash.base64EncodedString())\(helloAuthentication.challenge)"
            hash = Data(SHA256.hash(data: Data(concatenated.utf8)))
            authentication = hash.base64EncodedString()
        }
        sendIdentify(authentication: authentication)
    }

    private func handleIdentified(data: Data) throws {
        let identified = try JSONDecoder().decode(Identified.self, from: data)
        logger.info("obs-websocket-control: \(identified)")
        connected = true
    }

    private func handleEvent(data: Data) throws {
        let (type, _, _) = try unpackEvent(data: data)
        switch type {
        case .mediaInputPlaybackStarted:
            break
        case .mediaInputPlaybackEnded:
            break
        case nil:
            break
        }
    }

    private func handleRequestResponse(data: Data) throws {
        let (requestId, status, data) = try unpackRequestResponse(data: data)
        guard let request = requests[requestId] else {
            logger.info("Unexpected request id in response")
            return
        }
        if status.result {
            request.onSuccess(data)
        } else {
            logger.error("obs-websocket-control: Request failed.")
        }
    }

    private func sendIdentify(authentication: String?) {
        let identify = Identify(rpcVersion: rpcVersion, authentication: authentication)
        do {
            let identify = try JSONEncoder().encode(identify)
            let message = packMessage(op: .identify, data: identify)
            webSocket.send(.string(message)) { _ in }
        } catch {}
    }

    private func getNextId() -> String {
        nextId += 1
        return String(nextId)
    }
}
