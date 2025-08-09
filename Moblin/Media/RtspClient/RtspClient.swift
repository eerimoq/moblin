import CoreMedia
import Foundation
import Network

private let rtspClientQueue = DispatchQueue(label: "com.eerimoq.moblin.rtsp")

protocol RtspClientDelegate: AnyObject {
    func rtspClientConnected(cameraId: UUID)
    func rtspClientDisconnected(cameraId: UUID)
    func rtspClientOnVideoBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer)
}

private struct SdpVideoH264 {
    let sps: AvcNalUnit
    let pps: AvcNalUnit
}

private struct SdpVideoH265 {
    let vps: HevcNalUnit
    let sps: HevcNalUnit
    let pps: HevcNalUnit
}

private enum SdpVideoCodec {
    case h264(SdpVideoH264)
    case h265(SdpVideoH265)
}

private class SdpVideo {
    var control: URL?
    var codec: SdpVideoCodec?
}

private class SdpLinesReader {
    private var nextIndex = 0
    private var lines: [Substring]

    init(lines: [Substring]) {
        self.lines = lines
    }

    func next() throws -> (String, String)? {
        guard nextIndex < lines.count else {
            return nil
        }
        defer {
            nextIndex += 1
        }
        let line = lines[nextIndex]
        logger.info("rtsp-client: SDP line \(line.trim())")
        return try partition(text: String(line), separator: "=")
    }

    func back() {
        guard nextIndex > 0 else {
            return
        }
        nextIndex -= 1
    }
}

private struct SdpMediaDescription {
    var media: String
    var port: String
    var proto: String
    var attributes: [SdpAttribute] = []

    func getValue(for attributeName: String) throws -> String {
        guard let attribute = attributes.first(where: { $0.attribute == attributeName }) else {
            throw "Attribute \(attributeName) is missing."
        }
        guard let value = attribute.value else {
            throw "Attribute \(attributeName) has no value."
        }
        return value
    }
}

private struct SdpAttribute {
    var attribute: String
    var value: String?
}

private class SdpLinesParser {
    private var mediaDescriptions: [SdpMediaDescription] = []

    init(value: String) throws {
        try parse(value: value)
    }

    func getMediaDescriptions() -> [SdpMediaDescription] {
        return mediaDescriptions
    }

    private func parse(value: String) throws {
        let linesReader = SdpLinesReader(lines: value.split(separator: "\r\n"))
        while let (kind, value) = try linesReader.next() {
            switch kind {
            case "m":
                try parseMedia(value: value, linesReader: linesReader)
            default:
                break
            }
        }
    }

    private func parseMedia(value: String, linesReader: SdpLinesReader) throws {
        let parts = value.split(separator: " ")
        guard parts.count >= 3 else {
            throw "Bad media description \(value)"
        }
        var mediaDescription = SdpMediaDescription(media: String(parts[0]),
                                                   port: String(parts[1]),
                                                   proto: String(parts[2]))
        mediaLoop: while let (kind, value) = try linesReader.next() {
            switch kind {
            case "m":
                linesReader.back()
                break mediaLoop
            case "a":
                try parseAttribute(value: value, mediaDescription: &mediaDescription)
            default:
                break
            }
        }
        mediaDescriptions.append(mediaDescription)
    }

    private func parseAttribute(value: String, mediaDescription: inout SdpMediaDescription) throws {
        if value.contains(":") {
            let (attribute, value) = try partition(text: value, separator: ":")
            mediaDescription.attributes.append(SdpAttribute(attribute: attribute, value: value))
        } else {
            mediaDescription.attributes.append(SdpAttribute(attribute: value))
        }
    }
}

private class Sdp {
    var video: SdpVideo?

    init(value: String) throws {
        let linesParser = try SdpLinesParser(value: value)
        try parse(linesParser: linesParser)
    }

    private func parse(linesParser: SdpLinesParser) throws {
        for mediaDescription in linesParser.getMediaDescriptions() {
            switch mediaDescription.media {
            case "video":
                let video = SdpVideo()
                let rtpmap = try mediaDescription.getValue(for: "rtpmap")
                try parseVideoAttributeRtpmap(value: rtpmap)
                let fmtp = try mediaDescription.getValue(for: "fmtp")
                try parseVideoAttributeFmtp(value: fmtp, video: video)
                video.control = try URL(string: mediaDescription.getValue(for: "control"))
                self.video = video
            default:
                break
            }
        }
    }

