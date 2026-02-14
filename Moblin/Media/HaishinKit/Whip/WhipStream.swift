import AVFoundation
import libdatachannel

private let whipQueue = DispatchQueue(label: "com.eerimoq.Moblin.whip")
private let h264PayloadType: UInt8 = 96
private let h265PayloadType: UInt8 = 97
private let opusPayloadType: UInt8 = 111
private let aacPayloadType: UInt8 = 112
private let videoNackMaxStoredPacketCount: UInt32 = 8192
private let audioNackMaxStoredPacketCount: UInt32 = 512

private func makeSsrc() -> UInt32 {
    var ssrc: UInt32 = 0
    while ssrc == 0 {
        ssrc = UInt32.random(in: UInt32.min ... UInt32.max)
    }
    return ssrc
}

private func checkOkReturnResult(_ result: Int32) throws -> Int32 {
    guard result >= 0 else {
        throw "Error \(result)"
    }
    return result
}

private func checkOk(_ result: Int32) throws {
    _ = try checkOkReturnResult(result)
}

private enum ConnectionState {
    case new
    case connecting
    case connected
    case disconnected
    case failed
    case closed

    init?(value: rtcState) {
        switch value {
        case RTC_NEW:
            self = .new
        case RTC_CONNECTING:
            self = .connecting
        case RTC_CONNECTED:
            self = .connected
        case RTC_DISCONNECTED:
            self = .disconnected
        case RTC_FAILED:
            self = .failed
        case RTC_CLOSED:
            self = .closed
        default:
            return nil
        }
    }
}

private enum GatheringState {
    case new
    case inProgress
    case complete

    init?(value: rtcGatheringState) {
        switch value {
        case RTC_GATHERING_NEW:
            self = .new
        case RTC_GATHERING_INPROGRESS:
            self = .inProgress
        case RTC_GATHERING_COMPLETE:
            self = .complete
        default:
            return nil
        }
    }
}

private func makeEndpointUrl(url: String) -> URL? {
    guard var components = URLComponents(string: url) else {
        return nil
    }
    components.scheme = components.scheme?.replacing("whip", with: "http")
    return components.url
}

private enum TrackState {
    case connecting
    case open
    case closed
}

private final class H264NalUnits {
    private var sps: Data?
    private var pps: Data?

    func setParameterSets(sps: Data?, pps: Data?) {
        self.sps = sps
        self.pps = pps
    }

    func process(_ sampleBuffer: CMSampleBuffer) -> Data? {
        guard let (buffer, length) = sampleBuffer.dataBuffer?.getDataPointer() else {
            return nil
        }
        let sampleData = Data(bytes: buffer, count: length)
        guard !sampleData.isEmpty else {
            return nil
        }
        if sampleBuffer.getIsSync() {
            var data = Data()
            if let sps {
                appendNalUnit(&data, sps)
            }
            if let pps {
                appendNalUnit(&data, pps)
            }
            data.append(sampleData)
            return data
        }
        return sampleData
    }

    private func appendNalUnit(_ data: inout Data, _ nalUnit: Data) {
        var length = UInt32(nalUnit.count).bigEndian
        data.append(Data(bytes: &length, count: 4))
        data.append(nalUnit)
    }
}

private final class H265NalUnits {
    private var vps: Data?
    private var sps: Data?
    private var pps: Data?

    func setParameterSets(vps: Data?, sps: Data?, pps: Data?) {
        self.vps = vps
        self.sps = sps
        self.pps = pps
    }

    func process(_ sampleBuffer: CMSampleBuffer) -> Data? {
        guard let (buffer, length) = sampleBuffer.dataBuffer?.getDataPointer() else {
            return nil
        }
        let sampleData = Data(bytes: buffer, count: length)
        guard !sampleData.isEmpty else {
            return nil
        }
        if sampleBuffer.getIsSync() {
            var data = Data()
            if let vps {
                appendNalUnit(&data, vps)
            }
            if let sps {
                appendNalUnit(&data, sps)
            }
            if let pps {
                appendNalUnit(&data, pps)
            }
            data.append(sampleData)
            return data
        }
        return sampleData
    }

