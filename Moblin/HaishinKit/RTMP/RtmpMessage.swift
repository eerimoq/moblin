import AVFoundation

enum RtmpMessageType: UInt8 {
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

class RtmpMessage {
    let type: RtmpMessageType
    var length: Int = 0
    var streamId: UInt32 = 0
    var timestamp: UInt32 = 0
    var encoded = Data()

    init(type: RtmpMessageType) {
        self.type = type
    }

    func execute(_: RtmpConnection, type _: RTMPChunkType) {}

    static func create(type: RtmpMessageType) -> RtmpMessage {
        switch type {
        case .chunkSize:
            return RtmpSetChunkSizeMessage()
        case .abort:
            return RtmpAbortMessge()
        case .ack:
            return RtmpAcknowledgementMessage()
        case .user:
            return RtmpUserControlMessage()
        case .windowAck:
            return RtmpWindowAcknowledgementSizeMessage()
        case .bandwidth:
            return RtmpSetPeerBandwidthMessage()
        case .audio:
            return RtmpAudioMessage()
        case .video:
            return RtmpVideoMessage()
        case .amf3Data:
            return RtmpDataMessage(objectEncoding: .amf3)
        case .amf3Command:
            return RtmpCommandMessage(objectEncoding: .amf3)
        case .amf0Data:
            return RtmpDataMessage(objectEncoding: .amf0)
        case .amf0Command:
            return RtmpCommandMessage(objectEncoding: .amf0)
        case .aggregate:
            return RtmpAggregateMessage()
        }
    }
}

/**
 5.4.1. Set Chunk Size (1)
 */
final class RtmpSetChunkSizeMessage: RtmpMessage {
    var size: UInt32 = 0

    init() {
        super.init(type: .chunkSize)
    }

    init(_ size: UInt32) {
        super.init(type: .chunkSize)
        self.size = size
    }

