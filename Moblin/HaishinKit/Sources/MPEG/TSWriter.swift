import AVFoundation
import CoreMedia
import Foundation

public var payloadSize: Int = 1316

/// The interface an MPEG-2 TS (Transport Stream) writer uses to inform its delegates.
public protocol TSWriterDelegate: AnyObject {
    func writer(_ writer: TSWriter, doOutput data: Data)
    func writer(_ writer: TSWriter, doOutputPointer pointer: UnsafeRawBufferPointer, count: Int)
}

/// The TSWriter class represents writes MPEG-2 transport stream data.
public class TSWriter {
    public static let defaultPATPID: UInt16 = 0
    public static let defaultPMTPID: UInt16 = 4095
    public static let defaultVideoPID: UInt16 = 256
    public static let defaultAudioPID: UInt16 = 257

    private static let audioStreamId: UInt8 = 192
    private static let videoStreamId: UInt8 = 224

    public static let defaultSegmentDuration: Double = 2

    /// The delegate instance.
    public weak var delegate: (any TSWriterDelegate)?
    /// This instance is running to process(true) or not(false).
    public internal(set) var isRunning: Atomic<Bool> = .init(false)
    /// The exptected medias = [.video, .audio].
    public var expectedMedias: Set<AVMediaType> = []

    var audioContinuityCounter: UInt8 = 0
    var videoContinuityCounter: UInt8 = 0
    let PCRPID: UInt16 = TSWriter.defaultVideoPID
    var rotatedTimestamp = CMTime.zero
    var segmentDuration: Double = TSWriter.defaultSegmentDuration
    private let outputLock: DispatchQueue = .init(
        label: "com.haishinkit.HaishinKit.TSWriter",
        qos: .userInitiated
    )

    private var videoData: [Data?] = [nil, nil]
    private var videoDataOffset: Int = 0

    private(set) var PAT: TSProgramAssociation = {
        let PAT: TSProgramAssociation = .init()
        PAT.programs = [1: TSWriter.defaultPMTPID]
        return PAT
    }()

    private(set) var PMT: TSProgramMap = .init()
    private var audioConfig: AudioSpecificConfig? {
        didSet {
            writeProgramIfNeeded()
        }
    }

    private var videoConfig: DecoderConfigurationRecord? {
        didSet {
            writeProgramIfNeeded()
        }
    }

    private var baseVideoTimestamp: CMTime = .invalid
    private var baseAudioTimestamp: CMTime = .invalid
    private var PCRTimestamp = CMTime.zero
    private var canWriteFor: Bool {
        return (expectedMedias.contains(.audio) == (audioConfig != nil))
            && (expectedMedias.contains(.video) == (videoConfig != nil))
    }

    public init(segmentDuration: Double = TSWriter.defaultSegmentDuration) {
        self.segmentDuration = segmentDuration
    }

    public func startRunning() {
        guard isRunning.value else {
            return
        }
        isRunning.mutate { $0 = true }
    }

    public func stopRunning() {
        guard !isRunning.value else {
            return
        }
        audioContinuityCounter = 0
        videoContinuityCounter = 0
        PAT.programs.removeAll()
        PAT.programs = [1: TSWriter.defaultPMTPID]
        PMT = TSProgramMap()
        audioConfig = nil
        videoConfig = nil
        baseVideoTimestamp = .invalid
        baseAudioTimestamp = .invalid
        PCRTimestamp = .invalid
        isRunning.mutate { $0 = false }
    }

