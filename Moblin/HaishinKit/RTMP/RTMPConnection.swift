import AVFoundation
import Foundation

class RTMPResponder {
    typealias Handler = (_ data: [Any?]) -> Void
    private var result: Handler

    init(result: @escaping Handler) {
        self.result = result
    }

    final func on(result: [Any?]) {
        self.result(result)
    }
}

class RTMPConnection: EventDispatcher {
    private static let defaultWindowSizeFromServer: Int64 = 250_000
    private static let supportedProtocols = ["rtmp", "rtmps", "rtmpt", "rtmpts"]
    private static let defaultFlashVer = "FMLE/3.0 (compatible; FMSc/1.0)"
    private static let defaultMaximumChunkSizeToServer = 1024 * 8
    private static let defaultCapabilities = 239

    enum Code: String {
        case connectClosed = "NetConnection.Connect.Closed"
        case connectFailed = "NetConnection.Connect.Failed"
        case connectRejected = "NetConnection.Connect.Rejected"
        case connectSuccess = "NetConnection.Connect.Success"

        var level: String {
            switch self {
            case .connectClosed:
                return "status"
            case .connectFailed:
                return "error"
            case .connectRejected:
                return "error"
            case .connectSuccess:
                return "status"
            }
        }

        func data(_ description: String) -> ASObject {
            [
                "code": rawValue,
                "level": level,
                "description": description,
            ]
        }
    }

    enum SupportVideo: UInt16 {
        case h264 = 0x0080
    }

    enum SupportSound: UInt16 {
        case aac = 0x0400
    }

    enum VideoFunction: UInt8 {
        case clientSeek = 1
    }

    private static func makeSanJoseAuthCommand(_ url: URL, description: String) -> String {
        var command: String = url.absoluteString
        guard let index = description.firstIndex(of: "?") else {
            return command
        }
        let query = String(description[description.index(index, offsetBy: 1)...])
        let challenge = String(format: "%08x", UInt32.random(in: 0 ... UInt32.max))
        let dictionary = URL(string: "http://localhost?" + query)!.dictionaryFromQuery()
        var response = MD5.base64("\(url.user!)\(dictionary["salt"]!)\(url.password!)")
        if let opaque = dictionary["opaque"] {
            command += "&opaque=\(opaque)"
            response += opaque
        } else if let challenge: String = dictionary["challenge"] {
            response += challenge
        }
        response = MD5.base64("\(response)\(challenge)")
        command += "&challenge=\(challenge)&response=\(response)"
        return command
    }

    var flashVer = RTMPConnection.defaultFlashVer
    private(set) var uri: URL?
    private(set) var connected = false
    var socket: RTMPSocket!
    var streams: [RTMPStream] = []
    private var chunkStreamIdToStreamId: [UInt16: UInt32] = [:]
    var operations: [Int: RTMPResponder] = [:]
    var windowSizeFromServer = RTMPConnection.defaultWindowSizeFromServer {
        didSet {
            guard socket.connected else {
                return
            }
            _ = socket.write(chunk: RTMPChunk(
                type: .zero,
                chunkStreamId: RTMPChunk.ChunkStreamId.control.rawValue,
                message: RTMPWindowAcknowledgementSizeMessage(100_000)
            ))
        }
    }

    var currentTransactionId = 0
    private var timer = SimpleTimer(queue: netStreamLockQueue)
    private var messages: [UInt16: RTMPMessage] = [:]
    private var arguments: [Any?] = []
    private var currentChunk: RTMPChunk?
    private var fragmentedChunks: [UInt16: RTMPChunk] = [:]

