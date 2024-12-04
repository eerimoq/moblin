import AVFoundation

enum RTMPMessageType: UInt8 {
    case chunkSize = 0x01
    case abort = 0x02
    case ack = 0x03
    case user = 0x04
    case windowAck = 0x05
    case bandwidth = 0x06
    case audio = 0x08
    case video = 0x09
    case amf3Data = 0x0F
    case amf3Command = 0x11
    case amf0Data = 0x12
    case amf0Command = 0x14
    case aggregate = 0x16
}

class RTMPMessage {
    let type: RTMPMessageType
    var length: Int = 0
    var streamId: UInt32 = 0
    var timestamp: UInt32 = 0
    var encoded = Data()

    init(type: RTMPMessageType) {
        self.type = type
    }

    func execute(_: RTMPConnection, type _: RTMPChunkType) {}

    static func create(type: RTMPMessageType) -> RTMPMessage {
        switch type {
        case .chunkSize:
            return RTMPSetChunkSizeMessage()
        case .abort:
            return RTMPAbortMessge()
        case .ack:
            return RTMPAcknowledgementMessage()
        case .user:
            return RTMPUserControlMessage()
        case .windowAck:
            return RTMPWindowAcknowledgementSizeMessage()
        case .bandwidth:
            return RTMPSetPeerBandwidthMessage()
        case .audio:
            return RTMPAudioMessage()
        case .video:
            return RTMPVideoMessage()
        case .amf3Data:
            return RTMPDataMessage(objectEncoding: .amf3)
        case .amf3Command:
            return RTMPCommandMessage(objectEncoding: .amf3)
        case .amf0Data:
            return RTMPDataMessage(objectEncoding: .amf0)
        case .amf0Command:
            return RTMPCommandMessage(objectEncoding: .amf0)
        case .aggregate:
            return RTMPAggregateMessage()
        }
    }
}

/**
 5.4.1. Set Chunk Size (1)
 */
final class RTMPSetChunkSizeMessage: RTMPMessage {
    var size: UInt32 = 0

    init() {
        super.init(type: .chunkSize)
    }

    init(_ size: UInt32) {
        super.init(type: .chunkSize)
        self.size = size
    }

    override func execute(_ connection: RTMPConnection, type _: RTMPChunkType) {
        connection.socket.chunkSizeC = Int(size)
    }

    override var encoded: Data {
        get {
            guard super.encoded.isEmpty else {
                return super.encoded
            }
            super.encoded = size.bigEndian.data
            return super.encoded
        }
        set {
            if super.encoded == newValue {
                return
            }
            size = UInt32(data: newValue).bigEndian
            super.encoded = newValue
        }
    }
}

/**
 5.4.2. Abort Message (2)
 */
final class RTMPAbortMessge: RTMPMessage {
    var chunkStreamId: UInt32 = 0

    init() {
        super.init(type: .abort)
    }

    override var encoded: Data {
        get {
            guard super.encoded.isEmpty else {
                return super.encoded
            }
            super.encoded = chunkStreamId.bigEndian.data
            return super.encoded
        }
        set {
            if super.encoded == newValue {
                return
            }
            chunkStreamId = UInt32(data: newValue).bigEndian
            super.encoded = newValue
        }
    }
}

/**
 5.4.3. Acknowledgement (3)
 */
final class RTMPAcknowledgementMessage: RTMPMessage {
    var sequence: UInt32 = 0

    init() {
        super.init(type: .ack)
    }

    override func execute(_ connection: RTMPConnection, type _: RTMPChunkType) {
        // We only have one stream
        guard let stream = connection.streams.first else {
            return
        }
        stream.info.onAck(sequence: sequence)
    }

    override var encoded: Data {
        get {
            guard super.encoded.isEmpty else {
                return super.encoded
            }
            super.encoded = sequence.bigEndian.data
            return super.encoded
        }
        set {
            if super.encoded == newValue {
                return
            }
            sequence = UInt32(data: newValue).bigEndian
            super.encoded = newValue
        }
    }
}

/**
 5.4.4. Window Acknowledgement Size (5)
 */
final class RTMPWindowAcknowledgementSizeMessage: RTMPMessage {
    var size: UInt32 = 0

