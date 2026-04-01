import AVFoundation
import CoreMedia
import DataChannel
import libdatachannel

let whipClientDispatchQueue = DispatchQueue(label: "com.eerimoq.whip-client")

protocol WhipClientDelegate: AnyObject {
    func whipClientOnConnected(cameraId: UUID)
    func whipClientOnDisconnected(cameraId: UUID, reason: String)
    func whipClientOnVideoBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer)
    func whipClientOnAudioBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer)
    func whipClientSetTargetLatencies(
        cameraId: UUID,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    )
}

private func toWhipClient(pointer: UnsafeMutableRawPointer?) -> WhipClient? {
    guard let pointer else {
        return nil
    }
    return Unmanaged<WhipClient>.fromOpaque(pointer).takeUnretainedValue()
}

private func makeEndpointUrl(url: String) -> URL? {
    guard var components = URLComponents(string: url) else {
        return nil
    }
    components.scheme = components.scheme?.replacing("whip", with: "http")
    return components.url
}

final class WhipClient {
    let cameraId: UUID
    private let latency: Double
    private var peerConnectionId: Int32 = -1
    weak var delegate: WhipClientDelegate?
    private var connected = false
    private var videoDecoder: VideoDecoder?
    private var videoFormatDescription: CMFormatDescription?
    private var basePresentationTimeStamp: Double = -1
    private var timeStampRebaser = TimeStampRebaser()
    private var opusAudioConverter: AVAudioConverter?
    private var opusCompressedBuffer: AVAudioCompressedBuffer?
    private var pcmAudioFormat: AVAudioFormat?
    private var pcmAudioBuffer: AVAudioPCMBuffer?
    private var targetLatenciesSynchronizer: TargetLatenciesSynchronizer
    private var h264TrackId: Int32 = -1
    private var h265TrackId: Int32 = -1
    private var audioTrackId: Int32 = -1
    private var sessionUrl: URL?
    private var offerSent = false

    init(cameraId: UUID, latency: Double, delegate: WhipClientDelegate) {
        self.cameraId = cameraId
        self.latency = latency
        self.delegate = delegate
        targetLatenciesSynchronizer = TargetLatenciesSynchronizer(targetLatency: latency)
    }

    func start(url: String) {
        whipClientDispatchQueue.async {
            self.startInternal(url: url)
        }
    }

    func stop() {
        whipClientDispatchQueue.async {
            self.stopInternal()
        }
    }

    private func startInternal(url: String) {
        stopInternal()
        guard let endpointUrl = makeEndpointUrl(url: url) else {
            logger.info("whip-client: Invalid URL \(url)")
            return
        }
        logger.info("whip-client: Connecting to \(endpointUrl.absoluteString)")
        connected = false
        offerSent = false
        basePresentationTimeStamp = -1
        timeStampRebaser = TimeStampRebaser()
        targetLatenciesSynchronizer = TargetLatenciesSynchronizer(targetLatency: latency)
        do {
            try setupPeerConnection()
            try addReceiveTracks()
            try checkOk(rtcSetLocalDescription(peerConnectionId, "offer"))
            sessionUrl = endpointUrl
        } catch {
            logger.info("whip-client: Start failed: \(error)")
            stopInternal()
        }
    }

    private func setupPeerConnection() throws {
        var config = rtcConfiguration()
        let iceServers = ["stun:stun.l.google.com:19302"]
        peerConnectionId = iceServers.withCPointers {
            config.iceServers = $0
            config.iceServersCount = Int32(iceServers.count)
            return rtcCreatePeerConnection(&config)
        }
        guard peerConnectionId >= 0 else {
            throw "Failed to create peer connection"
        }
        rtcSetUserPointer(peerConnectionId, Unmanaged.passRetained(self).toOpaque())
        try checkOk(rtcSetStateChangeCallback(peerConnectionId) { _, state, pointer in
            toWhipClient(pointer: pointer)?.handleStateChange(state: state)
        })
        try checkOk(rtcSetGatheringStateChangeCallback(peerConnectionId) { _, state, pointer in
            toWhipClient(pointer: pointer)?.handleGatheringStateChange(state: state)
        })
    }

