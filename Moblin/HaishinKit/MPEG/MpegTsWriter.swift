import AVFoundation
import CoreMedia
import Foundation

var payloadSize: Int = 1316
var mpegTsWriterProgramClockReferencePacketId = MpegTsWriter.videoPacketId

protocol MpegTsWriterDelegate: AnyObject {
    func writer(_ writer: MpegTsWriter, doOutput data: Data)
    func writer(_ writer: MpegTsWriter, doOutputPointer pointer: UnsafeRawBufferPointer, count: Int)
}

/// The MpegTsWriter class represents writes MPEG-2 transport stream data.
class MpegTsWriter {
    static let programAssociationTablePacketId: UInt16 = 0
    static let programMappingTablePacketId: UInt16 = 4095
    static let audioPacketId: UInt16 = 257
    static let videoPacketId: UInt16 = 256
    private static let audioStreamId: UInt8 = 192
    private static let videoStreamId: UInt8 = 224
    private static let segmentDuration: Double = 2
    weak var delegate: (any MpegTsWriterDelegate)?
    private var isRunning: Atomic<Bool> = .init(false)
    var expectedMedias: Set<AVMediaType> = []
    private var audioContinuityCounter: UInt8 = 0
    private var videoContinuityCounter: UInt8 = 0
    private var rotatedTimestamp = CMTime.zero
    private let outputLock = DispatchQueue(
        label: "com.haishinkit.HaishinKit.MpegTsWriter",
        qos: .userInitiated
    )
    private var videoData: [Data?] = [nil, nil]
    private var videoDataOffset: Int = 0

    private var programAssociationTable: MpegTsProgramAssociation = {
        let programAssociationTable = MpegTsProgramAssociation()
        programAssociationTable.programs = [1: MpegTsWriter.programMappingTablePacketId]
        return programAssociationTable
    }()

    private var programMappingTable = MpegTsProgramMapping()
    private var audioConfig: MpegTsAudioConfig? {
        didSet {
            writeProgramIfNeeded()
        }
    }

    private var videoConfig: MpegTsVideoConfig? {
        didSet {
            writeProgramIfNeeded()
        }
    }

    private var baseVideoTimestamp: CMTime = .invalid
    private var baseAudioTimestamp: CMTime = .invalid
    private var programClockReferenceTimestamp = CMTime.zero

    init() {}

    func startRunning() {
        isRunning.mutate { $0 = true }
    }

    func stopRunning() {
        guard isRunning.value else {
            return
        }
        audioContinuityCounter = 0
        videoContinuityCounter = 0
        programAssociationTable.programs.removeAll()
        programAssociationTable.programs = [1: MpegTsWriter.programMappingTablePacketId]
        programMappingTable = MpegTsProgramMapping()
        audioConfig = nil
        videoConfig = nil
        baseAudioTimestamp = .invalid
        baseVideoTimestamp = .invalid
        programClockReferenceTimestamp = .zero
        isRunning.mutate { $0 = false }
    }

    private func canWriteFor() -> Bool {
        return (expectedMedias.contains(.audio) == (audioConfig != nil))
            && (expectedMedias.contains(.video) == (videoConfig != nil))
    }

