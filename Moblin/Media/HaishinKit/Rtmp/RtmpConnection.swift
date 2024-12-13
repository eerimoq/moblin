import AVFoundation
import Foundation

private let supportedProtocols = ["rtmp", "rtmps", "rtmpt", "rtmpts"]

private enum SupportVideo: UInt16 {
    case h264 = 0x0080
}

private enum SupportSound: UInt16 {
    case aac = 0x0400
}

private enum VideoFunction: UInt8 {
    case clientSeek = 1
}

enum RtmpConnectionCode: String {
    case connectClosed = "NetConnection.Connect.Closed"
    case connectFailed = "NetConnection.Connect.Failed"
    case connectRejected = "NetConnection.Connect.Rejected"
    case connectSuccess = "NetConnection.Connect.Success"

    func eventData() -> AsObject {
        return [
            "code": rawValue,
        ]
    }
}

class RtmpConnection: RtmpEventDispatcher {
    private(set) var uri: URL?
    private(set) var connected = false
    var socket: RtmpSocket!
    var streams: [RtmpStream] = []
    private var chunkStreamIdToStreamId: [UInt16: UInt32] = [:]
    var callCompletions: [Int: ([Any?]) -> Void] = [:]
    var windowSizeFromServer: Int64 = 250_000 {
        didSet {
            guard socket.connected else {
                return
            }
            _ = socket.write(chunk: RtmpChunk(
                type: .zero,
                chunkStreamId: RtmpChunk.ChunkStreamId.control.rawValue,
                message: RtmpWindowAcknowledgementSizeMessage(100_000)
            ))
        }
    }

    private var nextTransactionId = 0
    private var timer = SimpleTimer(queue: netStreamLockQueue)
    private var messages: [UInt16: RtmpMessage] = [:]
    private var currentChunk: RtmpChunk?
    private var fragmentedChunks: [UInt16: RtmpChunk] = [:]

