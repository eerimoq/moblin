import AVFoundation
import TrueTime

var payloadSize = 1316

protocol MpegTsWriterDelegate: AnyObject {
    func writer(_ writer: MpegTsWriter, doOutput data: Data)
    func writer(_ writer: MpegTsWriter, doOutputPointer pointer: UnsafeRawBufferPointer, count: Int)
}

struct MpegTsTimecode {
    let clock: Date
    let frame: UInt32
}

/// The MpegTsWriter class represents writes MPEG-2 transport stream data.
class MpegTsWriter {
    static let programAssociationTablePacketId: UInt16 = 0
    static let programMappingTablePacketId: UInt16 = 4095
    static let audioPacketId: UInt16 = 257
    static let videoPacketId: UInt16 = 256
    private static let audioStreamId: UInt8 = 192
    private static let videoStreamId: UInt8 = 224
    private static let segmentDuration = CMTime(seconds: 2)
    weak var delegate: (any MpegTsWriterDelegate)?
    private var isRunning = false
    private var audioContinuityCounter: UInt8 = 0
    private var videoContinuityCounter: UInt8 = 0
    private var patContinuityCounter: UInt8 = 0
    private var pmtContinuityCounter: UInt8 = 0
    private var latestPeriodicallySendProgramTime: CMTime = .zero
    private var videoData: [Data?] = [nil, nil]
    private var videoDataOffset = 0

    private var programAssociationTable: MpegTsProgramAssociation = {
        let programAssociationTable = MpegTsProgramAssociation()
        programAssociationTable.programs = [1: MpegTsWriter.programMappingTablePacketId]
        return programAssociationTable
    }()

    private var programMappingTable = MpegTsProgramMapping()
    private var audioConfig: MpegTsAudioConfig?
    private var videoConfig: MpegTsVideoConfig?
    private var programClockReferenceTimestamp: CMTime?
    private let timecodesEnabled: Bool
    private var presentationTimeStampBase: Double?
    private var previousDecodeTimeStamp: Double?
    private var estimatedFrameDuration: Double = 0.033
    private var offsetingFrames: Bool = false
    private let newSrt: Bool

    init(timecodesEnabled: Bool, newSrt: Bool) {
        self.timecodesEnabled = timecodesEnabled
        self.newSrt = newSrt
    }

    func startRunning() {
        isRunning = true
    }

    func stopRunning() {
        guard isRunning else {
            return
        }
        audioContinuityCounter = 0
        videoContinuityCounter = 0
        patContinuityCounter = 0
        pmtContinuityCounter = 0
        programAssociationTable.programs.removeAll()
        programAssociationTable.programs = [1: MpegTsWriter.programMappingTablePacketId]
        programMappingTable = MpegTsProgramMapping()
        audioConfig = nil
        videoConfig = nil
        videoDataOffset = 0
        videoData = [nil, nil]
        programClockReferenceTimestamp = nil
        presentationTimeStampBase = nil
        previousDecodeTimeStamp = nil
        isRunning = false
    }

    private func setAudioConfig(_ config: MpegTsAudioConfig) {
        audioConfig = config
        writeProgramIfNeeded()
    }

    private func setVideoConfig(_ config: MpegTsVideoConfig) {
        videoConfig = config
        writeProgramIfNeeded()
    }

    private func canWriteFor() -> Bool {
        return (audioConfig != nil) && (videoConfig != nil)
    }

    private func encode(_ packetId: UInt16, _ packets: [MpegTsPacket]) -> Data {
        var packetsBuffer = createPacketsBuffer(packetsCount: packets.count)
        packetsBuffer.withUnsafeMutableBytes { (pointer: UnsafeMutableRawBufferPointer) in
            var pointer = pointer
            for var packet in packets {
                packet.continuityCounter = nextContinuityCounter(packetId: packetId)
                packet.encodeFixedHeaderInto(pointer: pointer)
                pointer = UnsafeMutableRawBufferPointer(rebasing: pointer[MpegTsPacket.fixedHeaderSize...])
                if let adaptationField = packet.adaptationField {
                    let encodedAdaptationField = adaptationField.encode()
                    encodedAdaptationField.withUnsafeBytes {
                        pointer.copyMemory(from: $0)
                    }
                    pointer = UnsafeMutableRawBufferPointer(rebasing: pointer[encodedAdaptationField.count...])
                }
                packet.payload.withUnsafeBytes {
                    pointer.copyMemory(from: $0)
                }
                pointer = UnsafeMutableRawBufferPointer(rebasing: pointer[packet.payload.count...])
            }
        }
        return packetsBuffer
    }

