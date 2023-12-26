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

/* private enum CloseCode: Int, Codable {
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
 } */

/* private enum RequestStatus: Int, Codable {
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
 } */

private struct ResponseRequestStatus: Codable {
    let result: Bool
    let code: Int
}

private enum RequestType: String, Codable {
    case getSceneList = "GetSceneList"
    case setCurrentProgramScene = "SetCurrentProgramScene"
    case getStreamStatus = "GetStreamStatus"
    case startStream = "StartStream"
    case stopStream = "StopStream"
    case getRecordStatus = "GetRecordStatus"
    case startRecord = "StartRecord"
    case stopRecord = "StopRecord"
}

private enum EventType: String, Codable {
    case mediaInputPlaybackStarted = "MediaInputPlaybackStarted"
    case mediaInputPlaybackEnded = "MediaInputPlaybackEnded"
    case currentProgramSceneChanged = "CurrentProgramSceneChanged"
    case streamStateChanged = "StreamStateChanged"
    case recordStateChanged = "RecordStateChanged"
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
    // let obsWebSocketVersion: String
    // let rpcVersion: Int
    let authentication: HelloAuthentication?
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

struct GetStreamStatusResponse: Codable {
    let outputActive: Bool
}

struct GetRecordStatusResponse: Codable {
    let outputActive: Bool
}

struct SceneChangedEvent: Decodable {
    let sceneName: String
}

struct StreamStateChangedEvent: Decodable {
    let outputActive: Bool
}

struct RecordStateChangedEvent: Decodable {
    let outputActive: Bool
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
        logger.debug("obs-websocket: Unsupported event \(type)")
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
    let onError: (String) -> Void
}

struct ObsSceneList {
    let current: String
    let scenes: [String]
}

struct ObsStreamStatus {
    let active: Bool
}

struct ObsRecordStatus {
    let active: Bool
}

class ObsWebSocket {
    private let url: URL
    private let password: String
    private var task: Task<Void, Error>?
    private var connected: Bool = false
    private var webSocket: URLSessionWebSocketTask
    private var nextId: Int = 0
    private var requests: [String: Request] = [:]
    private var onConnected: () -> Void
    var onSceneChanged: ((String) -> Void)?
    var onStreamStatusChanged: ((Bool) -> Void)?
    var onRecordStatusChanged: ((Bool) -> Void)?
    var connectionErrorMessage: String = ""

    init(url: URL, password: String, onConnected: @escaping () -> Void) {
        self.url = url
        self.password = password
        self.onConnected = onConnected
        webSocket = URLSession(configuration: .default).webSocketTask(with: url)
    }

    func start() {
        stop()
        logger.info("obs-websocket: start")
        task = Task.init {
            while true {
                setupConnection()
                do {
                    try await receiveMessages()
                } catch {
                    logger.debug("obs-websocket: error: \(error.localizedDescription)")
                    connectionErrorMessage = error.localizedDescription
                }
                if Task.isCancelled {
                    logger.debug("obs-websocket: Cancelled")
                    connected = false
                    connectionErrorMessage = ""
                    break
                }
                logger.debug("obs-websocket: Disconnected")
                connected = false
                try await Task.sleep(nanoseconds: 5_000_000_000)
                logger.debug("obs-websocket: Reconnecting")
            }
        }
    }

    func stop() {
        logger.info("obs-websocket: stop")
        task?.cancel()
        task = nil
    }

    func isConnected() -> Bool {
        return connected
    }

    func getSceneList(onSuccess: @escaping (ObsSceneList) -> Void, onError: @escaping (String) -> Void) {
        performRequest(type: .getSceneList, data: nil, onSuccess: { data in
            guard let data else {
                onError("No data received")
                return
            }
            do {
                let decoded = try JSONDecoder().decode(GetSceneListResponse.self, from: data)
                onSuccess(ObsSceneList(
                    current: decoded.currentProgramSceneName,
                    scenes: decoded.scenes.reversed().map { $0.sceneName }
                ))
            } catch {
                onError("JSON decode failed")
            }
        }, onError: { message in
            onError(message)
        })
    }

    func setCurrentProgramScene(name: String, onSuccess: @escaping () -> Void,
                                onError: @escaping (String) -> Void)
    {
        let data = SetCurrentProgramSceneRequest(sceneName: name)
        do {
            let data = try JSONEncoder().encode(data)
            performRequest(type: .setCurrentProgramScene, data: data, onSuccess: { _ in
                onSuccess()
            }, onError: { message in
                onError(message)
            })
        } catch {
            onError("JSON decode failed")
        }
    }

