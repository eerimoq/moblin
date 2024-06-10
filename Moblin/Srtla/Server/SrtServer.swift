import AVFoundation
import Foundation
import libsrt

private let srtServerQueue = DispatchQueue(label: "com.eerimoq.srtla-srt-server")

class SrtServer {
    weak var srtlaServer: SrtlaServer?
    private var listenerSocket: SRTSOCKET = SRT_INVALID_SOCK
    private var acceptedStreamId = ""
    private var programAssociationTable = MpegTsProgramAssociation()
    private var programMappingTable: [UInt16: MpegTsProgramMapping] = [:]
    private var programs: [UInt16: UInt16] = [:]
    private var elementaryStreamSpecificData: [UInt16: ElementaryStreamSpecificData] = [:]
    private var packetizedElementaryStreams: [UInt16: MpegTsPacketizedElementaryStream] = [:]
    private var formatDescriptions: [UInt16: CMFormatDescription] = [:]
    private var nalUnitReader = NALUnitReader()
    private var previousPresentationTimeStamps: [UInt16: CMTime] = [:]
    private var audioBuffer: AVAudioCompressedBuffer?
    private var latestAudioBuffer: AVAudioPCMBuffer?
    private var latestAudioBufferPresentationTimeStamp = 0.0
    private var audioDecoder: AVAudioConverter?
    private var pcmAudioFormat: AVAudioFormat?
    private var running = false

    func start() {
        srt_startup()
        running = true
        srtServerQueue.async {
            do {
                try self.main()
            } catch {
                logger.info("srt-server: \(error)")
            }
        }
    }

    func stop() {
        srt_close(listenerSocket)
        listenerSocket = SRT_INVALID_SOCK
        running = false
        srt_cleanup()
    }

    private func main() throws {
        try open()
        try bind()
        try listen()
        while true {
            logger.info("srt-server: Waiting for client to connect.")
            let clientSocket = try accept()
            guard let stream = srtlaServer?.settings.streams
                .first(where: { $0.streamId == acceptedStreamId })
            else {
                srt_close(clientSocket)
                logger.info("srt-server: Client with stream id \(acceptedStreamId) denied.")
                continue
            }
            let option = SRTSocketOption(rawValue: "lossmaxttl")!
            if !option.setOption(clientSocket, value: "200") {
                logger.error("srt-server: Failed to set lossmaxttl option.")
            }
            logger.info("srt-server: Accepted client \(stream.name).")
            recvLoop(clientSocket: clientSocket)
            logger.info("srt-server: Closed client.")
        }
    }

    private func open() throws {
        listenerSocket = srt_create_socket()
        guard listenerSocket != SRT_ERROR else {
            throw "Failed to create socket."
        }
    }

    private func bind() throws {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout.size(ofValue: addr))
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("0.0.0.0")
        addr.sin_port = in_port_t(bigEndian: srtlaServer?.settings.srtPort ?? 4000)
        let addrSize = MemoryLayout.size(ofValue: addr)
        let res = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                srt_bind(listenerSocket, $0, Int32(addrSize))
            }
        }
        guard res != SRT_ERROR else {
            throw "Bind failed."
        }
    }

    private func listen() throws {
        var res = srt_listen(listenerSocket, 5)
        guard res != SRT_ERROR else {
            throw "Listen failed."
        }
        let server = Unmanaged.passRetained(self).toOpaque()
        res = srt_listen_callback(listenerSocket,
                                  { server, _, _, _, streamIdIn in
                                      guard let server, let streamIdIn else {
                                          return SRT_ERROR
                                      }
                                      let srtServer: SrtServer = Unmanaged.fromOpaque(server)
                                          .takeUnretainedValue()
                                      srtServer.acceptedStreamId = String(cString: streamIdIn)
                                      return 0
                                  },
                                  server)
        guard res != SRT_ERROR else {
            throw "Listen callback failed."
        }
    }

    private func accept() throws -> Int32 {
        let clientSocket = srt_accept(listenerSocket, nil, nil)
        guard clientSocket != SRT_ERROR else {
            throw "Accept failed."
        }
        return clientSocket
    }

    private func recvLoop(clientSocket: Int32) {
        let packetSize = 2048
        var packet = Data(count: packetSize)
        while running {
            let count = packet.withUnsafeMutableBytes { pointer in
                srt_recvmsg(clientSocket, pointer.baseAddress, Int32(packetSize))
            }
            guard count != SRT_ERROR else {
                break
            }
            let reader = ByteArray(data: packet.subdata(in: 0 ..< Int(count)))
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
        } else {
            let presentationTimeStamp = sampleBuffer.presentationTimeStamp.seconds
            if let latestAudioBuffer {
                let ptsDelta = presentationTimeStamp - latestAudioBufferPresentationTimeStamp
                // Assume 1024 samples/buffer at 48 kHz for now
                var gapBuffers = Int(((ptsDelta / 0.021333) - 1).rounded())
                logger.info("""
                srt-server: Decoded audio \(outputBuffer) for PTS \
                \(presentationTimeStamp) delta \(ptsDelta) gap \(gapBuffers)
                """)
                while gapBuffers > 0 {
                    logger.info("srt-server: Audio gap filler buffer")
                    srtlaServer?.delegate?.onAudioBuffer(
                        streamId: acceptedStreamId,
                        buffer: latestAudioBuffer
                    )
                    gapBuffers -= 1
                }
            }
            latestAudioBuffer = outputBuffer
            latestAudioBufferPresentationTimeStamp = presentationTimeStamp
            srtlaServer?.delegate?.onAudioBuffer(streamId: acceptedStreamId, buffer: outputBuffer)
        }
    }

    private func handleVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        logger.info("""
        srt-server: Video sample buffer sync \(sampleBuffer.isSync) length \
        \(sampleBuffer.dataBuffer?.dataLength ?? -1) \
        PTS \(sampleBuffer.presentationTimeStamp.seconds)
        """)
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

    private func handleVideoFormatDescription(_: CMFormatDescription) {}

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