    init() {
        super.init(type: .windowAck)
    }

    init(_ size: UInt32) {
        super.init(type: .windowAck)
        self.size = size
    }

    override func execute(_ connection: RTMPConnection, type _: RTMPChunkType) {
        connection.windowSizeC = Int64(size)
        // connection.windowSizeS = Int64(size)
    }

    override var encoded: Data {
        get {
            guard super.encoded.isEmpty else {
                return super.encoded
            }
            super.encoded = size.bigEndian.data
            return super.encoded
        }
        set {
            if super.encoded == newValue {
                return
            }
            size = UInt32(data: newValue).bigEndian
            super.encoded = newValue
        }
    }
}

/**
 5.4.5. Set Peer Bandwidth (6)
 */
final class RTMPSetPeerBandwidthMessage: RTMPMessage {
    enum Limit: UInt8 {
        case hard = 0x00
        case soft = 0x01
        case dynamic = 0x02
        case unknown = 0xFF
    }

    var size: UInt32 = 0
    var limit: Limit = .hard

    init() {
        super.init(type: .bandwidth)
    }

    init(size: UInt32, limit: Limit) {
        super.init(type: .bandwidth)
        self.size = size
        self.limit = limit
    }

    override func execute(_: RTMPConnection, type _: RTMPChunkType) {
        // connection.bandWidth = size
    }

    override var encoded: Data {
        get {
            guard super.encoded.isEmpty else {
                return super.encoded
            }
            var payload = Data()
            payload.append(size.bigEndian.data)
            payload.append(limit.rawValue)
            super.encoded = payload
            return super.encoded
        }
        set {
            if super.encoded == newValue {
                return
            }
            size = UInt32(data: newValue[0 ..< 4]).bigEndian
            limit = Limit(rawValue: newValue[4]) ?? .unknown
            super.encoded = newValue
        }
    }
}

/**
 7.1.1. Command Message (20, 17)
 */
final class RTMPCommandMessage: RTMPMessage {
    var commandName: String = ""
    var transactionId: Int = 0
    var commandObject: ASObject?
    var arguments: [Any?] = []

    private var serializer = AMF0Serializer()

    init(objectEncoding: RTMPObjectEncoding) {
        super.init(type: objectEncoding.commandType)
    }

    init(
        streamId: UInt32,
        transactionId: Int,
        objectEncoding: RTMPObjectEncoding,
        commandName: String,
        commandObject: ASObject?,
        arguments: [Any?]
    ) {
        self.transactionId = transactionId
        self.commandName = commandName
        self.commandObject = commandObject
        self.arguments = arguments
        super.init(type: objectEncoding.commandType)
        self.streamId = streamId
    }

    override func execute(_ connection: RTMPConnection, type _: RTMPChunkType) {
        guard let responder = connection.operations.removeValue(forKey: transactionId) else {
            switch commandName {
            case "close":
                connection.close(isDisconnected: true)
            default:
                connection.dispatch(.rtmpStatus, data: arguments.first as Any?)
            }
            return
        }

        switch commandName {
        case "_result":
            responder.on(result: arguments)
        case "_error":
            responder.on(status: arguments)
        default:
            break
        }
    }

    override var encoded: Data {
        get {
            guard super.encoded.isEmpty else {
                return super.encoded
            }
            if type == .amf3Command {
                serializer.writeUInt8(0)
            }
            serializer
                .serialize(commandName)
                .serialize(transactionId)
                .serialize(commandObject)
            for i in arguments {
                serializer.serialize(i)
            }
            super.encoded = serializer.data
            serializer.clear()
            return super.encoded
        }
        set {
            if length == newValue.count {
                serializer.writeBytes(newValue)
                serializer.position = 0
                do {
                    if type == .amf3Command {
                        serializer.position = 1
                    }
                    commandName = try serializer.deserialize()
                    transactionId = try serializer.deserialize()
                    commandObject = try serializer.deserialize()
                    arguments.removeAll()
                    if serializer.bytesAvailable > 0 {
                        try arguments.append(serializer.deserialize())
                    }
                } catch {
                    logger.error("\(serializer)")
                }
                serializer.clear()
            }
            super.encoded = newValue
        }
    }
}

/**
 7.1.2. Data Message (18, 15)
 */
