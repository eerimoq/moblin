import AVFoundation
import CoreMedia
import DataChannel
import libdatachannel

protocol WebrtcIngestClientDelegate: AnyObject {
    func webrtcIngestClientOnConnected(streamId: UUID)
    func webrtcIngestClientOnDisconnected(streamId: UUID, reason: String)
    func webrtcIngestClientOnVideoBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer)
    func webrtcIngestClientOnAudioBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer)
    func webrtcIngestClientSetTargetLatencies(
        streamId: UUID,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    )
    func webrtcIngestClientOnGatheringComplete(streamId: UUID, localDescription: String)
    func webrtcIngestClientOnDataReceived(streamId: UUID, count: Int)
}

private func decodeNtpTimestamp(v: UInt64) -> Double? {
    guard v >= 2_208_988_800 else {
        return nil
    }
    let secs = Int64(bitPattern: (v >> 32) - 2_208_988_800)
    let nanos = Int64(Double(((v & 0xFFFF_FFFF) * 1_000_000_000) / (1 << 32)))
    return Double(secs) + Double(nanos) / 1_000_000_000
}

private func toIngestClient(pointer: UnsafeMutableRawPointer?) -> WebrtcIngestClient? {
    guard let pointer else {
        return nil
    }
    return Unmanaged<WebrtcIngestClient>.fromOpaque(pointer).takeUnretainedValue()
}

private enum VideoCodec {
    case h264
    case h265

    init?(trackDescription: String) {
        if trackDescription.contains("h264") {
            self = .h264
        } else if trackDescription.contains("h265") {
            self = .h265
        } else {
            return nil
        }
    }
}

final class WebrtcIngestClient {
    let streamId: UUID
    private let latency: Double
    private let syncTimestamps: Bool
    private(set) var peerConnectionId: Int32 = -1
    weak var delegate: (any WebrtcIngestClientDelegate)?
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
    private let iceServers: [String]
    private var videoCodec: VideoCodec = .h264
    private var videoTrackId: Int32 = -1
    private var audioTrackId: Int32 = -1
    private var videoTimestampOffset: Double?
    private var audioTimestampOffset: Double?
    private let dispatchQueue: DispatchQueue

    init(streamId: UUID,
         latency: Double,
         syncTimestamps: Bool,
         iceServers: [String],
         dispatchQueue: DispatchQueue,
         delegate: any WebrtcIngestClientDelegate)
    {
        self.streamId = streamId
        self.latency = latency
        self.syncTimestamps = syncTimestamps
        self.iceServers = iceServers
        self.dispatchQueue = dispatchQueue
        targetLatenciesSynchronizer = TargetLatenciesSynchronizer(targetLatency: latency)
        self.delegate = delegate
    }