    private func addReceiveTracks() throws {
        let streamId = UUID().uuidString
        h264TrackId = try addVideoTrack(
            codec: RTC_CODEC_H264,
            payloadType: 96,
            mid: "1",
            profile: "level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f",
            streamId: streamId
        )
        rtcSetH264Depacketizer(h264TrackId, RTC_NAL_SEPARATOR_LONG_START_SEQUENCE)
        rtcChainRtcpReceivingSession(h264TrackId)
        rtcSetFrameCallback(h264TrackId) { _, data, size, info, pointer in
            guard let data, size > 0, let info, let pointer else {
                return
            }
            let frameData = Data(bytes: data, count: Int(size))
            let timestampSeconds = info.pointee.timestampSeconds
            toWhipClient(pointer: pointer)?.handleVideoMessage(
                codec: .h264,
                data: frameData,
                timestampSeconds: timestampSeconds
            )
        }
        h265TrackId = try addVideoTrack(
            codec: RTC_CODEC_H265,
            payloadType: 97,
            mid: "2",
            profile: "",
            streamId: streamId
        )
        rtcSetH265Depacketizer(h265TrackId, RTC_NAL_SEPARATOR_LONG_START_SEQUENCE)
        rtcChainRtcpReceivingSession(h265TrackId)
        rtcSetFrameCallback(h265TrackId) { _, data, size, info, pointer in
            guard let data, size > 0, let info, let pointer else {
                return
            }
            let frameData = Data(bytes: data, count: Int(size))
            let timestampSeconds = info.pointee.timestampSeconds
            toWhipClient(pointer: pointer)?.handleVideoMessage(
                codec: .h265,
                data: frameData,
                timestampSeconds: timestampSeconds
            )
        }
        audioTrackId = try addAudioTrack(streamId: streamId)
        setupOpusDecoder()
        rtcSetOpusDepacketizer(audioTrackId)
        rtcChainRtcpReceivingSession(audioTrackId)
        rtcSetFrameCallback(audioTrackId) { _, data, size, info, pointer in
            guard let data, size > 0, let info, let pointer else {
                return
            }
            let frameData = Data(bytes: data, count: Int(size))
            let timestampSeconds = info.pointee.timestampSeconds
            toWhipClient(pointer: pointer)?.handleAudioMessage(
                data: frameData,
                timestampSeconds: timestampSeconds
            )
        }
    }

    private func addVideoTrack(
        codec: rtcCodec,
        payloadType: Int32,
        mid: String,
        profile: String,
        streamId: String
    ) throws -> Int32 {
        return try mid.withCString { midPtr in
            try "video".withCString { namePtr in
                try streamId.withCString { streamIdPtr in
                    try UUID().uuidString.withCString { trackIdPtr in
                        try profile.withCString { profilePtr in
                            var trackInit = rtcTrackInit(
                                direction: RTC_DIRECTION_RECVONLY,
                                codec: codec,
                                payloadType: payloadType,
                                ssrc: 0,
                                mid: midPtr,
                                name: namePtr,
                                msid: streamIdPtr,
                                trackId: trackIdPtr,
                                profile: profilePtr
                            )
                            let id = rtcAddTrackEx(peerConnectionId, &trackInit)
                            guard id >= 0 else {
                                throw "Failed to add video track"
                            }
                            rtcSetUserPointer(id, Unmanaged.passRetained(self).toOpaque())
                            return id
                        }
                    }
                }
            }
        }
    }

    private func addAudioTrack(streamId: String) throws -> Int32 {
        return try "0".withCString { midPtr in
            try "audio".withCString { namePtr in
                try streamId.withCString { streamIdPtr in
                    try UUID().uuidString.withCString { trackIdPtr in
                        try "".withCString { profilePtr in
                            var trackInit = rtcTrackInit(
                                direction: RTC_DIRECTION_RECVONLY,
                                codec: RTC_CODEC_OPUS,
                                payloadType: 111,
                                ssrc: 0,
                                mid: midPtr,
                                name: namePtr,
                                msid: streamIdPtr,
                                trackId: trackIdPtr,
                                profile: profilePtr
                            )
                            let id = rtcAddTrackEx(peerConnectionId, &trackInit)
                            guard id >= 0 else {
                                throw "Failed to add audio track"
                            }
                            rtcSetUserPointer(id, Unmanaged.passRetained(self).toOpaque())
                            return id
                        }
                    }
                }
            }
        }
    }

    private func stopInternal(reason: String? = nil) {
        videoDecoder?.stopRunning()
        videoDecoder = nil
        videoFormatDescription = nil
        opusAudioConverter = nil
        opusCompressedBuffer = nil
        pcmAudioBuffer = nil
        if let sessionUrl, connected {
            sendDeleteRequest(url: sessionUrl)
        }
        sessionUrl = nil
        h264TrackId = -1
        h265TrackId = -1
        audioTrackId = -1
        rtcDeletePeerConnection(peerConnectionId)
        peerConnectionId = -1
        connected = false
        offerSent = false
        if let reason {
            delegate?.whipClientOnDisconnected(cameraId: cameraId, reason: reason)
        }
    }

    private func sendDeleteRequest(url: URL) {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        URLSession.shared.dataTask(with: request).resume()
    }

    private func handleStateChange(state: rtcState) {
        whipClientDispatchQueue.async {
            self.handleStateChangeInternal(state: state)
        }
    }

