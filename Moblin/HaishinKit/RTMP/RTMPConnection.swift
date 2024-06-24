import AVFoundation
import Foundation

/// The RTMPResponder class provides to use handle RTMPConnection's callback.
open class RTMPResponder {
    /// A Handler represents RTMPResponder's callback function.
    typealias Handler = (_ data: [Any?]) -> Void

    private var result: Handler
    private var status: Handler?

    /// Creates a new RTMPResponder object.
    init(result: @escaping Handler, status: Handler? = nil) {
        self.result = result
        self.status = status
    }

    final func on(result: [Any?]) {
        self.result(result)
    }

    final func on(status: [Any?]) {
        self.status?(status)
        self.status = nil
    }
}

/// The RTMPConneciton class create a two-way RTMP connection.
open class RTMPConnection: EventDispatcher {
    /// The default network's window size for RTMPConnection.
    public static let defaultWindowSizeS: Int64 = 250_000
    /// The supported protocols are rtmp, rtmps, rtmpt and rtmps.
    public static let supportedProtocols: Set<String> = ["rtmp", "rtmps", "rtmpt", "rtmpts"]
    /// The default RTMP port is 1935.
    public static let defaultPort: Int = 1935
    /// The default RTMPS port is 443.
    public static let defaultSecurePort: Int = 443
    /// The default flashVer is FMLE/3.0 (compatible; FMSc/1.0).
    public static let defaultFlashVer: String = "FMLE/3.0 (compatible; FMSc/1.0)"
    /// The default chunk size for RTMPConnection.
    public static let defaultChunkSizeS: Int = 1024 * 8
    /// The default capabilities for RTMPConneciton.
    public static let defaultCapabilities: Int = 239
    /// The default object encoding for RTMPConnection class.
    public static let defaultObjectEncoding: RTMPObjectEncoding = .amf0

    /**
     - NetStatusEvent#info.code for NetConnection
     - see: https://help.adobe.com/en_US/air/reference/html/flash/events/NetStatusEvent.html#NET_STATUS
     */
    public enum Code: String {
        case callBadVersion = "NetConnection.Call.BadVersion"
        case callFailed = "NetConnection.Call.Failed"
        case callProhibited = "NetConnection.Call.Prohibited"
        case connectAppshutdown = "NetConnection.Connect.AppShutdown"
        case connectClosed = "NetConnection.Connect.Closed"
        case connectFailed = "NetConnection.Connect.Failed"
        case connectIdleTimeOut = "NetConnection.Connect.IdleTimeOut"
        case connectInvalidApp = "NetConnection.Connect.InvalidApp"
        case connectNetworkChange = "NetConnection.Connect.NetworkChange"
        case connectRejected = "NetConnection.Connect.Rejected"
        case connectSuccess = "NetConnection.Connect.Success"