    func createPeerConnection() throws {
        var config = rtcConfiguration()
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
            toIngestClient(pointer: pointer)?.handleStateChange(state: state)
        })
        try checkOk(rtcSetGatheringStateChangeCallback(peerConnectionId) { _, state, pointer in
            toIngestClient(pointer: pointer)?.handleGatheringStateChange(state: state)
        })
        try checkOk(rtcSetTrackCallback(peerConnectionId) { _, trackId, pointer in
            toIngestClient(pointer: pointer)?.handleTrack(trackId: trackId)
        })
    }

    func setRemoteDescription(_ sdp: String, type: String) throws {
        try checkOk(rtcSetRemoteDescription(peerConnectionId, sdp, type))
    }

    func setLocalDescription(_ type: String) throws {
        try checkOk(rtcSetLocalDescription(peerConnectionId, type))
    }

    func getLocalDescription() throws -> String {
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
        return String(cArray: buffer)
    }

    func addRecvOnlyTrack(codec: rtcCodec,
                          payloadType: Int32,
                          mid: String,
                          msid: String,
                          name: String,
                          profile: String) throws -> Int32
    {
        try mid.withCString { midCStr in
            try name.withCString { nameCStr in
                try UUID().uuidString.withCString { trackIdCStr in
                    try msid.withCString { msidCStr in
                        try profile.withCString { profileCStr in
                            var trackInit = rtcTrackInit(
                                direction: RTC_DIRECTION_RECVONLY,
                                codec: codec,
                                payloadType: payloadType,
                                ssrc: makeSsrc(),
                                mid: midCStr,
                                name: nameCStr,
                                msid: msidCStr,
                                trackId: trackIdCStr,
                                profile: profileCStr
                            )
                            return try checkOkReturnResult(
                                rtcAddTrackEx(peerConnectionId, &trackInit)
                            )
                        }
                    }
                }
            }
        }
    }

    func stop() {
        stopInternal()
    }

    func setTrackCodec(trackId: Int32, description: String) {
        let descriptionLower = description.lowercased()
        let clientPointer = Unmanaged.passRetained(self).toOpaque()
        rtcSetUserPointer(trackId, clientPointer)
        if let videoCodec = VideoCodec(trackDescription: descriptionLower) {
            self.videoCodec = videoCodec
            videoTrackId = trackId
            switch videoCodec {
            case .h264:
                rtcSetH264Depacketizer(trackId, RTC_NAL_SEPARATOR_LONG_START_SEQUENCE)
            case .h265:
                rtcSetH265Depacketizer(trackId, RTC_NAL_SEPARATOR_LONG_START_SEQUENCE)
            }
            rtcChainRtcpReceivingSession(trackId)
            rtcSetFrameCallback(trackId) { _, data, size, info, pointer in
                guard let data, size > 0, let info, let pointer else {
                    return
                }
                let frameData = Data(bytes: data, count: Int(size))
                let timestampSeconds = info.pointee.timestampSeconds
                toIngestClient(pointer: pointer)?.handleVideoMessage(data: frameData,
                                                                     timestampSeconds: timestampSeconds)
            }
        } else if descriptionLower.contains("opus") {
            audioTrackId = trackId
            setupOpusDecoder()
            rtcSetOpusDepacketizer(trackId)
            rtcChainRtcpReceivingSession(trackId)
            rtcSetFrameCallback(trackId) { _, data, size, info, pointer in
                guard let data, size > 0, let info, let pointer else {
                    return
                }
                let frameData = Data(bytes: data, count: Int(size))
                let timestampSeconds = info.pointee.timestampSeconds
                toIngestClient(pointer: pointer)?.handleAudioMessage(data: frameData,
                                                                     timestampSeconds: timestampSeconds)
            }
        }
    }

    private func stopInternal(reason: String? = nil) {
        videoDecoder?.stopRunning()
        videoDecoder = nil
        opusAudioConverter = nil
        opusCompressedBuffer = nil
        pcmAudioBuffer = nil
        rtcDeletePeerConnection(peerConnectionId)
        peerConnectionId = -1
        connected = false
        videoTimestampOffset = nil
        audioTimestampOffset = nil
        if let reason {
            delegate?.webrtcIngestClientOnDisconnected(streamId: streamId, reason: reason)
        }
    }

    private func handleStateChange(state: rtcState) {
        dispatchQueue.async {
            self.handleStateChangeInternal(state: state)
        }
    }

    private func handleStateChangeInternal(state: rtcState) {
        guard let state = DataChannelConnectionState(value: state) else {
            return
        }
        logger.info("webrtc-ingest-client: Connection state: \(state)")
        switch state {
        case .connected:
            guard !connected else {
                return
            }
            connected = true
            delegate?.webrtcIngestClientOnConnected(streamId: streamId)
        case .disconnected, .failed, .closed:
            stopInternal(reason: "Connection \(state)")
        case .new, .connecting:
            break
        }
    }

    private func handleGatheringStateChange(state: rtcGatheringState) {
        dispatchQueue.async {
            self.handleGatheringStateChangeInternal(state: state)
        }
    }

    private func handleGatheringStateChangeInternal(state: rtcGatheringState) {
        guard let state = DataChannelGatheringState(value: state) else {
            return
        }
        logger.info("webrtc-ingest-client: ICE gathering state: \(state)")
        switch state {
        case .complete:
            do {
                let localDescription = try getLocalDescription()
                delegate?.webrtcIngestClientOnGatheringComplete(
                    streamId: streamId,
                    localDescription: localDescription
                )
            } catch {
                stopInternal(reason: "Failed to get local description")
            }
        case .new, .inProgress:
            break
        }
    }

    private func handleTrack(trackId: Int32) {
        dispatchQueue.async {
            self.handleTrackInternal(trackId: trackId)
        }
    }

    private func handleTrackInternal(trackId: Int32) {
        var descBuffer = [CChar](repeating: 0, count: 4096)
        let descSize = rtcGetTrackDescription(trackId, &descBuffer, Int32(descBuffer.count))
        let description = descSize > 0 ? String(cArray: descBuffer) : ""
        setTrackCodec(trackId: trackId, description: description)
    }

    private func handleVideoMessage(data: Data, timestampSeconds: Double) {
        dispatchQueue.async {
            self.handleVideoMessageInternal(data: data, timestampSeconds: timestampSeconds)
        }
    }

    private func handleVideoMessageInternal(data: Data, timestampSeconds: Double) {
        delegate?.webrtcIngestClientOnDataReceived(streamId: streamId, count: data.count)
        guard let timestampSeconds = syncTimestampIfEnabled(videoTrackId,
                                                            timestampSeconds,
                                                            &videoTimestampOffset,
                                                            90000)
        else {
            return
        }
        var frameData = data
        let nalUnits = getNalUnits(data: frameData)
        let formatDescription: CMFormatDescription?
        switch videoCodec {
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
            videoDecoder = VideoDecoder(lockQueue: dispatchQueue)
            videoDecoder?.delegate = self
            videoDecoder?.startRunning(formatDescription: videoFormatDescription)
        }
        targetLatenciesSynchronizer.setLatestVideoPresentationTimeStamp(presentationTimeStamp)
        updateTargetLatencies()
        videoDecoder?.decodeSampleBuffer(sampleBuffer)
    }

    private func handleAudioMessage(data: Data, timestampSeconds: Double) {
        dispatchQueue.async {
            self.handleAudioMessageInternal(data: data, timestampSeconds: timestampSeconds)
        }
    }

    private func handleAudioMessageInternal(data: Data, timestampSeconds: Double) {
        delegate?.webrtcIngestClientOnDataReceived(streamId: streamId, count: data.count)
        guard let timestampSeconds = syncTimestampIfEnabled(audioTrackId,
                                                            timestampSeconds,
                                                            &audioTimestampOffset,
                                                            48000)
        else {
            return
        }
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
            logger.info("webrtc-ingest-client: Opus decode error: \(error)")
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
        delegate?.webrtcIngestClientOnAudioBuffer(streamId: streamId, sampleBuffer)
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
            logger.info("webrtc-ingest-client: Failed to create Opus audio format")
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
            logger.info("webrtc-ingest-client: Failed to create PCM audio format")
            return
        }
        pcmAudioBuffer = AVAudioPCMBuffer(pcmFormat: pcmAudioFormat, frameCapacity: 960)
        opusAudioConverter = AVAudioConverter(from: opusFormat, to: pcmAudioFormat)
        if opusAudioConverter == nil {
            logger.info("webrtc-ingest-client: Failed to create Opus audio converter")
        }
    }

    private func getBasePresentationTimeStamp() -> Double {
        if basePresentationTimeStamp == -1 {
            basePresentationTimeStamp = currentPresentationTimeStamp().seconds + latency
        }
        return basePresentationTimeStamp
    }

    private func updateTargetLatencies() {
        guard let (audioTargetLatency, videoTargetLatency) = targetLatenciesSynchronizer.update() else {
            return
        }
        delegate?.webrtcIngestClientSetTargetLatencies(
            streamId: streamId,
            videoTargetLatency,
            audioTargetLatency
        )
    }

    private func syncTimestampIfEnabled(_ trackId: Int32,
                                        _ timestampSeconds: Double,
                                        _ timestampOffset: inout Double?,
                                        _ rate: Double) -> Double?
    {
        guard syncTimestamps else {
            return timestampSeconds
        }
        if timestampOffset == nil {
            var rtpTimestamp: UInt64 = 0
            var ntpTimestamp: UInt64 = 0
            rtcGetTrackRtcpSyncTimestamps(trackId, &rtpTimestamp, &ntpTimestamp)
            guard let ntpTimestamp = decodeNtpTimestamp(v: ntpTimestamp) else {
                return nil
            }
            let syncRtpTimestampSeconds = Double(rtpTimestamp) / rate
            let syncNtpTimestampSeconds = ntpTimestamp
            timestampOffset = syncNtpTimestampSeconds - syncRtpTimestampSeconds
        }
        return timestampSeconds + timestampOffset!
    }
}

extension WebrtcIngestClient: VideoDecoderDelegate {
    func videoDecoderOutputSampleBuffer(_: VideoDecoder, _ sampleBuffer: CMSampleBuffer) {
        delegate?.webrtcIngestClientOnVideoBuffer(streamId: streamId, sampleBuffer)
    }
}