    // swiftlint:disable:next function_parameter_count
    private func writeSampleBuffer(_ PID: UInt16,
                                   presentationTimeStamp: CMTime,
                                   decodeTimeStamp: CMTime,
                                   randomAccessIndicator: Bool,
                                   PES: PacketizedElementaryStream) -> Data
    {
        let timestamp = decodeTimeStamp == .invalid ? presentationTimeStamp : decodeTimeStamp
        let packets = split(PID, PES: PES, timestamp: timestamp)
        packets[0].adaptationField?.randomAccessIndicator = randomAccessIndicator
        rotateFileHandle(timestamp)

        let count = packets.count * 188
        var data = Data(
            bytesNoCopy: UnsafeMutableRawPointer.allocate(byteCount: count, alignment: 8),
            count: count,
            deallocator: .custom { (pointer: UnsafeMutableRawPointer, _: Int) in pointer.deallocate() }
        )
        data.withUnsafeMutableBytes { (pointer: UnsafeMutableRawBufferPointer) in
            var pointer = pointer
            for var packet in packets {
                switch PID {
                case TSWriter.defaultAudioPID:
                    packet.continuityCounter = audioContinuityCounter
                    audioContinuityCounter = (audioContinuityCounter + 1) & 0x0F
                case TSWriter.defaultVideoPID:
                    packet.continuityCounter = videoContinuityCounter
                    videoContinuityCounter = (videoContinuityCounter + 1) & 0x0F
                default:
                    break
                }
                packet.fixedHeader(pointer: pointer)
                pointer = UnsafeMutableRawBufferPointer(rebasing: pointer[4...])
                if let adaptationField = packet.adaptationField {
                    adaptationField.data.withUnsafeBytes { (adaptationPointer: UnsafeRawBufferPointer) in
                        pointer.copyMemory(from: adaptationPointer)
                    }
                    pointer = UnsafeMutableRawBufferPointer(rebasing: pointer[adaptationField.data.count...])
                }
                packet.payload.withUnsafeBytes { (payloadPointer: UnsafeRawBufferPointer) in
                    pointer.copyMemory(from: payloadPointer)
                }
                pointer = UnsafeMutableRawBufferPointer(rebasing: pointer[packet.payload.count...])
            }
        }

        return data
    }

    func rotateFileHandle(_ timestamp: CMTime) {
        let duration = timestamp.seconds - rotatedTimestamp.seconds
        if duration <= segmentDuration {
            return
        }
        writeProgram()
        rotatedTimestamp = timestamp
    }

    func write(_ data: Data) {
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

    final func writeProgram() {
        PMT.PCRPID = PCRPID
        var bytes = Data()
        var packets: [TSPacket] = []
        packets.append(contentsOf: PAT.arrayOfPackets(TSWriter.defaultPATPID))
        packets.append(contentsOf: PMT.arrayOfPackets(TSWriter.defaultPMTPID))
        for packet in packets {
            bytes.append(packet.data)
        }
        write(bytes)
    }

    final func writeProgramIfNeeded() {
        guard !expectedMedias.isEmpty else {
            return
        }
        guard canWriteFor else {
            return
        }
        writeProgram()
    }

    private func split(_ PID: UInt16, PES: PacketizedElementaryStream, timestamp: CMTime) -> [TSPacket] {
        var PCR: UInt64?
        let timeSinceLatestPcr = timestamp.seconds - PCRTimestamp.seconds
        /* if timeSinceLatestPcr <= 0 {
             logger.info("timeSinceLatestPcr: \(PID) \(timeSinceLatestPcr)")
         } */
        if PCRPID == PID, timeSinceLatestPcr >= 0.02 {
            PCR =
                UInt64((timestamp
                        .seconds - (PID == TSWriter.defaultVideoPID ? baseVideoTimestamp : baseAudioTimestamp)
                        .seconds) *
                    TSTimestamp.resolution)
            PCRTimestamp = timestamp
        }
        return PES.arrayOfPackets(PID, PCR: PCR)
    }
}

extension TSWriter: AudioCodecDelegate {
    public func audioCodec(didOutput outputFormat: AVAudioFormat) {
        logger.info("Audio setup \(outputFormat) (forcing AAC)")
        var data = ESSpecificData()
        data.streamType = .adtsAac
        data.elementaryPID = TSWriter.defaultAudioPID
        PMT.elementaryStreamSpecificData.append(data)
        audioContinuityCounter = 0
        audioConfig = AudioSpecificConfig(formatDescription: outputFormat.formatDescription)
    }

