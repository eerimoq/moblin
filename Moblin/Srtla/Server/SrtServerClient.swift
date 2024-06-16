import AVFoundation
import libsrt

class SrtServerClient {
    private weak var server: SrtServer?
    private var programAssociationTable = MpegTsProgramAssociation()
    private var programMappingTable: [UInt16: MpegTsProgramMapping] = [:]
    private var programs: [UInt16: UInt16] = [:]
    private var elementaryStreamSpecificData: [UInt16: ElementaryStreamSpecificData] = [:]
    private var packetizedElementaryStreams: [UInt16: MpegTsPacketizedElementaryStream] = [:]
    private var formatDescriptions: [UInt16: CMFormatDescription] = [:]
    private var nalUnitReader = NALUnitReader()
    private var previousPresentationTimeStamps: [UInt16: CMTime] = [:]
    private var audioBuffer: AVAudioCompressedBuffer?
    private var latestAudioSampleBuffer: CMSampleBuffer?
    private var latestAudioBufferPresentationTimeStamp = 0.0
    private var audioDecoder: AVAudioConverter?
    private var pcmAudioFormat: AVAudioFormat?
    private let streamId: String
    private var videoDecoder: VideoCodec?
    private var videoCodecLockQueue = DispatchQueue(label: "com.eerimoq.Moblin.VideoCodec")

    init(server: SrtServer, streamId: String) {
        self.server = server
        self.streamId = streamId
    }

    func run(clientSocket: Int32) {
        let packetSize = 2048
        var packet = Data(count: packetSize)
        while server?.running == true {
            let count = packet.withUnsafeMutableBytes { pointer in
                srt_recvmsg(clientSocket, pointer.baseAddress, Int32(packetSize))
            }
            guard count != SRT_ERROR else {
                break
            }
            packet.count = Int(count)
            server?.srtlaServer?.totalBytesReceived.mutate { $0 += UInt64(count) }
            let reader = ByteArray(data: packet)
            do {
                while reader.bytesAvailable >= MpegTsPacket.size {
                    let packet = try MpegTsPacket(reader: reader)
                    if packet.id == MpegTsPacket.programAssociationTableId {
                        try handleProgramAssociationTable(packet: packet)
                    } else if let programNumber = programs[packet.id] {
                        try handleProgramMappingTable(programNumber: programNumber, packet: packet)
                    } else if packet.id != MpegTsPacket.nullId {
                        try handleProgramMedia(packet: packet)
                    }
                }
            } catch {
                logger.info("srt-server: Got corrupt packet \(error).")
            }
        }
        srt_close(clientSocket)
        videoDecoder?.stopRunning()
        videoDecoder = nil
    }

    private func handleProgramAssociationTable(packet: MpegTsPacket) throws {
        programAssociationTable = try MpegTsProgramAssociation(data: packet.payload)
        for (programNumber, programId) in programAssociationTable.programs {
            programs[programId] = programNumber
        }
    }

    private func handleProgramMappingTable(programNumber: UInt16, packet: MpegTsPacket) throws {
        programMappingTable[programNumber] = try MpegTsProgramMapping(data: packet.payload)
        for programMapping in programMappingTable.values {
            for data in programMapping.elementaryStreamSpecificDatas {
                elementaryStreamSpecificData[data.elementaryPacketId] = data
            }
        }
    }

    private func handleProgramMedia(packet: MpegTsPacket) throws {
        if packet.payloadUnitStartIndicator {
            if let (sampleBuffer, streamType) = tryMakeSampleBuffer(packetId: packet.id, forUpdate: true) {
                handleSampleBuffer(streamType, sampleBuffer)
            }
            packetizedElementaryStreams[packet.id] = try MpegTsPacketizedElementaryStream(data: packet
                .payload)
        } else {
            packetizedElementaryStreams[packet.id]?.append(data: packet.payload)
            if let (sampleBuffer, streamType) = tryMakeSampleBuffer(packetId: packet.id, forUpdate: false) {
                handleSampleBuffer(streamType, sampleBuffer)
            }
        }
    }