    private func parseVideoAttributeRtpmap(value: String) throws {
        guard value.contains("H264") else {
            throw "Only H.264 is supported."
        }
    }

    private func parseVideoAttributeFmtp(value: String, video: SdpVideo) throws {
        for part in value.split(separator: /;\s*/) {
            let (name, value) = try partition(text: String(part), separator: "=")
            switch name {
            case "sprop-parameter-sets":
                try parseVideoAttributeFmtpSpropParameterSets(value: value, video: video)
            default:
                break
            }
        }
    }

    private func parseVideoAttributeFmtpSpropParameterSets(value: String, video: SdpVideo) throws {
        let (spsBase64, ppsBase64) = try partition(text: value, separator: ",")
        guard let sps = Data(base64Encoded: spsBase64) else {
            throw "Failed to decode SPS."
        }
        guard let pps = Data(base64Encoded: ppsBase64) else {
            throw "Failed to decode PPS."
        }
        guard let spsNalUnit = AvcNalUnit(sps) else {
            throw "Failed to parse SPS NAL unit."
        }
        guard let ppsNalUnit = AvcNalUnit(pps) else {
            throw "Failed to parse PPS NAL unit."
        }
        video.codec = .h264(SdpVideoH264(sps: spsNalUnit, pps: ppsNalUnit))
    }
}

private func partition(text: String, separator: String) throws -> (String, String) {
    let parts = text.split(separator: separator, maxSplits: 1)
    guard parts.count == 2 else {
        throw "Cannot partition '\(text)'"
    }
    return (String(parts[0]), parts[1].trim())
}

private let rtspEndOfHeaders = Data([0xD, 0xA, 0xD, 0xA])

private class Request {
    let url: URL
    let method: String
    var headers: [String: String]
    let content: Data?
    let completion: (Response) throws -> Void

    init(url: URL,
         method: String,
         headers: [String: String],
         content: Data?,
         completion: @escaping (Response) throws -> Void)
    {
        self.url = url
        self.method = method
        self.headers = headers
        self.content = content
        self.completion = completion
    }

    func pack(cSeq: Int) -> Data {
        var request = "\(method) \(url) RTSP/1.0\r\n"
        request += "CSeq: \(cSeq)\r\n"
        for (name, value) in headers {
            request += "\(name): \(value)\r\n"
        }
        request += "\r\n"
        logger.info("rtsp-client: Sending header \(request)")
        return request.utf8Data
    }
}

private class Response {
    let statusCode: Int
    let headers: [String: String]
    var content: Data?

    init(statusCode: Int, headers: [String: String], content: Data? = nil) {
        self.statusCode = statusCode
        self.headers = headers
        self.content = content
    }
}

private enum State {
    case disconnected
    case connecting
    case setup
    case streaming
}

private func md5String(data: String) -> String {
    return MD5.calculate(data).hexString()
}

extension URL {
    func removeCredentials() -> URL {
        var components = URLComponents(string: absoluteString)!
        components.user = nil
        components.password = nil
        return components.url!
    }
}

private class RtpVideo {
    var listener: NWListener?
    var connection: NWConnection?
    var timestamp: UInt32 = 0
    var data = Data()
    var nextExpectedSequenceNumber: UInt16?
    var packets: [UInt16: Data] = [:]
    var decoder: VideoDecoder?
    var formatDescription: CMFormatDescription?
    var basePresentationTimeStamp: Double = -1
    var firstPresentationTimeStamp: Double = -1
    weak var client: RtspClient?

