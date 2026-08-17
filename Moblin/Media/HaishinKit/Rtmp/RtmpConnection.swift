import AVFoundation

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
        [
            "code": .string(rawValue),
        ]
    }
}

private func makeSanJoseAuthCommand(_ url: URL, description: String) -> String {
    var command = url.absoluteString
    guard let index = description.firstIndex(of: "?") else {
        return command
    }
    let query = String(description[description.index(index, offsetBy: 1)...])
    let challenge = String(format: "%08x", UInt32.random(in: 0 ... UInt32.max))
    let dictionary = URL(string: "http://localhost?" + query)!.dictionaryFromQuery()
    var response = calculateMd5Base64("\(url.user!)\(dictionary["salt"]!)\(url.password!)")
    if let opaque = dictionary["opaque"] {
        command += "&opaque=\(opaque)"
        response += opaque
    } else if let challenge: String = dictionary["challenge"] {
        response += challenge
    }
    response = calculateMd5Base64("\(response)\(challenge)")
    command += "&challenge=\(challenge)&response=\(response)"
    return command
}

class RtmpConnection: @unchecked Sendable {
    private var uri: URL?
    private(set) var socket: RtmpSocket
    weak var stream: RtmpStream?
    var callCompletions: [Int: ([AsValue]) -> Void] = [:]
    private var nextTransactionId = 0
    private var timer = SimpleTimer(queue: processorControlQueue)
    private let chunkReader = RtmpChunkReader()
    private let name: String
    private let queue: DispatchQueue

    init(name: String, queue: DispatchQueue) {
        self.name = name
        self.queue = queue
        socket = RtmpSocket(name: name, queue: queue)
    }

    func connect(_ url: String) {
        guard let uri = URL(string: url), let scheme = uri.scheme, let host = uri.host else {
            return
        }
        self.uri = uri
        chunkReader.clear()
        socket = RtmpSocket(name: name, queue: queue)
        socket.delegate = self
        if scheme == "rtmps" {
            socket.connect(host: host, port: uri.port ?? 443, tlsOptions: .init())
        } else {
            socket.connect(host: host, port: uri.port ?? 1935, tlsOptions: nil)
        }
    }

    func disconnect() {
        timer.stop()
        stream?.closeInternal()
        socket.close(isDisconnected: false)
        socket = RtmpSocket(name: name, queue: queue)
    }

    func call(
        _ commandName: RtmpCommandName,
        arguments: [AsValue],
        onCompleted: (([AsValue]) -> Void)? = nil
    ) {
        let message = RtmpCommandMessage(
            streamId: 0,
            transactionId: getNextTransactionId(),
            commandType: .amf0Command,
            commandName: commandName,
            commandObject: nil,
            arguments: arguments
        )
        if let onCompleted {
            callCompletions[message.transactionId] = onCompleted
        }
        _ = socket.write(chunk: RtmpChunk(message: message))
    }

    func gotCommand(data: AsObject) {
        on(data: data)
    }

    func getNextTransactionId() -> Int {
        nextTransactionId += 1
        return nextTransactionId
    }

    private func on(data: AsObject) {
        queue.async {
            self.onInternal(data: data)
            self.stream?.onInternal(data: data)
        }
    }

