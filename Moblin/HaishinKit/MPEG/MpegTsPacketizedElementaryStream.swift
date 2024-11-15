import AVFoundation
import CoreMedia

/**
 - seealso: https://en.wikipedia.org/wiki/Packetized_elementary_stream
 */

private struct OptionalHeader {
    static let fixedSectionSize = 3
    var markerBits: UInt8 = 2
    var scramblingControl: UInt8 = 0
    var priority = false
    var dataAlignmentIndicator = false
    var copyright = false
    var originalOrCopy = false
    var ptsDtsIndicator: UInt8 = 0
    var esCRFlag = false
    var esRateFlag = false
    var dsmTrickModeFlag = false
    var additionalCopyInfoFlag = false
    var crcFlag = false
    var extentionFlag = false
    var pesHeaderLength: UInt8 = 0
    var optionalFields = Data()
    var stuffingBytes = Data()

    init() {}

    init(data: Data) throws {
        let reader = ByteArray(data: data)
        let bytes = try reader.readBytes(OptionalHeader.fixedSectionSize)
        markerBits = (bytes[0] & 0b1100_0000) >> 6
        scramblingControl = bytes[0] & 0b0011_0000 >> 4
        priority = (bytes[0] & 0b0000_1000) == 0b0000_1000
        dataAlignmentIndicator = (bytes[0] & 0b0000_0100) == 0b0000_0100
        copyright = (bytes[0] & 0b0000_0010) == 0b0000_0010
        originalOrCopy = (bytes[0] & 0b0000_0001) == 0b0000_0001
        ptsDtsIndicator = (bytes[1] & 0b1100_0000) >> 6
        esCRFlag = (bytes[1] & 0b0010_0000) == 0b0010_0000
        esRateFlag = (bytes[1] & 0b0001_0000) == 0b0001_0000
        dsmTrickModeFlag = (bytes[1] & 0b0000_1000) == 0b0000_1000
        additionalCopyInfoFlag = (bytes[1] & 0b0000_0100) == 0b0000_0100
        crcFlag = (bytes[1] & 0b0000_0010) == 0b0000_0010
        extentionFlag = (bytes[1] & 0b0000_0001) == 0b0000_0001
        pesHeaderLength = bytes[2]
        optionalFields = try reader.readBytes(Int(pesHeaderLength))
    }

    mutating func setTimestamp(_ presentationTimeStamp: CMTime, _ decodeTimeStamp: CMTime) {
        if presentationTimeStamp != .invalid {
            ptsDtsIndicator |= 0x02
        }
        if decodeTimeStamp != .invalid {
            ptsDtsIndicator |= 0x01
        }
        if (ptsDtsIndicator & 0x02) == 0x02 {
            let presentationTimeStamp = Int64(presentationTimeStamp.seconds * Double(TSTimestamp.resolution))
            optionalFields += TSTimestamp.encode(presentationTimeStamp, ptsDtsIndicator << 4)
        }
        if (ptsDtsIndicator & 0x01) == 0x01 {
            let decodeTimeStamp = Int64(decodeTimeStamp.seconds * Double(TSTimestamp.resolution))
            optionalFields += TSTimestamp.encode(decodeTimeStamp, 0x01 << 4)
        }
        pesHeaderLength = UInt8(optionalFields.count)
    }

    func encode() -> Data {
        var bytes = Data([0x00, 0x00])
        bytes[0] |= markerBits << 6
        bytes[0] |= scramblingControl << 4
        bytes[0] |= priority.uint8 << 3
        bytes[0] |= dataAlignmentIndicator.uint8 << 2
        bytes[0] |= copyright.uint8 << 1
        bytes[0] |= originalOrCopy.uint8
        bytes[1] |= ptsDtsIndicator << 6
        bytes[1] |= esCRFlag.uint8 << 5
        bytes[1] |= esRateFlag.uint8 << 4
        bytes[1] |= dsmTrickModeFlag.uint8 << 3
        bytes[1] |= additionalCopyInfoFlag.uint8 << 2
        bytes[1] |= crcFlag.uint8 << 1
        bytes[1] |= extentionFlag.uint8
        return ByteArray()
            .writeBytes(bytes)
            .writeUInt8(pesHeaderLength)
            .writeBytes(optionalFields)
            .writeBytes(stuffingBytes)
            .data
    }

    func getPresentationTimeStamp() -> CMTime {
        var presentationTimeStamp: CMTime = .invalid
        if ptsDtsIndicator & 0x02 == 0x02 {
            presentationTimeStamp = .init(
                value: TSTimestamp.decode(optionalFields, offset: 0),
                timescale: CMTimeScale(TSTimestamp.resolution)
            )
        }
        return presentationTimeStamp
    }

