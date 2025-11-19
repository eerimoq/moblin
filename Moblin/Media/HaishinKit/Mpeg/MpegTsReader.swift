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
    private var pcmAudioBuffer: AVAudioPCMBuffer?
    private var latestAudioBufferPresentationTimeStamp: CMTime?
    private var audioDecoder: AVAudioConverter?
    private var pcmAudioFormat: AVAudioFormat?
    private var videoDecoder: VideoDecoder?
    private let targetLatenciesSynchronizer: TargetLatenciesSynchronizer
    private let timecodesEnabled: Bool
    private let targetLatency: Double
    weak var delegate: MpegTsReaderDelegate?
    private let decoderQueue: DispatchQueue
    private let wrappingTimestamp = WrappingTimestamp(name: "MpegTsReader",
                                                      maximumTimestamp: CMTime(seconds: 0x2_0000_0000))

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
            if let (isAudio, sampleBuffer) = tryMakeSampleBuffer(packetId: packet.id, data: data) {
                handleSampleBuffer(isAudio, sampleBuffer)
            }
            packetizedElementaryStreams[packet.id] = try MpegTsPacketizedElementaryStream(data: packet.payload)
        } else {
            packetizedElementaryStreams[packet.id]?.append(data: packet.payload)
        }
    }

    private func handleSampleBuffer(_ isAudio: Bool, _ sampleBuffer: CMSampleBuffer) {
        if isAudio {
            handleAudioSampleBuffer(sampleBuffer)
        } else {
            handleVideoSampleBuffer(sampleBuffer)
        }
    }

    private func handleAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        targetLatenciesSynchronizer.setLatestAudioPresentationTimeStamp(sampleBuffer.presentationTimeStamp.seconds)
        updateTargetLatencies()
        guard let audioDecoder, let pcmAudioFormat, let audioBuffer, let pcmAudioBuffer else {
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
        audioBuffer.packetDescriptions?.pointee = AudioStreamPacketDescription(
            mStartOffset: 0,
            mVariableFramesInPacket: 0,
            mDataByteSize: UInt32(length)
        )
        audioBuffer.packetCount = 1
        audioBuffer.byteLength = UInt32(length)
        audioBuffer.data.copyMemory(from: dataPointer, byteCount: length)
        var error: NSError?
        audioDecoder.convert(to: pcmAudioBuffer, error: &error) { _, inputStatus in
            inputStatus.pointee = .haveData
            return self.audioBuffer
        }
        if let error {
            logger.info("mpeg-ts-reader: Audio error \(error)")
            return
        }
        outputSilenceIfGap(sampleBuffer.presentationTimeStamp, pcmAudioFormat)
        guard let sampleBuffer = pcmAudioBuffer.makeSampleBuffer(sampleBuffer.presentationTimeStamp) else {
            return
        }
        delegate?.mpegTsReaderAudioBuffer(sampleBuffer)
    }

    // Maybe only fill gaps in audio unit?
    private func outputSilenceIfGap(_ presentationTimeStamp: CMTime, _ pcmAudioFormat: AVAudioFormat) {
        defer {
            latestAudioBufferPresentationTimeStamp = presentationTimeStamp
        }
        guard let latestAudioBufferPresentationTimeStamp, let pcmAudioBuffer else {
            return
        }
        let samplesPerBuffer = pcmAudioBuffer.frameLength
        let sampleFrequency = pcmAudioBuffer.format.sampleRate
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
        pcmAudioBuffer = AVAudioPCMBuffer(pcmFormat: pcmAudioFormat,
                                          frameCapacity: streamBasicDescription.pointee.mFramesPerPacket)
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

    private func tryMakeSampleBuffer(packetId: UInt16, data: ElementaryStreamSpecificData) -> (Bool, CMSampleBuffer)? {
        guard var packetizedElementaryStream = packetizedElementaryStreams[packetId] else {
            return nil
        }
        defer {
            packetizedElementaryStreams[packetId] = nil
        }
        switch data.streamType {
        case .mpeg2PacketizedData:
            return makeSampleBufferMpeg2PacketizedData(packetId, data, &packetizedElementaryStream)
        case .adtsAac:
            return makeSampleBufferAac(packetId, &packetizedElementaryStream)
        case .h264:
            return makeSampleBufferH264(packetId, &packetizedElementaryStream)
        case .h265:
            return makeSampleBufferH265(packetId, &packetizedElementaryStream)
        default:
            return nil
        }
    }

    private func makeSampleBufferMpeg2PacketizedData(
        _ packetId: UInt16,
        _ data: ElementaryStreamSpecificData,
        _ packetizedElementaryStream: inout MpegTsPacketizedElementaryStream
    ) -> (Bool, CMSampleBuffer)? {
        switch data.getDescriptor(tag: .registration) {
        case ElementaryStreamDescriptiorRegistration.opus:
            return makeSampleBufferMpeg2PacketizedDataOpus(packetId, data, &packetizedElementaryStream)
        default:
            return nil
        }
    }

    private func getOpusFormatDescription(_ packetId: UInt16,
                                          _ data: ElementaryStreamSpecificData) -> CMFormatDescription?
    {
        guard let extensionData = data.getDescriptor(tag: .extension) else {
            return nil
        }
        guard extensionData.count == 2, extensionData[0] == 0x80 else {
            return nil
        }
        let channels = extensionData[1]
        var formatDescription: CMAudioFormatDescription?
        var audioStreamBasicDescription = AudioStreamBasicDescription(
            mSampleRate: 48000,
            mFormatID: kAudioFormatOpus,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: 960,
            mBytesPerFrame: 0,
            mChannelsPerFrame: UInt32(channels),
            mBitsPerChannel: 0,
            mReserved: 0
        )
        guard CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &audioStreamBasicDescription,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        ) == noErr else {
            return nil
        }
        guard let formatDescription else {
            return nil
        }
        if formatDescriptions[packetId] != formatDescription {
            formatDescriptions[packetId] = formatDescription
            handleAudioFormatDescription(formatDescription)
        }
        return formatDescription
    }

    private func makeSampleBufferMpeg2PacketizedDataOpus(
        _ packetId: UInt16,
        _ data: ElementaryStreamSpecificData,
        _ packetizedElementaryStream: inout MpegTsPacketizedElementaryStream
    ) -> (Bool, CMSampleBuffer)? {
        guard let formatDescription = getOpusFormatDescription(packetId, data) else {
            return nil
        }
        guard let (length, payloadOffset) = OpusHeader.decode(data: packetizedElementaryStream.data) else {
            return nil
        }
        let blockBuffer = packetizedElementaryStream.data.makeBlockBuffer(advancedBy: payloadOffset)
        var sampleSizes = [length]
        guard let sampleBuffer = makeSampleBuffer(
            packetId,
            packetizedElementaryStream.optionalHeader,
            formatDescription,
            blockBuffer,
            &sampleSizes
        ) else {
            return nil
        }
        return (true, sampleBuffer)
    }

    private func getAacFormatDescription(
        _ packetId: UInt16,
        _ packetizedElementaryStream: MpegTsPacketizedElementaryStream
    ) -> CMFormatDescription? {
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

    private func makeSampleBufferAac(
        _ packetId: UInt16,
        _ packetizedElementaryStream: inout MpegTsPacketizedElementaryStream
    ) -> (Bool, CMSampleBuffer)? {
        guard let formatDescription = getAacFormatDescription(packetId, packetizedElementaryStream) else {
            return nil
        }
        var sampleSizes: [Int] = []
        let blockBuffer = packetizedElementaryStream.data.makeBlockBuffer(advancedBy: AdtsHeader.size)
        let reader = ADTSReader(data: packetizedElementaryStream.data)
        var iterator = reader.makeIterator()
        while let dataLength = iterator.next() {
            sampleSizes.append(dataLength)
        }
        guard !sampleSizes.isEmpty else {
            return nil
        }
        guard let sampleBuffer = makeSampleBuffer(
            packetId,
            packetizedElementaryStream.optionalHeader,
            formatDescription,
            blockBuffer,
            &sampleSizes
        ) else {
            return nil
        }
        return (true, sampleBuffer)
    }

    private func makeSampleBufferH264(
        _ packetId: UInt16,
        _ packetizedElementaryStream: inout MpegTsPacketizedElementaryStream
    ) -> (Bool, CMSampleBuffer)? {
        let nalUnits = getNalUnits(data: packetizedElementaryStream.data)
        let units = readH264NalUnits(data: packetizedElementaryStream.data,
                                     nalUnits: nalUnits,
                                     filter: [.pps, .sps, .idr])
        let formatDescription = units.makeFormatDescription()
        if let formatDescription, formatDescriptions[packetId] != formatDescription {
            formatDescriptions[packetId] = formatDescription
            handleVideoFormatDescription(formatDescription)
        }
        removeNalUnitStartCodes(&packetizedElementaryStream.data, nalUnits)
        let blockBuffer = packetizedElementaryStream.data.makeBlockBuffer()
        var sampleSizes = [blockBuffer?.dataLength ?? 0]
        guard let sampleBuffer = makeSampleBuffer(
            packetId,
            packetizedElementaryStream.optionalHeader,
            formatDescriptions[packetId],
            blockBuffer,
            &sampleSizes
        ) else {
            return nil
        }
        sampleBuffer.setIsSync(units.contains { $0.header.type == .idr })
        return (false, sampleBuffer)
    }

    private func makeSampleBufferH265(
        _ packetId: UInt16,
        _ packetizedElementaryStream: inout MpegTsPacketizedElementaryStream
    ) -> (Bool, CMSampleBuffer)? {
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
        removeNalUnitStartCodes(&packetizedElementaryStream.data, nalUnits)
        let blockBuffer = packetizedElementaryStream.data.makeBlockBuffer()
        var sampleSizes = [blockBuffer?.dataLength ?? 0]
        guard let sampleBuffer = makeSampleBuffer(
            packetId,
            packetizedElementaryStream.optionalHeader,
            formatDescriptions[packetId],
            blockBuffer,
            &sampleSizes
        ) else {
            return nil
        }
        sampleBuffer.setIsSync(units.contains { $0.header.type == .sps })
        return (false, sampleBuffer)
    }

    private func makeSampleBuffer(
        _ packetId: UInt16,
        _ optionalHeader: OptionalHeader,
        _ formatDescription: CMFormatDescription?,
        _ blockBuffer: CMBlockBuffer?,
        _ sampleSizes: inout [Int]
    ) -> CMSampleBuffer? {
        var sampleBuffer: CMSampleBuffer?
        let basePresentationTimeStamp = getBasePresentationTimeStamp()
        let receivedPresentationTimeStamp = wrappingTimestamp.update(optionalHeader.getPresentationTimeStamp())
        let receivedDecodeTimeStamp = wrappingTimestamp.update(optionalHeader.getDecodeTimeStamp())
        var timing = CMSampleTimingInfo()
        var firstReceivedPresentationTimeStamp = firstReceivedPresentationTimeStamp
        if let firstReceivedPresentationTimeStamp {
            let basePresentationTimeStamp = basePresentationTimeStamp - firstReceivedPresentationTimeStamp
            timing.presentationTimeStamp = basePresentationTimeStamp + receivedPresentationTimeStamp
            timing.decodeTimeStamp = basePresentationTimeStamp + receivedDecodeTimeStamp
            if let previousReceivedPresentationTimeStamp = previousReceivedPresentationTimeStamps[packetId] {
                timing.duration = timing.presentationTimeStamp - previousReceivedPresentationTimeStamp
            } else {
                timing.duration = .invalid
            }
        } else {
            timing.presentationTimeStamp = basePresentationTimeStamp
            timing.decodeTimeStamp = basePresentationTimeStamp
            timing.duration = .invalid
            firstReceivedPresentationTimeStamp = receivedPresentationTimeStamp
        }
        guard let blockBuffer, CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleCount: sampleSizes.count,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: sampleSizes.count,
            sampleSizeArray: &sampleSizes,
            sampleBufferOut: &sampleBuffer
        ) == noErr, let sampleBuffer else {
            return nil
        }
        self.firstReceivedPresentationTimeStamp = firstReceivedPresentationTimeStamp
        previousReceivedPresentationTimeStamps[packetId] = timing.presentationTimeStamp
        return sampleBuffer
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
