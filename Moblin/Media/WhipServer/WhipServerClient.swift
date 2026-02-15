import AVFoundation
import CoreMedia
import libdatachannel
import Webrtc

protocol WhipServerClientDelegate: AnyObject {
    func whipServerClientOnConnected(streamId: UUID)
    func whipServerClientOnDisconnected(streamId: UUID, reason: String)
    func whipServerClientOnVideoBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer)
    func whipServerClientOnAudioBuffer(streamId: UUID, _ sampleBuffer: CMSampleBuffer)
}

private func toClient(pointer: UnsafeMutableRawPointer?) -> WhipServerClient? {
    guard let pointer else {
        return nil
    }
    return Unmanaged<WhipServerClient>.fromOpaque(pointer).takeUnretainedValue()
}

final class WhipServerClient {
    let streamId: UUID
    private var peerConnectionId: Int32 = -1
    weak var delegate: WhipServerClientDelegate?
    private var connected = false
    private var answerCompletion: ((String?) -> Void)?
    private var videoDecoder: VideoDecoder?
    private var videoFormatDescription: CMFormatDescription?
    private var basePresentationTimeStamp: Double = -1
    private var firstVideoPresentationTimeStamp: Double = -1
    private var firstAudioPresentationTimeStamp: Double = -1
    private var opusAudioConverter: AVAudioConverter?
    private var opusCompressedBuffer: AVAudioCompressedBuffer?
    private var pcmAudioFormat: AVAudioFormat?
    private var pcmAudioBuffer: AVAudioPCMBuffer?

    init(streamId: UUID, delegate: WhipServerClientDelegate) {
        self.streamId = streamId
        self.delegate = delegate
    }

    deinit {
        if peerConnectionId >= 0 {
            rtcDeletePeerConnection(peerConnectionId)
        }
    }

    func handleOffer(sdpOffer: String, completion: @escaping (String?) -> Void) {
        do {
            var config = rtcConfiguration()
            let iceServers: [String] = []
            peerConnectionId = iceServers.withCPointers {
                config.iceServers = $0
                config.iceServersCount = Int32(iceServers.count)
                return rtcCreatePeerConnection(&config)
            }
            guard peerConnectionId >= 0 else {
                throw "Failed to create peer connection"
            }
            rtcSetUserPointer(peerConnectionId, Unmanaged.passUnretained(self).toOpaque())
            try checkOk(rtcSetStateChangeCallback(peerConnectionId) { _, state, pointer in
                toClient(pointer: pointer)?.handleStateChange(state: state)
            })
            try checkOk(rtcSetGatheringStateChangeCallback(peerConnectionId) { _, state, pointer in
                toClient(pointer: pointer)?.handleGatheringStateChange(state: state)
            })
            try checkOk(rtcSetTrackCallback(peerConnectionId) { _, trackId, pointer in
                toClient(pointer: pointer)?.handleTrack(trackId: trackId)
            })
            try checkOk(rtcSetRemoteDescription(peerConnectionId, sdpOffer, "offer"))
            answerCompletion = completion
        } catch {
            completion(nil)
            stopInternal(reason: "Failed to handle offer \(error)")
        }
    }

    func stop() {
        stopInternal()
    }

    private func stopInternal(reason: String? = nil) {
        videoDecoder?.stopRunning()
        videoDecoder = nil
        opusAudioConverter = nil
        opusCompressedBuffer = nil
        pcmAudioBuffer = nil
        if peerConnectionId >= 0 {
            rtcClosePeerConnection(peerConnectionId)
        }
        connected = false
        if let reason {
            delegate?.whipServerClientOnDisconnected(streamId: streamId, reason: reason)
        }
    }

    private func handleStateChange(state: rtcState) {
        whipServerDispatchQueue.async {
            self.handleStateChangeInternal(state: state)
        }
    }

    private func handleStateChangeInternal(state: rtcState) {
        guard let state = WebrtcConnectionState(value: state) else {
            return
        }
        logger.info("whip-server-client: Connection state: \(state)")
        switch state {
        case .connected:
            guard !connected else {
                return
            }
            connected = true
            delegate?.whipServerClientOnConnected(streamId: streamId)
        case .disconnected, .failed, .closed:
            stopInternal(reason: "Connection \(state)")
        case .new, .connecting:
            break
        }
    }

    private func handleGatheringStateChange(state: rtcGatheringState) {
        whipServerDispatchQueue.async {
            self.handleGatheringStateChangeInternal(state: state)
        }
    }

    private func handleGatheringStateChangeInternal(state: rtcGatheringState) {
        guard let state = WebrtcGatheringState(value: state) else {
            return
        }
        logger.info("whip-server-client: ICE gathering state: \(state)")
        switch state {
        case .complete:
            do {
                try answerCompletion?(getLocalDescription())
            } catch {
                answerCompletion?(nil)
                stopInternal(reason: "Failed to get local description")
            }
            answerCompletion = nil
        case .new, .inProgress:
            break
        }
    }

    private func handleTrack(trackId: Int32) {
        whipServerDispatchQueue.async {
            self.handleTrackInternal(trackId: trackId)
        }
    }

