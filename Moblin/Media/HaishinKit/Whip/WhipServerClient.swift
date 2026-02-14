import AVFoundation
import CoreMedia
import libdatachannel

private let whipServerClientQueue = DispatchQueue(label: "com.eerimoq.Moblin.whip-server-client")

protocol WhipServerClientDelegate: AnyObject {
    func whipServerClientOnConnected(clientId: UUID)
    func whipServerClientOnDisconnected(clientId: UUID, reason: String)
    func whipServerClientOnVideoBuffer(clientId: UUID, _ sampleBuffer: CMSampleBuffer)
    func whipServerClientOnAudioBuffer(clientId: UUID, _ sampleBuffer: CMSampleBuffer)
}

private enum WhipServerConnectionState {
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

private enum WhipServerGatheringState {
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

private func toWhipServerClient(pointer: UnsafeMutableRawPointer?) -> WhipServerClient? {
    guard let pointer else {
        return nil
    }
    return Unmanaged<WhipServerClient>.fromOpaque(pointer).takeUnretainedValue()
}

final class WhipServerClient {
    let clientId = UUID()
    private var peerConnectionId: Int32 = -1
    weak var delegate: WhipServerClientDelegate?
    private var connected = false
    private var answerSdp: String?
    private var answerCompletion: ((String?) -> Void)?
    private var videoDecoder: VideoDecoder?
    private var videoFormatDescription: CMFormatDescription?
    private var basePresentationTimeStamp: Double = -1
    private var firstVideoPresentationTimeStamp: Double = -1
    private var firstAudioPresentationTimeStamp: Double = -1
    private var h264NalData = Data()
    private var h264NalTimestamp: Int64 = 0
    private var sps: Data?
    private var pps: Data?
    private var opusAudioConverter: AVAudioConverter?
    private var opusCompressedBuffer: AVAudioCompressedBuffer?
    private var pcmAudioFormat: AVAudioFormat?
    private var pcmAudioBuffer: AVAudioPCMBuffer?

    init(delegate: WhipServerClientDelegate) {
        self.delegate = delegate
    }

    deinit {
        if peerConnectionId >= 0 {
            rtcDeletePeerConnection(peerConnectionId)
        }
    }

    func handleOffer(sdpOffer: String, completion: @escaping (String?) -> Void) {
        whipServerClientQueue.async {
            self.answerCompletion = completion
            self.handleOfferInternal(sdpOffer: sdpOffer)
        }
    }

    func stop() {
        whipServerClientQueue.async {
            self.stopInternal()
        }
    }

    private func handleOfferInternal(sdpOffer: String) {
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
            try checkWhipServerOk(rtcSetStateChangeCallback(peerConnectionId) { _, state, pointer in
                toWhipServerClient(pointer: pointer)?.handleStateChange(state: state)
            })
            try checkWhipServerOk(rtcSetGatheringStateChangeCallback(peerConnectionId) { _, state, pointer in
                toWhipServerClient(pointer: pointer)?.handleGatheringStateChange(state: state)
            })
            try checkWhipServerOk(rtcSetTrackCallback(peerConnectionId) { _, trackId, pointer in
                toWhipServerClient(pointer: pointer)?.handleIncomingTrack(trackId: trackId)
            })
            try checkWhipServerOk(rtcSetRemoteDescription(peerConnectionId, sdpOffer, "offer"))
            try checkWhipServerOk(rtcSetLocalDescription(peerConnectionId, "answer"))
        } catch {
            logger.info("whip-server-client: Failed to handle offer: \(error)")
            answerCompletion?(nil)
            answerCompletion = nil
            stopInternal(reason: "Failed to handle offer")
        }
    }

    private func handleGatheringStateChange(state: rtcGatheringState) {
        whipServerClientQueue.async {
            self.handleGatheringStateChangeInternal(state: state)
        }
    }

    private func handleGatheringStateChangeInternal(state: rtcGatheringState) {
        guard let state = WhipServerGatheringState(value: state) else {
            return
        }
        logger.info("whip-server-client: ICE gathering state: \(state)")
        switch state {
        case .complete:
            do {
                let answer = try getLocalDescription()
                logger.debug("whip-server-client: Answer ready")
                answerSdp = answer
                answerCompletion?(answer)
                answerCompletion = nil
            } catch {
                logger.info("whip-server-client: Failed to get local description: \(error)")
                answerCompletion?(nil)
                answerCompletion = nil
                stopInternal(reason: "Failed to get local description")
            }
        case .new, .inProgress:
            break
        }
    }