    override init() {
        super.init()
        addEventListener(.rtmpStatus, selector: #selector(on(status:)))
    }

    deinit {
        timer.stop()
        streams.removeAll()
        removeEventListener(.rtmpStatus, selector: #selector(on(status:)))
    }

    func call(_ commandName: String, responder: RTMPResponder?, arguments: Any?...) {
        guard connected else {
            return
        }
        currentTransactionId += 1
        let message = RTMPCommandMessage(
            streamId: 0,
            transactionId: currentTransactionId,
            objectEncoding: .amf0,
            commandName: commandName,
            commandObject: nil,
            arguments: arguments
        )
        if responder != nil {
            operations[message.transactionId] = responder
        }
        _ = socket.write(chunk: RTMPChunk(message: message))
    }

    func connect(_ url: String, arguments: Any?...) {
        guard let uri = URL(string: url),
              let scheme = uri.scheme,
              let host = uri.host,
              !connected && Self.supportedProtocols.contains(scheme)
        else {
            return
        }
        self.uri = uri
        self.arguments = arguments
        socket = socket != nil ? socket : RTMPSocket()
        socket.delegate = self
        let secure = uri.scheme == "rtmps" || uri.scheme == "rtmpts"
        socket.secure = secure
        socket.connect(host: host, port: uri.port ?? (secure ? 443 : 1935))
    }

    func close() {
        close(isDisconnected: false)
    }

    func close(isDisconnected: Bool) {
        timer.stop()
        guard connected || isDisconnected else {
            return
        }
        if !isDisconnected {
            uri = nil
        }
        for stream in streams {
            stream.close()
        }
        // Just to let stream send unpublish and delete stream commands. It's a mess...
        netStreamLockQueue.async {
            self.socket?.close(isDisconnected: false)
        }
    }

    func createStream(_ stream: RTMPStream) {
        let responder = RTMPResponder(result: { data in
            guard let id = data[0] as? Double else {
                return
            }
            stream.id = UInt32(id)
            stream.setReadyState(state: .open)
        })
        call("createStream", responder: responder)
    }

    @objc
    private func on(status: Notification) {
        let e = Event.from(status)
        guard let data = e.data as? ASObject, let code = data["code"] as? String else {
            return
        }
        switch Code(rawValue: code) {
        case .some(.connectSuccess):
            connected = true
            socket.maximumChunkSizeToServer = RTMPConnection.defaultMaximumChunkSizeToServer
            _ = socket.write(chunk: RTMPChunk(
                type: .zero,
                chunkStreamId: RTMPChunk.ChunkStreamId.control.rawValue,
                message: RTMPSetChunkSizeMessage(UInt32(socket.maximumChunkSizeToServer))
            ))
        case .some(.connectRejected):
            guard
                let uri,
                let user = uri.user,
                let password = uri.password,
                let description = data["description"] as? String
            else {
                break
            }
            socket.close(isDisconnected: false)
            switch true {
            case description.contains("reason=nosuchuser"):
                break
            case description.contains("reason=authfailed"):
                break
            case description.contains("reason=needauth"):
                let command = Self.makeSanJoseAuthCommand(uri, description: description)
                connect(command, arguments: arguments)
            case description.contains("authmod=adobe"):
                if user.isEmpty || password.isEmpty {
                    close(isDisconnected: true)
                    break
                }
                let query = uri.query ?? ""
                let command = uri.absoluteString + (query.isEmpty ? "?" : "&") + "authmod=adobe&user=\(user)"
                connect(command, arguments: arguments)
            default:
                break
            }
        case .some(.connectClosed):
            if let description = data["description"] as? String {
                logger.info(description)
            }
            close(isDisconnected: true)
        default:
            break
        }
    }

    private func makeConnectChunk() -> RTMPChunk? {
        guard let uri else {
            return nil
        }
        var app = uri.path.isEmpty ? "" : String(uri.path[uri.path.index(uri.path.startIndex, offsetBy: 1)...])
        if let query = uri.query {
            app += "?" + query
        }
        currentTransactionId += 1
        let message = RTMPCommandMessage(
            streamId: 0,
            transactionId: currentTransactionId,
            // "connect" must be a objectEncoding = 0
            objectEncoding: .amf0,
            commandName: "connect",
            commandObject: [
                "app": app,
                "flashVer": flashVer,
                "swfUrl": nil,
                "tcUrl": uri.absoluteWithoutAuthenticationString,
                "fpad": false,
                "capabilities": Self.defaultCapabilities,
                "audioCodecs": SupportSound.aac.rawValue,
                "videoCodecs": SupportVideo.h264.rawValue,
                "videoFunction": VideoFunction.clientSeek.rawValue,
                "pageUrl": nil,
                "objectEncoding": RTMPObjectEncoding.amf0.rawValue,
            ],
            arguments: arguments
        )
        return RTMPChunk(message: message)
    }

    private func handleHandshakeDone() {
        guard let chunk = makeConnectChunk() else {
            close()
            return
        }
        _ = socket.write(chunk: chunk)
        timer.startPeriodic(interval: 1.0, handler: { [weak self] in
            guard let self else {
                return
            }
            for stream in self.streams {
                stream.onTimeout()
            }
        })
    }

    private func handleClosed() {
        connected = false
        currentChunk = nil
        currentTransactionId = 0
        messages.removeAll()
        operations.removeAll()
        fragmentedChunks.removeAll()
    }
}

extension RTMPConnection: RTMPSocketDelegate {
    func socketReadyStateChanged(_: RTMPSocket, readyState: RTMPSocketReadyState) {
        switch readyState {
        case .handshakeDone:
            handleHandshakeDone()
        case .closed:
            handleClosed()
        default:
            break
        }
    }

    func socketUpdateStats(_: RTMPSocket, totalBytesOut: Int64) {
        guard let stream = streams.first else {
            return
        }
        stream.info.onWritten(sequence: totalBytesOut)
    }

    func socketDataReceived(_ socket: RTMPSocket, data: Data) {
        guard let chunk = currentChunk ?? RTMPChunk(data, size: socket.maximumChunkSizeFromServer) else {
            socket.inputBuffer.append(data)
            return
        }
        let chunkData = chunk.encode()
        var position = chunkData.count
        if (chunkData.count >= 4) && (chunkData[1] == 0xFF) && (chunkData[2] == 0xFF) && (chunkData[3] == 0xFF) {
            position += 4
        }
        if currentChunk != nil {
            position = chunk.append(data, size: socket.maximumChunkSizeFromServer)
        }
        if chunk.type == .two {
            position = chunk.append(data, message: messages[chunk.chunkStreamId])
        }
        if chunk.type == .three && fragmentedChunks[chunk.chunkStreamId] == nil {
            position = chunk.append(data, message: messages[chunk.chunkStreamId])
        }
        if let message = chunk.message, chunk.ready() {
            switch chunk.type {
            case .zero:
                chunkStreamIdToStreamId[chunk.chunkStreamId] = message.streamId
            case .one:
                if let streamId = chunkStreamIdToStreamId[chunk.chunkStreamId] {
                    message.streamId = streamId
                }
            case .two:
                break
            case .three:
                break
            }
            message.execute(self, type: chunk.type)
            currentChunk = nil
            messages[chunk.chunkStreamId] = message
            if position > 0 && position < data.count {
                socketDataReceived(socket, data: data.advanced(by: position))
            }
            return
        }
        if chunk.fragmented {
            fragmentedChunks[chunk.chunkStreamId] = chunk
            currentChunk = nil
        } else {
            currentChunk = chunk.type == .three ? fragmentedChunks[chunk.chunkStreamId] : chunk
            fragmentedChunks.removeValue(forKey: chunk.chunkStreamId)
        }
        if position > 0 && position < data.count {
            socketDataReceived(socket, data: data.advanced(by: position))
        }
    }

    func socketDispatch(_: RTMPSocket, event: Event) {
        dispatch(event: event)
    }
}