    private func handleTrackInternal(trackId: Int32) {
        var descBuffer = [CChar](repeating: 0, count: 4096)
        let descSize = rtcGetTrackDescription(trackId, &descBuffer, Int32(descBuffer.count))
        let description = descSize > 0 ? String(cString: descBuffer) : ""
        let isVideo = description.lowercased().contains("h264")
        let isAudio = description.lowercased().contains("opus")
        logger.info("whip-server-client: Track video=\(isVideo) audio=\(isAudio)")
        let clientPointer = Unmanaged.passUnretained(self).toOpaque()
        rtcSetUserPointer(trackId, clientPointer)
        if isVideo {
            rtcSetH264Depacketizer(trackId, RTC_NAL_SEPARATOR_LONG_START_SEQUENCE)
            rtcChainRtcpReceivingSession(trackId)
            rtcSetFrameCallback(trackId) { _, data, size, info, pointer in
                guard let data, size > 0, let info, let pointer else {
                    return
                }
                let frameData = Data(bytes: data, count: Int(size))
                let timestampSeconds = info.pointee.timestampSeconds
                let client = Unmanaged<WhipServerClient>.fromOpaque(pointer).takeUnretainedValue()
                client.handleVideoMessage(data: frameData, timestampSeconds: timestampSeconds)
            }
        } else if isAudio {
            setupOpusDecoder()
            rtcSetOpusDepacketizer(trackId)
            rtcChainRtcpReceivingSession(trackId)
            rtcSetFrameCallback(trackId) { _, data, size, info, pointer in
                guard let data, size > 0, let info, let pointer else {
                    return
                }
                let frameData = Data(bytes: data, count: Int(size))
                let timestampSeconds = info.pointee.timestampSeconds
                let client = Unmanaged<WhipServerClient>.fromOpaque(pointer).takeUnretainedValue()
                client.handleAudioMessage(data: frameData, timestampSeconds: timestampSeconds)
            }
        }
    }

    private func handleVideoMessage(data: Data, timestampSeconds: Double) {
        whipServerDispatchQueue.async {
            self.handleVideoMessageInternal(data: data, timestampSeconds: timestampSeconds)
        }
    }

    private func handleVideoMessageInternal(data: Data, timestampSeconds: Double) {
        var frameData = data
        let nalUnits = getNalUnits(data: frameData)
        let units = readH264NalUnits(data: frameData, nalUnits: nalUnits, filter: [.sps, .pps, .idr])
        let formatDescription = units.makeFormatDescription()
        if let formatDescription, videoFormatDescription != formatDescription {
            videoFormatDescription = formatDescription
            videoDecoder?.stopRunning()
            videoDecoder = nil
        }
        guard let videoFormatDescription else {
            return
        }
        removeNalUnitStartCodes(&frameData, nalUnits)
        var presentationTimeStamp = timestampSeconds
        if firstVideoPresentationTimeStamp == -1 {
            firstVideoPresentationTimeStamp = presentationTimeStamp
        }
        presentationTimeStamp = getBasePresentationTimeStamp()
            + (presentationTimeStamp - firstVideoPresentationTimeStamp)
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
            videoDecoder = VideoDecoder(lockQueue: whipServerDispatchQueue)
            videoDecoder?.delegate = self
            videoDecoder?.startRunning(formatDescription: videoFormatDescription)
        }
        videoDecoder?.decodeSampleBuffer(sampleBuffer)
    }

    private func handleAudioMessage(data: Data, timestampSeconds: Double) {
        whipServerDispatchQueue.async {
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
            logger.info("whip-server-client: Opus decode error: \(error)")
            return
        }
        var presentationTimeStamp = timestampSeconds
        if firstAudioPresentationTimeStamp == -1 {
            firstAudioPresentationTimeStamp = presentationTimeStamp
        }
        presentationTimeStamp = getBasePresentationTimeStamp()
            + (presentationTimeStamp - firstAudioPresentationTimeStamp)
        let pts = CMTime(seconds: presentationTimeStamp)
        guard let sampleBuffer = pcmAudioBuffer.makeSampleBuffer(pts) else {
            return
        }
        delegate?.whipServerClientOnAudioBuffer(streamId: streamId, sampleBuffer)
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
            logger.info("whip-server-client: Failed to create Opus audio format")
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
            logger.info("whip-server-client: Failed to create PCM audio format")
            return
        }
        pcmAudioBuffer = AVAudioPCMBuffer(pcmFormat: pcmAudioFormat, frameCapacity: 960)
        opusAudioConverter = AVAudioConverter(from: opusFormat, to: pcmAudioFormat)
        if opusAudioConverter == nil {
            logger.info("whip-server-client: Failed to create Opus audio converter")
        }
    }

    private func getBasePresentationTimeStamp() -> Double {
        if basePresentationTimeStamp == -1 {
            basePresentationTimeStamp = currentPresentationTimeStamp().seconds
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
}

extension WhipServerClient: VideoDecoderDelegate {
    func videoDecoderOutputSampleBuffer(_: VideoDecoder, _ sampleBuffer: CMSampleBuffer) {
        delegate?.whipServerClientOnVideoBuffer(streamId: streamId, sampleBuffer)
    }
}
