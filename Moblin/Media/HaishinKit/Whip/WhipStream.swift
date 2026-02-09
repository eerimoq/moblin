import AVFoundation
import Foundation
import libdatachannel

private let whipQueue = DispatchQueue(label: "com.eerimoq.Moblin.whip")

protocol WhipStreamDelegate: AnyObject {
    func whipStreamOnConnected()
    func whipStreamOnDisconnected()
}

class WhipStream: NSObject {
    private var peerConnection: Int32 = -1
    private var videoTrack: Int32 = -1
    private var audioTrack: Int32 = -1
    private weak var whipDelegate: (any WhipStreamDelegate)?
    private let processor: Processor
    private var url: String = ""
    private var connected = false
    private var videoCodec: SettingsStreamCodec = .h264avc
    private var videoSsrc: UInt32 = 1
    private var audioSsrc: UInt32 = 2
    private var deleteResourceUrl: String?
    private var videoFormatDescription: CMFormatDescription?

    init(processor: Processor, delegate: WhipStreamDelegate) {
        self.processor = processor
        super.init()
        whipDelegate = delegate
    }

    func start(url: String, videoCodec: SettingsStreamCodec) {
        whipQueue.async {
            self.startInternal(url: url, videoCodec: videoCodec)
        }
    }

    func stop() {
        whipQueue.async {
            self.stopInternal()
        }
    }

    private func startInternal(url: String, videoCodec: SettingsStreamCodec) {
        self.url = url
        self.videoCodec = videoCodec
        connected = false

        rtcInitLogger(RTC_LOG_WARNING, nil)

        var config = rtcConfiguration()
        memset(&config, 0, MemoryLayout<rtcConfiguration>.size)
        config.iceServersCount = 0
        config.disableAutoNegotiation = false
        config.forceMediaTransport = false

        peerConnection = rtcCreatePeerConnection(&config)
        guard peerConnection >= 0 else {
            logger.info("whip: Failed to create peer connection")
            return
        }

        let pointer = Unmanaged.passUnretained(self).toOpaque()
        rtcSetUserPointer(peerConnection, pointer)

        rtcSetStateChangeCallback(peerConnection) { _, state, ptr in
            guard let ptr else { return }
            let stream = Unmanaged<WhipStream>.fromOpaque(ptr).takeUnretainedValue()
            stream.handleStateChange(state: state)
        }

        rtcSetGatheringStateChangeCallback(peerConnection) { _, state, ptr in
            guard let ptr else { return }
            let stream = Unmanaged<WhipStream>.fromOpaque(ptr).takeUnretainedValue()
            stream.handleGatheringStateChange(state: state)
        }

        addVideoTrack()
        addAudioTrack()

        rtcSetLocalDescription(peerConnection, "offer")
    }

    private func addVideoTrack() {
        let codec: rtcCodec = videoCodec == .h265hevc ? RTC_CODEC_H265 : RTC_CODEC_H264
        let profile = videoCodec == .h265hevc ? nil : "42e01f"

        var trackInit = rtcTrackInit()
        memset(&trackInit, 0, MemoryLayout<rtcTrackInit>.size)
        trackInit.direction = RTC_DIRECTION_SENDONLY
        trackInit.codec = codec
        trackInit.payloadType = 96
        trackInit.ssrc = videoSsrc

        let mid = "0"
        let name = "video"

        mid.withCString { midPtr in
            name.withCString { namePtr in
                trackInit.mid = midPtr
                trackInit.name = namePtr

                if let profile {
                    profile.withCString { profilePtr in
                        trackInit.profile = profilePtr
                        videoTrack = rtcAddTrackEx(peerConnection, &trackInit)
                    }
                } else {
                    videoTrack = rtcAddTrackEx(peerConnection, &trackInit)
                }
            }
        }

        guard videoTrack >= 0 else {
            logger.info("whip: Failed to add video track")
            return
        }

        var packetizerInit = rtcPacketizerInit()
        memset(&packetizerInit, 0, MemoryLayout<rtcPacketizerInit>.size)
        packetizerInit.ssrc = videoSsrc
        packetizerInit.payloadType = 96
        packetizerInit.clockRate = 90000
        packetizerInit.maxFragmentSize = UInt16(RTC_DEFAULT_MAX_FRAGMENT_SIZE)
        packetizerInit.nalSeparator = RTC_NAL_SEPARATOR_START_SEQUENCE

        "video".withCString { cnamePtr in
            packetizerInit.cname = cnamePtr
            if videoCodec == .h265hevc {
                rtcSetH265Packetizer(videoTrack, &packetizerInit)
            } else {
                rtcSetH264Packetizer(videoTrack, &packetizerInit)
            }
        }

        rtcChainRtcpSrReporter(videoTrack)
        rtcChainRtcpNackResponder(videoTrack, UInt32(RTC_DEFAULT_MAX_STORED_PACKET_COUNT))
    }