    private func createPacketsBuffer(packetsCount: Int) -> Data {
        let packetsBufferSize = packetsCount * MpegTsPacket.size
        return Data(
            bytesNoCopy: UnsafeMutableRawPointer.allocate(byteCount: packetsBufferSize, alignment: 8),
            count: packetsBufferSize,
            deallocator: .custom { (pointer: UnsafeMutableRawPointer, _: Int) in pointer.deallocate() }
        )
    }

    private func nextContinuityCounter(packetId: UInt16) -> UInt8 {
        switch packetId {
        case MpegTsWriter.audioPacketId:
            defer {
                audioContinuityCounter += 1
                audioContinuityCounter &= 0x0F
            }
            return audioContinuityCounter
        case MpegTsWriter.videoPacketId:
            defer {
                videoContinuityCounter += 1
                videoContinuityCounter &= 0x0F
            }
            return videoContinuityCounter
        default:
            return 0
        }
    }

    private func nextProgramAssociationTableContinuityCounter() -> UInt8 {
        defer {
            patContinuityCounter += 1
            patContinuityCounter &= 0x0F
        }
        return patContinuityCounter
    }

    private func nextProgramMappingTableContinuityCounter() -> UInt8 {
        defer {
            pmtContinuityCounter += 1
            pmtContinuityCounter &= 0x0F
        }
        return pmtContinuityCounter
    }

    private func periodicallySendProgram(_ now: CMTime) {
        guard now - latestPeriodicallySendProgramTime > MpegTsWriter.segmentDuration else {
            return
        }
        writeProgram()
        latestPeriodicallySendProgramTime = now
    }

    private func writeNew(_ data: Data) {
        delegate?.writer(self, doOutput: data)
    }

    private func writeOld(_ data: Data) {
        writeBytesOld(data)
    }

    private func writePacketOld(_ data: Data) {
        delegate?.writer(self, doOutput: data)
    }

    private func writePacketPointerOld(pointer: UnsafeRawBufferPointer, count: Int) {
        delegate?.writer(self, doOutputPointer: pointer, count: count)
    }

    private func writeBytesOld(_ data: Data) {
        data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            writeBytesPointerOld(pointer: pointer, count: data.count)
        }
    }

    private func writeBytesPointerOld(pointer: UnsafeRawBufferPointer, count: Int) {
        for offset in stride(from: 0, to: count, by: payloadSize) {
            let length = min(payloadSize, count - offset)
            writePacketPointerOld(
                pointer: UnsafeRawBufferPointer(rebasing: pointer[offset ..< offset + length]),
                count: length
            )
        }
    }

    private func appendVideoData(data: Data?) {
        videoData[0] = videoData[1]
        videoData[1] = data
        videoDataOffset = 0
    }

    private func writeVideo(data: Data) {
        if newSrt {
            writeVideoNew(data: data)
        } else {
            writeVideoOld(data: data)
        }
    }

    private func writeAudio(data: Data) {
        if newSrt {
            writeAudioNew(data: data)
        } else {
            writeAudioOld(data: data)
        }
    }

    private func writeVideoNew(data: Data) {
        if let videoData = videoData[0] {
            writeNew(videoData[videoDataOffset ..< videoData.count])
        }
        appendVideoData(data: data)
    }

    private func writeAudioNew(data: Data) {
        if let videoData = videoData[0] {
            for var packet in data.chunks(payloadSize) {
                let videoSize = payloadSize - packet.count
                if videoSize > 0 {
                    let endOffset = min(videoDataOffset + videoSize, videoData.count)
                    if videoDataOffset != endOffset {
                        packet = videoData[videoDataOffset ..< endOffset] + packet
                        videoDataOffset = endOffset
                    }
                }
                writeNew(packet)
            }
            if videoDataOffset == videoData.count {
                appendVideoData(data: nil)
            }
        } else {
            writeNew(data)
        }
    }

    private func writeVideoOld(data: Data) {
        if let videoData = videoData[0] {
            videoData.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
                writeBytesPointerOld(
                    pointer: UnsafeRawBufferPointer(
                        rebasing: pointer[videoDataOffset ..< videoData.count]
                    ),
                    count: videoData.count - videoDataOffset
                )
            }
        }
        appendVideoData(data: data)
    }

    private func writeAudioOld(data: Data) {
        if let videoData = videoData[0] {
            for var packet in data.chunks(payloadSize) {
                let videoSize = payloadSize - packet.count
                if videoSize > 0 {
                    let endOffset = min(videoDataOffset + videoSize, videoData.count)
                    if videoDataOffset != endOffset {
                        packet = videoData[videoDataOffset ..< endOffset] + packet
                        videoDataOffset = endOffset
                    }
                }
                writeOld(packet)
            }
            if videoDataOffset == videoData.count {
                appendVideoData(data: nil)
            }
        } else {
            writeOld(data)
        }
    }

    private func writeProgram() {
        programMappingTable.programClockReferencePacketId = MpegTsWriter.audioPacketId
        var patPacket = programAssociationTable.packet(MpegTsWriter.programAssociationTablePacketId)
        var pmtPacket = programMappingTable.packet(MpegTsWriter.programMappingTablePacketId)
        patPacket.continuityCounter = nextProgramAssociationTableContinuityCounter()
        pmtPacket.continuityCounter = nextProgramMappingTableContinuityCounter()
        if newSrt {
            writeNew(patPacket.encode() + pmtPacket.encode())
        } else {
            writeOld(patPacket.encode() + pmtPacket.encode())
        }
    }

    private func writeProgramIfNeeded() {
        guard canWriteFor() else {
            return
        }
        writeProgram()
    }

    private func updateProgramClockReference(_ timestamp: CMTime) -> UInt64? {
        var programClockReference: UInt64?
        if timestamp.seconds - (programClockReferenceTimestamp?.seconds ?? 0) >= 0.02 {
            programClockReference = UInt64(max(timestamp.seconds, 0) * TSTimestamp.resolution)
            programClockReferenceTimestamp = timestamp
        }
        return programClockReference
    }

    private func addStreamSpecificDatasToProgramMappingTable(packetId: UInt16, data: ElementaryStreamSpecificData) {
        if let index = programMappingTable.elementaryStreamSpecificDatas.firstIndex(where: {
            $0.elementaryPacketId == packetId
        }) {
            programMappingTable.elementaryStreamSpecificDatas[index] = data
        } else {
            programMappingTable.elementaryStreamSpecificDatas.append(data)
        }
    }

    private func addAudioSpecificDatas(data: ElementaryStreamSpecificData) {
        addStreamSpecificDatasToProgramMappingTable(packetId: MpegTsWriter.audioPacketId, data: data)
    }

    private func addVideoSpecificDatas(data: ElementaryStreamSpecificData) {
        addStreamSpecificDatasToProgramMappingTable(packetId: MpegTsWriter.videoPacketId, data: data)
    }
}

