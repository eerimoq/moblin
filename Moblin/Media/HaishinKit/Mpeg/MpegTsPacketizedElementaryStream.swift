import AVFoundation
import CoreMedia

/**
 - seealso: https://en.wikipedia.org/wiki/Packetized_elementary_stream
 */

struct OptionalHeader {
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
        let reader = ByteReader(data: data)
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
        let writer = ByteWriter()
        writer.writeBytes(bytes)
        writer.writeUInt8(pesHeaderLength)
        writer.writeBytes(optionalFields)
        writer.writeBytes(stuffingBytes)
        return writer.data
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
    private static let untilPacketLengthSize: Int = 6
    private static let startCode = Data([0x00, 0x00, 0x01])
    private let streamId: UInt8
    private let packetLength: UInt16
    var optionalHeader = OptionalHeader()
    var data = Data()

    init(streamId: UInt8, presentationTimeStamp: CMTime, decodeTimeStamp: CMTime, data: Data) {
        self.data = data
        optionalHeader.dataAlignmentIndicator = true
        optionalHeader.setTimestamp(presentationTimeStamp, decodeTimeStamp)
        let length = self.data.count + optionalHeader.encode().count
        if length < Int(UInt16.max) {
            packetLength = UInt16(length)
        } else {
            packetLength = 0
        }
        self.streamId = streamId
    }

    init(data: Data) throws {
        let reader = ByteReader(data: data)
        if try reader.readBytes(3) != MpegTsPacketizedElementaryStream.startCode {
            throw "Bad PES start code"
        }
        streamId = try reader.readUInt8()
        packetLength = try reader.readUInt16()
        optionalHeader = try OptionalHeader(data: reader.readBytes(reader.bytesAvailable))
        reader.position = MpegTsPacketizedElementaryStream
            .untilPacketLengthSize + 3 + Int(optionalHeader.pesHeaderLength)
        self.data = try reader.readBytes(reader.bytesAvailable)
    }

    mutating func append(data: Data) {
        self.data.append(data)
    }

    private func encode() -> Data {
        let writer = ByteWriter()
        writer.writeBytes(MpegTsPacketizedElementaryStream.startCode)
        writer.writeUInt8(streamId)
        writer.writeUInt16(packetLength)
        writer.writeBytes(optionalHeader.encode())
        writer.writeBytes(data)
        return writer.data
    }

    func arrayOfPackets(_ packetId: UInt16,
                        _ randomAccessIndicator: Bool,
                        _ programClockReference: UInt64?) -> [MpegTsPacket]
    {
        let payload = encode()
        var packets: [MpegTsPacket] = []
        var payloadOffset = 0
        appendFirstPacket(packetId, randomAccessIndicator, programClockReference, &packets, &payloadOffset, payload)
        appendMiddlePackets(packetId, &packets, &payloadOffset, payload)
        appendLastPackets(packetId, &packets, &payloadOffset, payload)
        return packets
    }

    private func appendFirstPacket(_ packetId: UInt16,
                                   _ randomAccessIndicator: Bool,
                                   _ programClockReference: UInt64?,
                                   _ packets: inout [MpegTsPacket],
                                   _ payloadOffset: inout Int,
                                   _ payload: Data)
    {
        var packet = MpegTsPacket(id: packetId)
        packet.payloadUnitStartIndicator = true
        var adaptationField = MpegTsAdaptationField()
        adaptationField.randomAccessIndicator = randomAccessIndicator
        if let programClockReference {
            adaptationField.programClockReference = TSProgramClockReference.encode(programClockReference, 0)
        }
        packet.adaptationField = adaptationField
        payloadOffset = min(packet.maximumPayloadSize(), payload.count)
        packet.payload = payload[0 ..< payloadOffset]
        if payloadOffset > payload.count {
            packet.setAdaptionFieldStuffing(size: payloadOffset - payload.count)
        }
        packets.append(packet)
    }

    private func appendMiddlePackets(_ packetId: UInt16,
                                     _ packets: inout [MpegTsPacket],
                                     _ payloadOffset: inout Int,
                                     _ payload: Data)
    {
        var packet = MpegTsPacket(id: packetId)
        while payloadOffset <= payload.count - 184 {
            packet.payload = payload[payloadOffset ..< payloadOffset + 184]
            packets.append(packet)
            payloadOffset += 184
        }
    }

    private func appendLastPackets(_ packetId: UInt16,
                                   _ packets: inout [MpegTsPacket],
                                   _ payloadOffset: inout Int,
                                   _ payload: Data)
    {
        let rest = (payload.count - payloadOffset) % 184
        switch rest {
        case 0:
            break
        case 183:
            var packet = MpegTsPacket(id: packetId)
            packet.adaptationField = MpegTsAdaptationField()
            packet.payload = payload[payloadOffset ..< payloadOffset + 182]
            payloadOffset += 182
            packets.append(packet)
            packet = MpegTsPacket(id: packetId)
            packet.adaptationField = MpegTsAdaptationField()
            packet.payload = payload[payloadOffset ..< payload.count]
            packet.setAdaptionFieldStuffing(size: 182 - packet.payload.count)
            packets.append(packet)
        default:
            var packet = MpegTsPacket(id: packetId)
            packet.adaptationField = MpegTsAdaptationField()
            packet.payload = payload[payloadOffset ..< payload.count]
            packet.setAdaptionFieldStuffing(size: 182 - packet.payload.count)
            packets.append(packet)
        }
    }
}