        public var level: String {
            switch self {
            case .callBadVersion:
                return "error"
            case .callFailed:
                return "error"
            case .callProhibited:
                return "error"
            case .connectAppshutdown:
                return "error"
            case .connectClosed:
                return "status"
            case .connectFailed:
                return "error"
            case .connectIdleTimeOut:
                return "status"
            case .connectInvalidApp:
                return "error"
            case .connectNetworkChange:
                return "status"
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
        case unused = 0x0001
        case jpeg = 0x0002
        case sorenson = 0x0004
        case homebrew = 0x0008
        case vp6 = 0x0010
        case vp6Alpha = 0x0020
        case homebrewv = 0x0040
        case h264 = 0x0080
        case all = 0x00FF
    }

    enum SupportSound: UInt16 {
        case none = 0x0001
        case adpcm = 0x0002
        case mp3 = 0x0004
        case intel = 0x0008
        case unused = 0x0010
        case nelly8 = 0x0020
        case nelly = 0x0040
        case g711A = 0x0080
        case g711U = 0x0100
        case nelly16 = 0x0200
        case aac = 0x0400
        case speex = 0x0800
        case all = 0x0FFF
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

    var swfUrl: String?
    var pageUrl: String?
    var flashVer: String = RTMPConnection.defaultFlashVer
    var chunkSize: Int = RTMPConnection.defaultChunkSizeS
    private(set) var uri: URL?
    private(set) var connected = false
    var objectEncoding = RTMPConnection.defaultObjectEncoding
    var socket: RTMPSocket!
    var streams: [RTMPStream] = []
    var streamsmap: [UInt16: UInt32] = [:]
    var operations: [Int: RTMPResponder] = [:]
    var windowSizeC: Int64 = RTMPConnection.defaultWindowSizeS {
        didSet {
            guard socket.connected else {
                return
            }
            socket.doOutput(chunk: RTMPChunk(
                type: .zero,
                streamId: RTMPChunk.StreamID.control.rawValue,
                message: RTMPWindowAcknowledgementSizeMessage(100_000)
            ))
        }
    }

    var currentTransactionId: Int = 0
    private var timer: Timer? {
        didSet {
            oldValue?.invalidate()
            if let timer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }

    private var messages: [UInt16: RTMPMessage] = [:]
    private var arguments: [Any?] = []
    private var currentChunk: RTMPChunk?
    private var fragmentedChunks: [UInt16: RTMPChunk] = [:]

    override init() {
        super.init()
        addEventListener(.rtmpStatus, selector: #selector(on(status:)))
    }

    deinit {
        timer = nil
        streams.removeAll()
        removeEventListener(.rtmpStatus, selector: #selector(on(status:)))
    }

    /// Calls a command or method on RTMP Server.
    open func call(_ commandName: String, responder: RTMPResponder?, arguments: Any?...) {
        guard connected else {
            return
        }
        currentTransactionId += 1
        let message = RTMPCommandMessage(
            streamId: 0,
            transactionId: currentTransactionId,
            objectEncoding: objectEncoding,
            commandName: commandName,
            commandObject: nil,
            arguments: arguments
        )
        if responder != nil {
            operations[message.transactionId] = responder
        }
        socket.doOutput(chunk: RTMPChunk(message: message))
    }

    /// Creates a two-way connection to an application on RTMP Server.
    open func connect(_ command: String, arguments: Any?...) {
        guard let uri = URL(string: command), let scheme = uri.scheme,
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
        socket.connect(
            withName: uri.host!,
            port: uri.port ?? (secure ? Self.defaultSecurePort : Self.defaultPort)
        )
    }

    /// Closes the connection from the server.
    open func close() {
        close(isDisconnected: false)
    }

    func close(isDisconnected: Bool) {
        guard connected || isDisconnected else {
            timer = nil
            return
        }
        timer = nil
        if !isDisconnected {
            uri = nil
        }
        for stream in streams {
            stream.close()
        }
        socket.close(isDisconnected: false)
    }

    func createStream(_ stream: RTMPStream) {
        let responder = RTMPResponder(result: { data in
            guard let id = data[0] as? Double else {
                return
            }
            stream.id = UInt32(id)
            stream.readyState = .open
        })
        call("createStream", responder: responder)
    }

    @objc
    private func on(status: Notification) {
        let e = Event.from(status)

        guard
            let data = e.data as? ASObject,
            let code = data["code"] as? String
        else {
            return
        }

        switch Code(rawValue: code) {
        case .some(.connectSuccess):
            connected = true
            socket.chunkSizeS = chunkSize
            socket.doOutput(chunk: RTMPChunk(
                type: .zero,
                streamId: RTMPChunk.StreamID.control.rawValue,
                message: RTMPSetChunkSizeMessage(UInt32(socket.chunkSizeS))
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

    private func makeConnectionChunk() -> RTMPChunk? {
        guard let uri else {
            return nil
        }

        var app = uri.path
            .isEmpty ? "" : String(uri.path[uri.path.index(uri.path.startIndex, offsetBy: 1)...])
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
                "swfUrl": swfUrl,
                "tcUrl": uri.absoluteWithoutAuthenticationString,
                "fpad": false,
                "capabilities": Self.defaultCapabilities,
                "audioCodecs": SupportSound.aac.rawValue,
                "videoCodecs": SupportVideo.h264.rawValue,
                "videoFunction": VideoFunction.clientSeek.rawValue,
                "pageUrl": pageUrl,
                "objectEncoding": objectEncoding.rawValue,
            ],
            arguments: arguments
        )

        return RTMPChunk(message: message)
    }

    @objc
    private func on(timer _: Timer) {
        for stream in streams {
            stream.onTimeout()
        }
    }
}

extension RTMPConnection: RTMPSocketDelegate {
    func socket(_ socket: RTMPSocket, readyState: RTMPSocketReadyState) {
        switch readyState {
        case .handshakeDone:
            guard let chunk = makeConnectionChunk() else {
                close()
                break
            }
            timer = Timer(
                timeInterval: 1.0,
                target: self,
                selector: #selector(on(timer:)),
                userInfo: nil,
                repeats: true
            )
            socket.doOutput(chunk: chunk)
        case .closed:
            connected = false
            currentChunk = nil
            currentTransactionId = 0
            messages.removeAll()
            operations.removeAll()
            fragmentedChunks.removeAll()
        default:
            break
        }
    }

    func socket(_: RTMPSocket, totalBytesOut: Int64) {
        guard let stream = streams.first else {
            return
        }
        stream.info.onWritten(sequence: totalBytesOut)
    }

    func socket(_ socket: RTMPSocket, data: Data) {
        guard let chunk = currentChunk ?? RTMPChunk(data, size: socket.chunkSizeC) else {
            socket.inputBuffer.append(data)
            return
        }

        var position = chunk.data.count
        if (chunk.data.count >= 4) && (chunk.data[1] == 0xFF) && (chunk.data[2] == 0xFF) &&
            (chunk.data[3] == 0xFF)
        {
            position += 4
        }

        if currentChunk != nil {
            position = chunk.append(data, size: socket.chunkSizeC)
        }
        if chunk.type == .two {
            position = chunk.append(data, message: messages[chunk.streamId])
        }
        if chunk.type == .three && fragmentedChunks[chunk.streamId] == nil {
            position = chunk.append(data, message: messages[chunk.streamId])
        }

        if let message = chunk.message, chunk.ready {
            switch chunk.type {
            case .zero:
                streamsmap[chunk.streamId] = message.streamId
            case .one:
                if let streamId = streamsmap[chunk.streamId] {
                    message.streamId = streamId
                }
            case .two:
                break
            case .three:
                break
            }
            message.execute(self, type: chunk.type)
            currentChunk = nil
            messages[chunk.streamId] = message
            if position > 0 && position < data.count {
                self.socket(socket, data: data.advanced(by: position))
            }
            return
        }

        if chunk.fragmented {
            fragmentedChunks[chunk.streamId] = chunk
            currentChunk = nil
        } else {
            currentChunk = chunk.type == .three ? fragmentedChunks[chunk.streamId] : chunk
            fragmentedChunks.removeValue(forKey: chunk.streamId)
        }

        if position > 0 && position < data.count {
            self.socket(socket, data: data.advanced(by: position))
        }
    }
}