extension MpegTsWriter: AudioCodecDelegate {
    func audioCodecOutputFormat(_ format: AVAudioFormat) {
        logger.info("ts-writer: Audio setup \(format)")
        var data = ElementaryStreamSpecificData()
        switch format.formatDescription.audioStreamBasicDescription?.mFormatID {
        case kAudioFormatMPEG4AAC:
            data.streamType = .adtsAac
        case kAudioFormatOpus:
            data.streamType = .mpeg2PacketizedData
            data.appendDescriptor(tag: .registration, data: elementaryStreamDescriptiorRegistrationOpus)
            data.appendDescriptor(tag: .extension, data: Data([0x80, UInt8(format.channelCount)]))
        default:
            logger.info("ts-writer: Unsupported audio format.")
            return
        }
        data.elementaryPacketId = MpegTsWriter.audioPacketId
        addAudioSpecificDatas(data: data)
        audioContinuityCounter = 0
        setAudioConfig(MpegTsAudioConfig(formatDescription: format.formatDescription))
    }

    func audioCodecOutputBuffer(_ audioBuffer: AVAudioCompressedBuffer, _ presentationTimeStamp: CMTime) {
        guard canWriteFor(), let audioConfig else {
            return
        }
        guard let packetizedElementaryStream = MpegTsPacketizedElementaryStream(
            bytes: audioBuffer.data.assumingMemoryBound(to: UInt8.self),
            count: Int(audioBuffer.byteLength),
            presentationTimeStamp: presentationTimeStamp,
            config: audioConfig,
            streamId: MpegTsWriter.audioStreamId
        ) else {
            return
        }
        let programClockReference = updateProgramClockReference(presentationTimeStamp)
        let packets = packetizedElementaryStream.arrayOfPackets(MpegTsWriter.audioPacketId,
                                                                true,
                                                                programClockReference)
        periodicallySendProgram(presentationTimeStamp)
        writeAudio(data: encode(MpegTsWriter.audioPacketId, packets))
    }
}