    private func appendNalUnit(_ data: inout Data, _ nalUnit: Data) {
        var length = UInt32(nalUnit.count).bigEndian
        data.append(Data(bytes: &length, count: 4))
        data.append(nalUnit)
    }
}

private func toRtcTrack(pointer: UnsafeMutableRawPointer?) -> RtcTrack? {
    guard let pointer else {
        return nil
    }
    return Unmanaged<RtcTrack>.fromOpaque(pointer).takeUnretainedValue()
}

private final class RtcTrack {
    private let trackId: Int32
    private var state: TrackState = .connecting

    init(trackId: Int32) throws {
        self.trackId = trackId
        do {
            rtcSetUserPointer(trackId, Unmanaged.passUnretained(self).toOpaque())
            try checkOk(rtcSetOpenCallback(trackId) { _, pointer in
                toRtcTrack(pointer: pointer)?.setState(state: .open)
            })
            try checkOk(rtcSetClosedCallback(trackId) { _, pointer in
                toRtcTrack(pointer: pointer)?.setState(state: .closed)
            })
            try checkOk(rtcSetErrorCallback(trackId) { _, _, pointer in
                toRtcTrack(pointer: pointer)?.setState(state: .closed)
            })
        } catch {
            rtcDeleteTrack(trackId)
            throw error
        }
    }

    deinit {
        rtcDeleteTrack(trackId)
    }

    func setTimestamp(presentationTimeStamp: Double) throws {
        var timestamp: UInt32 = 0
        try checkOk(rtcTransformSecondsToTimestamp(trackId, presentationTimeStamp, &timestamp))
        try checkOk(rtcSetTrackRtpTimestamp(trackId, timestamp))
    }

    func send(message: Data) -> Bool {
        guard state == .open else {
            return false
        }
        let result = message.withUnsafeBytes { pointer in
            rtcSendMessage(trackId, pointer.bindMemory(to: CChar.self).baseAddress, Int32(message.count))
        }
        return result >= 0
    }

    private func setState(state: TrackState) {
        self.state = state
    }
}

private struct RtcTrackConfig {
    let name: String
    let codec: rtcCodec
    let payloadType: Int32
    let ssrc: UInt32
    let mid: String
    let profile: String
    let bitrate: Double

    static func makeAudio(ssrc: UInt32, codec: SettingsStreamAudioCodec) -> Self {
        switch codec {
        case .opus:
            return .init(name: "audio",
                         codec: RTC_CODEC_OPUS,
                         payloadType: Int32(opusPayloadType),
                         ssrc: ssrc,
                         mid: "0",
                         profile: "",
                         bitrate: 0)
        case .aac:
            return .init(name: "audio",
                         codec: RTC_CODEC_AAC,
                         payloadType: Int32(aacPayloadType),
                         ssrc: ssrc,
                         mid: "0",
                         profile: "",
                         bitrate: 0)
        }
    }

    static func makeVideo(ssrc: UInt32, codec: SettingsStreamCodec, bitrate: Double) -> Self {
        switch codec {
        case .h264avc:
            return .init(name: "video",
                         codec: RTC_CODEC_H264,
                         payloadType: Int32(h264PayloadType),
                         ssrc: ssrc,
                         mid: "1",
                         profile: "level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f",
                         bitrate: bitrate)
        case .h265hevc:
            return .init(name: "video",
                         codec: RTC_CODEC_H265,
                         payloadType: Int32(h265PayloadType),
                         ssrc: ssrc,
                         mid: "1",
                         profile: "",
                         bitrate: bitrate)
        }
    }

    func isVideo() -> Bool {
        switch codec {
        case RTC_CODEC_H264:
            return true
        case RTC_CODEC_H265:
            return true
        default:
            return false
        }
    }
}

private protocol PeerConnectionDelegate: AnyObject {
    func peerConnectionOnConnectionStateChanged(state: ConnectionState)
    func peerConnectionOnGatheringStateChanged(state: GatheringState)
}

private func toPeerConnection(pointer: UnsafeMutableRawPointer?) -> PeerConnection? {
    guard let pointer else {
        return nil
    }
    return Unmanaged<PeerConnection>.fromOpaque(pointer).takeUnretainedValue()
}

private final class PeerConnection {
    private let peerConnectionId: Int32
    weak var delegate: PeerConnectionDelegate?