    func start() {
        listener = try? NWListener(using: .udp)
        listener?.stateUpdateHandler = connectionStateDidChange
        listener?.newConnectionHandler = newConnection
        listener?.start(queue: rtspClientQueue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        connection?.cancel()
        connection = nil
    }

    private func connectionStateDidChange(to state: NWListener.State) {
        switch state {
        case .ready:
            client?.performOptionsIfReady()
        default:
            break
        }
    }

    private func newConnection(_ connection: NWConnection) {
        connection.start(queue: rtspClientQueue)
        self.connection = connection
        receivePacket()
    }

    private func receivePacket() {
        connection?.receiveMessage { packet, _, _, error in
            do {
                try self.handlePacket(packet: packet)
            } catch {
                logger.info("rtsp-client: Failed to handle RTP packet with error: \(error)")
            }
        }
    }

    private func handlePacket(packet: Data?) throws {
        guard let packet else {
            throw "Connection closed."
        }
        guard packet.count >= 12 else {
            throw "Packet shorter than 12 bytes: \(packet)"
        }
        var value = packet[0]
        let version = value >> 6
        let x = (value >> 4) & 0x1
        let cc = value & 0xF
        value = packet[1]
        let sequenceNumber = UInt16(packet[2]) << 8 | UInt16(packet[3])
        let timestamp = packet.withUnsafeBytes { pointer in
            pointer.readUInt32(offset: 4)
        }
        guard version == 2 else {
            throw "Unsupported version \(version)"
        }
        guard x == 0 else {
            throw "Unsupported x \(x)"
        }
        guard cc == 0 else {
            throw "Unsupported cc \(cc)"
        }
        if nextExpectedSequenceNumber == nil {
            nextExpectedSequenceNumber = sequenceNumber
        }
        if sequenceNumber == nextExpectedSequenceNumber {
            try processBuffer(packet: packet, timestamp: timestamp)
            nextExpectedSequenceNumber = sequenceNumber + 1
            try processOutOfOrderPackets()
        } else if packets.count < 20 {
            packets[sequenceNumber] = packet
        } else {
            logger.info("rtsp-client: Dropping \(packets.count) packets.")
            packets.removeAll()
            data = Data()
            nextExpectedSequenceNumber = sequenceNumber + 1
        }
        receivePacket()
    }

    private func processOutOfOrderPackets() throws {
        guard var nextExpectedSequenceNumber = nextExpectedSequenceNumber else {
            return
        }
        while true {
            guard let packet = packets.removeValue(forKey: nextExpectedSequenceNumber) else {
                self.nextExpectedSequenceNumber = nextExpectedSequenceNumber
                return
            }
            let timestamp = packet.withUnsafeBytes { pointer in
                pointer.readUInt32(offset: 4)
            }
            try processBuffer(packet: packet, timestamp: timestamp)
            nextExpectedSequenceNumber += 1
        }
    }

    private func processBuffer(packet: Data, timestamp: UInt32) throws {
        guard packet.count >= 14 else {
            throw "Packet shorter than 14 bytes: \(packet)"
        }
        let type = packet[12] & 0x1F
        switch type {
        case 1:
            try processBufferType1(packet: packet, timestamp: timestamp)
        case 28:
            try processBufferType28(packet: packet, timestamp: timestamp)
        default:
            throw "Unsupported RTP packet type \(type)."
        }
    }

    private func processBufferType1(packet: Data, timestamp: UInt32) throws {
        if !data.isEmpty {
            decodeFrame()
        }
        self.timestamp = timestamp
        data = nalUnitStartCode + packet[12...]
        decodeFrame()
        data = Data()
    }

    private func processBufferType28(packet: Data, timestamp: UInt32) throws {
        let fuIndicator = packet[12]
        let fuHeader = packet[13]
        let startBit = fuHeader >> 7
        let nalType = fuHeader & 0x1F
        let nal = fuIndicator & 0xE0 | nalType
        // logger.info("rtsp-client: type \(type) startBit \(startBit) nalType \(nalType)")
        if startBit == 1 {
            if data.isEmpty {
                self.timestamp = timestamp
                data = nalUnitStartCode + Data([nal]) + packet[14...]
            } else {
                decodeFrame()
                self.timestamp = timestamp
                data = nalUnitStartCode + Data([nal]) + packet[14...]
            }
        } else {
            data += packet[14...]
        }
    }

    private func decodeFrame() {
        guard let client else {
            return
        }
        let nalUnits = getNalUnits(data: data)
        let units = readH264NalUnits(data: data, nalUnits: nalUnits, filter: [.idr])
        let count = UInt32(data.count - 4)
        data.withUnsafeMutableBytes { pointer in
            pointer.writeUInt32(count, offset: 0)
        }
        var presenationTimeStamp = Double(timestamp) / 90000
        if firstPresentationTimeStamp == -1 {
            firstPresentationTimeStamp = presenationTimeStamp
        }
        presenationTimeStamp = client.getBasePresentationTimeStamp()
            + (presenationTimeStamp - firstPresentationTimeStamp)
            + client.latency
        var timing = CMSampleTimingInfo(
            duration: .zero,
            presentationTimeStamp: CMTime(seconds: presenationTimeStamp),
            decodeTimeStamp: CMTime(seconds: presenationTimeStamp)
        )
        let blockBuffer = data.makeBlockBuffer()
        var sampleBuffer: CMSampleBuffer?
        var sampleSize = blockBuffer?.dataLength ?? 0
        guard CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        ) == noErr else {
            return
        }
        sampleBuffer?.isSync = units.contains { $0.header.type == .idr }
        guard let sampleBuffer else {
            return
        }
        decoder?.decodeSampleBuffer(sampleBuffer)
    }
}

