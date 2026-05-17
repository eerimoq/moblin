import AVFoundation

protocol MpegTsReaderDelegate: AnyObject {
    func mpegTsReaderAudioBuffer(_ sampleBuffer: CMSampleBuffer)
    func mpegTsReaderVideoBuffer(_ sampleBuffer: CMSampleBuffer)
    func mpegTsReaderSetTargetLatencies(_ videoTargetLatency: Double, _ audioTargetLatency: Double)
}

class MpegTsReader: @unchecked Sendable {
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
    private var typicalAudioPacketDuration: Double?
    private var audioDecoder: AVAudioConverter?
    private var pcmAudioFormat: AVAudioFormat?
    private var mpgaDecoder: MiniMp3Decoder?
    private var videoDecoder: VideoDecoder?
    private let targetLatenciesSynchronizer: TargetLatenciesSynchronizer
    private let timecodesEnabled: Bool
    private let targetLatency: Double
    weak var delegate: (any MpegTsReaderDelegate)?
    private let decoderQueue: DispatchQueue
    private var wrappingTimestamps: [UInt16: WrappingTimestamp] = [:]

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
            packetizedElementaryStreams[packet.id] = try MpegTsPacketizedElementaryStream(data: packet
                .payload)
        } else {
            packetizedElementaryStreams[packet.id]?.append(data: packet.payload)
        }
    }

    private func handleSampleBuffer(_ isAudio: Bool, _ sampleBuffer: CMSampleBuffer) {
        if isAudio {
            if let asbd = sampleBuffer.formatDescription?.audioStreamBasicDescription,
               asbd.mFormatID == kAudioFormatMPEGLayer1
               || asbd.mFormatID == kAudioFormatMPEGLayer2
               || asbd.mFormatID == kAudioFormatMPEGLayer3
            {
                handleMpgaAudioSampleBuffer(sampleBuffer)
            } else {
                handleAudioSampleBuffer(sampleBuffer)
            }
        } else {
            handleVideoSampleBuffer(sampleBuffer)
        }
    }

    private func handleAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        targetLatenciesSynchronizer
            .setLatestAudioPresentationTimeStamp(sampleBuffer.presentationTimeStamp.seconds)
        updateTargetLatencies()
        guard let audioDecoder, let pcmAudioFormat, let audioBuffer else {
            return
        }
        guard let dataBuffer = sampleBuffer.dataBuffer else {
            return
        }
        guard let (basePointer, totalLength) = dataBuffer.getDataPointer() else {
            return
        }
        // The CMSampleBuffer may contain multiple AAC frames. The block buffer was
        // created by makeSampleBufferAac which skipped the ADTS header of the first
        // frame only. Subsequent frames still have their ADTS headers (7 bytes) in
        // the data. sampleSize(at:) returns the raw AAC payload size (excluding
        // ADTS header), so for frames after the first we must skip AdtsHeader.size
        // bytes before reading the payload.
        let numSamples = sampleBuffer.numSamples
        var offset = 0
        let basePts = sampleBuffer.presentationTimeStamp
        // Check for PTS discontinuity only once per PES packet (using the base PTS),
        // not for each individual AAC frame within the packet.
        checkAudioPtsDiscontinuity(basePts, numSamples)
        for sampleIndex in 0 ..< numSamples {
            // Skip ADTS header for frames after the first
            if sampleIndex > 0 {
                offset += AdtsHeader.size
            }
            let sampleSize: Int
            if numSamples == 1 {
                sampleSize = totalLength
            } else {
                sampleSize = sampleBuffer.sampleSize(at: sampleIndex)
            }
            guard sampleSize > 0, offset + sampleSize <= totalLength else {
                break
            }
            guard sampleSize <= audioBuffer.maximumPacketSize else {
                offset += sampleSize
                continue
            }
            audioBuffer.packetDescriptions?.pointee = AudioStreamPacketDescription(
                mStartOffset: 0,
                mVariableFramesInPacket: 0,
                mDataByteSize: UInt32(sampleSize)
            )
            audioBuffer.packetCount = 1
            audioBuffer.byteLength = UInt32(sampleSize)
            audioBuffer.data.copyMemory(from: basePointer.advanced(by: offset), byteCount: sampleSize)
            guard let freshPcmBuffer = AVAudioPCMBuffer(pcmFormat: pcmAudioFormat,
                                                        frameCapacity: 1024) else {
                offset += sampleSize
                continue
            }
            var error: NSError?
            audioDecoder.convert(to: freshPcmBuffer, error: &error) { _, inputStatus in
                inputStatus.pointee = .haveData
                return self.audioBuffer
            }
            if let error {
                logger.info("mpeg-ts-reader: Audio decode error \(error)")
                offset += sampleSize
                continue
            }
            guard freshPcmBuffer.frameLength > 0 else {
                offset += sampleSize
                continue
            }
            let framePts = basePts + CMTime(value: CMTimeValue(1024 * sampleIndex),
                                           timescale: CMTimeScale(pcmAudioFormat.sampleRate))
            if let outputBuffer = freshPcmBuffer.makeSampleBuffer(framePts) {
                delegate?.mpegTsReaderAudioBuffer(outputBuffer)
            }
            offset += sampleSize
        }
    }

    // Track the PTS of the last delivered audio PES packet. Used only to detect large
    // discontinuities (e.g. stream reconnect) that require a PTS anchor reset.
    // Gap-filling for short network dropouts is handled by BufferedAudio.
    // Called once per PES packet with the base PTS, the number of frames, and
    // the samples-per-frame (1024 for AAC, 1152 for MP3/MPGA, etc.)
    private func checkAudioPtsDiscontinuity(_ presentationTimeStamp: CMTime,
                                            _ numFrames: Int,
                                            samplesPerFrame: Int = 1024,
                                            sampleRate: Double? = nil)
    {
        let sampleRate = sampleRate ?? pcmAudioFormat?.sampleRate ?? 48000
        let pesDuration = CMTime(value: CMTimeValue(samplesPerFrame * numFrames),
                                 timescale: CMTimeScale(sampleRate))
        let lastFramePts = presentationTimeStamp + pesDuration
            - CMTime(value: CMTimeValue(samplesPerFrame), timescale: CMTimeScale(sampleRate))
        guard let latestAudioBufferPresentationTimeStamp else {
            self.latestAudioBufferPresentationTimeStamp = lastFramePts
            return
        }
        let ptsDelta = (presentationTimeStamp - latestAudioBufferPresentationTimeStamp).seconds
        let singleFrameDuration = Double(samplesPerFrame) / sampleRate
        if ptsDelta > singleFrameDuration {
            typicalAudioPacketDuration = min(typicalAudioPacketDuration ?? ptsDelta, ptsDelta)
        }
        let packetDuration = typicalAudioPacketDuration ?? singleFrameDuration
        // Reset PTS anchor only on genuine large discontinuities (> 10 inter-packet intervals).
        // Do NOT update latestAudioBufferPresentationTimeStamp on reset — leave it nil so the
        // next frame after re-anchoring is treated as the first frame with no prior reference.
        if ptsDelta > 10 * packetDuration {
            logger.debug("mpeg-ts-reader: Audio gap too large (\(ptsDelta)s), resetting PTS")
            firstReceivedPresentationTimeStamp = nil
            basePresentationTimeStamp = .invalid
            previousReceivedPresentationTimeStamps.removeAll()
            self.latestAudioBufferPresentationTimeStamp = nil
            return
        }
        self.latestAudioBufferPresentationTimeStamp = lastFramePts
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

    private func handleMpgaFormatDescription(_: CMFormatDescription) {
        // MiniMp3Decoder initialises lazily on the first decoded frame —
        // no separate setup step is needed.
        if mpgaDecoder == nil {
            mpgaDecoder = MiniMp3Decoder()
        }
    }

    private func handleMpgaAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        targetLatenciesSynchronizer
            .setLatestAudioPresentationTimeStamp(sampleBuffer.presentationTimeStamp.seconds)
        updateTargetLatencies()
        guard let decoder = mpgaDecoder else {
            logger.info("mpeg-ts-reader: MPGA decoder not ready")
            return
        }
        guard let dataBuffer = sampleBuffer.dataBuffer,
              let (dataPointer, length) = dataBuffer.getDataPointer()
        else {
            logger.info("mpeg-ts-reader: MPGA no data buffer")
            return
        }
        let frameData = Data(bytesNoCopy: dataPointer, count: length, deallocator: .none)
        let pcmBuffers = decoder.decodeAll(frameData)
        guard !pcmBuffers.isEmpty, let fmt = decoder.outputFormat else {
            if pcmBuffers.isEmpty { logger.info("mpeg-ts-reader: MPGA decode returned no frames") }
            return
        }
        // Each decoded frame advances the PTS by one frame duration.
        let samplesPerFrame = Double(pcmBuffers[0].frameLength)
        let sampleRate = fmt.sampleRate
        var pts = sampleBuffer.presentationTimeStamp
        // Check for PTS discontinuity once per PES packet
        checkAudioPtsDiscontinuity(pts, pcmBuffers.count,
                                   samplesPerFrame: Int(samplesPerFrame),
                                   sampleRate: sampleRate)
        for pcmBuf in pcmBuffers {
            guard let outputSampleBuffer = pcmBuf.makeSampleBuffer(pts) else {
                logger.info("mpeg-ts-reader: MPGA failed to make output sample buffer")
                pts = pts + CMTime(value: CMTimeValue(samplesPerFrame),
                                   timescale: CMTimeScale(sampleRate))
                continue
            }
            delegate?.mpegTsReaderAudioBuffer(outputSampleBuffer)
            pts = pts + CMTime(value: CMTimeValue(samplesPerFrame),
                               timescale: CMTimeScale(sampleRate))
        }
    }

    private func handleAudioFormatDescription(_ formatDescription: CMFormatDescription) {
        guard let streamBasicDescription =
            CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        else {
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
            interleaved: true
        )
        guard let pcmAudioFormat else {
            logger.info("mpeg-ts-reader: Failed to create PCM audio format")
            return
        }
        logger.info("mpeg-ts-reader: in: \(audioFormat), out: \(pcmAudioFormat)")
        audioDecoder = AVAudioConverter(from: audioFormat, to: pcmAudioFormat)
        if audioDecoder == nil {
            logger.info("mpeg-ts-reader: Failed to create audio decoder")
        }
    }

    private func handleVideoFormatDescription(_ formatDescription: CMFormatDescription) {
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        logger.info("mpeg-ts-reader: Got new video dimensions \(dimensions)")
        videoDecoder?.stopRunning()
        videoDecoder = VideoDecoder(lockQueue: decoderQueue)
        videoDecoder?.delegate = self
        videoDecoder?.startRunning(formatDescription: formatDescription)
    }

    private func tryMakeSampleBuffer(packetId: UInt16,
                                     data: ElementaryStreamSpecificData) -> (Bool, CMSampleBuffer)?
    {
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
        case .mpeg1Audio, .mpeg2Audio:
            return makeSampleBufferMpga(packetId, &packetizedElementaryStream)
        case .h264:
            return makeSampleBufferH264(packetId, &packetizedElementaryStream)
        case .h265:
            return makeSampleBufferH265(packetId, &packetizedElementaryStream)
        default:
            return nil
        }
    }

    // MPEG-1/2 audio frame header parser.
    // Header layout (32 bits):
    //   [31:21] sync (all 1s)
    //   [20:19] MPEG version: 3=MPEG-1, 2=MPEG-2, 0=MPEG-2.5
    //   [18:17] layer: 3=I, 2=II, 1=III
    //   [16]    protection
    //   [15:12] bitrate index
    //   [11:10] sample rate index
    //   [9]     padding
    //   [8]     private
    //   [7:6]   channel mode: 3=mono, else stereo/joint/dual
    private func parseMpgaFrameHeader(_ data: Data) -> (formatId: AudioFormatID,
                                                         sampleRate: Double,
                                                         channels: UInt32,
                                                         framesPerPacket: UInt32,
                                                         frameSizeBytes: UInt32)? {
        guard data.count >= 4 else {
            return nil
        }
        let b0 = data[data.startIndex]
        let b1 = data[data.startIndex + 1]
        guard b0 == 0xFF, (b1 & 0xE0) == 0xE0 else {
            return nil
        }
        let mpegVersion = (b1 >> 3) & 0x03 // 0=MPEG2.5, 1=reserved, 2=MPEG-2, 3=MPEG-1
        let layer = (b1 >> 1) & 0x03       // 3=Layer I, 2=Layer II, 1=Layer III

        let formatId: AudioFormatID
        let framesPerPacket: UInt32
        let samplesPerFrame: UInt32
        switch layer {
        case 3:
            formatId = kAudioFormatMPEGLayer1
            samplesPerFrame = 384
            framesPerPacket = 384
        case 2:
            formatId = kAudioFormatMPEGLayer2
            samplesPerFrame = 1152
            framesPerPacket = 1152
        case 1:
            formatId = kAudioFormatMPEGLayer3
            samplesPerFrame = (mpegVersion == 3) ? 1152 : 576
            framesPerPacket = samplesPerFrame
        default:
            return nil
        }

        let b2 = data[data.startIndex + 2]
        let b3 = data[data.startIndex + 3]

        let bitrateIndex = (b2 >> 4) & 0x0F
        let sampleRateIndex = (b2 >> 2) & 0x03
        let padding = UInt32((b2 >> 1) & 0x01)

        // Channel mode: 3 = single channel (mono), all others = 2 channels
        let channelMode = (b3 >> 6) & 0x03
        let channels: UInt32 = (channelMode == 3) ? 1 : 2

        let sampleRate: Double
        switch mpegVersion {
        case 3: // MPEG-1
            switch sampleRateIndex {
            case 0: sampleRate = 44100
            case 1: sampleRate = 48000
            case 2: sampleRate = 32000
            default: return nil
            }
        case 2: // MPEG-2
            switch sampleRateIndex {
            case 0: sampleRate = 22050
            case 1: sampleRate = 24000
            case 2: sampleRate = 16000
            default: return nil
            }
        case 0: // MPEG-2.5
            switch sampleRateIndex {
            case 0: sampleRate = 11025
            case 1: sampleRate = 12000
            case 2: sampleRate = 8000
            default: return nil
            }
        default:
            return nil
        }

        // Bitrate tables (kbps), indexed by [mpegVersion==3 ? 0 : 1][layer][bitrateIndex]
        let bitrateKbps: UInt32
        switch layer {
        case 3: // Layer I
            let table: [UInt32] = [0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448, 0]
            bitrateKbps = table[Int(bitrateIndex)]
        case 2: // Layer II
            let tableV1: [UInt32] = [0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384, 0]
            let tableV2: [UInt32] = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0]
            bitrateKbps = (mpegVersion == 3) ? tableV1[Int(bitrateIndex)] : tableV2[Int(bitrateIndex)]
        case 1: // Layer III
            let tableV1: [UInt32] = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0]
            let tableV2: [UInt32] = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0]
            bitrateKbps = (mpegVersion == 3) ? tableV1[Int(bitrateIndex)] : tableV2[Int(bitrateIndex)]
        default:
            return nil
        }
        guard bitrateKbps > 0 else {
            return nil
        }

        // Frame size in bytes
        let frameSizeBytes: UInt32
        switch layer {
        case 3: // Layer I: (12 * bitrate / sampleRate + padding) * 4
            frameSizeBytes = (12 * bitrateKbps * 1000 / UInt32(sampleRate) + padding) * 4
        default: // Layer II/III: 144 * bitrate / sampleRate + padding
            frameSizeBytes = 144 * bitrateKbps * 1000 / UInt32(sampleRate) + padding
        }

        return (formatId, sampleRate, channels, framesPerPacket, frameSizeBytes)
    }

    private func getMpgaFormatDescription(_ packetId: UInt16,
                                          _ data: Data) -> CMFormatDescription? {
        guard let parsed = parseMpgaFrameHeader(data) else {
            logger.info("mpeg-ts-reader: Failed to parse MPEG audio frame header")
            return nil
        }
        // Re-use cached description if nothing changed
        if let existing = formatDescriptions[packetId],
           let asbd = existing.audioStreamBasicDescription,
           asbd.mFormatID == parsed.formatId,
           asbd.mSampleRate == parsed.sampleRate,
           asbd.mChannelsPerFrame == parsed.channels
        {
            return existing
        }
        var asbd = AudioStreamBasicDescription(
            mSampleRate: parsed.sampleRate,
            mFormatID: parsed.formatId,
            mFormatFlags: 0,
            mBytesPerPacket: parsed.frameSizeBytes,
            mFramesPerPacket: parsed.framesPerPacket,
            mBytesPerFrame: 0,
            mChannelsPerFrame: parsed.channels,
            mBitsPerChannel: 0,
            mReserved: 0
        )
        var formatDescription: CMAudioFormatDescription?
        guard CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        ) == noErr, let formatDescription else {
            logger.info("mpeg-ts-reader: Failed to create MPEG audio format description")
            return nil
        }
        formatDescriptions[packetId] = formatDescription
        handleMpgaFormatDescription(formatDescription)
        return formatDescription
    }

    private func makeSampleBufferMpga(
        _ packetId: UInt16,
        _ packetizedElementaryStream: inout MpegTsPacketizedElementaryStream
    ) -> (Bool, CMSampleBuffer)? {
        guard let formatDescription = getMpgaFormatDescription(packetId,
                                                               packetizedElementaryStream.data)
        else {
            return nil
        }
        let blockBuffer = packetizedElementaryStream.data.makeBlockBuffer()
        var sampleSizes = [blockBuffer?.dataLength ?? 0]
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

    private func makeSampleBufferMpeg2PacketizedData(
        _ packetId: UInt16,
        _ data: ElementaryStreamSpecificData,
        _ packetizedElementaryStream: inout MpegTsPacketizedElementaryStream
    ) -> (Bool, CMSampleBuffer)? {
        switch data.getDescriptor(tag: .registration) {
        case ElementaryStreamDescriptiorRegistration.opus:
            makeSampleBufferMpeg2PacketizedDataOpus(packetId, data, &packetizedElementaryStream)
        default:
            nil
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
                        logger.debug("mpeg-ts-reader: Got H.265 SEI timecode \(timecode) (frame: \(frame))")
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
        let wrappingTimestamp = wrappingTimestamps[packetId] ?? WrappingTimestamp(
            name: "MpegTsReader-pts-\(packetId)",
            maximumTimestamp: CMTime(seconds: 0x2_0000_0000)
        )
        wrappingTimestamps[packetId] = wrappingTimestamp
        let rawPts = optionalHeader.getPresentationTimeStamp()
        let receivedPresentationTimeStamp = rawPts.isValid
            ? wrappingTimestamp.update(rawPts)
            : rawPts
        let rawDts = optionalHeader.getDecodeTimeStamp()
        let receivedDecodeTimeStamp = rawDts.isValid
            ? wrappingTimestamp.update(rawDts)
            : rawDts
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