    init(delegate: PeerConnectionDelegate, iceServers: [String]) throws {
        self.delegate = delegate
        var config = rtcConfiguration()
        peerConnectionId = iceServers.withCPointers {
            config.iceServers = $0
            config.iceServersCount = Int32(iceServers.count)
            return rtcCreatePeerConnection(&config)
        }
        try checkOk(peerConnectionId)
        do {
            rtcSetUserPointer(peerConnectionId, Unmanaged.passUnretained(self).toOpaque())
            try checkOk(rtcSetStateChangeCallback(peerConnectionId) { _, state, pointer in
                toPeerConnection(pointer: pointer)?.handleStateChange(state: state)
            })
            try checkOk(rtcSetGatheringStateChangeCallback(peerConnectionId) { _, state, pointer in
                toPeerConnection(pointer: pointer)?.handleGatheringStateChange(state: state)
            })
        } catch {
            rtcDeletePeerConnection(peerConnectionId)
            throw error
        }
    }

    deinit {
        rtcDeletePeerConnection(peerConnectionId)
    }

    func close() {
        _ = rtcClosePeerConnection(peerConnectionId)
    }

    func addTrack(config: RtcTrackConfig, streamId: String) throws -> RtcTrack {
        return try config.mid.withCString { mid in
            try config.name.withCString { name in
                try streamId.withCString { streamId in
                    try UUID().uuidString.withCString { trackId in
                        try config.profile.withCString { profile in
                            var trackInit = rtcTrackInit(
                                direction: RTC_DIRECTION_SENDONLY,
                                codec: config.codec,
                                payloadType: config.payloadType,
                                ssrc: config.ssrc,
                                mid: mid,
                                name: name,
                                msid: streamId,
                                trackId: trackId,
                                profile: profile
                            )
                            let trackId = try checkOkReturnResult(rtcAddTrackEx(peerConnectionId, &trackInit))
                            var packetizerInit = rtcPacketizerInit()
                            packetizerInit.ssrc = config.ssrc
                            packetizerInit.cname = name
                            packetizerInit.payloadType = UInt8(config.payloadType)
                            let nackMaxStoredPacketCount: UInt32
                            if config.isVideo() {
                                packetizerInit.clockRate = 90000
                                switch config.codec {
                                case RTC_CODEC_H264:
                                    try checkOk(rtcSetH264Packetizer(trackId, &packetizerInit))
                                case RTC_CODEC_H265:
                                    try checkOk(rtcSetH265Packetizer(trackId, &packetizerInit))
                                default:
                                    throw "Unsupported video codec \(config.codec)"
                                }
                                if false {
                                    try checkOk(rtcChainPacingHandler(trackId, 1.2 * config.bitrate, 5))
                                }
                                nackMaxStoredPacketCount = videoNackMaxStoredPacketCount
                            } else {
                                packetizerInit.clockRate = 48000
                                switch config.codec {
                                case RTC_CODEC_AAC:
                                    try checkOk(rtcSetAACPacketizer(trackId, &packetizerInit))
                                case RTC_CODEC_OPUS:
                                    try checkOk(rtcSetOpusPacketizer(trackId, &packetizerInit))
                                default:
                                    throw "Unsupported audio codec \(config.codec)"
                                }
                                nackMaxStoredPacketCount = audioNackMaxStoredPacketCount
                            }
                            try checkOk(rtcChainRtcpSrReporter(trackId))
                            try checkOk(rtcChainRtcpNackResponder(trackId, nackMaxStoredPacketCount))
                            return try RtcTrack(trackId: trackId)
                        }
                    }
                }
            }
        }
    }

    func setLocalDescriptionOffer() throws {
        try checkOk(rtcSetLocalDescription(peerConnectionId, "offer"))
    }

    func getLocalDescription() throws -> String {
        let size = try checkOkReturnResult(rtcGetLocalDescription(peerConnectionId, nil, 0))
        var buffer = [CChar](repeating: 0, count: Int(size))
        try checkOk(rtcGetLocalDescription(peerConnectionId, &buffer, Int32(size)))
        return String(cString: buffer)
    }

    func setRemoteAnswer(_ sdp: String) throws {
        try checkOk(rtcSetRemoteDescription(peerConnectionId, sdp, "answer"))
    }

