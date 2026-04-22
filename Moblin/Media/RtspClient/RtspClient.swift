import CoreMedia
import Foundation

private let rtpH264PacketTypeFuA: UInt8 = 28
let rtspClientQueue = DispatchQueue(label: "com.eerimoq.moblin.rtsp")

protocol RtspClientDelegate: AnyObject {
    func rtspClientErrorToast(title: String)
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
        logger.debug("rtsp-client: SDP line \(line.trim())")
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
    let media: String
    // periphery:ignore
    let port: String
    // periphery:ignore
    let proto: String
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
        let (attribute, value) = try partition(text: value, optionalSeparator: ":")
        mediaDescription.attributes.append(SdpAttribute(attribute: attribute, value: value))
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
                let fmtp = try mediaDescription.getValue(for: "fmtp")
                if rtpmap.contains("H264") {
                    try parseVideoAttributeFmtpH264(value: fmtp, video: video)
                } else if rtpmap.contains("H265") {
                    try parseVideoAttributeFmtpH265(value: fmtp, video: video)
                } else {
                    throw "Unsupported codec in rtpmap: \(rtpmap)"
                }
                video.control = try URL(string: mediaDescription.getValue(for: "control"))
                self.video = video
            default:
                break
            }
        }
    }

    private func parseVideoAttributeFmtpH264(value: String, video: SdpVideo) throws {
        let (_, value) = try partition(text: value, separator: " ")
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
        guard let spsNalUnit = AvcNalUnit(data: sps, offset: 0) else {
            throw "Failed to parse SPS NAL unit."
        }
        guard let ppsNalUnit = AvcNalUnit(data: pps, offset: 0) else {
            throw "Failed to parse PPS NAL unit."
        }
        video.codec = .h264(SdpVideoH264(sps: spsNalUnit, pps: ppsNalUnit))
    }

    private func parseVideoAttributeFmtpH265(value: String, video: SdpVideo) throws {
        var vps: HevcNalUnit?
        var sps: HevcNalUnit?
        var pps: HevcNalUnit?
        let (_, value) = try partition(text: value, separator: " ")
        for part in value.split(separator: /;\s*/) {
            let (name, value) = try partition(text: String(part), separator: "=")
            switch name {
            case "sprop-vps":
                vps = try parseVideoAttributeFmtpSpropVpsSpsPps(value: value)
            case "sprop-sps":
                sps = try parseVideoAttributeFmtpSpropVpsSpsPps(value: value)
            case "sprop-pps":
                pps = try parseVideoAttributeFmtpSpropVpsSpsPps(value: value)
            default:
                break
            }
        }
        guard let vps, let sps, let pps else {
            throw "VPS, SPS or PPS missing."
        }
        video.codec = .h265(SdpVideoH265(vps: vps, sps: sps, pps: pps))
    }

    private func parseVideoAttributeFmtpSpropVpsSpsPps(value: String) throws -> HevcNalUnit {
        guard let value = Data(base64Encoded: value) else {
            throw "Failed to decode VPS, SPS or PPS."
        }
        guard let nalUnit = HevcNalUnit(data: value, offset: 0) else {
            throw "Failed to parse VPS, SPS or PPS unit."
        }
        return nalUnit
    }
}

private func partition(text: String, separator: String) throws -> (String, String) {
    let (first, second) = try partition(text: text, optionalSeparator: separator)
    guard let second else {
        throw "Cannot partition '\(text)'"
    }
    return (first, second)
}

private func partition(text: String, optionalSeparator: String) throws -> (String, String?) {
    let parts = text.split(separator: optionalSeparator, maxSplits: 1)
    switch parts.count {
    case 1:
        return (String(parts[0]), nil)
    case 2:
        return (String(parts[0]), parts[1].trim())
    default:
        throw "Cannot partition '\(text)'"
    }
}

private class Request {
    let method: String
    let url: URL
    var headers: [String: String]
    // periphery:ignore
    let content: Data?
    let completion: (Response) throws -> Void
    var dueToAuthenticationFailure = false

