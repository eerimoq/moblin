import AVFoundation

protocol MpegTsReaderDelegate: AnyObject {
    func mpegTsReaderAudioBuffer(_ sampleBuffer: CMSampleBuffer)
    func mpegTsReaderVideoBuffer(_ sampleBuffer: CMSampleBuffer)
    func mpegTsReaderSetTargetLatencies(_ videoTargetLatency: Double, _ audioTargetLatency: Double)
}

class MpegTsReader {
    private var programAssociationTable = MpegTsProgramAssociation()
    private var programMappingTable: [UInt16: MpegTsProgramMapping] = [:]
    private var programs: [UInt16: UInt16] = [:]
    private var elementaryStreamSpecificData: [UInt16: ElementaryStreamSpecificData] = [:]
    private var packetizedElementaryStreams: [UInt16: MpegTsPacketizedElementaryStream] = [:]
    private var formatDescriptions: [UInt16: CMFormatDescription] = [:]
    private var adtsHeaders: [UInt16: AdtsHeader] = [:]
    private var firstReceivedPresentationTimeStamp: CMTime?
    private var previousReceivedPresentationTimeStamps: [UInt16: CMTime] = [:]
    private var basePresentationTimeStamp: CMTime = .invalid
    private var audioBuffer: AVAudioCompressedBuffer?
    private var latestAudioBufferPresentationTimeStamp: CMTime?
    private var audioDecoder: AVAudioConverter?
    private var pcmAudioFormat: AVAudioFormat?
    private var videoDecoder: VideoDecoder?
    private let targetLatenciesSynchronizer: TargetLatenciesSynchronizer
    private let timecodesEnabled: Bool
    private let targetLatency: Double
    weak var delegate: MpegTsReaderDelegate?
    private let decoderQueue: DispatchQueue

    init(decoderQueue: DispatchQueue, timecodesEnabled: Bool, targetLatency: Double) {
        self.decoderQueue = decoderQueue
        self.timecodesEnabled = timecodesEnabled
        self.targetLatency = targetLatency
        targetLatenciesSynchronizer = TargetLatenciesSynchronizer(targetLatency: targetLatency)
    }

    func handlePacketFromClient(packet: Data) throws {
        let reader = ByteReader(data: packet)
        while reader.bytesAvailable >= MpegTsPacket.size {
            let packet = try MpegTsPacket(reader: reader)
            if packet.id == MpegTsPacket.programAssociationTableId {
                try handleProgramAssociationTable(packet: packet)
            } else if let programNumber = programs[packet.id] {
                try handleProgramMappingTable(programNumber: programNumber, packet: packet)
            } else if let data = elementaryStreamSpecificData[packet.id] {
                try handleProgramMedia(packet: packet, data: data)
            }
        }
    }

