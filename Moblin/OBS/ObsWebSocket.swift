import CryptoKit
import Foundation
import Network

let obsMinimumAudioDelay = -950
let obsMaximumAudioDelay = 20000

private enum EventSubscription: UInt64 {
    case general = 0x1
    case config = 0x2
    case scenes = 0x4
    case inputs = 0x8
    case transitions = 0x10
    case filters = 0x20
    case outputs = 0x40
    case sceneItems = 0x80
    case mediaInputs = 0x100
    case vendors = 0x200
    case ui = 0x400
    case inputVolumeMeters = 0x10000
    case inputActiveStateChanged = 0x20000
    case inputShowStateChanged = 0x40000
    case sceneItemTransformChanged = 0x80000

    static func all() -> UInt64 {
        return EventSubscription.general.rawValue | EventSubscription.config.rawValue | EventSubscription
            .scenes.rawValue | EventSubscription.inputs.rawValue | EventSubscription.transitions
            .rawValue | EventSubscription.filters.rawValue | EventSubscription.outputs
            .rawValue | EventSubscription.sceneItems.rawValue | EventSubscription.mediaInputs
            .rawValue | EventSubscription.vendors.rawValue | EventSubscription.ui.rawValue
    }
}

private func mulToDb(mul: Float) -> Float {
    return 20 * log10f(mul)
}

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
    let comment: String?
}

private enum RequestError {
    case message(String)
    case response(RequestStatus, String?)
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
    case getSourceScreenshot = "GetSourceScreenshot"
    case getVersion = "GetVersion"
    case setInputAudioSyncOffset = "SetInputAudioSyncOffset"
    case getInputAudioSyncOffset = "GetInputAudioSyncOffset"
    case setSceneItemEnabled = "SetSceneItemEnabled"
    case getSceneItemId = "GetSceneItemId"
    case setInputSettings = "SetInputSettings"
}

private enum EventType: String, Codable {
    case mediaInputPlaybackStarted = "MediaInputPlaybackStarted"
    case mediaInputPlaybackEnded = "MediaInputPlaybackEnded"
    case currentProgramSceneChanged = "CurrentProgramSceneChanged"
    case streamStateChanged = "StreamStateChanged"
    case recordStateChanged = "RecordStateChanged"
    case inputVolumeMeters = "InputVolumeMeters"
    case inputAudioSyncOffsetChanged = "InputAudioSyncOffsetChanged"
}

// periphery:ignore
private struct Identify: Codable {
    let rpcVersion: Int
    let authentication: String?
}

// periphery:ignore
private struct Identified: Codable {
    let negotiatedRpcVersion: Int
}