    init(method: String,
         url: URL,
         headers: [String: String] = [:],
         content: Data? = nil,
         completion: @escaping (Response) throws -> Void)
    {
        self.method = method
        self.url = url
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
        logger.debug("rtsp-client: Sending header \(request)")
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
    return calculateMd5(data).hexString()
}

extension URL {
    func removeCredentialsAndPort() -> URL {
        var components = URLComponents(string: absoluteString)!
        components.user = nil
        components.password = nil
        components.port = nil
        return components.url!
    }
}

private class RtpProcessor {
    func process(packet _: Data, timestamp _: Int64) throws {
        throw "Not implemented"
    }
}

private class RtpVideoProcessor: RtpProcessor {
    private var timestamp: Int64 = 0
    var data = Data()
    private var basePresentationTimeStamp: Double = -1
    private var timeStampRebaser = TimeStampRebaser()
    private var decoder: VideoDecoder
    private var formatDescription: CMFormatDescription?
    private weak var client: RtspClient?

    init(formatDescription: CMFormatDescription, client: RtspClient) {
        self.formatDescription = formatDescription
        self.client = client
        decoder = VideoDecoder(lockQueue: rtspClientQueue)
        super.init()
        decoder.delegate = self
        decoder.startRunning(formatDescription: formatDescription)
    }

    func startNewFrame(timestamp: Int64, first: Data, second: Data? = nil) {
        self.timestamp = timestamp
        data.removeAll(keepingCapacity: true)
        data += nalUnitStartCode
        data += first
        if let second {
            data += second
        }
    }

    func tryDecodeFrame() {
        guard let client, data.count > 4 else {
            return
        }
        let count = UInt32(data.count - 4)
        data.withUnsafeMutableBytes { pointer in
            pointer.writeUInt32(count, offset: 0)
        }
        var presenationTimeStamp = Double(timestamp) / 90000
        guard let rebasedPresentationTimeStamp = timeStampRebaser.rebase(presenationTimeStamp) else {
            return
        }
        presenationTimeStamp = getBasePresentationTimeStamp()
            + rebasedPresentationTimeStamp
            + client.latency
        var timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: CMTime(seconds: presenationTimeStamp),
            decodeTimeStamp: .invalid
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
        ) == noErr, let sampleBuffer else {
            return
        }
        decoder.decodeSampleBuffer(sampleBuffer)
    }

    private func getBasePresentationTimeStamp() -> Double {
        if basePresentationTimeStamp == -1 {
            basePresentationTimeStamp = currentPresentationTimeStamp().seconds
        }
        return basePresentationTimeStamp
    }
}

extension RtpVideoProcessor: VideoDecoderDelegate {
    func videoDecoderOutputSampleBuffer(_: VideoDecoder, _ sampleBuffer: CMSampleBuffer) {
        client?.videoOutputSampleBuffer(sampleBuffer)
    }
}

private class RtpProcessorVideoH264: RtpVideoProcessor {
    override func process(packet: Data, timestamp: Int64) throws {
        guard packet.count >= 14 else {
            throw "Packet shorter than 14 bytes: \(packet)"
        }
        let type = packet[12] & 0x1F
        switch type {
        case 1 ... 23:
            try processBufferTypeSingle(packet: packet, timestamp: timestamp)
        case rtpH264PacketTypeFuA:
            try processBufferTypeFuA(packet: packet, timestamp: timestamp)
        default:
            throw "Unsupported RTP packet type \(type)."
        }
    }

    private func processBufferTypeSingle(packet: Data, timestamp: Int64) throws {
        decodeFrame()
        startNewFrame(timestamp: timestamp, first: packet[12...])
    }

    private func processBufferTypeFuA(packet: Data, timestamp: Int64) throws {
        let fuIndicator = packet[12]
        let fuHeader = packet[13]
        let startBit = fuHeader >> 7
        let nalType = fuHeader & 0x1F
        let nal = fuIndicator & 0xE0 | nalType
        if startBit == 1 {
            decodeFrame()
            startNewFrame(timestamp: timestamp, first: Data([nal]), second: packet[14...])
        } else {
            data += packet[14...]
        }
    }

    private func decodeFrame() {
        guard data.count > 4 else {
            return
        }
        switch AvcNalUnit(data: data, offset: 4)?.header.type {
        case .idr:
            break
        case .slice:
            break
        default:
            return
        }
        tryDecodeFrame()
    }
}

private class RtpProcessorVideoH265: RtpVideoProcessor {
    override func process(packet: Data, timestamp: Int64) throws {
        guard packet.count >= 14 else {
            throw "Packet shorter than 14 bytes: \(packet)"
        }
        let type = (packet[12] >> 1) & 0x3F
        switch type {
        case 1 ... 47:
            try processBufferTypeSingle(packet: packet, timestamp: timestamp)
        case 49:
            try processBufferTypeFu(packet: packet, timestamp: timestamp)
        default:
            throw "Unsupported RTP packet type \(type)."
        }
    }