class RtspClient {
    private var state: State
    private var connection: NWConnection?
    private let cameraId: UUID
    private let url: URL
    fileprivate let latency: Double
    private var username: String?
    private var password: String?
    private var realm: String?
    private var nonce: String?
    private var header = Data()
    private var nextCSeq = 0
    private var requests: [Int: Request] = [:]
    private var videoSession: String?
    private let video = RtpVideo()
    private var rtcpVideoListener: NWListener?
    private var rtcpVideoConnection: NWConnection?
    weak var delegate: RtspClientDelegate?
    private var connectTimer = SimpleTimer(queue: rtspClientQueue)
    private var keepAliveTimer = SimpleTimer(queue: rtspClientQueue)
    private var started = false
    private var isAlive = true

    init(cameraId: UUID, url: URL, latency: Double) {
        self.cameraId = cameraId
        self.latency = latency
        username = url.user()
        password = url.password()
        self.url = url.removeCredentials()
        state = .disconnected
        video.client = self
    }

    func start() {
        logger.info("rtsp-client: Start")
        rtspClientQueue.async {
            self.started = true
            self.startInner()
        }
    }

    func stop() {
        logger.info("rtsp-client: Stop")
        rtspClientQueue.async {
            self.started = false
            self.stopInner()
        }
    }

    private func setState(newState: State) {
        guard newState != state else {
            return
        }
        logger.info("rtsp-client: State change \(state) -> \(newState)")
        state = newState
        switch state {
        case .disconnected:
            delegate?.rtspClientDisconnected(cameraId: cameraId)
        case .streaming:
            delegate?.rtspClientConnected(cameraId: cameraId)
        default:
            break
        }
    }

    private func startInner() {
        guard started else {
            return
        }
        stopInner()
        guard let host = url.host() else {
            return
        }
        let port = url.port ?? 554
        logger.info("rtsp-client: Connecting to \(host):\(port)")
        connection = NWConnection(
            to: .hostPort(host: .init(host), port: .init(integerLiteral: NWEndpoint.Port.IntegerLiteralType(port))),
            using: .init(tls: nil)
        )
        connection?.stateUpdateHandler = rtspConnectionStateDidChange
        connection?.start(queue: rtspClientQueue)
        receiveNewRtspHeader()
        video.start()
        rtcpVideoListener = try? NWListener(using: .udp)
        rtcpVideoListener?.stateUpdateHandler = rtcpVideoConnectionStateDidChange
        rtcpVideoListener?.newConnectionHandler = rtcpVideoNewConnection
        rtcpVideoListener?.start(queue: rtspClientQueue)
        setState(newState: .connecting)
        connectTimer.startSingleShot(timeout: 5) { [weak self] in
            self?.startInner()
        }
        isAlive = true
    }

    private func stopInner() {
        connectTimer.stop()
        keepAliveTimer.stop()
        connection?.cancel()
        connection = nil
        video.stop()
        rtcpVideoListener?.cancel()
        rtcpVideoListener = nil
        setState(newState: .disconnected)
    }

    private func rtspConnectionStateDidChange(to state: NWConnection.State) {
        switch state {
        case .ready:
            performOptionsIfReady()
        default:
            break
        }
    }

    private func getNextCSeq() -> Int {
        nextCSeq += 1
        return nextCSeq
    }

    private func createDigestHeader(request: Request) -> String? {
        guard let realm, let nonce, let username, let password else {
            return nil
        }
        let ha1 = md5String(data: "\(username):\(realm):\(password)")
        let ha2 = md5String(data: "\(request.method):\(url)")
        let response = md5String(data: "\(ha1):\(nonce):\(ha2)")
        return """
        Digest username="\(username)", \
        realm="\(realm)", \
        nonce="\(nonce)", \
        uri="\(url)", \
        response="\(response)"
        """
    }