    private func addAudioTrack() {
        var trackInit = rtcTrackInit()
        memset(&trackInit, 0, MemoryLayout<rtcTrackInit>.size)
        trackInit.direction = RTC_DIRECTION_SENDONLY
        trackInit.codec = RTC_CODEC_OPUS
        trackInit.payloadType = 111
        trackInit.ssrc = audioSsrc

        let mid = "1"
        let name = "audio"

        mid.withCString { midPtr in
            name.withCString { namePtr in
                trackInit.mid = midPtr
                trackInit.name = namePtr
                audioTrack = rtcAddTrackEx(peerConnection, &trackInit)
            }
        }

        guard audioTrack >= 0 else {
            logger.info("whip: Failed to add audio track")
            return
        }

        var packetizerInit = rtcPacketizerInit()
        memset(&packetizerInit, 0, MemoryLayout<rtcPacketizerInit>.size)
        packetizerInit.ssrc = audioSsrc
        packetizerInit.payloadType = 111
        packetizerInit.clockRate = 48000

        "audio".withCString { cnamePtr in
            packetizerInit.cname = cnamePtr
            rtcSetOpusPacketizer(audioTrack, &packetizerInit)
        }

        rtcChainRtcpSrReporter(audioTrack)
    }

    private func handleStateChange(state: rtcState) {
        whipQueue.async {
            switch state {
            case RTC_CONNECTED:
                logger.info("whip: Peer connection connected")
                if !self.connected {
                    self.connected = true
                    self.whipDelegate?.whipStreamOnConnected()
                }
            case RTC_DISCONNECTED, RTC_FAILED, RTC_CLOSED:
                logger.info("whip: Peer connection state: \(state.rawValue)")
                if self.connected {
                    self.connected = false
                    self.whipDelegate?.whipStreamOnDisconnected()
                }
            default:
                logger.info("whip: Peer connection state: \(state.rawValue)")
            }
        }
    }

    private func handleGatheringStateChange(state: rtcGatheringState) {
        guard state == RTC_GATHERING_COMPLETE else {
            return
        }
        whipQueue.async {
            self.sendOffer()
        }
    }