    private func handleStateChangeInternal(state: rtcState) {
        guard let state = DataChannelConnectionState(value: state) else {
            return
        }
        logger.info("whip-client: Connection state: \(state)")
        switch state {
        case .connected:
            guard !connected else {
                return
            }
            connected = true
            delegate?.whipClientOnConnected(cameraId: cameraId)
        case .disconnected, .failed, .closed:
            stopInternal(reason: "Connection \(state)")
        case .new, .connecting:
            break
        }
    }

    private func handleGatheringStateChange(state: rtcGatheringState) {
        whipClientDispatchQueue.async {
            self.handleGatheringStateChangeInternal(state: state)
        }
    }

    private func handleGatheringStateChangeInternal(state: rtcGatheringState) {
        guard let state = DataChannelGatheringState(value: state) else {
            return
        }
        logger.info("whip-client: ICE gathering state: \(state)")
        switch state {
        case .complete:
            guard !offerSent else {
                return
            }
            do {
                try sendOffer(offer: getLocalDescription())
            } catch {
                stopInternal(reason: "Failed to get local description: \(error)")
            }
        case .new, .inProgress:
            break
        }
    }

    private func sendOffer(offer: String) throws {
        guard let sessionUrl else {
            return
        }
        logger.debug("whip-client: Sending offer")
        offerSent = true
        var request = URLRequest(url: sessionUrl)
        request.httpMethod = "POST"
        request.setValue("application/sdp", forHTTPHeaderField: "Content-Type")
        request.httpBody = offer.utf8Data
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            whipClientDispatchQueue.async {
                self?.handleOfferResponse(data: data, response: response, error: error)
            }
        }.resume()
    }

    private func handleOfferResponse(data: Data?, response: URLResponse?, error: (any Error)?) {
        if let error {
            stopInternal(reason: "Sending offer failed: \(error.localizedDescription)")
            return
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            stopInternal(reason: "Bad server response")
            return
        }
        guard httpResponse.statusCode == 201 else {
            stopInternal(reason: "Server returned HTTP \(httpResponse.statusCode)")
            return
        }
        guard let data, let sdpAnswer = String(data: data, encoding: .utf8) else {
            stopInternal(reason: "Bad SDP answer from server")
            return
        }
        if let location = httpResponse.value(forHTTPHeaderField: "Location") {
            if let locationUrl = URL(string: location) {
                sessionUrl = locationUrl
            }
        }
        do {
            try checkOk(rtcSetRemoteDescription(peerConnectionId, sdpAnswer, "answer"))
        } catch {
            stopInternal(reason: "Failed to set remote description: \(error)")
        }
    }

    private func handleVideoMessage(codec: VideoCodec, data: Data, timestampSeconds: Double) {
        whipClientDispatchQueue.async {
            self.handleVideoMessageInternal(codec: codec, data: data, timestampSeconds: timestampSeconds)
        }
    }

    private func handleVideoMessageInternal(codec: VideoCodec, data: Data, timestampSeconds: Double) {
        var frameData = data
        let nalUnits = getNalUnits(data: frameData)
        let formatDescription: CMFormatDescription?
        switch codec {
        case .h264:
            let units = readH264NalUnits(data: frameData,
                                         nalUnits: nalUnits,
                                         filter: [.sps, .pps, .idr])
            formatDescription = units.makeFormatDescription()
        case .h265:
            let units = readH265NalUnits(data: frameData,
                                         nalUnits: nalUnits,
                                         filter: [.sps, .pps, .vps])
            formatDescription = units.makeFormatDescription()
        }
        if let formatDescription, videoFormatDescription != formatDescription {
            videoFormatDescription = formatDescription
            videoDecoder?.stopRunning()
            videoDecoder = nil
        }
        guard let videoFormatDescription else {
            return
        }
        removeNalUnitStartCodes(&frameData, nalUnits)
        guard let rebasedTimeStamp = timeStampRebaser.rebase(timestampSeconds) else {
            return
        }
        let presentationTimeStamp = getBasePresentationTimeStamp() + rebasedTimeStamp
        var timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: CMTime(seconds: presentationTimeStamp),
            decodeTimeStamp: .invalid
        )
        let blockBuffer = frameData.makeBlockBuffer()
        var sampleBuffer: CMSampleBuffer?
        var sampleSize = blockBuffer?.dataLength ?? 0
        guard CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: videoFormatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        ) == noErr, let sampleBuffer else {
            return
        }
        if videoDecoder == nil {
            videoDecoder = VideoDecoder(lockQueue: whipClientDispatchQueue)
            videoDecoder?.delegate = self
            videoDecoder?.startRunning(formatDescription: videoFormatDescription)
        }
        targetLatenciesSynchronizer.setLatestVideoPresentationTimeStamp(presentationTimeStamp)
        updateTargetLatencies()
        videoDecoder?.decodeSampleBuffer(sampleBuffer)
    }

    private func handleAudioMessage(data: Data, timestampSeconds: Double) {
        whipClientDispatchQueue.async {
            self.handleAudioMessageInternal(data: data, timestampSeconds: timestampSeconds)
        }
    }

    private func handleAudioMessageInternal(data: Data, timestampSeconds: Double) {
        guard !data.isEmpty else {
            return
        }
        guard let opusCompressedBuffer,
              let opusAudioConverter,
              let pcmAudioBuffer,
              pcmAudioFormat != nil
        else {
            return
        }
        let length = data.count
        guard length <= opusCompressedBuffer.maximumPacketSize else {
            return
        }
        data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return
            }
            opusCompressedBuffer.packetDescriptions?.pointee = AudioStreamPacketDescription(
                mStartOffset: 0,
                mVariableFramesInPacket: 0,
                mDataByteSize: UInt32(length)
            )
            opusCompressedBuffer.packetCount = 1
            opusCompressedBuffer.byteLength = UInt32(length)
            opusCompressedBuffer.data.copyMemory(from: baseAddress, byteCount: length)
        }
        var error: NSError?
        opusAudioConverter.convert(to: pcmAudioBuffer, error: &error) { _, inputStatus in
            inputStatus.pointee = .haveData
            return self.opusCompressedBuffer
        }
        if let error {
            logger.info("whip-client: Opus decode error: \(error)")
            return
        }
        guard let rebasedTimeStamp = timeStampRebaser.rebase(timestampSeconds) else {
            return
        }
        let presentationTimeStamp = getBasePresentationTimeStamp() + rebasedTimeStamp
        let pts = CMTime(seconds: presentationTimeStamp)
        guard let sampleBuffer = pcmAudioBuffer.makeSampleBuffer(pts) else {
            return
        }
        targetLatenciesSynchronizer.setLatestAudioPresentationTimeStamp(presentationTimeStamp)
        updateTargetLatencies()
        delegate?.whipClientOnAudioBuffer(cameraId: cameraId, sampleBuffer)
    }

    private func setupOpusDecoder() {
        var audioStreamBasicDescription = AudioStreamBasicDescription(
            mSampleRate: 48000,
            mFormatID: kAudioFormatOpus,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: 960,
            mBytesPerFrame: 0,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 0,
            mReserved: 0
        )
        guard let opusFormat = AVAudioFormat(streamDescription: &audioStreamBasicDescription) else {
            logger.info("whip-client: Failed to create Opus audio format")
            return
        }
        opusCompressedBuffer = AVAudioCompressedBuffer(
            format: opusFormat,
            packetCapacity: 1,
            maximumPacketSize: 4096
        )
        pcmAudioFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 48000,
            channels: 2,
            interleaved: true
        )
        guard let pcmAudioFormat else {
            logger.info("whip-client: Failed to create PCM audio format")
            return
        }
        pcmAudioBuffer = AVAudioPCMBuffer(pcmFormat: pcmAudioFormat, frameCapacity: 960)
        opusAudioConverter = AVAudioConverter(from: opusFormat, to: pcmAudioFormat)
        if opusAudioConverter == nil {
            logger.info("whip-client: Failed to create Opus audio converter")
        }
    }

    private func getBasePresentationTimeStamp() -> Double {
        if basePresentationTimeStamp == -1 {
            basePresentationTimeStamp = currentPresentationTimeStamp().seconds + latency
        }
        return basePresentationTimeStamp
    }

    private func getLocalDescription() throws -> String {
        guard peerConnectionId >= 0 else {
            throw "No peer connection"
        }
        let size = rtcGetLocalDescription(peerConnectionId, nil, 0)
        guard size > 0 else {
            throw "Failed to get local description size"
        }
        var buffer = [CChar](repeating: 0, count: Int(size))
        let result = rtcGetLocalDescription(peerConnectionId, &buffer, Int32(size))
        guard result >= 0 else {
            throw "Failed to get local description"
        }
        return String(cString: buffer)
    }

    private func updateTargetLatencies() {
        guard let (audioTargetLatency, videoTargetLatency) = targetLatenciesSynchronizer.update() else {
            return
        }
        delegate?.whipClientSetTargetLatencies(
            cameraId: cameraId,
            videoTargetLatency,
            audioTargetLatency
        )
    }
}

extension WhipClient: VideoDecoderDelegate {
    func videoDecoderOutputSampleBuffer(_: VideoDecoder, _ sampleBuffer: CMSampleBuffer) {
        delegate?.whipClientOnVideoBuffer(cameraId: cameraId, sampleBuffer)
    }
}

private enum VideoCodec {
    case h264
    case h265
}