extension MpegTsWriter: VideoEncoderDelegate {
    func videoEncoderOutputFormat(_ encoder: VideoEncoder, _ formatDescription: CMFormatDescription) {
        var data = ElementaryStreamSpecificData()
        data.elementaryPacketId = MpegTsWriter.videoPacketId
        videoContinuityCounter = 0
        let videoConfig: MpegTsVideoConfig
        switch encoder.settings.value.format {
        case .h264:
            data.streamType = .h264
            guard let config = MpegTsVideoConfigAvc(formatDescription: formatDescription) else {
                logger.info("mpeg-ts: Failed to create avcC")
                return
            }
            videoConfig = .avc(config)
        case .hevc:
            data.streamType = .h265
            guard let config = MpegTsVideoConfigHevc(formatDescription: formatDescription) else {
                logger.info("mpeg-ts: Failed to create hvcC")
                return
            }
            videoConfig = .hevc(config)
        }
        addVideoSpecificDatas(data: data)
        setVideoConfig(videoConfig)
    }

    func videoEncoderOutputSampleBuffer(_: VideoEncoder,
                                        _ sampleBuffer: CMSampleBuffer,
                                        _ decodeTimeStampOffset: CMTime)
    {
        guard canWriteFor(), let (buffer, length) = sampleBuffer.dataBuffer?.getDataPointer() else {
            return
        }
        let decodeTimeStamp = CMTimeSubtract(sampleBuffer.decodeTimeStamp, decodeTimeStampOffset)
        let randomAccessIndicator = sampleBuffer.isSync
        let bytes = UnsafeMutableRawPointer(buffer).bindMemory(to: UInt8.self, capacity: length)
        updateTimecodeReference()
        let timecode = makeTimecode(sampleBuffer.presentationTimeStamp, decodeTimeStamp)
        let packetizedElementaryStream: MpegTsPacketizedElementaryStream
        switch videoConfig {
        case let .avc(videoConfig):
            packetizedElementaryStream = MpegTsPacketizedElementaryStream(
                bytes: bytes,
                count: length,
                presentationTimeStamp: sampleBuffer.presentationTimeStamp,
                decodeTimeStamp: decodeTimeStamp,
                config: randomAccessIndicator ? videoConfig : nil,
                streamId: MpegTsWriter.videoStreamId,
                timecode: timecode
            )
        case let .hevc(videoConfig):
            packetizedElementaryStream = MpegTsPacketizedElementaryStream(
                bytes: bytes,
                count: length,
                presentationTimeStamp: sampleBuffer.presentationTimeStamp,
                decodeTimeStamp: decodeTimeStamp,
                config: randomAccessIndicator ? videoConfig : nil,
                streamId: MpegTsWriter.videoStreamId,
                timecode: timecode
            )
        default:
            return
        }
        let packets = packetizedElementaryStream.arrayOfPackets(MpegTsWriter.videoPacketId,
                                                                randomAccessIndicator,
                                                                nil)
        writeVideo(data: encode(MpegTsWriter.videoPacketId, packets))
    }

    private func updateTimecodeReference() {
        guard timecodesEnabled, presentationTimeStampBase == nil else {
            return
        }
        guard let now = TrueTimeClient.sharedInstance.referenceTime?.now().timeIntervalSince1970 else {
            // logger.info("timecode: Failed to get NTP time")
            return
        }
        let presentationTimeStamp = currentPresentationTimeStamp().seconds
        presentationTimeStampBase = now - presentationTimeStamp
        logger.info("""
        timecode: Updated base time - NTP: \(now) PTS: \(presentationTimeStamp) \
        BASE: \(presentationTimeStampBase!)
        """)
    }

    private func makeTimecode(_ presentationTimeStamp: CMTime, _ decodeTimeStamp: CMTime) -> MpegTsTimecode? {
        guard timecodesEnabled, let presentationTimeStampBase else {
            return nil
        }
        let presentationTimeStamp = presentationTimeStamp.seconds
        var decodeTimeStamp = decodeTimeStamp.seconds
        if decodeTimeStamp.isNaN {
            decodeTimeStamp = presentationTimeStamp
        }
        if let previousDecodeTimeStamp {
            estimatedFrameDuration = 0.7 * estimatedFrameDuration + 0.3 * (decodeTimeStamp - previousDecodeTimeStamp)
        }
        previousDecodeTimeStamp = decodeTimeStamp
        let now = Date(timeIntervalSince1970: presentationTimeStampBase
            + presentationTimeStamp
            + (offsetingFrames ? estimatedFrameDuration / 2 : 0))
        let offsetWithinSecond = now.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)
        let frame = offsetWithinSecond / estimatedFrameDuration
        let offsetFromFrame = offsetWithinSecond - frame.rounded(.down) * estimatedFrameDuration
        if offsetFromFrame < estimatedFrameDuration / 6 || offsetFromFrame > estimatedFrameDuration * 5 / 6 {
            offsetingFrames.toggle()
        }
        // logger.info("timecode: now: \(now), frame: \(frame)")
        return MpegTsTimecode(clock: now, frame: UInt32(frame))
    }
}