    func getSelectedCandidatePair() -> (local: String, remote: String)? {
        do {
            var local = Data(count: 1024)
            var remote = Data(count: 1024)
            try local.withUnsafeMutableBytes { (localPointer: UnsafeMutableRawBufferPointer) in
                try remote.withUnsafeMutableBytes { (remotePointer: UnsafeMutableRawBufferPointer) in
                    try checkOk(rtcGetSelectedCandidatePair(peerConnectionId,
                                                            localPointer.baseAddress,
                                                            Int32(localPointer.count),
                                                            remotePointer.baseAddress,
                                                            Int32(remotePointer.count)))
                }
            }
            guard let local = String(bytes: local, encoding: .utf8) else {
                return nil
            }
            guard let remote = String(bytes: remote, encoding: .utf8) else {
                return nil
            }
            return (local, remote)
        } catch {
            logger.info("whip: Failed to get selected candidate pair")
            return nil
        }
    }

    private func handleStateChange(state: rtcState) {
        guard let state = ConnectionState(value: state) else {
            return
        }
        delegate?.peerConnectionOnConnectionStateChanged(state: state)
    }

    private func handleGatheringStateChange(state: rtcGatheringState) {
        guard let state = GatheringState(value: state) else {
            return
        }
        delegate?.peerConnectionOnGatheringStateChanged(state: state)
    }
}

protocol WhipStreamDelegate: AnyObject {
    func whipStreamOnConnected()
    func whipStreamOnDisconnected(reason: String)
}

final class WhipStream {
    private let processor: Processor
    private weak var delegate: WhipStreamDelegate?
    private var peerConnection: PeerConnection?
    private var videoTrack: RtcTrack?
    private var audioTrack: RtcTrack?
    private var h264NalUnits = H264NalUnits()
    private var h265NalUnits = H265NalUnits()
    private var videoCodec: SettingsStreamCodec = .h264avc
    private var totalByteCount: Int64 = 0
    private var sessionUrl: URL?
    private var endpointUrl: URL?
    private var headers: [SettingsHttpHeader] = []
    private var connected = false
    private var offerSent = false
    private var firstPresentationTimeStamp: Double = .nan
    private let connectTimer = SimpleTimer(queue: whipQueue)

    init(processor: Processor, delegate: WhipStreamDelegate) {
        self.processor = processor
        self.delegate = delegate
    }

    func start(url: String,
               headers: [SettingsHttpHeader],
               iceServers: [String],
               videoCodec: SettingsStreamCodec,
               audioCodec: SettingsStreamAudioCodec,
               videoBitrate: Double)
    {
        whipQueue.async {
            self.startInternal(url: url,
                               headers: headers,
                               iceServers: iceServers,
                               videoCodec: videoCodec,
                               audioCodec: audioCodec,
                               videoBitrate: videoBitrate)
        }
    }

    func stop() {
        whipQueue.async {
            self.stopInternal()
        }
    }

    func getTotalByteCount() -> Int64 {
        return whipQueue.sync {
            totalByteCount
        }
    }

    private func startInternal(url: String,
                               headers: [SettingsHttpHeader],
                               iceServers: [String],
                               videoCodec: SettingsStreamCodec,
                               audioCodec: SettingsStreamAudioCodec,
                               videoBitrate: Double)
    {
        stopInternal()
        guard let endpointUrl = makeEndpointUrl(url: url) else {
            return
        }
        self.endpointUrl = endpointUrl
        self.headers = headers
        self.videoCodec = videoCodec
        totalByteCount = 0
        connected = false
        offerSent = false
        logger.info("whip: Start URL: \(endpointUrl.absoluteString)")
        h264NalUnits = H264NalUnits()
        h265NalUnits = H265NalUnits()
        do {
            let peerConnection = try PeerConnection(delegate: self, iceServers: iceServers)
            let streamId = UUID().uuidString
            audioTrack = try peerConnection.addTrack(
                config: .makeAudio(ssrc: makeSsrc(), codec: audioCodec),
                streamId: streamId
            )
            videoTrack = try peerConnection.addTrack(
                config: .makeVideo(ssrc: makeSsrc(), codec: videoCodec, bitrate: videoBitrate),
                streamId: streamId
            )
            self.peerConnection = peerConnection
            try peerConnection.setLocalDescriptionOffer()
            connectTimer.startSingleShot(timeout: 10) { [weak self] in
                self?.handleConnectTimeout()
            }
        } catch {
            stopInternal(reason: "Start failed: \(error)")
        }
    }