    private func perform(request: Request) {
        let cSeq = getNextCSeq()
        requests[cSeq] = request
        if let authorization = createDigestHeader(request: request) {
            request.headers["Authorization"] = authorization
        }
        connection?.send(content: request.pack(cSeq: cSeq), completion: .idempotent)
    }

    private func rtcpVideoConnectionStateDidChange(to state: NWListener.State) {
        switch state {
        case .ready:
            performOptionsIfReady()
        default:
            break
        }
    }

    private func rtcpVideoNewConnection(_ connection: NWConnection) {
        connection.start(queue: rtspClientQueue)
        rtcpVideoConnection = connection
        receiveRtcpVideoPacket()
    }

    private func receiveRtcpVideoPacket() {
        rtcpVideoConnection?.receiveMessage { data, _, _, _ in
            guard let data else {
                return
            }
            guard data.count >= 8 else {
                return
            }
            let value = data[0]
            let version = value >> 6
            let pt = data[1]
            guard version == 2 else {
                logger.info("rtsp-client: Unsupported version \(version)")
                return
            }
            if pt == 200 {
                var receiverReport = Data(count: 8)
                receiverReport[0] = 2 << 6
                receiverReport[1] = 201
                receiverReport[3] = 1
                self.rtcpVideoConnection?.send(content: receiverReport, completion: .idempotent)
            }
            self.receiveRtcpVideoPacket()
        }
    }

    private func receiveNewRtspHeader() {
        header.removeAll()
        receiveRtspHeader()
    }