    private func sendOffer() {
        var buffer = [CChar](repeating: 0, count: 16384)
        let length = rtcGetLocalDescription(peerConnection, &buffer, Int32(buffer.count))
        guard length >= 0 else {
            logger.info("whip: Failed to get local description")
            return
        }
        let sdpOffer = String(cString: buffer)
        logger.info("whip: Sending SDP offer to \(url)")

        let whipUrl = url.replacingOccurrences(of: "whip://", with: "http://")
            .replacingOccurrences(of: "whips://", with: "https://")

        guard let requestUrl = URL(string: whipUrl) else {
            logger.info("whip: Invalid WHIP URL: \(whipUrl)")
            return
        }

        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        request.setValue("application/sdp", forHTTPHeaderField: "Content-Type")
        request.httpBody = sdpOffer.data(using: .utf8)

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            whipQueue.async {
                self.handleWhipResponse(data: data, response: response, error: error)
            }
        }
        task.resume()
    }

    private func handleWhipResponse(data: Data?, response: URLResponse?, error: Error?) {
        if let error {
            logger.info("whip: HTTP request failed: \(error.localizedDescription)")
            whipDelegate?.whipStreamOnDisconnected()
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.info("whip: Invalid HTTP response")
            whipDelegate?.whipStreamOnDisconnected()
            return
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            logger.info("whip: HTTP response status \(httpResponse.statusCode)")
            whipDelegate?.whipStreamOnDisconnected()
            return
        }

        if let location = httpResponse.value(forHTTPHeaderField: "Location") {
            deleteResourceUrl = location
        }

        guard let data, let sdpAnswer = String(data: data, encoding: .utf8) else {
            logger.info("whip: No SDP answer in response")
            whipDelegate?.whipStreamOnDisconnected()
            return
        }

        logger.info("whip: Received SDP answer")

        sdpAnswer.withCString { answerPtr in
            "answer".withCString { typePtr in
                rtcSetRemoteDescription(peerConnection, answerPtr, typePtr)
            }
        }

        processorControlQueue.async {
            self.processor.startEncoding(self)
        }
    }

    private func stopInternal() {
        processorControlQueue.async {
            self.processor.stopEncoding(self)
        }

        if peerConnection >= 0 {
            rtcClosePeerConnection(peerConnection)
            rtcDeletePeerConnection(peerConnection)
            peerConnection = -1
        }
        videoTrack = -1
        audioTrack = -1
        connected = false
        videoFormatDescription = nil

        sendDeleteRequest()
    }

    private func sendDeleteRequest() {
        guard let deleteUrl = deleteResourceUrl else {
            return
        }
        deleteResourceUrl = nil

        let whipUrl = url.replacingOccurrences(of: "whip://", with: "http://")
            .replacingOccurrences(of: "whips://", with: "https://")

        let resolvedUrl: String
        if deleteUrl.hasPrefix("http://") || deleteUrl.hasPrefix("https://") {
            resolvedUrl = deleteUrl
        } else if let baseUrl = URL(string: whipUrl) {
            resolvedUrl = baseUrl.deletingLastPathComponent()
                .appendingPathComponent(deleteUrl).absoluteString
        } else {
            return
        }

        guard let requestUrl = URL(string: resolvedUrl) else {
            return
        }

        var request = URLRequest(url: requestUrl)
        request.httpMethod = "DELETE"
        URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
    }
}

extension WhipStream: VideoEncoderDelegate {
    func videoEncoderOutputFormat(_: VideoEncoder, _ formatDescription: CMFormatDescription) {
        videoFormatDescription = formatDescription
    }

    func videoEncoderOutputSampleBuffer(_: VideoEncoder,
                                        _ sampleBuffer: CMSampleBuffer,
                                        _: CMTime)
    {
        guard videoTrack >= 0 else {
            return
        }

        guard let dataBuffer = sampleBuffer.dataBuffer else {
            return
        }

        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<CChar>?
        let status = CMBlockBufferGetDataPointer(
            dataBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &totalLength,
            dataPointerOut: &dataPointer
        )

        guard status == kCMBlockBufferNoErr, let dataPointer, totalLength > 0 else {
            return
        }

        let isKeyframe = sampleBuffer.getIsSync()

        var nalData = Data()

        if isKeyframe, let formatDescription = videoFormatDescription {
            nalData.append(contentsOf: extractParameterSets(formatDescription: formatDescription))
        }

        let startCode: [UInt8] = [0x00, 0x00, 0x00, 0x01]
        var offset = 0
        while offset + 4 <= totalLength {
            let nalLength = Int(UInt8(bitPattern: dataPointer[offset])) << 24 |
                Int(UInt8(bitPattern: dataPointer[offset + 1])) << 16 |
                Int(UInt8(bitPattern: dataPointer[offset + 2])) << 8 |
                Int(UInt8(bitPattern: dataPointer[offset + 3]))
            offset += 4
            guard nalLength > 0, offset + nalLength <= totalLength else {
                break
            }
            nalData.append(contentsOf: startCode)
            nalData.append(Data(bytes: dataPointer.advanced(by: offset), count: nalLength))
            offset += nalLength
        }

        guard !nalData.isEmpty else {
            return
        }

        let pts = sampleBuffer.presentationTimeStamp
        let seconds = CMTimeGetSeconds(pts)

        whipQueue.async {
            guard self.videoTrack >= 0 else { return }
            var timestamp: UInt32 = 0
            rtcTransformSecondsToTimestamp(self.videoTrack, seconds, &timestamp)
            rtcSetTrackRtpTimestamp(self.videoTrack, timestamp)
            nalData.withUnsafeBytes { ptr in
                rtcSendMessage(self.videoTrack, ptr.baseAddress?.assumingMemoryBound(to: CChar.self),
                               Int32(nalData.count))
            }
        }
    }