    func getDecodeTimeStamp() -> CMTime {
        var decodeTimeStamp: CMTime = .invalid
        if ptsDtsIndicator & 0x01 == 0x01 {
            decodeTimeStamp = .init(
                value: TSTimestamp.decode(optionalFields, offset: TSTimestamp.dataSize),
                timescale: CMTimeScale(TSTimestamp.resolution)
            )
        }
        return decodeTimeStamp
    }
}

struct MpegTsPacketizedElementaryStream {
    static let untilPacketLengthSize: Int = 6
    static let startCode = Data([0x00, 0x00, 0x01])
    private var startCode = MpegTsPacketizedElementaryStream.startCode
    private var streamID: UInt8 = 0
    private var packetLength: UInt16 = 0
    private var optionalHeader = OptionalHeader()
    var data = Data()

    init?(
        bytes: UnsafePointer<UInt8>,
        count: UInt32,
        presentationTimeStamp: CMTime,
        config: MpegTsAudioConfig,
        streamID: UInt8
    ) {
        data.append(contentsOf: config.makeHeader(Int(count)))
        data.append(bytes, count: Int(count))
        optionalHeader.dataAlignmentIndicator = true
        optionalHeader.setTimestamp(presentationTimeStamp, .invalid)
        let length = data.count + optionalHeader.encode().count
        if length < Int(UInt16.max) {
            packetLength = UInt16(length)
        } else {
            return nil
        }
        self.streamID = streamID
    }

    init(
        bytes: UnsafeMutablePointer<UInt8>,
        count: Int,
        presentationTimeStamp: CMTime,
        decodeTimeStamp: CMTime,
        config: MpegTsVideoConfigAvc?,
        streamID: UInt8
    ) {
        if let config {
            // 3 NAL units. SEI(9), SPS(7) and PPS(8)
            data += nalUnitStartCode
            data.append(contentsOf: [0x09, 0x10])
            data += nalUnitStartCode
            data.append(contentsOf: config.sequenceParameterSets[0])
            data += nalUnitStartCode
            data.append(contentsOf: config.pictureParameterSets[0])
        } else {
            data += nalUnitStartCode
            data.append(contentsOf: [0x09, 0x30])
        }
        var payload = Data(bytesNoCopy: bytes, count: count, deallocator: .none)
        addNalUnitStartCodes(&payload)
        data.append(payload)
        optionalHeader.dataAlignmentIndicator = true
        optionalHeader.setTimestamp(presentationTimeStamp, decodeTimeStamp)
        let length = data.count + optionalHeader.encode().count
        if length < Int(UInt16.max) {
            packetLength = UInt16(length)
        }
        self.streamID = streamID
    }

    init(
        bytes: UnsafeMutablePointer<UInt8>,
        count: Int,
        presentationTimeStamp: CMTime,
        decodeTimeStamp: CMTime,
        config: MpegTsVideoConfigHevc?,
        streamID: UInt8
    ) {
        if let config {
            if let nal = config.array[.vps] {
                data += nalUnitStartCode
                data.append(nal[0])
            }
            if let nal = config.array[.sps] {
                data += nalUnitStartCode
                data.append(nal[0])
            }
            if let nal = config.array[.pps] {
                data += nalUnitStartCode
                data.append(nal[0])
            }
        }
        var payload = Data(bytesNoCopy: bytes, count: count, deallocator: .none)
        addNalUnitStartCodes(&payload)
        data.append(payload)
        optionalHeader.dataAlignmentIndicator = true
        optionalHeader.setTimestamp(presentationTimeStamp, decodeTimeStamp)
        let length = data.count + optionalHeader.encode().count
        if length < Int(UInt16.max) {
            packetLength = UInt16(length)
        }
        self.streamID = streamID
    }

    init(data: Data) throws {
        let reader = ByteArray(data: data)
        startCode = try reader.readBytes(3)
        if startCode != MpegTsPacketizedElementaryStream.startCode {
            throw "Bad PES start code"
        }
        streamID = try reader.readUInt8()
        packetLength = try reader.readUInt16()
        optionalHeader = try OptionalHeader(data: reader.readBytes(reader.bytesAvailable))
        reader.position = MpegTsPacketizedElementaryStream
            .untilPacketLengthSize + 3 + Int(optionalHeader.pesHeaderLength)
        self.data = try reader.readBytes(reader.bytesAvailable)
    }

    mutating func append(data: Data) {
        self.data.append(data)
    }

    func isComplete() -> Bool {
        if packetLength > 0 {
            return data.count == packetLength - 8
        }
        return false
    }

    private func encode() -> Data {
        ByteArray()
            .writeBytes(startCode)
            .writeUInt8(streamID)
            .writeUInt16(packetLength)
            .writeBytes(optionalHeader.encode())
            .writeBytes(data)
            .data
    }