    private func receiveRtspHeader() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 1) { data, _, _, _ in
            guard let data else {
                return
            }
            self.header += data
            if self.header.suffix(4) == rtspEndOfHeaders {
                do {
                    try self.handleRtspHeader()
                } catch {
                    logger.info("rtsp-client: Header handling failed with error: \(error)")
                }
            } else {
                self.receiveRtspHeader()
            }
        }
    }

    private func receiveRtspContent(response: Response, size: Int) {
        connection?.receive(minimumIncompleteLength: size, maximumLength: size) { data, _, _, _ in
            response.content = data
            do {
                try self.handleResponse(response: response)
            } catch {
                logger.info("rtsp-client: Response handling failed with error: \(error)")
                return
            }
            self.receiveNewRtspHeader()
        }
    }

    private func handleRtspHeader() throws {
        guard let header = String(bytes: header, encoding: .utf8) else {
            throw "Header is not text."
        }
        logger.info("rtsp-client: Got header \(header)")
        let lines = header.split(separator: "\r\n")
        guard lines.count >= 1 else {
            throw "Status line missing."
        }
        guard let statusLine = lines[0].wholeMatch(of: /^RTSP\/1.0 (\d+) .*$/) else {
            throw "Invalid status line '\(lines[0])'."
        }
        guard let statusCode = Int(statusLine.output.1) else {
            throw "Status code not an integer."
        }
        var headers: [String: String] = [:]
        for line in lines.suffix(from: 1) {
            let (name, value) = try partition(text: String(line), separator: ":")
            headers[name] = value
        }
        let response = Response(statusCode: statusCode, headers: headers)
        if let contentLength = headers["Content-Length"], let contentLength = Int(contentLength) {
            receiveRtspContent(response: response, size: contentLength)
        } else {
            try handleResponse(response: response)
            receiveNewRtspHeader()
        }
    }

    private func handleResponse(response: Response) throws {
        guard let cSeq = response.headers["CSeq"],
              let cSeq = Int(cSeq),
              let request = requests.removeValue(forKey: cSeq)
        else {
            throw "No request found for response."
        }
        guard response.statusCode != 401 else {
            try handleUnauthorizedResponse(response: response)
            perform(request: request)
            return
        }
        try request.completion(response)
    }

    private func handleUnauthorizedResponse(response: Response) throws {
        guard let wwwAuthenticate = response.headers["WWW-Authenticate"] else {
            throw "Missing authenticate field when authentication failed."
        }
        guard wwwAuthenticate.starts(with: "Digest ") else {
            throw "Only Digest authentication is supported."
        }
        let index = wwwAuthenticate.index(wwwAuthenticate.startIndex, offsetBy: 7)
        for parameter in wwwAuthenticate.suffix(from: index).split(separator: ", ") {
            let (name, value) = try partition(text: String(parameter), separator: "=")
            switch name {
            case "realm":
                realm = value.trimmingCharacters(in: ["\""])
            case "nonce":
                nonce = value.trimmingCharacters(in: ["\""])
            default:
                break
            }
        }
    }

    private func isReadyToSendOptions() -> Bool {
        return connection?.state == .ready && video.listener?.port != nil && rtcpVideoListener?.port != nil
    }

    fileprivate func performOptionsIfReady() {
        if isReadyToSendOptions() {
            setState(newState: .setup)
            performOptions()
        }
    }

    private func keepAlive() {
        guard isAlive else {
            startInner()
            return
        }
        isAlive = false
        performGetParameter()
    }

    private func performOptions() {
        let request = Request(url: url, method: "OPTIONS", headers: [:], content: nil) { _ in
            self.performDescribe()
        }
        perform(request: request)
    }

    private func performGetParameter() {
        let request = Request(url: url, method: "GET_PARAMETER", headers: [:], content: nil) { _ in
            self.isAlive = true
        }
        perform(request: request)
    }

    private func performDescribe() {
        let headers = ["Accept": "application/sdp"]
        let request = Request(url: url, method: "DESCRIBE", headers: headers, content: nil) { response in
            try self.handleDescribeResponse(response: response)
        }
        perform(request: request)
    }

    private func handleDescribeResponse(response: Response) throws {
        guard let content = response.content, let content = String(data: content, encoding: .utf8) else {
            throw "Bad DESCRIBE content."
        }
        let baseUrl = response.headers["Content-Base"] ?? url.absoluteString
        let sdp = try Sdp(value: content)
        switch sdp.video?.codec {
        case let .h264(sdpVideo):
            try setupH264(sdpVideo: sdpVideo)
        case .h265:
            throw "H.265 is not supported."
        default:
            throw "No video media found."
        }
        // This is wrong.
        if let controlUrl = sdp.video?.control {
            if controlUrl.host() != nil {
                performSetup(url: controlUrl)
            } else if let url = URL(string: baseUrl + controlUrl.path) {
                performSetup(url: url)
            } else {
                performSetup(url: url)
            }
        } else {
            performSetup(url: url)
        }
    }

    private func setupH264(sdpVideo: SdpVideoH264) throws {
        let nalUnits = [sdpVideo.sps, sdpVideo.pps]
        video.formatDescription = nalUnits.makeFormatDescription()
        guard video.formatDescription != nil else {
            throw "Failed to create H.264 format description."
        }
        video.decoder = VideoDecoder(lockQueue: rtspClientQueue)
        video.decoder?.delegate = self
        video.decoder?.startRunning(formatDescription: video.formatDescription)
    }

    private func performSetup(url: URL) {
        guard let rtpVideoPort = video.listener?.port, let rtcpVideoPort = rtcpVideoListener?.port else {
            return
        }
        let headers = ["Transport": "RTP/AVP;unicast;client_port=\(rtpVideoPort)-\(rtcpVideoPort)"]
        let request = Request(url: url, method: "SETUP", headers: headers, content: nil) { response in
            try self.handleSetupResponse(response: response)
        }
        perform(request: request)
    }

    private func handleSetupResponse(response: Response) throws {
        guard let session = response.headers["Session"] else {
            throw "Session header missing."
        }
        (videoSession, _) = try partition(text: session, separator: ";")
        try performPlay()
    }

    private func performPlay() throws {
        guard let videoSession else {
            throw "No video session."
        }
        let headers = [
            "Session": videoSession,
            "Range": "npt=now-",
        ]
        let request = Request(url: url, method: "PLAY", headers: headers, content: nil) { response in
            self.handlePlayResponse(response: response)
        }
        perform(request: request)
    }

    private func handlePlayResponse(response _: Response) {
        setState(newState: .streaming)
        connectTimer.stop()
        keepAliveTimer.startPeriodic(interval: 15) { [weak self] in
            self?.keepAlive()
        }
    }

    fileprivate func getBasePresentationTimeStamp() -> Double {
        if video.basePresentationTimeStamp == -1 {
            video.basePresentationTimeStamp = currentPresentationTimeStamp().seconds
        }
        return video.basePresentationTimeStamp
    }
}

extension RtspClient: VideoDecoderDelegate {
    func videoDecoderOutputSampleBuffer(_: VideoDecoder, _ sampleBuffer: CMSampleBuffer) {
        delegate?.rtspClientOnVideoBuffer(cameraId: cameraId, sampleBuffer)
    }
}