    private func processBufferTypeSingle(packet: Data, timestamp: Int64) throws {
        decodeFrame()
        startNewFrame(timestamp: timestamp, first: packet[12...])
    }

    private func processBufferTypeFu(packet: Data, timestamp: Int64) throws {
        guard packet.count >= 15 else {
            throw "Packet shorter than 15 bytes: \(packet)"
        }
        let fuHeader = packet[14]
        let startBit = fuHeader >> 7
        let nalType = fuHeader & 0x3F
        let nal = (packet[12] & 0x81) | (nalType << 1)
        if startBit == 1 {
            decodeFrame()
            startNewFrame(timestamp: timestamp, first: Data([nal, packet[13]]), second: packet[15...])
        } else {
            data += packet[15...]
        }
    }

    private func decodeFrame() {
        tryDecodeFrame()
    }
}

private class Rtp {
    private var nextExpectedSequenceNumber: UInt16?
    var processor: RtpProcessor?
    weak var client: RtspClient?
    private let wrappingTimestamp = WrappingTimestamp(
        name: "RTP",
        maximumTimestamp: CMTime(seconds: 0x1_0000_0000)
    )

    func handlePacket(packet: Data) throws {
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
        guard sequenceNumber == nextExpectedSequenceNumber else {
            nextExpectedSequenceNumber = nil
            throw "Wrong sequence number"
        }
        try processor?.process(packet: packet, timestamp: updateTimestamp(timestamp: timestamp))
        nextExpectedSequenceNumber! &+= 1
    }

    private func updateTimestamp(timestamp: UInt32) -> Int64 {
        return wrappingTimestamp.update(CMTime(value: Int64(timestamp), timescale: 1)).value
    }
}

class RtspClient {
    private var state: State
    private var transport: RtspTransport?
    private let cameraId: UUID
    private let url: URL
    fileprivate let latency: Double
    private let username: String?
    private let password: String?
    private let port: Int
    private var realm: String?
    private var nonce: String?
    private var nextCSeq = 0
    private var requests: [Int: Request] = [:]
    private var videoSession: String?
    private var rtpVideo = Rtp()
    private let delegate: RtspClientDelegate
    private var connectTimer = SimpleTimer(queue: rtspClientQueue)
    private var keepAliveTimer = SimpleTimer(queue: rtspClientQueue)
    private var reconnectTimer = SimpleTimer(queue: rtspClientQueue)
    private var started = false
    private var isAlive = true
    private var bitrateStats = BitrateStats()
    private let transportType: SettingsRtspTransport

    init(cameraId: UUID,
         url: URL,
         latency: Double,
         transport: SettingsRtspTransport,
         delegate: RtspClientDelegate)
    {
        self.cameraId = cameraId
        self.latency = latency
        self.delegate = delegate
        transportType = transport
        username = url.user()
        password = url.password()
        port = url.port ?? 554
        self.url = url.removeCredentialsAndPort()
        state = .disconnected
    }

    func start() {
        logger.debug("rtsp-client: Start")
        rtspClientQueue.async {
            self.started = true
            self.startInternal()
        }
    }

    func stop() {
        logger.debug("rtsp-client: Stop")
        rtspClientQueue.async {
            self.started = false
            self.stopInternal()
        }
    }

    func updateStats() -> BitrateStatsInstant {
        return rtspClientQueue.sync {
            bitrateStats.update()
        }
    }

    private func setState(newState: State) {
        guard newState != state else {
            return
        }
        logger.debug("rtsp-client: State change \(state) -> \(newState)")
        switch newState {
        case .disconnected:
            if state == .streaming {
                delegate.rtspClientDisconnected(cameraId: cameraId)
            }
        case .streaming:
            delegate.rtspClientConnected(cameraId: cameraId)
        default:
            break
        }
        state = newState
    }

    private func startInternal() {
        guard started else {
            return
        }
        stopInternal()
        guard let host = url.host() else {
            return
        }
        logger.info("""
        rtsp-debug: Connecting to \(host):\(port) with transport \(transportType.toString())
        """)
        transport = createTransport()
        transport?.delegate = self
        transport?.start(host: host, port: port)
        rtpVideo = Rtp()
        rtpVideo.client = self
        setState(newState: .connecting)
        connectTimer.startSingleShot(timeout: 5) { [weak self] in
            self?.reconnectSoon()
        }
        isAlive = true
        realm = nil
        nonce = nil
        nextCSeq = 0
        requests = [:]
        videoSession = nil
    }