// periphery:ignore
private struct Reidentify: Codable {
    let eventSubscriptions: UInt64
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

// periphery:ignore
struct SetCurrentProgramSceneRequest: Codable {
    let sceneName: String
}

struct GetStreamStatusResponse: Codable {
    let outputActive: Bool
}

struct GetRecordStatusResponse: Codable {
    let outputActive: Bool
}

// periphery:ignore
struct GetSourceScreenshot: Codable {
    let sourceName: String
    let imageFormat: String
    let imageWidth: Int
    let imageCompressionQuality: Int
}

struct GetSourceScreenshotResponse: Codable {
    let imageData: String
}

// periphery:ignore
struct SetInputAudioSyncOffset: Codable {
    let inputName: String
    let inputAudioSyncOffset: Int
}

// periphery:ignore
struct GetInputAudioSyncOffset: Codable {
    let inputName: String
}

struct GetInputAudioSyncOffsetResponse: Codable {
    let inputAudioSyncOffset: Int
}

// periphery:ignore
struct SetSceneItemEnabled: Codable {
    let sceneName: String
    let sceneItemId: Int
    let sceneItemEnabled: Bool
}

// periphery:ignore
struct GetSceneItemId: Codable {
    let sceneName: String
    let sourceName: String
}

struct InputSettings: Codable {}

// periphery:ignore
struct SetInputSettings: Codable {
    let inputName: String
    let inputSettings: InputSettings
}

struct SceneChangedEvent: Decodable {
    let sceneName: String
}

enum ObsOutputState: String {
    case starting = "OBS_WEBSOCKET_OUTPUT_STARTING"
    case started = "OBS_WEBSOCKET_OUTPUT_STARTED"
    case stopping = "OBS_WEBSOCKET_OUTPUT_STOPPING"
    case stopped = "OBS_WEBSOCKET_OUTPUT_STOPPED"
}

struct StreamStateChangedEvent: Decodable {
    let outputActive: Bool
    let outputState: String
}

struct RecordStateChangedEvent: Decodable {
    let outputActive: Bool
    let outputState: String
}

struct InputVolumeMeter: Decodable {
    let inputName: String
    let inputLevelsMul: [[Float]]
}

struct InputVolumeMeters: Decodable {
    let inputs: [InputVolumeMeter]
}

struct ObsAudioInputVolume: Identifiable {
    let id: UUID = .init()
    let name: String
    var volumes: [Float] = []
}

private let rpcVersion = 1

private func packMessage(op: OpCode, data: Data) -> String {
    let data = String.fromUtf8(data: data)
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

private struct Request {
    let onSuccess: (Data?) -> Void
    let onError: (RequestError) -> Void
}

struct ObsSceneList {
    let current: String
    let scenes: [String]
}

struct ObsStreamStatus {
    let active: Bool
    let state: ObsOutputState? = nil
}

struct ObsRecordStatus {
    let active: Bool
}

protocol ObsWebsocketDelegate: AnyObject {
    func obsWebsocketConnected()
    func obsWebsocketSceneChanged(sceneName: String)
    func obsWebsocketStreamStatusChanged(active: Bool, state: ObsOutputState?)
    func obsWebsocketRecordStatusChanged(active: Bool, state: ObsOutputState?)
    func obsWebsocketAudioVolume(volumes: [ObsAudioInputVolume])
}

class ObsWebSocket {
    private let url: URL
    private let password: String
    private var webSocket: WebSocketClient
    private var nextId: Int = 0
    private var requests: [String: Request] = [:]
    var connectionErrorMessage: String = ""
    private var connected = false
    weak var delegate: (any ObsWebsocketDelegate)?

    init(url: URL, password: String, delegate: ObsWebsocketDelegate) {
        self.url = url
        self.password = password
        self.delegate = delegate
        webSocket = .init(url: url)
    }

    func start() {
        logger.debug("obs-websocket: start")
        startInternal()
    }

    func stop() {
        logger.debug("obs-websocket: stop")
        stopInternal()
    }

    private func startInternal() {
        stopInternal()
        webSocket = .init(url: url)
        webSocket.delegate = self
        webSocket.start()
    }

    func stopInternal() {
        webSocket.stop()
        connected = false
    }

    func isConnected() -> Bool {
        return connected
    }

    func getSceneList(onSuccess: @escaping (ObsSceneList) -> Void, onError: @escaping (String) -> Void) {
        performRequest(type: .getSceneList, data: nil, onSuccess: { response in
            guard let response else {
                onError("No data received")
                return
            }
            do {
                let response = try JSONDecoder().decode(GetSceneListResponse.self, from: response)
                onSuccess(ObsSceneList(
                    current: response.currentProgramSceneName,
                    scenes: response.scenes.reversed().map { $0.sceneName }
                ))
            } catch {
                onError("JSON decode failed")
            }
        }, onError: { requestError in
            self.onRequestError(requestError: requestError, onError: onError)
        })
    }

    private func onRequestError(
        requestError: RequestError,
        onError: @escaping (String) -> Void,
        onObsResponseError: ((RequestStatus, String?) -> Bool)? = nil
    ) {
        switch requestError {
        case let .message(message):
            onError(message)
        case let .response(code, comment):
            if let onObsResponseError, onObsResponseError(code, comment) {
                return
            }
            var message = ""
            if let comment {
                message = " (\(comment))"
            }
            onError("Operation failed with \(code)\(message)")
        }
    }

    func setCurrentProgramScene(name: String, onSuccess: @escaping () -> Void,
                                onError: @escaping (String) -> Void)
    {
        let request = SetCurrentProgramSceneRequest(sceneName: name)
        do {
            let request = try JSONEncoder().encode(request)
            performRequest(type: .setCurrentProgramScene, data: request, onSuccess: { _ in
                onSuccess()
            }, onError: { requestError in
                self.onRequestError(requestError: requestError, onError: onError)
            })
        } catch {
            onError("JSON decode failed")
        }
    }

    func getStreamStatus(onSuccess: @escaping (ObsStreamStatus) -> Void,
                         onError: @escaping (String) -> Void)
    {
        performRequest(type: .getStreamStatus, data: nil, onSuccess: { response in
            guard let response else {
                onError("No data received")
                return
            }
            do {
                let response = try JSONDecoder().decode(GetStreamStatusResponse.self, from: response)
                onSuccess(ObsStreamStatus(active: response.outputActive))
            } catch {
                onError("JSON decode failed")
            }
        }, onError: { requestError in
            self.onRequestError(requestError: requestError, onError: onError)
        })
    }

    func getRecordStatus(onSuccess: @escaping (ObsRecordStatus) -> Void,
                         onError: @escaping (String) -> Void)
    {
        performRequest(type: .getRecordStatus, data: nil, onSuccess: { response in
            guard let response else {
                onError("No data received")
                return
            }
            do {
                let response = try JSONDecoder().decode(GetRecordStatusResponse.self, from: response)
                onSuccess(ObsRecordStatus(active: response.outputActive))
            } catch {
                onError("JSON decode failed")
            }
        }, onError: { requestError in
            self.onRequestError(requestError: requestError, onError: onError)
        })
    }

    func startStream(onSuccess: @escaping () -> Void, onError: @escaping (String) -> Void) {
        performRequest(type: .startStream, data: nil, onSuccess: { _ in
            onSuccess()
        }, onError: { requestError in
            self.onRequestError(requestError: requestError, onError: onError) { code, _ in
                switch code {
                case .outputRunning:
                    onError("Already streaming")
                default:
                    return false
                }
                return true
            }
        })
    }

    func stopStream(onSuccess: @escaping () -> Void, onError: @escaping (String) -> Void) {
        performRequest(type: .stopStream, data: nil, onSuccess: { _ in
            onSuccess()
        }, onError: { requestError in
            self.onRequestError(requestError: requestError, onError: onError) { code, _ in
                switch code {
                case .outputNotRunning:
                    onError("Not streaming")
                default:
                    return false
                }
                return true
            }
        })
    }

    func startRecord(onSuccess: @escaping () -> Void, onError: @escaping (String) -> Void) {
        performRequest(type: .startRecord, data: nil, onSuccess: { _ in
            onSuccess()
        }, onError: { requestError in
            self.onRequestError(requestError: requestError, onError: onError) { code, _ in
                switch code {
                case .outputRunning:
                    onError("Already recording")
                default:
                    return false
                }
                return true
            }
        })
    }

    func stopRecord(onSuccess: @escaping () -> Void, onError: @escaping (String) -> Void) {
        performRequest(type: .stopRecord, data: nil, onSuccess: { _ in
            onSuccess()
        }, onError: { requestError in
            self.onRequestError(requestError: requestError, onError: onError) { code, _ in
                switch code {
                case .outputNotRunning:
                    onError("Not recording")
                default:
                    return false
                }
                return true
            }
        })
    }

    func startAudioVolume() {
        sendReidentify(eventSubscriptions: EventSubscription.all() | EventSubscription.inputVolumeMeters
            .rawValue)
    }

    func stopAudioVolume() {
        sendReidentify(eventSubscriptions: EventSubscription.all())
    }

    func getSourceScreenshot(
        name: String,
        onSuccess: @escaping (Data) -> Void,
        onError: @escaping (String) -> Void
    ) {
        var request: Data
        do {
            request = try JSONEncoder().encode(GetSourceScreenshot(
                sourceName: name,
                imageFormat: "jpg",
                imageWidth: 640,
                imageCompressionQuality: 30
            ))
        } catch {
            onError("JSON encode failed")
            return
        }
        performRequest(type: .getSourceScreenshot, data: request, onSuccess: { response in
            guard let response else {
                onError("No image data")
                return
            }
            do {
                let response = try JSONDecoder().decode(GetSourceScreenshotResponse.self, from: response)
                let imageData = response.imageData
                let index = imageData.index(imageData.startIndex, offsetBy: 22)
                if let image = Data(base64Encoded: String(imageData[index...])) {
                    onSuccess(image)
                } else {
                    onError("Base64 decode failed")
                }
            } catch {
                onError("JSON decode failed")
            }
        }, onError: { requestError in
            self.onRequestError(requestError: requestError, onError: onError)
        })
    }

    func setInputAudioSyncOffset(
        name: String,
        offsetInMs: Int,
        onSuccess: @escaping () -> Void,
        onError: @escaping (String) -> Void
    ) {
        var request: Data
        do {
            request = try JSONEncoder().encode(SetInputAudioSyncOffset(
                inputName: name,
                inputAudioSyncOffset: offsetInMs
            ))
        } catch {
            onError("JSON encode failed")
            return
        }
        performRequest(type: .setInputAudioSyncOffset, data: request, onSuccess: { _ in
            onSuccess()
        }, onError: { requestError in
            self.onRequestError(requestError: requestError, onError: onError)
        })
    }

    func getInputAudioSyncOffset(
        name: String,
        onSuccess: @escaping (Int) -> Void,
        onError: @escaping (String) -> Void
    ) {
        var request: Data
        do {
            request = try JSONEncoder().encode(GetInputAudioSyncOffset(inputName: name))
        } catch {
            onError("JSON encode failed")
            return
        }
        performRequest(type: .getInputAudioSyncOffset, data: request, onSuccess: { response in
            guard let response else {
                onError("No data")
                return
            }
            do {
                let response = try JSONDecoder().decode(GetInputAudioSyncOffsetResponse.self, from: response)
                onSuccess(response.inputAudioSyncOffset)
            } catch {
                onError("JSON decode failed")
            }
        }, onError: { requestError in
            self.onRequestError(requestError: requestError, onError: onError)
        })
    }

    func setInputSettings(inputName: String,
                          onSuccess: @escaping () -> Void,
                          onError: @escaping (String) -> Void)
    {
        var request: Data
        do {
            request = try JSONEncoder().encode(SetInputSettings(inputName: inputName, inputSettings: .init()))
        } catch {
            onError("JSON encode failed")
            return
        }
        performRequest(type: .setInputSettings, data: request, onSuccess: { _ in
            onSuccess()
        }, onError: { requestError in
            self.onRequestError(requestError: requestError, onError: onError)
        })
    }

    private func performRequest(
        type: RequestType,
        data: Data?,
        onSuccess: @escaping (Data?) -> Void,
        onError: @escaping (RequestError) -> Void
    ) {
        guard isConnected() else {
            onError(.message("Not connected to server"))
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
        webSocket.send(string: message)
    }

    private func handleMessage(message: String) throws {
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
        delegate?.obsWebsocketConnected()
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
        case .inputVolumeMeters:
            handleInputVolumeMeters(data: data)
        case .inputAudioSyncOffsetChanged:
            handleInputAudioSyncOffsetChanged(data: data)
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
            delegate?.obsWebsocketSceneChanged(sceneName: decoded.sceneName)
        } catch {}
    }

    private func handleStreamChanged(data: Data?) {
        guard let data else {
            return
        }
        do {
            let event = try JSONDecoder().decode(StreamStateChangedEvent.self, from: data)
            if let state = ObsOutputState(rawValue: event.outputState) {
                delegate?.obsWebsocketStreamStatusChanged(active: event.outputActive, state: state)
            } else {
                delegate?.obsWebsocketStreamStatusChanged(active: event.outputActive, state: .stopped)
            }
        } catch {}
    }

    private func handleRecordChanged(data: Data?) {
        guard let data else {
            return
        }
        do {
            let event = try JSONDecoder().decode(RecordStateChangedEvent.self, from: data)
            if let state = ObsOutputState(rawValue: event.outputState) {
                delegate?.obsWebsocketRecordStatusChanged(active: event.outputActive, state: state)
            } else {
                delegate?.obsWebsocketRecordStatusChanged(active: event.outputActive, state: .started)
            }
        } catch {}
    }

    private func handleInputVolumeMeters(data: Data?) {
        guard let data else {
            return
        }
        do {
            let decoded = try JSONDecoder().decode(InputVolumeMeters.self, from: data)
            var volumes: [ObsAudioInputVolume] = []
            for input in decoded.inputs {
                var audioInput = ObsAudioInputVolume(name: input.inputName)
                for channel in input.inputLevelsMul where channel.count > 0 {
                    audioInput.volumes.append(mulToDb(mul: channel[0]))
                }
                volumes.append(audioInput)
            }
            delegate?.obsWebsocketAudioVolume(volumes: volumes)
        } catch {}
    }

    private func handleInputAudioSyncOffsetChanged(data _: Data?) {}

    private func handleRequestResponse(data: Data) throws {
        let (requestId, status, data) = try unpackRequestResponse(data: data)
        guard let request = requests[requestId] else {
            logger.debug("Unexpected request id in response")
            return
        }
        if status.result {
            request.onSuccess(data)
        } else {
            let code = RequestStatus(rawValue: status.code) ?? .unknown
            request.onError(.response(code, status.comment))
        }
    }

    private func sendIdentify(authentication: String?) {
        let identify = Identify(rpcVersion: rpcVersion, authentication: authentication)
        do {
            let identify = try JSONEncoder().encode(identify)
            let message = packMessage(op: .identify, data: identify)
            webSocket.send(string: message)
        } catch {}
    }

    private func sendReidentify(eventSubscriptions: UInt64) {
        let reidentify = Reidentify(eventSubscriptions: eventSubscriptions)
        do {
            let reidentify = try JSONEncoder().encode(reidentify)
            let message = packMessage(op: .reidentify, data: reidentify)
            webSocket.send(string: message)
        } catch {}
    }

    private func getNextId() -> String {
        nextId += 1
        return String(nextId)
    }
}

extension ObsWebSocket: WebSocketClientDelegate {
    func webSocketClientConnected() {}

    func webSocketClientDisconnected() {
        connected = false
        connectionErrorMessage = String(localized: "Disconnected")
    }

    func webSocketClientReceiveMessage(string: String) {
        try? handleMessage(message: string)
    }
}