    private func extractParameterSets(formatDescription: CMFormatDescription) -> Data {
        var data = Data()
        let startCode: [UInt8] = [0x00, 0x00, 0x00, 0x01]
        let codec = CMFormatDescriptionGetMediaSubType(formatDescription)

        if codec == kCMVideoCodecType_H264 {
            var spsSize: Int = 0
            var spsCount: Int = 0
            var spsPointer: UnsafePointer<UInt8>?
            if CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                formatDescription, parameterSetIndex: 0,
                parameterSetPointerOut: &spsPointer, parameterSetSizeOut: &spsSize,
                parameterSetCountOut: &spsCount, nalUnitHeaderLengthOut: nil
            ) == noErr, let spsPointer {
                data.append(contentsOf: startCode)
                data.append(spsPointer, count: spsSize)
            }
            var ppsSize: Int = 0
            var ppsPointer: UnsafePointer<UInt8>?
            if CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                formatDescription, parameterSetIndex: 1,
                parameterSetPointerOut: &ppsPointer, parameterSetSizeOut: &ppsSize,
                parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil
            ) == noErr, let ppsPointer {
                data.append(contentsOf: startCode)
                data.append(ppsPointer, count: ppsSize)
            }
        } else if codec == kCMVideoCodecType_HEVC {
            var paramCount: Int = 0
            if CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(
                formatDescription, parameterSetIndex: 0,
                parameterSetPointerOut: nil, parameterSetSizeOut: nil,
                parameterSetCountOut: &paramCount, nalUnitHeaderLengthOut: nil
            ) == noErr {
                for i in 0 ..< paramCount {
                    var paramSize: Int = 0
                    var paramPointer: UnsafePointer<UInt8>?
                    if CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(
                        formatDescription, parameterSetIndex: i,
                        parameterSetPointerOut: &paramPointer, parameterSetSizeOut: &paramSize,
                        parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil
                    ) == noErr, let paramPointer {
                        data.append(contentsOf: startCode)
                        data.append(paramPointer, count: paramSize)
                    }
                }
            }
        }

        return data
    }
}

extension WhipStream: AudioEncoderDelegate {
    func audioEncoderOutputFormat(_: AVAudioFormat) {}

    func audioEncoderOutputBuffer(_ buffer: AVAudioCompressedBuffer,
                                  _ presentationTimeStamp: CMTime)
    {
        guard audioTrack >= 0 else {
            return
        }

        let length = Int(buffer.byteLength)
        guard length > 0, let audioData = buffer.data else {
            return
        }

        let seconds = CMTimeGetSeconds(presentationTimeStamp)

        let dataCopy = Data(bytes: audioData, count: length)

        whipQueue.async {
            guard self.audioTrack >= 0 else { return }
            var timestamp: UInt32 = 0
            rtcTransformSecondsToTimestamp(self.audioTrack, seconds, &timestamp)
            rtcSetTrackRtpTimestamp(self.audioTrack, timestamp)
            dataCopy.withUnsafeBytes { ptr in
                rtcSendMessage(self.audioTrack, ptr.baseAddress?.assumingMemoryBound(to: CChar.self),
                               Int32(dataCopy.count))
            }
        }
    }
}