final class RTMPDataMessage: RTMPMessage {
    var handlerName: String = ""
    var arguments: [Any?] = []

    private var serializer = AMF0Serializer()

    init(objectEncoding: RTMPObjectEncoding) {
        super.init(type: objectEncoding.dataType)
    }

    init(
        streamId: UInt32,
        objectEncoding: RTMPObjectEncoding,
        timestamp: UInt32,
        handlerName: String,
        arguments: [Any?] = []
    ) {
        self.handlerName = handlerName
        self.arguments = arguments
        super.init(type: objectEncoding.dataType)
        self.timestamp = timestamp
        self.streamId = streamId
    }

    override func execute(_ connection: RTMPConnection, type _: RTMPChunkType) {
        guard let stream = connection.streams.first(where: { $0.id == streamId }) else {
            return
        }
        stream.info.byteCount.mutate { $0 += Int64(encoded.count) }
    }

    override var encoded: Data {
        get {
            guard super.encoded.isEmpty else {
                return super.encoded
            }

            if type == .amf3Data {
                serializer.writeUInt8(0)
            }
            _ = serializer.serialize(handlerName)
            for arg in arguments {
                serializer.serialize(arg)
            }
            super.encoded = serializer.data
            serializer.clear()

            return super.encoded
        }
        set {
            guard super.encoded != newValue else {
                return
            }

            if length == newValue.count {
                serializer.writeBytes(newValue)
                serializer.position = 0
                if type == .amf3Data {
                    serializer.position = 1
                }
                do {
                    handlerName = try serializer.deserialize()
                    while serializer.bytesAvailable > 0 {
                        try arguments.append(serializer.deserialize())
                    }
                } catch {
                    logger.error("\(serializer)")
                }
                serializer.clear()
            }

            super.encoded = newValue
        }
    }
}

/**
 7.1.5. Audio Message (9)
 */
final class RTMPAudioMessage: RTMPMessage {
    private(set) var codec: FLVAudioCodec = .unknown
    private(set) var soundRate: FLVSoundRate = .kHz44
    private(set) var soundSize: FLVSoundSize = .snd8bit
    private(set) var soundType: FLVSoundType = .stereo

    init() {
        super.init(type: .audio)
    }

    init(streamId: UInt32, timestamp: UInt32, payload: Data) {
        super.init(type: .audio)
        self.streamId = streamId
        self.timestamp = timestamp
        self.encoded = payload
    }

    override func execute(_ connection: RTMPConnection, type: RTMPChunkType) {
        guard let stream = connection.streams.first(where: { $0.id == streamId }) else {
            return
        }
        stream.info.byteCount.mutate { $0 += Int64(encoded.count) }
        guard codec.isSupported else {
            return
        }
        var duration = Int64(timestamp)
        switch type {
        case .zero:
            if stream.audioTimestampZero == -1 {
                stream.audioTimestampZero = Double(timestamp)
            }
            duration -= Int64(stream.audioTimeStamp)
            stream.audioTimeStamp = Double(timestamp) - stream.audioTimestampZero
        default:
            stream.audioTimeStamp += Double(timestamp)
        }
        switch encoded[1] {
        case FLVAACPacketType.seq.rawValue:
            let config = MpegTsAudioConfig(bytes: [UInt8](encoded[codec.headerSize ..< encoded.count]))
            stream.mixer.audio.codec.outputSettings.format = .pcm
            stream.mixer.audio.codec.inSourceFormat = config?.audioStreamBasicDescription()
        case FLVAACPacketType.raw.rawValue:
            if stream.mixer.audio.codec.inSourceFormat == nil {
                stream.mixer.audio.codec.outputSettings.format = .pcm
                stream.mixer.audio.codec.inSourceFormat = makeAudioStreamBasicDescription()
            }
            if let audioBuffer = makeAudioBuffer(stream) {
                stream.mixer.audio.codec.appendAudioBuffer(
                    audioBuffer,
                    presentationTimeStamp: CMTime(
                        seconds: stream.audioTimeStamp / 1000,
                        preferredTimescale: 1000
                    )
                )
            }
        default:
            break
        }
    }