    public func audioCodec(didOutput audioBuffer: AVAudioBuffer, presentationTimeStamp: CMTime) {
        guard let audioBuffer = audioBuffer as? AVAudioCompressedBuffer else {
            logger.info("Audio output no buffer")
            return
        }
        guard canWriteFor else {
            logger.info("Cannot write audio buffer")
            return
        }
        if baseAudioTimestamp == .invalid {
            baseAudioTimestamp = presentationTimeStamp
            if PCRPID == TSWriter.defaultAudioPID {
                PCRTimestamp = baseAudioTimestamp
            }
        }
        guard let audioConfig else {
            return
        }
        guard let PES = PacketizedElementaryStream(
            bytes: audioBuffer.data.assumingMemoryBound(to: UInt8.self),
            count: audioBuffer.byteLength,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: .invalid,
            timestamp: baseAudioTimestamp,
            config: audioConfig,
            streamID: TSWriter.audioStreamId
        ) else {
            return
        }
        writeAudio(data: writeSampleBuffer(
            TSWriter.defaultAudioPID,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: .invalid,
            randomAccessIndicator: true,
            PES: PES
        ))
    }
}

extension TSWriter: VideoCodecDelegate {
    public func videoCodec(_: VideoCodec, didOutput formatDescription: CMFormatDescription?) {
        guard let formatDescription else {
            return
        }
        var data = ESSpecificData()
        data.elementaryPID = TSWriter.defaultVideoPID
        videoContinuityCounter = 0
        if let avcC = AVCDecoderConfigurationRecord.getData(formatDescription) {
            data.streamType = .h264
            PMT.elementaryStreamSpecificData.append(data)
            videoConfig = AVCDecoderConfigurationRecord(data: avcC)
        } else if let hvcC = HEVCDecoderConfigurationRecord.getData(formatDescription) {
            data.streamType = .h265
            PMT.elementaryStreamSpecificData.append(data)
            videoConfig = HEVCDecoderConfigurationRecord(data: hvcC)
        }
    }

    public func videoCodec(_: VideoCodec, didOutput sampleBuffer: CMSampleBuffer) {
        guard let dataBuffer = sampleBuffer.dataBuffer else {
            return
        }
        var length = 0
        var buffer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(
            dataBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &buffer
        ) == noErr else {
            return
        }
        guard let buffer else {
            return
        }
        guard canWriteFor else {
            logger.info("Cannot write video buffer")
            return
        }
        if baseVideoTimestamp == .invalid {
            baseVideoTimestamp = sampleBuffer.presentationTimeStamp
            if PCRPID == TSWriter.defaultVideoPID {
                PCRTimestamp = baseVideoTimestamp
            }
        }
        guard let videoConfig else {
            return
        }
        let randomAccessIndicator = !sampleBuffer.isNotSync
        let PES: PacketizedElementaryStream
        let bytes = UnsafeRawPointer(buffer).bindMemory(to: UInt8.self, capacity: length)
        if let videoConfig = videoConfig as? AVCDecoderConfigurationRecord {
            PES = PacketizedElementaryStream(
                bytes: bytes,
                count: length,
                presentationTimeStamp: sampleBuffer.presentationTimeStamp,
                decodeTimeStamp: sampleBuffer.decodeTimeStamp,
                timestamp: baseVideoTimestamp,
                config: randomAccessIndicator ? videoConfig : nil,
                streamID: TSWriter.videoStreamId
            )
        } else if let videoConfig = videoConfig as? HEVCDecoderConfigurationRecord {
            PES = PacketizedElementaryStream(
                bytes: bytes,
                count: length,
                presentationTimeStamp: sampleBuffer.presentationTimeStamp,
                decodeTimeStamp: sampleBuffer.decodeTimeStamp,
                timestamp: baseVideoTimestamp,
                config: randomAccessIndicator ? videoConfig : nil,
                streamID: TSWriter.videoStreamId
            )
        } else {
            return
        }
        writeVideo(data: writeSampleBuffer(
            TSWriter.defaultVideoPID,
            presentationTimeStamp: sampleBuffer.presentationTimeStamp,
            decodeTimeStamp: sampleBuffer.decodeTimeStamp,
            randomAccessIndicator: randomAccessIndicator,
            PES: PES
        ))
    }
}