    override init() {
        super.init()
        addEventListener(.rtmpStatus, selector: #selector(on(status:)))
    }

    deinit {
        timer.stop()
        streams.removeAll()
        removeEventListener(.rtmpStatus, selector: #selector(on(status:)))
    }

    func connect(_ url: String) {
        netStreamLockQueue.async {
            self.connectInternal(url)
        }
    }

    func disconnect() {
        netStreamLockQueue.async {
            self.disconnectInternal()
        }
    }

    private static func makeSanJoseAuthCommand(_ url: URL, description: String) -> String {
        var command = url.absoluteString
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

    func call(_ commandName: String, arguments: [Any?], onCompleted: (([Any?]) -> Void)? = nil) {
        guard connected else {
            return
        }
        let message = RtmpCommandMessage(
            streamId: 0,
            transactionId: getNextTransactionId(),
            objectEncoding: .amf0,
            commandName: commandName,
            commandObject: nil,
            arguments: arguments
        )
        if let onCompleted {
            callCompletions[message.transactionId] = onCompleted
        }
        _ = socket.write(chunk: RtmpChunk(message: message))
    }

    func connectInternal(_ url: String) {
        guard let uri = URL(string: url),
              let scheme = uri.scheme,
              let host = uri.host,
              !connected && supportedProtocols.contains(scheme)
        else {
            return
        }
        self.uri = uri
        socket = socket ?? RtmpSocket()
        socket.delegate = self
        socket.secure = scheme.hasSuffix("s")
        socket.connect(host: host, port: uri.port ?? (socket.secure ? 443 : 1935))
    }

    func disconnectInternal() {
        timer.stop()
        for stream in streams {
            stream.closeInternal()
        }
        socket?.close()
    }

    func createStream(_ stream: RtmpStream) {
        call("createStream", arguments: []) { data in
            guard let id = data[0] as? Double else {
                return
            }
            stream.id = UInt32(id)
            stream.setReadyState(state: .open)
        }
    }

    func getNextTransactionId() -> Int {
        nextTransactionId += 1
        return nextTransactionId
    }

    @objc
    private func on(status: Notification) {
        guard let event = RtmpEvent.from(status) else {
            return
        }
        netStreamLockQueue.async {
            self.onInternal(event: event)
        }
    }

    private func onInternal(event: RtmpEvent) {
        guard let data = event.data as? AsObject, let code = data["code"] as? String else {
            return
        }
        switch RtmpConnectionCode(rawValue: code) {
        case .connectSuccess:
            handleConnectSuccess()
        case .connectRejected:
            handleConnectRejected(data: data)
        case .connectClosed:
            handleConnectClosed()
        default:
            break
        }
    }

    private func handleConnectSuccess() {
        connected = true
        socket.maximumChunkSizeToServer = 1024 * 8
        _ = socket.write(chunk: RtmpChunk(
            type: .zero,
            chunkStreamId: RtmpChunk.ChunkStreamId.control.rawValue,
            message: RtmpSetChunkSizeMessage(UInt32(socket.maximumChunkSizeToServer))
        ))
    }

    private func handleConnectRejected(data: AsObject) {
        guard
            let uri,
            let user = uri.user,
            let password = uri.password,
            let description = data["description"] as? String
        else {
            return
        }
        socket.close()
        switch true {
        case description.contains("reason=nosuchuser"):
            break
        case description.contains("reason=authfailed"):
            break
        case description.contains("reason=needauth"):
            let command = Self.makeSanJoseAuthCommand(uri, description: description)
            connect(command)
        case description.contains("authmod=adobe"):
            if user.isEmpty || password.isEmpty {
                disconnectInternal()
                break
            }
            let query = uri.query ?? ""
            let command = uri.absoluteString + (query.isEmpty ? "?" : "&") + "authmod=adobe&user=\(user)"
            connect(command)
        default:
            break
        }
    }

    private func handleConnectClosed() {
        disconnectInternal()
    }

    private func makeConnectChunk() -> RtmpChunk? {
        guard let uri else {
            return nil
        }
        var app = uri.path.isEmpty ? "" : String(uri.path[uri.path.index(uri.path.startIndex, offsetBy: 1)...])
        if let query = uri.query {
            app += "?" + query
        }
        let message = RtmpCommandMessage(
            streamId: 0,
            transactionId: getNextTransactionId(),
            objectEncoding: .amf0,
            commandName: "connect",
            commandObject: [
                "app": app,
                "flashVer": "FMLE/3.0 (compatible; FMSc/1.0)",
                "swfUrl": nil,
                "tcUrl": uri.absoluteWithoutAuthenticationString,
                "fpad": false,
                "capabilities": 239,
                "audioCodecs": SupportSound.aac.rawValue,
                "videoCodecs": SupportVideo.h264.rawValue,
                "videoFunction": VideoFunction.clientSeek.rawValue,
                "pageUrl": nil,
                "objectEncoding": RtmpObjectEncoding.amf0.rawValue,
            ],
            arguments: []
        )
        return RtmpChunk(message: message)
    }

    private func handleHandshakeDone() {
        guard let chunk = makeConnectChunk() else {
            disconnectInternal()
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
        nextTransactionId = 0
        messages.removeAll()
        callCompletions.removeAll()
        fragmentedChunks.removeAll()
    }
}

extension RtmpConnection: RtmpSocketDelegate {
    func socketReadyStateChanged(_: RtmpSocket, readyState: RtmpSocketReadyState) {
        switch readyState {
        case .handshakeDone:
            handleHandshakeDone()
        case .closed:
            handleClosed()
        default:
            break
        }
    }

    func socketUpdateStats(_: RtmpSocket, totalBytesOut: Int64) {
        guard let stream = streams.first else {
            return
        }
        stream.info.onWritten(sequence: totalBytesOut)
    }

    func socketDataReceived(_ socket: RtmpSocket, data: Data) {
        guard let chunk = currentChunk ?? RtmpChunk(data, size: socket.maximumChunkSizeFromServer) else {
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
            default:
                break
            }
            message.execute(self)
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

    func socketDispatch(_: RtmpSocket, event: RtmpEvent) {
        dispatch(event: event)
    }
}