    private func stopInternal() {
        connectTimer.stop()
        keepAliveTimer.stop()
        reconnectTimer.stop()
        transport?.stop()
        transport = nil
        setState(newState: .disconnected)
    }

    private func reconnectSoon() {
        stopInternal()
        reconnectTimer.startSingleShot(timeout: 5) { [weak self] in
            self?.startInternal()
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
        send(data: request.pack(cSeq: cSeq))
    }

    private func handleRtcpVideoPacket(packet: Data) {
        guard packet.count >= 8 else {
            return
        }
        let value = packet[0]
        let version = value >> 6
        let pt = packet[1]
        guard version == 2 else {
            logger.debug("rtsp-client: Unsupported version \(version)")
            return
        }
        if pt == 200 {
            var receiverReport = Data(count: 8)
            receiverReport[0] = 2 << 6
            receiverReport[1] = 201
            receiverReport[3] = 1
            sendRtcp(data: receiverReport)
        }
    }

    private func sendRtcp(data: Data) {
        transport?.sendRtcp(data)
    }

    private func send(data: Data) {
        transport?.sendRtsp(data)
    }

    private func handleRtspMessage(header: Data, content: Data?) throws {
        guard let header = String(bytes: header, encoding: .utf8) else {
            throw "Header is not text."
        }
        logger.debug("rtsp-client: Got header \(header)")
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
            headers[name.lowercased()] = value
        }
        let response = Response(statusCode: statusCode, headers: headers)
        response.content = content
        try handleResponse(response: response)
    }

    private func handleResponse(response: Response) throws {
        guard let cSeq = response.headers["cseq"],
              let cSeq = Int(cSeq),
              let request = requests.removeValue(forKey: cSeq)
        else {
            throw "No request found for response."
        }
        guard response.statusCode != 401 else {
            try handleUnauthorizedResponse(request: request, response: response)
            request.dueToAuthenticationFailure = true
            perform(request: request)
            return
        }
        try request.completion(response)
    }

    private func handleUnauthorizedResponse(request: Request, response: Response) throws {
        guard !request.dueToAuthenticationFailure else {
            delegate.rtspClientErrorToast(title: String(localized: "Wrong RTSP username or password"))
            throw "Wrong username or password"
        }
        guard username != nil, password != nil else {
            delegate.rtspClientErrorToast(title: String(localized: "RTSP username or password missing"))
            throw "Username or password missing."
        }
        guard let wwwAuthenticate = response.headers["www-authenticate"] else {
            throw "Missing authenticate field when authentication failed."
        }
        guard wwwAuthenticate.starts(with: "Digest ") else {
            delegate.rtspClientErrorToast(
                title: String(localized: "RTSP only supports Digest authentication")
            )
            throw "Only Digest authentication is supported."
        }
        let index = wwwAuthenticate.index(wwwAuthenticate.startIndex, offsetBy: 7)
        for parameter in wwwAuthenticate.suffix(from: index).split(separator: /,\s*/) {
            let (name, value) = try partition(text: String(parameter), separator: "=")
            switch name {
            case "realm":
                realm = value.trimmingCharacters(in: ["\""])
            case "nonce":
                nonce = value.trimmingCharacters(in: ["\""])
            case "algorithm":
                if value.trimmingCharacters(in: ["\""]) != "MD5" {
                    delegate.rtspClientErrorToast(
                        title: String(localized: "RTSP only supports MD5 algorithm in authentication")
                    )
                    throw "Only authentication using MD5 algorithm is supported."
                }
            default:
                break
            }
        }
    }

    private func keepAlive() {
        guard isAlive else {
            reconnectSoon()
            return
        }
        isAlive = false
        performGetParameter()
    }

    private func performOptions() {
        perform(request: Request(method: "OPTIONS", url: url) { _ in
            self.performDescribe()
        })
    }

    private func performGetParameter() {
        perform(request: Request(method: "GET_PARAMETER", url: url) { _ in
            self.isAlive = true
        })
    }

    private func performDescribe() {
        let headers = [
            "Accept": "application/sdp",
        ]
        perform(request: Request(method: "DESCRIBE", url: url, headers: headers) { response in
            try self.handleDescribeResponse(response: response)
        })
    }