    private func stopInternal(reason: String? = nil) {
        stopEncoding()
        if let sessionUrl {
            sendDeleteRequest(url: sessionUrl)
        }
        sessionUrl = nil
        endpointUrl = nil
        peerConnection?.close()
        peerConnection = nil
        videoTrack = nil
        audioTrack = nil
        connected = false
        offerSent = false
        connectTimer.stop()
        if let reason {
            notifyDisconnected(reason: reason)
        }
    }

    private func handleConnectTimeout() {
        stopInternal(reason: "Connect timeout")
    }

    private func handleConnectionStateChanged(state: ConnectionState) {
        logger.info("whip: Connection state: \(state)")
        switch state {
        case .connected:
            guard !connected else {
                return
            }
            connectTimer.stop()
            connected = true
            if let (local, remote) = peerConnection?.getSelectedCandidatePair() {
                logger.info("whip: Local candidate: \(local)")
                logger.info("whip: Remote candidate: \(remote)")
            }
            startEncoding()
            notifyConnected()
        case .disconnected, .failed, .closed:
            stopInternal(reason: "Connection \(state)")
        case .new, .connecting:
            break
        }
    }

    private func handleGatheringStateChanged(state: GatheringState) {
        logger.info("whip: ICE gathering state: \(state)")
        switch state {
        case .complete:
            guard let peerConnection else {
                return
            }
            do {
                try sendOffer(offer: peerConnection.getLocalDescription())
            } catch {
                stopInternal(reason: "Failed to create offer")
            }
        case .new, .inProgress:
            break
        }
    }

    private func sendOffer(offer: String) {
        guard !offerSent, let endpointUrl else {
            return
        }
        logger.debug("whip: Sending offer: \(offer.replacingOccurrences(of: "\r", with: ""))")
        var request = URLRequest(url: endpointUrl)
        request.httpMethod = "POST"
        request.setContentType("application/sdp")
        for header in headers {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }
        request.httpBody = offer.utf8Data
        httpRequest(request: request, queue: whipQueue) { [weak self] data, response, error in
            self?.handleOfferResponse(data: data, response: response, error: error)
        }
        offerSent = true
    }

    private func handleOfferResponse(data: Data?, response: URLResponse?, error: (any Error)?) {
        if let error {
            stopInternal(reason: "Sending WHIP offer failed: \(error.localizedDescription)")
            return
        }
        guard let response = response?.http else {
            stopInternal(reason: "Bad WHIP server response")
            return
        }
        guard response.isSuccessful else {
            stopInternal(reason: "WHIP server returned HTTP status \(response.statusCode)")
            return
        }
        if let locationHeader = response.value(forHTTPHeaderField: "Location") {
            sessionUrl = URL(string: locationHeader, relativeTo: endpointUrl)
        }
        guard let data, let answer = String(data: data, encoding: .utf8) else {
            stopInternal(reason: "WHIP answer missing")
            return
        }
        logger.debug("whip: Got answer: \(answer.replacingOccurrences(of: "\r", with: ""))")
        do {
            try peerConnection?.setRemoteAnswer(answer)
        } catch {
            stopInternal(reason: "Failed to set remote answer")
        }
    }

    private func sendDeleteRequest(url: URL) {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        httpRequest(request: request)
    }

    private func startEncoding() {
        processorControlQueue.async {
            self.processor.startEncoding(self)
        }
    }

    private func stopEncoding() {
        processorControlQueue.async {
            self.processor.stopEncoding(self)
        }
    }

    private func notifyConnected() {
        delegate?.whipStreamOnConnected()
    }

    private func notifyDisconnected(reason: String) {
        delegate?.whipStreamOnDisconnected(reason: reason)
    }

    private func rebaseTimestamp(_ presentationTimeStamp: CMTime) -> Double? {
        if firstPresentationTimeStamp.isNaN {
            firstPresentationTimeStamp = presentationTimeStamp.seconds
        }
        let presentationTimeStamp = presentationTimeStamp.seconds - firstPresentationTimeStamp
        guard presentationTimeStamp > 0 else {
            return nil
        }
        return presentationTimeStamp
    }