    private func encode(_ packetId: UInt16,
                        presentationTimeStamp: CMTime,
                        decodeTimeStamp: CMTime,
                        randomAccessIndicator: Bool,
                        PES: MpegTsPacketizedElementaryStream) -> Data
    {
        let timestamp = decodeTimeStamp == .invalid ? presentationTimeStamp : decodeTimeStamp
        let packets = split(packetId, PES: PES, timestamp: timestamp)
        packets[0].adaptationField!.randomAccessIndicator = randomAccessIndicator
        rotateFileHandle(timestamp)
        let count = packets.count * MpegTsPacket.size
        var data = Data(
            bytesNoCopy: UnsafeMutableRawPointer.allocate(byteCount: count, alignment: 8),
            count: count,
            deallocator: .custom { (pointer: UnsafeMutableRawPointer, _: Int) in pointer.deallocate() }
        )
        data.withUnsafeMutableBytes { (pointer: UnsafeMutableRawBufferPointer) in
            var pointer = pointer
            for var packet in packets {
                packet.continuityCounter = nextContinuityCounter(packetId: packetId)
                packet.encodeFixedHeaderInto(pointer: pointer)
                pointer = UnsafeMutableRawBufferPointer(rebasing: pointer[4...])
                if let adaptationField = packet.adaptationField {
                    adaptationField.encode().withUnsafeBytes { (adaptationPointer: UnsafeRawBufferPointer) in
                        pointer.copyMemory(from: adaptationPointer)
                    }
                    pointer =
                        UnsafeMutableRawBufferPointer(rebasing: pointer[adaptationField.encode().count...])
                }
                packet.payload.withUnsafeBytes { (payloadPointer: UnsafeRawBufferPointer) in
                    pointer.copyMemory(from: payloadPointer)
                }
                pointer = UnsafeMutableRawBufferPointer(rebasing: pointer[packet.payload.count...])
            }
        }
        return data
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

    private func rotateFileHandle(_ timestamp: CMTime) {
        let duration = timestamp.seconds - rotatedTimestamp.seconds
        if duration <= MpegTsWriter.segmentDuration {
            return
        }
        writeProgram()
        rotatedTimestamp = timestamp
    }

    private func write(_ data: Data) {
        outputLock.sync {
            self.writeBytes(data)
        }
    }

    private func writePacket(_ data: Data) {
        delegate?.writer(self, doOutput: data)
    }

    private func writePacketPointer(pointer: UnsafeRawBufferPointer, count: Int) {
        delegate?.writer(self, doOutputPointer: pointer, count: count)
    }

    private func writeBytes(_ data: Data) {
        data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            writeBytesPointer(pointer: pointer, count: data.count)
        }
    }

    private func writeBytesPointer(pointer: UnsafeRawBufferPointer, count: Int) {
        for offset in stride(from: 0, to: count, by: payloadSize) {
            let length = min(payloadSize, count - offset)
            writePacketPointer(
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
        outputLock.sync {
            if let videoData = videoData[0] {
                videoData.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
                    writeBytesPointer(
                        pointer: UnsafeRawBufferPointer(
                            rebasing: pointer[videoDataOffset ..< videoData.count]
                        ),
                        count: videoData.count - videoDataOffset
                    )
                }
            }
            self.appendVideoData(data: data)
        }
    }

    private func writeAudio(data: Data) {
        outputLock.sync {
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
                    self.writePacket(packet)
                }
                if videoDataOffset == videoData.count {
                    self.appendVideoData(data: nil)
                }
            } else {
                self.writeBytes(data)
            }
        }
    }

    private func writeProgram() {
        programMappingTable.programClockReferencePacketId = mpegTsWriterProgramClockReferencePacketId
        write(programAssociationTable.packet(MpegTsWriter.programAssociationTablePacketId).encode()
            + programMappingTable.packet(MpegTsWriter.programMappingTablePacketId).encode())
    }

    private func writeProgramIfNeeded() {
        guard !expectedMedias.isEmpty, canWriteFor() else {
            return
        }
        writeProgram()
    }

    private func split(_ packetId: UInt16, PES: MpegTsPacketizedElementaryStream,
                       timestamp: CMTime) -> [MpegTsPacket]
    {
        var programClockReference: UInt64?
        let timeSinceLatestProgramClockReference = timestamp.seconds - programClockReferenceTimestamp.seconds
        if mpegTsWriterProgramClockReferencePacketId == packetId,
           timeSinceLatestProgramClockReference >= 0.02
        {
            let baseTimestamp = (packetId == MpegTsWriter
                .videoPacketId ? baseVideoTimestamp : baseAudioTimestamp)
            let delta = timestamp.seconds - baseTimestamp.seconds
            // Negative delta handling is not correct, but makes the app not crash. Improve
            // timestamp handling in general at some point. How?
            programClockReference = UInt64(max(delta, 0) * TSTimestamp.resolution)
            programClockReferenceTimestamp = timestamp
        }
        return PES.arrayOfPackets(packetId, programClockReference)
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
        default:
            logger.info("ts-writer: Unsupported audio format.")
            return
        }
        data.elementaryPacketId = MpegTsWriter.audioPacketId
        programMappingTable.elementaryStreamSpecificDatas.append(data)
        audioContinuityCounter = 0
        audioConfig = MpegTsAudioConfig(formatDescription: format.formatDescription)
    }

    func audioCodecOutputBuffer(_ buffer: AVAudioBuffer, _ presentationTimeStamp: CMTime) {
        guard let audioBuffer = buffer as? AVAudioCompressedBuffer else {
            logger.info("ts-writer: Audio output no buffer")
            return
        }
        guard canWriteFor() else {
            return
        }
        if baseAudioTimestamp == .invalid {
            baseAudioTimestamp = presentationTimeStamp
            if mpegTsWriterProgramClockReferencePacketId == MpegTsWriter.audioPacketId {
                programClockReferenceTimestamp = baseAudioTimestamp
            }
        }
        guard let audioConfig else {
            return
        }
        guard let PES = MpegTsPacketizedElementaryStream(
            bytes: audioBuffer.data.assumingMemoryBound(to: UInt8.self),
            count: audioBuffer.byteLength,
            presentationTimeStamp: presentationTimeStamp,
            timestamp: baseAudioTimestamp,
            config: audioConfig,
            streamID: MpegTsWriter.audioStreamId
        ) else {
            return
        }
        writeAudio(data: encode(
            MpegTsWriter.audioPacketId,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: .invalid,
            randomAccessIndicator: true,
            PES: PES
        ))
    }
}