    func arrayOfPackets(_ packetId: UInt16, _ programClockReference: UInt64?) -> [MpegTsPacket] {
        let payload = encode()
        var packets: [MpegTsPacket] = []
        // start
        var packet = MpegTsPacket(id: packetId)
        packet.payloadUnitStartIndicator = true
        packet.adaptationField = MpegTsAdaptationField()
        if let programClockReference {
            packet.adaptationField!.programClockReference = TSProgramClockReference.encode(
                programClockReference,
                0
            )
        }
        var payloadOffset = packet.setPayload(payload)
        packets.append(packet)
        // middle
        packet = MpegTsPacket(id: packetId)
        while payloadOffset <= payload.count - 184 {
            packet.payload = payload[payloadOffset ..< payloadOffset + 184]
            packets.append(packet)
            payloadOffset += 184
        }
        let rest = (payload.count - payloadOffset) % 184
        switch rest {
        case 0:
            break
        case 183:
            let remain = payload.subdata(in: payload.endIndex - rest ..< payload.endIndex - 1)
            var packet = MpegTsPacket(id: packetId)
            packet.adaptationField = MpegTsAdaptationField()
            _ = packet.setPayload(remain)
            packets.append(packet)
            packet = MpegTsPacket(id: packetId)
            packet.adaptationField = MpegTsAdaptationField()
            _ = packet.setPayload(Data([payload[payload.count - 1]]))
            packets.append(packet)
        default:
            let remain = payload.subdata(in: payload.count - rest ..< payload.count)
            var packet = MpegTsPacket(id: packetId)
            packet.adaptationField = MpegTsAdaptationField()
            _ = packet.setPayload(remain)
            packets.append(packet)
        }
        return packets
    }

    mutating func makeVideoSampleBuffer(
        _ basePresentationTimeStamp: CMTime,
        _ firstReceivedPresentationTimeStamp: CMTime?,
        _ previousReceivedPresentationTimeStamp: CMTime?,
        _ formatDescription: CMFormatDescription?
    ) -> (CMSampleBuffer, CMTime, CMTime)? {
        removeNalUnitStartCodes(&data)
        let blockBuffer = data.makeBlockBuffer()
        var sampleSizes = [blockBuffer?.dataLength ?? 0]
        return makeSampleBuffer(
            basePresentationTimeStamp,
            firstReceivedPresentationTimeStamp,
            previousReceivedPresentationTimeStamp,
            formatDescription,
            blockBuffer,
            &sampleSizes
        )
    }

    mutating func makeAudioSampleBuffer(
        _ basePresentationTimeStamp: CMTime,
        _ firstReceivedPresentationTimeStamp: CMTime?,
        _ previousReceivedPresentationTimeStamp: CMTime?,
        _ formatDescription: CMFormatDescription?
    ) -> (CMSampleBuffer, CMTime, CMTime)? {
        var sampleSizes: [Int] = []
        let blockBuffer = data.makeBlockBuffer(advancedBy: 7)
        let reader = ADTSReader()
        reader.read(data)
        var iterator = reader.makeIterator()
        while let next = iterator.next() {
            sampleSizes.append(next)
        }
        return makeSampleBuffer(
            basePresentationTimeStamp,
            firstReceivedPresentationTimeStamp,
            previousReceivedPresentationTimeStamp,
            formatDescription,
            blockBuffer,
            &sampleSizes
        )
    }

    private func makeSampleBuffer(
        _ basePresentationTimeStamp: CMTime,
        _ firstReceivedPresentationTimeStamp: CMTime?,
        _ previousReceivedPresentationTimeStamp: CMTime?,
        _ formatDescription: CMFormatDescription?,
        _ blockBuffer: CMBlockBuffer?,
        _ sampleSizes: inout [Int]
    ) -> (CMSampleBuffer, CMTime, CMTime)? {
        var sampleBuffer: CMSampleBuffer?
        let receivedPresentationTimeStamp = optionalHeader.getPresentationTimeStamp()
        let receivedDecodeTimeStamp = optionalHeader.getDecodeTimeStamp()
        var timing = CMSampleTimingInfo()
        var firstReceivedPresentationTimeStamp = firstReceivedPresentationTimeStamp
        if let firstReceivedPresentationTimeStamp {
            let basePresentationTimeStamp = basePresentationTimeStamp - firstReceivedPresentationTimeStamp
            timing.presentationTimeStamp = basePresentationTimeStamp + receivedPresentationTimeStamp
            timing.decodeTimeStamp = basePresentationTimeStamp + receivedDecodeTimeStamp
            if let previousReceivedPresentationTimeStamp {
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
        ) == noErr else {
            return nil
        }
        guard let sampleBuffer else {
            return nil
        }
        return (sampleBuffer, firstReceivedPresentationTimeStamp!, timing.presentationTimeStamp)
    }
}