    private func handleAudioEncoderOutputBuffer(_ buffer: AVAudioCompressedBuffer,
                                                _ presentationTimeStamp: CMTime)
    {
        guard connected, let audioTrack else {
            return
        }
        guard let presentationTimeStamp = rebaseTimestamp(presentationTimeStamp) else {
            return
        }
        guard buffer.byteLength > 0 else {
            return
        }
        do {
            try audioTrack.setTimestamp(presentationTimeStamp: presentationTimeStamp)
        } catch {
            logger.info("whip: Failed to set audio timestamp")
            return
        }
        let allData = Data(bytes: buffer.data, count: Int(buffer.byteLength))
        guard buffer.packetCount > 0, let descriptions = buffer.packetDescriptions else {
            if audioTrack.send(message: allData) {
                totalByteCount += Int64(allData.count)
            }
            return
        }
        for index in 0 ..< Int(buffer.packetCount) {
            let description = descriptions[index]
            let offset = Int(description.mStartOffset)
            let size = Int(description.mDataByteSize)
            guard size > 0, offset >= 0, offset + size <= allData.count else {
                continue
            }
            let packet = allData.subdata(in: offset ..< offset + size)
            if audioTrack.send(message: packet) {
                totalByteCount += Int64(packet.count)
            }
        }
    }

    private func handleVideoEncoderOutputFormat(_ formatDescription: CMFormatDescription) {
        switch videoCodec {
        case .h264avc:
            guard let config = MpegTsVideoConfigAvc(formatDescription: formatDescription) else {
                return
            }
            h264NalUnits.setParameterSets(sps: config.sequenceParameterSet, pps: config.pictureParameterSet)
        case .h265hevc:
            guard let config = MpegTsVideoConfigHevc(formatDescription: formatDescription) else {
                return
            }
            h265NalUnits.setParameterSets(vps: config.videoParameterSet,
                                          sps: config.sequenceParameterSet,
                                          pps: config.pictureParameterSet)
        }
    }

    private func handleVideoEncoderOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard connected, let videoTrack else {
            return
        }
        guard let presentationTimeStamp = rebaseTimestamp(sampleBuffer.presentationTimeStamp) else {
            return
        }
        do {
            try videoTrack.setTimestamp(presentationTimeStamp: presentationTimeStamp)
        } catch {
            logger.info("whip: Failed to set timestamp")
            return
        }
        let data: Data?
        switch videoCodec {
        case .h264avc:
            data = h264NalUnits.process(sampleBuffer)
        case .h265hevc:
            data = h265NalUnits.process(sampleBuffer)
        }
        guard let data else {
            return
        }
        if videoTrack.send(message: data) {
            totalByteCount += Int64(data.count)
        }
    }
}

extension WhipStream: PeerConnectionDelegate {
    fileprivate func peerConnectionOnConnectionStateChanged(state: ConnectionState) {
        whipQueue.async {
            self.handleConnectionStateChanged(state: state)
        }
    }

    fileprivate func peerConnectionOnGatheringStateChanged(state: GatheringState) {
        whipQueue.async {
            self.handleGatheringStateChanged(state: state)
        }
    }
}

extension WhipStream: AudioEncoderDelegate {
    func audioEncoderOutputFormat(_: AVAudioFormat) {}

    func audioEncoderOutputBuffer(_ buffer: AVAudioCompressedBuffer, _ presentationTimeStamp: CMTime) {
        whipQueue.async {
            self.handleAudioEncoderOutputBuffer(buffer, presentationTimeStamp)
        }
    }
}

extension WhipStream: VideoEncoderDelegate {
    func videoEncoderOutputFormat(_: VideoEncoder, _ formatDescription: CMFormatDescription) {
        whipQueue.async {
            self.handleVideoEncoderOutputFormat(formatDescription)
        }
    }

    func videoEncoderOutputSampleBuffer(_: VideoEncoder,
                                        _ sampleBuffer: CMSampleBuffer,
                                        _: CMTime)
    {
        whipQueue.async {
            self.handleVideoEncoderOutputSampleBuffer(sampleBuffer)
        }
    }
}