extension MpegTsWriter: VideoCodecDelegate {
    func videoCodecOutputFormat(_ codec: VideoCodec, _ formatDescription: CMFormatDescription) {
        var data = ElementaryStreamSpecificData()
        data.elementaryPacketId = MpegTsWriter.videoPacketId
        videoContinuityCounter = 0
        switch codec.settings.format {
        case .h264:
            guard let avcC = MpegTsVideoConfigAvc.getData(formatDescription) else {
                logger.info("mpeg-ts: Failed to create avcC")
                return
            }
            data.streamType = .h264
            programMappingTable.elementaryStreamSpecificDatas.append(data)
            videoConfig = MpegTsVideoConfigAvc(data: avcC)
        case .hevc:
            guard let hvcC = MpegTsVideoConfigHevc.getData(formatDescription) else {
                logger.info("mpeg-ts: Failed to create hvcC")
                return
            }
            data.streamType = .h265
            programMappingTable.elementaryStreamSpecificDatas.append(data)
            videoConfig = MpegTsVideoConfigHevc(data: hvcC)
        }
    }

    func videoCodecOutputSampleBuffer(_: VideoCodec, _ sampleBuffer: CMSampleBuffer) {
        guard let dataBuffer = sampleBuffer.dataBuffer else {
            return
        }
        guard let (buffer, length) = dataBuffer.getDataPointer() else {
            return
        }
        guard canWriteFor() else {
            return
        }
        if baseVideoTimestamp == .invalid {
            baseVideoTimestamp = sampleBuffer.presentationTimeStamp
            if mpegTsWriterProgramClockReferencePacketId == MpegTsWriter.videoPacketId {
                programClockReferenceTimestamp = baseVideoTimestamp
            }
        }
        guard let videoConfig else {
            return
        }
        let randomAccessIndicator = sampleBuffer.isSync
        let PES: MpegTsPacketizedElementaryStream
        let bytes = UnsafeRawPointer(buffer).bindMemory(to: UInt8.self, capacity: length)
        if let videoConfig = videoConfig as? MpegTsVideoConfigAvc {
            PES = MpegTsPacketizedElementaryStream(
                bytes: bytes,
                count: length,
                presentationTimeStamp: sampleBuffer.presentationTimeStamp,
                decodeTimeStamp: sampleBuffer.decodeTimeStamp,
                timestamp: baseVideoTimestamp,
                config: randomAccessIndicator ? videoConfig : nil,
                streamID: MpegTsWriter.videoStreamId
            )
        } else if let videoConfig = videoConfig as? MpegTsVideoConfigHevc {
            PES = MpegTsPacketizedElementaryStream(
                bytes: bytes,
                count: length,
                presentationTimeStamp: sampleBuffer.presentationTimeStamp,
                decodeTimeStamp: sampleBuffer.decodeTimeStamp,
                timestamp: baseVideoTimestamp,
                config: randomAccessIndicator ? videoConfig : nil,
                streamID: MpegTsWriter.videoStreamId
            )
        } else {
            return
        }
        writeVideo(data: encode(
            MpegTsWriter.videoPacketId,
            presentationTimeStamp: sampleBuffer.presentationTimeStamp,
            decodeTimeStamp: sampleBuffer.decodeTimeStamp,
            randomAccessIndicator: randomAccessIndicator,
            PES: PES
        ))
    }
}