    private func handleStateChange(state: rtcState) {
        whipServerClientQueue.async {
            self.handleStateChangeInternal(state: state)
        }
    }

    private func handleStateChangeInternal(state: rtcState) {
        guard let state = WhipServerConnectionState(value: state) else {
            return
        }
        logger.info("whip-server-client: Connection state: \(state)")
        switch state {
        case .connected:
            guard !connected else {
                return
            }
            connected = true
            delegate?.whipServerClientOnConnected(clientId: clientId)
        case .disconnected, .failed, .closed:
            stopInternal(reason: "Connection \(state)")
        case .new, .connecting:
            break
        }
    }

    private func handleIncomingTrack(trackId: Int32) {
        whipServerClientQueue.async {
            self.handleIncomingTrackInternal(trackId: trackId)
        }
    }

    private func handleIncomingTrackInternal(trackId: Int32) {
        var descBuffer = [CChar](repeating: 0, count: 4096)
        let descSize = rtcGetTrackDescription(trackId, &descBuffer, Int32(descBuffer.count))
        let description = descSize > 0 ? String(cString: descBuffer) : ""
        let isVideo = description.lowercased().contains("h264")
        let isAudio = description.lowercased().contains("opus")
        logger.info("whip-server-client: Incoming track video=\(isVideo) audio=\(isAudio)")
        rtcChainRtcpReceivingSession(trackId)
        let clientPointer = Unmanaged.passUnretained(self).toOpaque()
        rtcSetUserPointer(trackId, clientPointer)
        if isVideo {
            rtcSetMessageCallback(trackId) { _, message, size, pointer in
                guard let message, size > 0, let pointer else {
                    return
                }
                let data = Data(bytes: message, count: Int(size))
                let client = Unmanaged<WhipServerClient>.fromOpaque(pointer).takeUnretainedValue()
                client.handleVideoRtpPacket(data: data)
            }
        } else if isAudio {
            setupOpusDecoder()
            rtcSetMessageCallback(trackId) { _, message, size, pointer in
                guard let message, size > 0, let pointer else {
                    return
                }
                let data = Data(bytes: message, count: Int(size))
                let client = Unmanaged<WhipServerClient>.fromOpaque(pointer).takeUnretainedValue()
                client.handleAudioRtpPacket(data: data)
            }
        }
    }

    // MARK: - Video

    private func handleVideoRtpPacket(data: Data) {
        whipServerClientQueue.async {
            self.handleVideoRtpPacketInternal(data: data)
        }
    }

    private func handleVideoRtpPacketInternal(data: Data) {
        guard data.count >= 12 else {
            return
        }
        let timestamp = Int64(data.getFourBytesBe(offset: 4))
        let nalType = data[12] & 0x1F
        switch nalType {
        case 1 ... 23:
            processH264SingleNal(data: data, timestamp: timestamp)
        case rtpH264PacketTypeFuA:
            processH264FuA(data: data, timestamp: timestamp)
        default:
            break
        }
    }

    private func processH264SingleNal(data: Data, timestamp: Int64) {
        tryDecodeH264Frame()
        let nalData = data.suffix(from: 12)
        let type = nalData[nalData.startIndex] & 0x1F
        if type == 7 {
            sps = Data(nalData)
        } else if type == 8 {
            pps = Data(nalData)
            updateFormatDescription()
        }
        startNewH264Frame(timestamp: timestamp, first: Data(nalData))
    }

    private func processH264FuA(data: Data, timestamp: Int64) {
        guard data.count >= 14 else {
            return
        }
        let fuIndicator = data[12]
        let fuHeader = data[13]
        let startBit = fuHeader >> 7
        let nalType = fuHeader & 0x1F
        let nal = fuIndicator & 0xE0 | nalType
        if startBit == 1 {
            tryDecodeH264Frame()
            startNewH264Frame(timestamp: timestamp, first: Data([nal]), second: Data(data[14...]))
        } else {
            h264NalData += data[14...]
        }
    }

    private func startNewH264Frame(timestamp: Int64, first: Data, second: Data? = nil) {
        h264NalTimestamp = timestamp
        h264NalData.removeAll(keepingCapacity: true)
        h264NalData += Data([0, 0, 0, 0])
        h264NalData += first
        if let second {
            h264NalData += second
        }
    }