    private func handleProgramAssociationTable(packet: MpegTsPacket) throws {
        programAssociationTable = try MpegTsProgramAssociation(data: packet.payload)
        for (programNumber, programId) in programAssociationTable.programs {
            // logger.info("Program id \(programId) and number \(programNumber)")
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

    private func handleProgramMedia(packet: MpegTsPacket, data: ElementaryStreamSpecificData) throws {
        if packet.payloadUnitStartIndicator {
            if let (sampleBuffer, streamType) = tryMakeSampleBuffer(packetId: packet.id, data: data) {
                handleSampleBuffer(streamType, sampleBuffer)
            }
            packetizedElementaryStreams[packet.id] = try MpegTsPacketizedElementaryStream(data: packet.payload)
        } else {
            packetizedElementaryStreams[packet.id]?.append(data: packet.payload)
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
        targetLatenciesSynchronizer.setLatestAudioPresentationTimeStamp(sampleBuffer.presentationTimeStamp.seconds)
        updateTargetLatencies()
        guard let audioDecoder, let pcmAudioFormat, let audioBuffer else {
            return
        }
        guard let dataBuffer = sampleBuffer.dataBuffer else {
            return
        }
        guard let (dataPointer, length) = dataBuffer.getDataPointer() else {
            return
        }
        guard length <= audioBuffer.maximumPacketSize else {
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
            logger.info("mpeg-ts-reader: Audio error \(error)")
            return
        }
        outputSilenceIfGap(sampleBuffer.presentationTimeStamp, pcmAudioFormat)
        guard let sampleBuffer = outputBuffer.makeSampleBuffer(sampleBuffer.presentationTimeStamp) else {
            return
        }
        delegate?.mpegTsReaderAudioBuffer(sampleBuffer)
    }

    // Maybe only fill gaps in audio unit?
    private func outputSilenceIfGap(_ presentationTimeStamp: CMTime, _ pcmAudioFormat: AVAudioFormat) {
        defer {
            latestAudioBufferPresentationTimeStamp = presentationTimeStamp
        }
        guard let latestAudioBufferPresentationTimeStamp else {
            return
        }
        // Assume 1024 samples/buffer at 48 kHz for now
        let samplesPerBuffer: UInt32 = 1024
        let sampleFrequency = 48000.0
        let numberOfGapBuffers = calcNumberOfGapBuffers(
            presentationTimeStamp,
            latestAudioBufferPresentationTimeStamp,
            samplesPerBuffer,
            sampleFrequency
        )
        for index in 0 ..< numberOfGapBuffers {
            let timeOffset = CMTime(
                value: CMTimeValue(Double(samplesPerBuffer) * Double(1 + index)),
                timescale: CMTimeScale(sampleFrequency)
            )
            let newPresentationTimeStamp = latestAudioBufferPresentationTimeStamp + timeOffset
            logger.info("""
            mpeg-ts-reader: Filling audio gap \
            \(latestAudioBufferPresentationTimeStamp.seconds)..\(presentationTimeStamp.seconds) \
            with \(newPresentationTimeStamp.seconds)
            """)
            if let sampleBuffer = CMSampleBuffer.createSilent(
                pcmAudioFormat,
                newPresentationTimeStamp,
                samplesPerBuffer
            ) {
                delegate?.mpegTsReaderAudioBuffer(sampleBuffer)
            }
        }
    }

    private func calcNumberOfGapBuffers(_ presentationTimeStamp: CMTime,
                                        _ latestPresentationTimeStamp: CMTime,
                                        _ samplesPerBuffer: UInt32,
                                        _ sampleFrequency: Double) -> Int
    {
        let ptsDelta = (presentationTimeStamp - latestPresentationTimeStamp).seconds
        let timePerBuffer = Double(samplesPerBuffer) / sampleFrequency
        return max(Int((ptsDelta / timePerBuffer - 1).rounded()), 0)
    }

    private func handleVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        targetLatenciesSynchronizer
            .setLatestVideoPresentationTimeStamp(sampleBuffer.presentationTimeStamp.seconds)
        updateTargetLatencies()
        guard let videoDecoder else {
            return
        }
        videoDecoder.decodeSampleBuffer(sampleBuffer)
    }

    private func handleAudioFormatDescription(_ formatDescription: CMFormatDescription) {
        guard let streamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return
        }
        guard let audioFormat = AVAudioFormat(streamDescription: streamBasicDescription) else {
            logger.info("mpeg-ts-reader: Failed to create audio format")
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
            logger.info("mpeg-ts-reader: Failed to create PCM audio format")
            return
        }
        logger.info("mpeg-ts-reader: in: \(audioFormat), out: \(pcmAudioFormat)")
        audioDecoder = AVAudioConverter(from: audioFormat, to: pcmAudioFormat)
        if audioDecoder == nil {
            logger.info("mpeg-ts-reader: Failed to create audio decdoer")
        }
    }

    private func handleVideoFormatDescription(_ formatDescription: CMFormatDescription) {
        let dimentions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        logger.info("mpeg-ts-reader: Got new video dimensions \(dimentions)")
        videoDecoder?.stopRunning()
        videoDecoder = VideoDecoder(lockQueue: ristServerQueue)
        videoDecoder?.delegate = self
        videoDecoder?.startRunning(formatDescription: formatDescription)
    }

    private func tryMakeSampleBuffer(packetId: UInt16,
                                     data: ElementaryStreamSpecificData) -> (CMSampleBuffer, ElementaryStreamType)?
    {
        guard var packetizedElementaryStream = packetizedElementaryStreams[packetId] else {
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

    private func getAacFormatDescription(_ packetId: UInt16,
                                         _ packetizedElementaryStream: MpegTsPacketizedElementaryStream)
        -> CMFormatDescription?
    {
        guard let adtsHeader = AdtsHeader(data: packetizedElementaryStream.data) else {
            return nil
        }
        if adtsHeader.isSameFormatDescription(other: adtsHeaders[packetId]) {
            return formatDescriptions[packetId]
        }
        guard let formatDescription = adtsHeader.makeFormatDescription() else {
            return nil
        }
        adtsHeaders[packetId] = adtsHeader
        formatDescriptions[packetId] = formatDescription
        handleAudioFormatDescription(formatDescription)
        return formatDescription
    }

    private func tryMakeSampleBufferAac(packetId: UInt16,
                                        data: ElementaryStreamSpecificData,
                                        packetizedElementaryStream: inout MpegTsPacketizedElementaryStream)
        -> (CMSampleBuffer, ElementaryStreamType)?
    {
        guard let formatDescription = getAacFormatDescription(packetId, packetizedElementaryStream) else {
            return nil
        }
        guard let (sampleBuffer,
                   firstReceivedPresentationTimeStamp,
                   previousReceivedPresentationTimeStamp) = packetizedElementaryStream.makeAudioSampleBuffer(
            getBasePresentationTimeStamp(),
            firstReceivedPresentationTimeStamp,
            previousReceivedPresentationTimeStamps[packetId],
            formatDescription
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
        let nalUnits = getNalUnits(data: packetizedElementaryStream.data)
        let units = readH264NalUnits(data: packetizedElementaryStream.data,
                                     nalUnits: nalUnits,
                                     filter: [.pps, .sps, .idr])
        let formatDescription = units.makeFormatDescription()
        if let formatDescription, formatDescriptions[packetId] != formatDescription {
            formatDescriptions[packetId] = formatDescription
            handleVideoFormatDescription(formatDescription)
        }
        guard let (sampleBuffer,
                   firstReceivedPresentationTimeStamp,
                   previousReceivedPresentationTimeStamp) = packetizedElementaryStream.makeVideoSampleBuffer(
            nalUnits,
            getBasePresentationTimeStamp(),
            firstReceivedPresentationTimeStamp,
            previousReceivedPresentationTimeStamps[packetId],
            formatDescriptions[packetId]
        ) else {
            return nil
        }
        sampleBuffer.isSync = units.contains { $0.header.type == .idr }
        self.firstReceivedPresentationTimeStamp = firstReceivedPresentationTimeStamp
        previousReceivedPresentationTimeStamps[packetId] = previousReceivedPresentationTimeStamp
        return (sampleBuffer, data.streamType)
    }

    private func tryMakeSampleBufferH265(packetId: UInt16,
                                         data: ElementaryStreamSpecificData,
                                         packetizedElementaryStream: inout MpegTsPacketizedElementaryStream)
        -> (CMSampleBuffer, ElementaryStreamType)?
    {
        let nalUnits = getNalUnits(data: packetizedElementaryStream.data)
        let units = readH265NalUnits(data: packetizedElementaryStream.data,
                                     nalUnits: nalUnits,
                                     filter: [.sps, .pps, .vps, .prefixSeiNut])
        let formatDescription = units.makeFormatDescription()
        if let formatDescription, formatDescriptions[packetId] != formatDescription {
            formatDescriptions[packetId] = formatDescription
            handleVideoFormatDescription(formatDescription)
        }
        if timecodesEnabled {
            for unit in units {
                switch unit.payload {
                case let .prefixSeiNut(hevcSei):
                    switch hevcSei.payload {
                    case let .timeCode(timeCode):
                        let (timecode, frame) = timeCode.makeClock()
                        logger.debug("xxx Got H.265 SEI timecode \(timecode) (frame: \(frame))")
                    }
                default:
                    break
                }
            }
        }
        guard let (sampleBuffer,
                   firstReceivedPresentationTimeStamp,
                   previousReceivedPresentationTimeStamp) = packetizedElementaryStream.makeVideoSampleBuffer(
            nalUnits,
            getBasePresentationTimeStamp(),
            firstReceivedPresentationTimeStamp,
            previousReceivedPresentationTimeStamps[packetId],
            formatDescriptions[packetId]
        ) else {
            return nil
        }
        sampleBuffer.isSync = units.contains { $0.header.type == .sps }
        self.firstReceivedPresentationTimeStamp = firstReceivedPresentationTimeStamp
        previousReceivedPresentationTimeStamps[packetId] = previousReceivedPresentationTimeStamp
        return (sampleBuffer, data.streamType)
    }

    private func getBasePresentationTimeStamp() -> CMTime {
        if basePresentationTimeStamp == .invalid {
            let latency = CMTime(seconds: targetLatency)
            basePresentationTimeStamp = currentPresentationTimeStamp() + latency
        }
        return basePresentationTimeStamp
    }

    private func updateTargetLatencies() {
        guard let (audioTargetLatency, videoTargetLatency) = targetLatenciesSynchronizer.update() else {
            return
        }
        delegate?.mpegTsReaderSetTargetLatencies(videoTargetLatency, audioTargetLatency)
    }
}

extension MpegTsReader: VideoDecoderDelegate {
    func videoDecoderOutputSampleBuffer(_: VideoDecoder, _ sampleBuffer: CMSampleBuffer) {
        delegate?.mpegTsReaderVideoBuffer(sampleBuffer)
    }
}