    override func execute(_ connection: RtmpConnection, type _: RTMPChunkType) {
        connection.socket.maximumChunkSizeFromServer = Int(size)
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
final class RtmpAbortMessge: RtmpMessage {
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
final class RtmpAcknowledgementMessage: RtmpMessage {
    var sequence: UInt32 = 0

    init() {
        super.init(type: .ack)
    }

    override func execute(_ connection: RtmpConnection, type _: RTMPChunkType) {
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
final class RtmpWindowAcknowledgementSizeMessage: RtmpMessage {
    var size: UInt32 = 0

    init() {
        super.init(type: .windowAck)
    }

    init(_ size: UInt32) {
        super.init(type: .windowAck)
        self.size = size
    }

    override func execute(_ connection: RtmpConnection, type _: RTMPChunkType) {
        connection.windowSizeFromServer = Int64(size)
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
final class RtmpSetPeerBandwidthMessage: RtmpMessage {
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

    override func execute(_: RtmpConnection, type _: RTMPChunkType) {
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
final class RtmpCommandMessage: RtmpMessage {
    var commandName: String = ""
    var transactionId: Int = 0
    var commandObject: AsObject?
    var arguments: [Any?] = []

    private var serializer = Amf0Serializer()

    init(objectEncoding: RtmpObjectEncoding) {
        super.init(type: objectEncoding.commandType)
    }

    init(
        streamId: UInt32,
        transactionId: Int,
        objectEncoding: RtmpObjectEncoding,
        commandName: String,
        commandObject: AsObject?,
        arguments: [Any?]
    ) {
        self.transactionId = transactionId
        self.commandName = commandName
        self.commandObject = commandObject
        self.arguments = arguments
        super.init(type: objectEncoding.commandType)
        self.streamId = streamId
    }

    override func execute(_ connection: RtmpConnection, type _: RTMPChunkType) {
        guard let responder = connection.callCompletions.removeValue(forKey: transactionId) else {
            switch commandName {
            case "close":
                connection.disconnectInternal()
            default:
                connection.dispatch(.rtmpStatus, data: arguments.first as Any?)
            }
            return
        }
        switch commandName {
        case "_result":
            responder(arguments)
        case "_error":
            // Should probably do something.
            break
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
            for argument in arguments {
                serializer.serialize(argument)
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
final class RtmpDataMessage: RtmpMessage {
    var handlerName: String = ""
    var arguments: [Any?] = []

    private var serializer = Amf0Serializer()

    init(objectEncoding: RtmpObjectEncoding) {
        super.init(type: objectEncoding.dataType)
    }

    init(
        streamId: UInt32,
        objectEncoding: RtmpObjectEncoding,
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

    override func execute(_ connection: RtmpConnection, type _: RTMPChunkType) {
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
final class RtmpAudioMessage: RtmpMessage {
    private(set) var codec: FlvAudioCodec = .unknown
    private(set) var soundRate: FlvSoundRate = .kHz44
    private(set) var soundSize: FlvSoundSize = .snd8bit
    private(set) var soundType: FlvSoundType = .stereo

    init() {
        super.init(type: .audio)
    }

    init(streamId: UInt32, timestamp: UInt32, payload: Data) {
        super.init(type: .audio)
        self.streamId = streamId
        self.timestamp = timestamp
        encoded = payload
    }

    override func execute(_ connection: RtmpConnection, type: RTMPChunkType) {
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
        case FlvAacPacketType.seq.rawValue:
            let config = MpegTsAudioConfig(bytes: [UInt8](encoded[codec.headerSize ..< encoded.count]))
            stream.mixer.audio.encoder.settings.format = .pcm
            stream.mixer.audio.encoder.inSourceFormat = config?.audioStreamBasicDescription()
        case FlvAacPacketType.raw.rawValue:
            if stream.mixer.audio.encoder.inSourceFormat == nil {
                stream.mixer.audio.encoder.settings.format = .pcm
                stream.mixer.audio.encoder.inSourceFormat = makeAudioStreamBasicDescription()
            }
            if let audioBuffer = makeAudioBuffer(stream) {
                stream.mixer.audio.encoder.appendAudioBuffer(
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
                guard let codec = FlvAudioCodec(rawValue: newValue[0] >> 4),
                      let soundRate = FlvSoundRate(rawValue: (newValue[0] & 0b0000_1100) >> 2),
                      let soundSize = FlvSoundSize(rawValue: (newValue[0] & 0b0000_0010) >> 1),
                      let soundType = FlvSoundType(rawValue: newValue[0] & 0b0000_0001)
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

    private func makeAudioBuffer(_ stream: RtmpStream) -> AVAudioBuffer? {
        return encoded.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) -> AVAudioBuffer? in
            guard let baseAddress = buffer.baseAddress,
                  let buffer = stream.mixer.audio.encoder.makeInputBuffer() as? AVAudioCompressedBuffer
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
final class RtmpVideoMessage: RtmpMessage {
    init() {
        super.init(type: .video)
    }

    init(streamId: UInt32, timestamp: UInt32, payload: Data) {
        super.init(type: .video)
        self.streamId = streamId
        self.timestamp = timestamp
        encoded = payload
    }

    override func execute(_ connection: RtmpConnection, type: RTMPChunkType) {
        guard let stream = connection.streams.first(where: { $0.id == streamId }) else {
            return
        }
        stream.info.byteCount.mutate { $0 += Int64(encoded.count) }
        guard FlvTagType.video.headerSize <= encoded.count else {
            return
        }
        if (encoded[0] & 0b1000_0000) == 0 {
            guard encoded[0] & 0b0111_0000 >> 4 == FlvVideoCodec.avc.rawValue else {
                return
            }
            switch encoded[1] {
            case FlvAvcPacketType.seq.rawValue:
                makeFormatDescription(stream, format: .h264)
            case FlvAvcPacketType.nal.rawValue:
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
            case FlvVideoPacketType.sequenceStart.rawValue:
                makeFormatDescription(stream, format: .hevc)
            case FlvVideoPacketType.codedFrames.rawValue:
                if let sampleBuffer = makeSampleBuffer(stream, type: type, offset: 3) {
                    stream.mixer.video.encoder.decodeSampleBuffer(sampleBuffer)
                }
            default:
                break
            }
        }
    }

    private func makeSampleBuffer(_ stream: RtmpStream, type: RTMPChunkType,
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
        let blockBuffer = encoded.makeBlockBuffer(advancedBy: FlvTagType.video.headerSize + offset)
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
        sampleBuffer?.isSync = encoded[0] >> 4 & 0b0111 == FlvFrameType.key.rawValue
        return sampleBuffer
    }

    private func makeFormatDescription(_ stream: RtmpStream, format: VideoCodecSettings.Format) {
        var status = noErr
        switch format {
        case .h264:
            var config = MpegTsVideoConfigAvc()
            config.data = encoded.subdata(in: FlvTagType.video.headerSize ..< encoded.count)
            status = config.makeFormatDescription(&stream.mixer.video.formatDescription)
        case .hevc:
            var config = MpegTsVideoConfigHevc()
            config.data = encoded.subdata(in: FlvTagType.video.headerSize ..< encoded.count)
            status = config.makeFormatDescription(&stream.mixer.video.formatDescription)
        }
        if status == noErr {
            stream.dispatch(.rtmpStatus, data: RtmpStreamCode.videoDimensionChange.eventData())
        }
    }
}

/**
 7.1.6. Aggregate Message (22)
 */
final class RtmpAggregateMessage: RtmpMessage {
    init() {
        super.init(type: .aggregate)
    }
}

/**
 7.1.7. User Control Message Events
 */
final class RtmpUserControlMessage: RtmpMessage {
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

    override func execute(_ connection: RtmpConnection, type _: RTMPChunkType) {
        switch event {
        case .ping:
            _ = connection.socket.write(chunk: RtmpChunk(
                type: .zero,
                chunkStreamId: RtmpChunk.ChunkStreamId.control.rawValue,
                message: RtmpUserControlMessage(event: .pong, value: value)
            ))
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