    private func tryDecodeH264Frame() {
        guard h264NalData.count > 4, let videoFormatDescription else {
            return
        }
        let nalType = h264NalData[4] & 0x1F
        guard nalType == 1 || nalType == 5 else {
            return
        }
        let count = UInt32(h264NalData.count - 4)
        h264NalData.withUnsafeMutableBytes { pointer in
            pointer.storeBytes(of: count.bigEndian, as: UInt32.self)
        }
        var presentationTimeStamp = Double(h264NalTimestamp) / 90000
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
        let blockBuffer = h264NalData.makeBlockBuffer()
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
            videoDecoder = VideoDecoder(lockQueue: whipServerClientQueue)
            videoDecoder?.delegate = self
            videoDecoder?.startRunning(formatDescription: videoFormatDescription)
        }
        videoDecoder?.decodeSampleBuffer(sampleBuffer)
    }

    private func updateFormatDescription() {
        guard let sps, let pps else {
            return
        }
        var formatDescription: CMFormatDescription?
        sps.withUnsafeBytes { spsBuffer in
            guard let spsBaseAddress = spsBuffer.baseAddress else {
                return
            }
            pps.withUnsafeBytes { ppsBuffer in
                guard let ppsBaseAddress = ppsBuffer.baseAddress else {
                    return
                }
                let pointers = [
                    spsBaseAddress.assumingMemoryBound(to: UInt8.self),
                    ppsBaseAddress.assumingMemoryBound(to: UInt8.self),
                ]
                let sizes = [spsBuffer.count, ppsBuffer.count]
                CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: kCFAllocatorDefault,
                    parameterSetCount: pointers.count,
                    parameterSetPointers: pointers,
                    parameterSetSizes: sizes,
                    nalUnitHeaderLength: 4,
                    formatDescriptionOut: &formatDescription
                )
            }
        }
        if let formatDescription {
            self.videoFormatDescription = formatDescription
            videoDecoder?.stopRunning()
            videoDecoder = nil
        }
    }

    // MARK: - Audio

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

    private func handleAudioRtpPacket(data: Data) {
        whipServerClientQueue.async {
            self.handleAudioRtpPacketInternal(data: data)
        }
    }

    private func handleAudioRtpPacketInternal(data: Data) {
        guard data.count > 12 else {
            return
        }
        guard let opusCompressedBuffer, let opusAudioConverter, let pcmAudioBuffer, let pcmAudioFormat else {
            return
        }
        let timestamp = Int64(data.getFourBytesBe(offset: 4))
        let opusData = data[12...]
        let length = opusData.count
        guard length > 0, length <= opusCompressedBuffer.maximumPacketSize else {
            return
        }
        opusData.withUnsafeBytes { buffer in
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
        var presentationTimeStamp = Double(timestamp) / 48000
        if firstAudioPresentationTimeStamp == -1 {
            firstAudioPresentationTimeStamp = presentationTimeStamp
        }
        presentationTimeStamp = getBasePresentationTimeStamp()
            + (presentationTimeStamp - firstAudioPresentationTimeStamp)
        let pts = CMTime(seconds: presentationTimeStamp)
        guard let sampleBuffer = pcmAudioBuffer.makeSampleBuffer(pts) else {
            return
        }
        delegate?.whipServerClientOnAudioBuffer(clientId: clientId, sampleBuffer)
    }

    // MARK: - Utilities

    private func getBasePresentationTimeStamp() -> Double {
        if basePresentationTimeStamp == -1 {
            basePresentationTimeStamp = currentPresentationTimeStamp().seconds
        }
        return basePresentationTimeStamp
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
        return String(cString: buffer)
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
            delegate?.whipServerClientOnDisconnected(clientId: clientId, reason: reason)
        }
    }
}

extension WhipServerClient: VideoDecoderDelegate {
    func videoDecoderOutputSampleBuffer(_: VideoDecoder, _ sampleBuffer: CMSampleBuffer) {
        delegate?.whipServerClientOnVideoBuffer(clientId: clientId, sampleBuffer)
    }
}

private func checkWhipServerOk(_ result: Int32) throws {
    guard result >= 0 else {
        throw "Error \(result)"
    }
}