    func getStreamStatus(onSuccess: @escaping (ObsStreamStatus) -> Void,
                         onError: @escaping (String) -> Void)
    {
        performRequest(type: .getStreamStatus, data: nil, onSuccess: { data in
            guard let data else {
                onError("No data received")
                return
            }
            do {
                let decoded = try JSONDecoder().decode(GetStreamStatusResponse.self, from: data)
                onSuccess(ObsStreamStatus(active: decoded.outputActive))
            } catch {
                onError("JSON decode failed")
            }
        }, onError: { message in
            onError(message)
        })
    }

    func getRecordStatus(onSuccess: @escaping (ObsRecordStatus) -> Void,
                         onError: @escaping (String) -> Void)
    {
        performRequest(type: .getRecordStatus, data: nil, onSuccess: { data in
            guard let data else {
                onError("No data received")
                return
            }
            do {
                let decoded = try JSONDecoder().decode(GetRecordStatusResponse.self, from: data)
                onSuccess(ObsRecordStatus(active: decoded.outputActive))
            } catch {
                onError("JSON decode failed")
            }
        }, onError: { message in
            onError(message)
        })
    }

    func startStream(onSuccess: @escaping () -> Void, onError: @escaping (String) -> Void) {
        performRequest(type: .startStream, data: nil, onSuccess: { _ in
            onSuccess()
        }, onError: { message in
            onError(message)
        })
    }

    func stopStream(onSuccess: @escaping () -> Void, onError: @escaping (String) -> Void) {
        performRequest(type: .stopStream, data: nil, onSuccess: { _ in
            onSuccess()
        }, onError: { message in
            onError(message)
        })
    }

    /*
     func startRecord(onSuccess: @escaping () -> Void, onError: @escaping () -> Void) {
         performRequest(type: .startRecord, data: nil, onSuccess: { _ in
             onSuccess()
         }, onError: {
             onError()
         })
     }

     func stopRecord(onSuccess: @escaping () -> Void, onError: @escaping () -> Void) {
         performRequest(type: .stopRecord, data: nil, onSuccess: { _ in
             onSuccess()
         }, onError: {
             onError()
         })
     }
     */
    private func performRequest(
        type: RequestType,
        data: Data?,
        onSuccess: @escaping (Data?) -> Void,
        onError: @escaping (String) -> Void
    ) {
        guard connected else {
            onError("Not connected to server")
            return
        }
        let requestId = getNextId()
        requests[requestId] = Request(onSuccess: onSuccess, onError: onError)
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
                logger.debug("obs-websocket: Got data \(message)")
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
                    logger.debug("obs-websocket: Ignoring message nil")
                default:
                    logger.debug("obs-websocket: Ignoring message \(op!)")
                }
            default:
                logger.debug("obs-websocket: ???")
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
        logger.debug("obs-websocket: \(identified)")
        connected = true
        onConnected()
    }

    private func handleEvent(data: Data) throws {
        let (type, _, data) = try unpackEvent(data: data)
        switch type {
        case .mediaInputPlaybackStarted:
            break
        case .mediaInputPlaybackEnded:
            break
        case .currentProgramSceneChanged:
            handleSceneChanged(data: data)
        case .streamStateChanged:
            handleStreamChanged(data: data)
        case .recordStateChanged:
            handleRecordChanged(data: data)
        case nil:
            break
        }
    }

    private func handleSceneChanged(data: Data?) {
        guard let data else {
            return
        }
        do {
            let decoded = try JSONDecoder().decode(SceneChangedEvent.self, from: data)
            onSceneChanged?(decoded.sceneName)
        } catch {}
    }

    private func handleStreamChanged(data: Data?) {
        guard let data else {
            return
        }
        do {
            let decoded = try JSONDecoder().decode(StreamStateChangedEvent.self, from: data)
            onStreamStatusChanged?(decoded.outputActive)
        } catch {}
    }

    private func handleRecordChanged(data: Data?) {
        guard let data else {
            return
        }
        do {
            let decoded = try JSONDecoder().decode(RecordStateChangedEvent.self, from: data)
            onRecordStatusChanged?(decoded.outputActive)
        } catch {}
    }

    private func handleRequestResponse(data: Data) throws {
        let (requestId, status, data) = try unpackRequestResponse(data: data)
        guard let request = requests[requestId] else {
            logger.debug("Unexpected request id in response")
            return
        }
        if status.result {
            request.onSuccess(data)
        } else {
            request.onError("Operation failed")
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