    private func handleDescribeResponse(response: Response) throws {
        guard let content = response.content, let content = String(data: content, encoding: .utf8) else {
            throw "Bad or missing DESCRIBE content."
        }
        let baseUrl = response.headers["content-base"] ?? url.absoluteString
        let sdp = try Sdp(value: content)
        switch sdp.video?.codec {
        case let .h264(sdpVideo):
            try setupH264(sdpVideo: sdpVideo)
        case let .h265(sdpVideo):
            try setupH265(sdpVideo: sdpVideo)
        default:
            throw "No video media found."
        }
        try performSetup(url: makeSetupUrl(baseUrl: baseUrl, controlUrl: sdp.video?.control))
    }

    private func makeSetupUrl(baseUrl: String, controlUrl: URL?) throws -> URL {
        if let controlUrl {
            if controlUrl.host() != nil {
                return controlUrl
            } else if let url = URL(string: baseUrl + controlUrl.path) {
                return url
            } else {
                throw "Bad control URL: \(controlUrl)"
            }
        }
        return url
    }

    private func setupH264(sdpVideo: SdpVideoH264) throws {
        let nalUnits = [sdpVideo.sps, sdpVideo.pps]
        let formatDescription = nalUnits.makeFormatDescription()
        guard let formatDescription else {
            throw "Failed to create H.264 format description."
        }
        rtpVideo.processor = RtpProcessorVideoH264(formatDescription: formatDescription, client: self)
    }

    private func setupH265(sdpVideo: SdpVideoH265) throws {
        let nalUnits = [sdpVideo.vps, sdpVideo.sps, sdpVideo.pps]
        let formatDescription = nalUnits.makeFormatDescription()
        guard let formatDescription else {
            throw "Failed to create H.265 format description."
        }
        rtpVideo.processor = RtpProcessorVideoH265(formatDescription: formatDescription, client: self)
    }

    private func performSetup(url: URL) {
        guard let transport else {
            return
        }
        let headers = [
            "Transport": transport.setupTransportHeader(),
        ]
        perform(request: Request(method: "SETUP", url: url, headers: headers) { response in
            try self.handleSetupResponse(response: response)
        })
    }

    private func handleSetupResponse(response: Response) throws {
        guard let session = response.headers["session"] else {
            throw "Session header missing."
        }
        guard let transportHeader = response.headers["transport"] else {
            throw "Transport header missing."
        }
        (videoSession, _) = try partition(text: session, optionalSeparator: ";")
        try transport?.handleSetupTransportResponse(transportHeader)
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
        perform(request: Request(method: "PLAY", url: url, headers: headers) { response in
            self.handlePlayResponse(response: response)
        })
    }

    private func handlePlayResponse(response _: Response) {
        setState(newState: .streaming)
        connectTimer.stop()
        keepAliveTimer.startPeriodic(interval: 5) { [weak self] in
            self?.keepAlive()
        }
    }

    func videoOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        delegate.rtspClientOnVideoBuffer(cameraId: cameraId, sampleBuffer)
    }

    private func createTransport() -> RtspTransport {
        switch transportType {
        case .rtpRtspTcp:
            return RtspTransportRtpRtspTcp()
        case .rtpUdp:
            return RtspTransportRtpUdp()
        }
    }
}

extension RtspClient: RtspTransportDelegate {
    func rtspTransportConnected() {
        setState(newState: .setup)
        performOptions()
    }

    func rtspTransportDisconnected() {}

    func rtspTransportReceivedRtspMessage(header: Data, content: Data?) {
        do {
            try handleRtspMessage(header: header, content: content)
        } catch {
            logger.debug("rtsp-client: Error handling RTSP message: \(error)")
        }
    }

    func rtspTransportReceivedRtpPacket(_ packet: Data) {
        bitrateStats.add(bytesTransferred: packet.count)
        do {
            try rtpVideo.handlePacket(packet: packet)
        } catch {
            logger.debug("rtsp-client: Error handling RTP packet: \(error)")
        }
    }

    func rtspTransportReceivedRtcpPacket(_ packet: Data) {
        bitrateStats.add(bytesTransferred: packet.count)
        handleRtcpVideoPacket(packet: packet)
    }

    func rtspTransportBytesReceived(count: Int) {
        bitrateStats.add(bytesTransferred: count)
    }
}