    private func onInternal(data: AsObject) {
        guard case let .string(code) = data["code"] else {
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
            case let .string(description) = data["description"]
        else {
            return
        }
        socket.close(isDisconnected: false)
        if description.contains("reason=nosuchuser") {
        } else if description.contains("reason=authfailed") {
        } else if description.contains("reason=needauth") {
            connect(makeSanJoseAuthCommand(uri, description: description))
        } else if description.contains("authmod=adobe") {
            if user.isEmpty || password.isEmpty {
                disconnect()
            } else {
                let query = uri.query ?? ""
                let command = uri.absoluteString + (query.isEmpty ? "?" : "&") + "authmod=adobe&user=\(user)"
                connect(command)
            }
        }
    }

    private func handleConnectClosed() {
        disconnect()
    }

    private func makeConnectChunk() -> RtmpChunk? {
        guard let uri else {
            return nil
        }
        var app = String(uri.path.trimmingPrefix(while: { $0 == "/" }))
        if let query = uri.query {
            app += "?" + query
        }
        let message = RtmpCommandMessage(
            streamId: 0,
            transactionId: getNextTransactionId(),
            commandType: .amf0Command,
            commandName: .connect,
            commandObject: [
                "app": .string(app),
                "flashVer": .string("FMLE/3.0 (compatible; FMSc/1.0)"),
                "swfUrl": .null,
                "tcUrl": .string(uri.absoluteWithoutAuthenticationString),
                "fpad": .bool(false),
                "capabilities": .number(239),
                "audioCodecs": .number(Double(SupportSound.aac.rawValue)),
                "videoCodecs": .number(Double(SupportVideo.h264.rawValue)),
                "videoFunction": .number(Double(VideoFunction.clientSeek.rawValue)),
                "pageUrl": .null,
                "objectEncoding": .number(0),
            ],
            arguments: []
        )
        return RtmpChunk(message: message)
    }

    private func handleHandshakeDone() {
        guard let chunk = makeConnectChunk() else {
            disconnect()
            return
        }
        _ = socket.write(chunk: chunk)
        timer.startPeriodic(interval: 1.0, handler: { [weak self] in
            guard let self else {
                return
            }
            stream?.onTimeout()
        })
    }

    private func handleClosed() {
        nextTransactionId = 0
        callCompletions.removeAll()
        chunkReader.clear()
    }

    private func processMessageSetChunkSize(message: RtmpSetChunkSizeMessage) {
        chunkReader.maximumChunkSize = Int(message.size)
    }

    private func processMessageAcknowledgementMessage(message: RtmpAcknowledgementMessage) {
        stream?.info.onAck(sequence: message.sequence)
    }

    private func processMessageWindowAcknowledgementSize() {
        _ = socket.write(chunk: RtmpChunk(
            type: .zero,
            chunkStreamId: RtmpChunk.ChunkStreamId.control.rawValue,
            message: RtmpWindowAcknowledgementSizeMessage(100_000)
        ))
    }

    private func processMessageUserControl(message: RtmpUserControlMessage) {
        switch message.event {
        case .ping:
            _ = socket.write(chunk: RtmpChunk(
                type: .zero,
                chunkStreamId: RtmpChunk.ChunkStreamId.control.rawValue,
                message: RtmpUserControlMessage(event: .pong, value: message.value)
            ))
        default:
            break
        }
    }

    private func processMessageCommand(message: RtmpCommandMessage) {
        guard let completion = callCompletions.removeValue(forKey: message.transactionId) else {
            switch message.commandName {
            case .close:
                disconnect()
            default:
                if case let .object(data) = message.arguments.first {
                    gotCommand(data: data)
                }
            }
            return
        }
        switch message.commandName {
        case .result:
            completion(message.arguments)
        default:
            break
        }
    }

    private func processMessageData(message: RtmpDataMessage) {
        stream?.info.bitrateStats.mutate { $0.add(bytesTransferred: message.encoded.count) }
    }
}

extension RtmpConnection: RtmpSocketDelegate {
    func socketReadyStateChanged(readyState: RtmpSocketReadyState) {
        switch readyState {
        case .handshakeDone:
            handleHandshakeDone()
        case .closed:
            handleClosed()
        default:
            break
        }
    }

    func socketUpdateStats(totalBytesSent: Int64) {
        stream?.info.onWritten(sequence: totalBytesSent)
    }

    func socketDataReceived(data: Data) -> Data {
        chunkReader.read(data: data) { message in
            processMessage(message: message)
        }
    }

    private func processMessage(message: RtmpMessage) {
        if let message = message as? RtmpSetChunkSizeMessage {
            processMessageSetChunkSize(message: message)
        } else if let message = message as? RtmpAcknowledgementMessage {
            processMessageAcknowledgementMessage(message: message)
        } else if let message = message as? RtmpUserControlMessage {
            processMessageUserControl(message: message)
        } else if message is RtmpWindowAcknowledgementSizeMessage {
            processMessageWindowAcknowledgementSize()
        } else if let message = message as? RtmpCommandMessage {
            processMessageCommand(message: message)
        } else if let message = message as? RtmpDataMessage {
            processMessageData(message: message)
        }
    }

    func socketPost(data: AsObject) {
        on(data: data)
    }
}