    override var encoded: Data {
        get {
            super.encoded
        }
        set {
            if super.encoded == newValue {
                return
            }
            super.encoded = newValue
            if length == newValue.count && !newValue.isEmpty {
                guard let codec = FLVAudioCodec(rawValue: newValue[0] >> 4),
                      let soundRate = FLVSoundRate(rawValue: (newValue[0] & 0b0000_1100) >> 2),
                      let soundSize = FLVSoundSize(rawValue: (newValue[0] & 0b0000_0010) >> 1),
                      let soundType = FLVSoundType(rawValue: newValue[0] & 0b0000_0001)
                else {
                    return
                }
                self.codec = codec
                self.soundRate = soundRate
                self.soundSize = soundSize
                self.soundType = soundType
            }
        }
    }

    private func makeAudioBuffer(_ stream: RTMPStream) -> AVAudioBuffer? {
        return encoded.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) -> AVAudioBuffer? in
            guard let baseAddress = buffer.baseAddress,
                  let buffer = stream.mixer.audio.codec.makeInputBuffer() as? AVAudioCompressedBuffer
            else {
                return nil
            }
            let byteCount = encoded.count - codec.headerSize
            buffer.packetDescriptions?.pointee = AudioStreamPacketDescription(
                mStartOffset: 0,
                mVariableFramesInPacket: 0,
                mDataByteSize: UInt32(byteCount)
            )
            buffer.packetCount = 1
            buffer.byteLength = UInt32(byteCount)
            buffer.data.copyMemory(from: baseAddress.advanced(by: codec.headerSize), byteCount: byteCount)
            return buffer
        }
    }

    private func makeAudioStreamBasicDescription() -> AudioStreamBasicDescription? {
        return codec.audioStreamBasicDescription(soundRate, size: soundSize, type: soundType)
    }
}

/**
 7.1.5. Video Message (9)
 */
final class RTMPVideoMessage: RTMPMessage {
    init() {
        super.init(type: .video)
    }

    init(streamId: UInt32, timestamp: UInt32, payload: Data) {
        super.init(type: .video)
        self.streamId = streamId
        self.timestamp = timestamp
        encoded = payload
    }

    override func execute(_ connection: RTMPConnection, type: RTMPChunkType) {
        guard let stream = connection.streams.first(where: { $0.id == streamId }) else {
            return
        }
        stream.info.byteCount.mutate { $0 += Int64(encoded.count) }
        guard FLVTagType.video.headerSize <= encoded.count else {
            return
        }
        if (encoded[0] & 0b1000_0000) == 0 {
            guard encoded[0] & 0b0111_0000 >> 4 == FLVVideoCodec.avc.rawValue else {
                return
            }
            switch encoded[1] {
            case FLVAVCPacketType.seq.rawValue:
                makeFormatDescription(stream, format: .h264)
            case FLVAVCPacketType.nal.rawValue:
                if let sampleBuffer = makeSampleBuffer(stream, type: type, offset: 0) {
                    stream.mixer.video.encoder.decodeSampleBuffer(sampleBuffer)
                }
            default:
                break
            }
        } else {
            // IsExHeader for Enhancing RTMP, FLV
            guard encoded[1] == 0x68 && encoded[2] == 0x76 && encoded[3] == 0x63 && encoded[4] == 0x31 else {
                return
            }
            switch encoded[0] & 0b0000_1111 {
            case FLVVideoPacketType.sequenceStart.rawValue:
                makeFormatDescription(stream, format: .hevc)
            case FLVVideoPacketType.codedFrames.rawValue:
                if let sampleBuffer = makeSampleBuffer(stream, type: type, offset: 3) {
                    stream.mixer.video.encoder.decodeSampleBuffer(sampleBuffer)
                }
            default:
                break
            }
        }
    }