    private func handleSampleBuffer(_ streamType: ElementaryStreamType, _ sampleBuffer: CMSampleBuffer) {
        switch streamType {
        case .adtsAac:
            handleAudioSampleBuffer(sampleBuffer)
        default:
            handleVideoSampleBuffer(sampleBuffer)
        }
    }

    private func handleAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let audioDecoder, let pcmAudioFormat, let audioBuffer else {
            return
        }
        guard let dataBuffer = sampleBuffer.dataBuffer else {
            return
        }
        guard let (dataPointer, length) = dataBuffer.getDataPointer() else {
            return
        }
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: pcmAudioFormat, frameCapacity: 1024) else {
            return
        }
        audioBuffer.packetDescriptions?.pointee = AudioStreamPacketDescription(
            mStartOffset: 0,
            mVariableFramesInPacket: 0,
            mDataByteSize: UInt32(length)
        )
        audioBuffer.packetCount = 1
        audioBuffer.byteLength = UInt32(length)
        audioBuffer.data.copyMemory(from: dataPointer, byteCount: length)
        var error: NSError?
        audioDecoder.convert(to: outputBuffer, error: &error) { _, inputStatus in
            inputStatus.pointee = .haveData
            return self.audioBuffer
        }
        if let error {
            logger.info("srt-server: Error \(error)")
            return
        }
        let presentationTimeStamp = sampleBuffer.presentationTimeStamp.seconds
        if let latestAudioSampleBuffer {
            let ptsDelta = presentationTimeStamp - latestAudioBufferPresentationTimeStamp
            // Assume 1024 samples/buffer at 48 kHz for now
            var gapBuffers = Int(((ptsDelta / 0.021333) - 1).rounded())
            // logger.info("""
            // srt-server: Decoded audio \(outputBuffer) for PTS \
            // \(presentationTimeStamp) delta \(ptsDelta) gap \(gapBuffers)
            // """)
            while gapBuffers > 0 {
                logger.info("srt-server: Audio gap filler buffer")
                guard let sampleBuffer = latestAudioSampleBuffer
                    .replacePresentationTimeStamp(presentationTimeStamp: .init())
                else {
                    continue
                }
                server?.srtlaServer?.delegate?.srtlaServerOnAudioBuffer(
                    streamId: streamId,
                    sampleBuffer: sampleBuffer
                )
                gapBuffers -= 1
            }
        }
        latestAudioBufferPresentationTimeStamp = presentationTimeStamp
        guard let sampleBuffer = outputBuffer
            .makeSampleBuffer(presentationTimeStamp: sampleBuffer.presentationTimeStamp)
        else {
            return
        }
        latestAudioSampleBuffer = sampleBuffer
        server?.srtlaServer?.delegate?.srtlaServerOnAudioBuffer(
            streamId: streamId,
            sampleBuffer: sampleBuffer
        )
    }

    private func handleVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        videoDecoder?.appendSampleBuffer(sampleBuffer)
    }

    private func handleFormatDescription(
        _ streamType: ElementaryStreamType,
        _ formatDescription: CMFormatDescription
    ) {
        switch streamType {
        case .adtsAac:
            handleAudioFormatDescription(formatDescription)
        default:
            handleVideoFormatDescription(formatDescription)
        }
    }

    private func handleAudioFormatDescription(_ formatDescription: CMFormatDescription) {
        guard let streamBasicDescription = formatDescription.streamBasicDescription else {
            return
        }
        guard let audioFormat = AVAudioFormat(streamDescription: streamBasicDescription) else {
            logger.info("srt-server: Failed to create audio format")
            audioBuffer = nil
            audioDecoder = nil
            return
        }
        audioBuffer = AVAudioCompressedBuffer(
            format: audioFormat,
            packetCapacity: 1,
            maximumPacketSize: 1024 * Int(audioFormat.channelCount)
        )
        pcmAudioFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: audioFormat.sampleRate,
            channels: audioFormat.channelCount,
            interleaved: audioFormat.isInterleaved
        )
        guard let pcmAudioFormat else {
            logger.info("srt-server: Failed to create PCM audio format")
            return
        }
        logger.info("srt-server: in: \(audioFormat), out: \(pcmAudioFormat)")
        audioDecoder = AVAudioConverter(from: audioFormat, to: pcmAudioFormat)
        if audioDecoder == nil {
            logger.info("srt-server: Failed to create audio decdoer")
        }
    }

    private func handleVideoFormatDescription(_ formatDescription: CMFormatDescription) {
        guard videoDecoder == nil else {
            return
        }
        videoDecoder = VideoCodec(lockQueue: videoCodecLockQueue)
        videoDecoder?.formatDescription = formatDescription
        videoDecoder?.delegate = self
        videoDecoder?.startRunning()
    }

    private func tryMakeSampleBuffer(packetId: UInt16,
                                     forUpdate: Bool) -> (CMSampleBuffer, ElementaryStreamType)?
    {
        guard let data = elementaryStreamSpecificData[packetId] else {
            return nil
        }
        guard var packetizedElementaryStream = packetizedElementaryStreams[packetId] else {
            return nil
        }
        guard packetizedElementaryStream.isComplete() || forUpdate else {
            return nil
        }
        defer {
            packetizedElementaryStreams[packetId] = nil
        }
        let formatDescription = makeFormatDescription(data, &packetizedElementaryStream)
        if let formatDescription, formatDescriptions[packetId] != formatDescription {
            formatDescriptions[packetId] = formatDescription
            handleFormatDescription(data.streamType, formatDescription)
        }
        var isSync = false
        switch data.streamType {
        case .h264:
            let units = nalUnitReader.read(&packetizedElementaryStream.data, type: AvcNalUnit.self)
            if let unit = units.first(where: { $0.type == .idr || $0.type == .slice }) {
                var data = Data([0x00, 0x00, 0x00, 0x01])
                data.append(unit.data)
                packetizedElementaryStream.data = data
            }
            isSync = units.contains { $0.type == .idr }
        case .h265:
            let units = nalUnitReader.read(&packetizedElementaryStream.data, type: HevcNalUnit.self)
            isSync = units.contains { $0.type == .sps }
        case .adtsAac:
            isSync = true
        default:
            break
        }
        guard let sampleBuffer = packetizedElementaryStream.makeSampleBuffer(
            data.streamType,
            previousPresentationTimeStamps[packetId] ?? .invalid,
            formatDescriptions[packetId]
        ) else {
            return nil
        }
        sampleBuffer.isSync = isSync
        previousPresentationTimeStamps[packetId] = sampleBuffer.presentationTimeStamp
        return (sampleBuffer, data.streamType)
    }

    private func makeFormatDescription(
        _ data: ElementaryStreamSpecificData,
        _ packetizedElementaryStream: inout MpegTsPacketizedElementaryStream
    ) -> CMFormatDescription? {
        switch data.streamType {
        case .adtsAac:
            return AdtsHeader(data: packetizedElementaryStream.data).makeFormatDescription()
        case .h264, .h265:
            return nalUnitReader.makeFormatDescription(
                &packetizedElementaryStream.data,
                type: data.streamType
            )
        default:
            return nil
        }
    }
}

extension SrtServerClient: VideoCodecDelegate {
    func videoCodecOutputFormat(_: VideoCodec, _: CMFormatDescription) {}

    func videoCodecOutputSampleBuffer(_: VideoCodec, _ sampleBuffer: CMSampleBuffer) {
        server?.srtlaServer?.delegate?.srtlaServerOnVideoBuffer(
            streamId: streamId,
            sampleBuffer: sampleBuffer
        )
    }
}
