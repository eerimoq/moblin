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
    private var firstReceivedPresentationTimeStamp: CMTime?
    private var previousReceivedPresentationTimeStamps: [UInt16: CMTime] = [:]
    private var basePresentationTimeStamp: CMTime = .invalid
    private var audioBuffer: AVAudioCompressedBuffer?
    private var latestAudioBufferPresentationTimeStamp: CMTime?
    private var latestMissingAudioBufferPresentationTimeStamp: CMTime = .zero
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
                logger.info("srt-server-client: Got corrupt packet \(error).")
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
        guard !outputSilence(sampleBuffer.presentationTimeStamp, pcmAudioFormat) else {
            return
        }
        guard let sampleBuffer = outputBuffer
            .makeSampleBuffer(presentationTimeStamp: sampleBuffer.presentationTimeStamp)
        else {
            return
        }
        server?.srtlaServer?.delegate?.srtlaServerOnAudioBuffer(
            streamId: streamId,
            sampleBuffer: sampleBuffer
        )
    }

    // Maybe only fill gaps in audio unit?
    private func outputSilence(_ presentationTimeStamp: CMTime, _ pcmAudioFormat: AVAudioFormat) -> Bool {
        defer {
            latestAudioBufferPresentationTimeStamp = presentationTimeStamp
        }
        guard let latestAudioBufferPresentationTimeStamp else {
            return false
        }
        let ptsDelta = (presentationTimeStamp - latestAudioBufferPresentationTimeStamp).seconds
        // Assume 1024 samples/buffer at 48 kHz for now
        var numberOfGapBuffers = max(Int(((ptsDelta / (1024 / 48000)) - 1).rounded()), 0)
        if numberOfGapBuffers > 0 {
            logger.info("""
            srt-server: Audio gap latest buffer PTS \
            \(latestAudioBufferPresentationTimeStamp.seconds)
            """)
            latestMissingAudioBufferPresentationTimeStamp = latestAudioBufferPresentationTimeStamp + CMTime(
                value: CMTimeValue(Double(1024 * numberOfGapBuffers)),
                timescale: CMTimeScale(48000)
            )
            numberOfGapBuffers += 1
        } else if (presentationTimeStamp - latestMissingAudioBufferPresentationTimeStamp).seconds < 0.5 {
            logger.info("""
            srt-server: Audio gap latest missing buffer PTS \
            \(latestMissingAudioBufferPresentationTimeStamp.seconds)
            """)
            numberOfGapBuffers = 1
        }
        for index in 0 ..< numberOfGapBuffers {
            let newPresentationTimeStamp = latestAudioBufferPresentationTimeStamp +
                CMTime(
                    value: CMTimeValue(Double(1024 * (1 + index))),
                    timescale: CMTimeScale(48000)
                )
            logger.info("srt-server: Audio gap filler buffer PTS \(newPresentationTimeStamp.seconds)")
            if let sampleBuffer = createSilentSampleBuffer(
                format: pcmAudioFormat,
                presentationTimeStamp: newPresentationTimeStamp
            ) {
                server?.srtlaServer?.delegate?.srtlaServerOnAudioBuffer(
                    streamId: streamId,
                    sampleBuffer: sampleBuffer
                )
            }
        }
        if numberOfGapBuffers > 0 {
            logger.info("srt-server: Audio gap new buffer PTS \(presentationTimeStamp.seconds)")
        }
        return numberOfGapBuffers > 0
    }

    private func createSilentSampleBuffer(format: AVAudioFormat,
                                          presentationTimeStamp: CMTime) -> CMSampleBuffer?
    {
        guard let dataBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024) else {
            return nil
        }
        guard let data = dataBuffer.int16ChannelData else {
            return nil
        }
        for i in 0 ..< 1024 {
            data.pointee[i] = 0
        }
        dataBuffer.frameLength = 1024
        return dataBuffer.makeSampleBuffer(presentationTimeStamp: presentationTimeStamp)
    }

    private func handleVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        // logger.info("srt-server: Decoding sample buffer with sync \(sampleBuffer.isSync)
        // data size \(sampleBuffer.dataBuffer?.dataLength ?? -1)")
        guard let videoDecoder else {
            return
        }
        videoCodecLockQueue.async {
            videoDecoder.decodeSampleBuffer(sampleBuffer)
        }
    }

    private func handleAudioFormatDescription(_ formatDescription: CMFormatDescription) {
        guard let streamBasicDescription = formatDescription.streamBasicDescription else {
            return
        }
        guard let audioFormat = AVAudioFormat(streamDescription: streamBasicDescription) else {
            logger.info("srt-server-client: Failed to create audio format")
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
            logger.info("srt-server-client: Failed to create PCM audio format")
            return
        }
        logger.info("srt-server-client: in: \(audioFormat), out: \(pcmAudioFormat)")
        audioDecoder = AVAudioConverter(from: audioFormat, to: pcmAudioFormat)
        if audioDecoder == nil {
            logger.info("srt-server-client: Failed to create audio decdoer")
        }
    }

    private func handleVideoFormatDescription(_ formatDescription: CMFormatDescription) {
        let dimentions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        logger.info("srt-server-client: Got new video dimensions \(dimentions)")
        videoDecoder?.stopRunning()
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
        switch data.streamType {
        case .adtsAac:
            return tryMakeSampleBufferAac(
                packetId: packetId,
                data: data,
                packetizedElementaryStream: &packetizedElementaryStream
            )
        case .h264:
            return tryMakeSampleBufferH264(
                packetId: packetId,
                data: data,
                packetizedElementaryStream: &packetizedElementaryStream
            )
        case .h265:
            return tryMakeSampleBufferH265(
                packetId: packetId,
                data: data,
                packetizedElementaryStream: &packetizedElementaryStream
            )
        default:
            return nil
        }
    }

    private func tryMakeSampleBufferAac(packetId: UInt16,
                                        data: ElementaryStreamSpecificData,
                                        packetizedElementaryStream: inout MpegTsPacketizedElementaryStream)
        -> (CMSampleBuffer, ElementaryStreamType)?
    {
        let formatDescription = AdtsHeader(data: packetizedElementaryStream.data).makeFormatDescription()
        if let formatDescription, formatDescriptions[packetId] != formatDescription {
            formatDescriptions[packetId] = formatDescription
            handleAudioFormatDescription(formatDescription)
        }
        guard let (sampleBuffer,
                   firstReceivedPresentationTimeStamp,
                   previousReceivedPresentationTimeStamp) = packetizedElementaryStream.makeSampleBuffer(
            data.streamType,
            getBasePresentationTimeStamp(),
            firstReceivedPresentationTimeStamp,
            previousReceivedPresentationTimeStamps[packetId],
            formatDescriptions[packetId]
        ) else {
            return nil
        }
        sampleBuffer.isSync = true
        self.firstReceivedPresentationTimeStamp = firstReceivedPresentationTimeStamp
        previousReceivedPresentationTimeStamps[packetId] = previousReceivedPresentationTimeStamp
        return (sampleBuffer, data.streamType)
    }

    private func tryMakeSampleBufferH264(packetId: UInt16,
                                         data: ElementaryStreamSpecificData,
                                         packetizedElementaryStream: inout MpegTsPacketizedElementaryStream)
        -> (CMSampleBuffer, ElementaryStreamType)?
    {
        let units = nalUnitReader.readH264(&packetizedElementaryStream.data)
        if let unit = units.first(where: { $0.type == .idr || $0.type == .slice }) {
            var data = Data([0x00, 0x00, 0x00, 0x01])
            data.append(unit.data)
            packetizedElementaryStream.data = data
        }
        let formatDescription = units.makeFormatDescription(NALUnitReader.defaultNALUnitHeaderLength)
        if let formatDescription, formatDescriptions[packetId] != formatDescription {
            formatDescriptions[packetId] = formatDescription
            handleVideoFormatDescription(formatDescription)
        }
        guard let (sampleBuffer,
                   firstReceivedPresentationTimeStamp,
                   previousReceivedPresentationTimeStamp) = packetizedElementaryStream.makeSampleBuffer(
            data.streamType,
            getBasePresentationTimeStamp(),
            firstReceivedPresentationTimeStamp,
            previousReceivedPresentationTimeStamps[packetId],
            formatDescriptions[packetId]
        ) else {
            return nil
        }
        sampleBuffer.isSync = units.contains { $0.type == .idr }
        self.firstReceivedPresentationTimeStamp = firstReceivedPresentationTimeStamp
        previousReceivedPresentationTimeStamps[packetId] = previousReceivedPresentationTimeStamp
        return (sampleBuffer, data.streamType)
    }

    private func tryMakeSampleBufferH265(packetId: UInt16,
                                         data: ElementaryStreamSpecificData,
                                         packetizedElementaryStream: inout MpegTsPacketizedElementaryStream)
        -> (CMSampleBuffer, ElementaryStreamType)?
    {
        let units = nalUnitReader.readH265(&packetizedElementaryStream.data)
        let formatDescription = units.makeFormatDescription(NALUnitReader.defaultNALUnitHeaderLength)
        if let formatDescription, formatDescriptions[packetId] != formatDescription {
            formatDescriptions[packetId] = formatDescription
            handleVideoFormatDescription(formatDescription)
        }
        guard let (sampleBuffer,
                   firstReceivedPresentationTimeStamp,
                   previousReceivedPresentationTimeStamp) = packetizedElementaryStream.makeSampleBuffer(
            data.streamType,
            getBasePresentationTimeStamp(),
            firstReceivedPresentationTimeStamp,
            previousReceivedPresentationTimeStamps[packetId],
            formatDescriptions[packetId]
        ) else {
            return nil
        }
        sampleBuffer.isSync = units.contains { $0.type == .sps }
        self.firstReceivedPresentationTimeStamp = firstReceivedPresentationTimeStamp
        previousReceivedPresentationTimeStamps[packetId] = previousReceivedPresentationTimeStamp
        return (sampleBuffer, data.streamType)
    }

    private func getBasePresentationTimeStamp() -> CMTime {
        if basePresentationTimeStamp == .invalid {
            let latency = CMTime(seconds: 0.5, preferredTimescale: 1000)
            basePresentationTimeStamp = currentPresentationTimeStamp() + latency
        }
        return basePresentationTimeStamp
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