    private func makeSampleBuffer(_ stream: RTMPStream, type: RTMPChunkType,
                                  offset: Int = 0) -> CMSampleBuffer?
    {
        // compositionTime -> SI24
        var compositionTime = Int32(data: [0] + encoded[2 + offset ..< 5 + offset]).bigEndian
        compositionTime <<= 8
        compositionTime /= 256
        var duration = Int64(timestamp)
        switch type {
        case .zero:
            if stream.videoTimestampZero == -1 {
                stream.videoTimestampZero = Double(timestamp)
            }
            duration -= Int64(stream.videoTimeStamp)
            stream.videoTimeStamp = Double(timestamp) - stream.videoTimestampZero
        default:
            stream.videoTimeStamp += Double(timestamp)
        }
        var timing = CMSampleTimingInfo(
            duration: CMTimeMake(value: duration, timescale: 1000),
            presentationTimeStamp: CMTimeMake(
                value: Int64(stream.videoTimeStamp) + Int64(compositionTime),
                timescale: 1000
            ),
            decodeTimeStamp: compositionTime == 0 ? .invalid : CMTimeMake(
                value: Int64(stream.videoTimeStamp),
                timescale: 1000
            )
        )
        let blockBuffer = encoded.makeBlockBuffer(advancedBy: FLVTagType.video.headerSize + offset)
        var sampleBuffer: CMSampleBuffer?
        var sampleSize = blockBuffer?.dataLength ?? 0
        guard CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: stream.mixer.video.formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        ) == noErr else {
            return nil
        }
        sampleBuffer?.isSync = encoded[0] >> 4 & 0b0111 == FLVFrameType.key.rawValue
        return sampleBuffer
    }

    private func makeFormatDescription(_ stream: RTMPStream, format: VideoCodecSettings.Format) {
        var status = noErr
        switch format {
        case .h264:
            var config = MpegTsVideoConfigAvc()
            config.data = encoded.subdata(in: FLVTagType.video.headerSize ..< encoded.count)
            status = config.makeFormatDescription(&stream.mixer.video.formatDescription)
        case .hevc:
            var config = MpegTsVideoConfigHevc()
            config.data = encoded.subdata(in: FLVTagType.video.headerSize ..< encoded.count)
            status = config.makeFormatDescription(&stream.mixer.video.formatDescription)
        }
        if status == noErr {
            stream.dispatch(.rtmpStatus, data: RTMPStream.Code.videoDimensionChange.data(""))
        }
    }
}

/**
 7.1.6. Aggregate Message (22)
 */
final class RTMPAggregateMessage: RTMPMessage {
    init() {
        super.init(type: .aggregate)
    }
}

/**
 7.1.7. User Control Message Events
 */
final class RTMPUserControlMessage: RTMPMessage {
    enum Event: UInt8 {
        case streamBegin = 0x00
        case streamEof = 0x01
        case streamDry = 0x02
        case setBuffer = 0x03
        case recorded = 0x04
        case ping = 0x06
        case pong = 0x07
        case bufferEmpty = 0x1F
        case bufferFull = 0x20
        case unknown = 0xFF

        var bytes: [UInt8] {
            [0x00, rawValue]
        }
    }

    var event: Event = .unknown
    var value: Int32 = 0

    init() {
        super.init(type: .user)
    }

    init(event: Event, value: Int32) {
        super.init(type: .user)
        self.event = event
        self.value = value
    }

    override func execute(_ connection: RTMPConnection, type _: RTMPChunkType) {
        switch event {
        case .ping:
            connection.socket.doOutput(chunk: RTMPChunk(
                type: .zero,
                chunkStreamId: RTMPChunk.ChunkStreamId.control.rawValue,
                message: RTMPUserControlMessage(event: .pong, value: value)
            ))
        case .bufferEmpty:
            connection.streams.first(where: { $0.id == UInt32(value) })?.dispatch(
                .rtmpStatus,
                data: RTMPStream.Code.bufferEmpty.data("")
            )
        case .bufferFull:
            connection.streams.first(where: { $0.id == UInt32(value) })?.dispatch(
                .rtmpStatus,
                data: RTMPStream.Code.bufferFull.data("")
            )
        default:
            break
        }
    }

    override var encoded: Data {
        get {
            guard super.encoded.isEmpty else {
                return super.encoded
            }
            super.encoded.removeAll()
            super.encoded += event.bytes
            super.encoded += value.bigEndian.data
            return super.encoded
        }
        set {
            if super.encoded == newValue {
                return
            }
            if length == newValue.count {
                if let event = Event(rawValue: newValue[1]) {
                    self.event = event
                }
                value = Int32(data: newValue[2 ..< newValue.count]).bigEndian
            }
            super.encoded = newValue
        }
    }
}
