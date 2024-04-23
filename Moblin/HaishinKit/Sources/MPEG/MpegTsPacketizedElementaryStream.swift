import AVFoundation
import CoreMedia

/**
 - seealso: https://en.wikipedia.org/wiki/Packetized_elementary_stream
 */

private struct OptionalHeader {
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

    mutating func setTimestamp(_ timestamp: CMTime, presentationTimeStamp: CMTime, decodeTimeStamp: CMTime) {
        let base = Double(timestamp.seconds)
        if presentationTimeStamp != CMTime.invalid {
            ptsDtsIndicator |= 0x02
        }
        if decodeTimeStamp != CMTime.invalid {
            ptsDtsIndicator |= 0x01
        }
        if (ptsDtsIndicator & 0x02) == 0x02 {
            let pts = Int64((presentationTimeStamp.seconds - base) * Double(TSTimestamp.resolution))
            optionalFields += TSTimestamp.encode(pts, ptsDtsIndicator << 4)
        }
        if (ptsDtsIndicator & 0x01) == 0x01 {
            let dts = Int64((decodeTimeStamp.seconds - base) * Double(TSTimestamp.resolution))
            optionalFields += TSTimestamp.encode(dts, 0x01 << 4)
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
}

struct MpegTsPacketizedElementaryStream {
    static let startCode = Data([0x00, 0x00, 0x01])
    private var startCode = MpegTsPacketizedElementaryStream.startCode
    private var streamID: UInt8 = 0
    private var packetLength: UInt16 = 0
    private var optionalHeader = OptionalHeader()
    private var data = Data()

    init?(
        bytes: UnsafePointer<UInt8>,
        count: UInt32,
        presentationTimeStamp: CMTime,
        timestamp: CMTime,
        config: AudioSpecificConfig,
        streamID: UInt8
    ) {
        data.append(contentsOf: config.makeHeader(Int(count)))
        data.append(bytes, count: Int(count))
        optionalHeader.dataAlignmentIndicator = true
        optionalHeader.setTimestamp(
            timestamp,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: CMTime.invalid
        )
        let length = data.count + optionalHeader.encode().count
        if length < Int(UInt16.max) {
            packetLength = UInt16(length)
        } else {
            return nil
        }
        self.streamID = streamID
    }

    init(
        bytes: UnsafePointer<UInt8>,
        count: Int,
        presentationTimeStamp: CMTime,
        decodeTimeStamp: CMTime,
        timestamp: CMTime,
        config: AVCDecoderConfigurationRecord?,
        streamID: UInt8
    ) {
        if let config {
            // 3 NAL units. SEI(9), SPS(7) and PPS(8)
            data.append(contentsOf: [0x00, 0x00, 0x00, 0x01, 0x09, 0x10])
            data.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
            data.append(contentsOf: config.sequenceParameterSets[0])
            data.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
            data.append(contentsOf: config.pictureParameterSets[0])
        } else {
            data.append(contentsOf: [0x00, 0x00, 0x00, 0x01, 0x09, 0x30])
        }
        if let stream = AVCFormatStream(bytes: bytes, count: count) {
            data.append(stream.toByteStream())
        }
        optionalHeader.dataAlignmentIndicator = true
        optionalHeader.setTimestamp(
            timestamp,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: decodeTimeStamp
        )
        let length = data.count + optionalHeader.encode().count
        if length < Int(UInt16.max) {
            packetLength = UInt16(length)
        }
        self.streamID = streamID
    }

    init(
        bytes: UnsafePointer<UInt8>,
        count: Int,
        presentationTimeStamp: CMTime,
        decodeTimeStamp: CMTime,
        timestamp: CMTime,
        config: HEVCDecoderConfigurationRecord?,
        streamID: UInt8
    ) {
        if let config {
            if let nal = config.array[.vps] {
                data.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
                data.append(nal[0])
            }
            if let nal = config.array[.sps] {
                data.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
                data.append(nal[0])
            }
            if let nal = config.array[.pps] {
                data.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
                data.append(nal[0])
            }
        }
        if let stream = AVCFormatStream(bytes: bytes, count: count) {
            data.append(stream.toByteStream())
        }
        optionalHeader.dataAlignmentIndicator = true
        optionalHeader.setTimestamp(
            timestamp,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: decodeTimeStamp
        )
        let length = data.count + optionalHeader.encode().count
        if length < Int(UInt16.max) {
            packetLength = UInt16(length)
        }
        self.streamID = streamID
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

    func arrayOfPackets(_ PID: UInt16, PCR: UInt64?) -> [MpegTsPacket] {
        let payload = encode()
        var packets: [MpegTsPacket] = []
        // start
        var packet = MpegTsPacket(pid: PID)
        packet.payloadUnitStartIndicator = true
        packet.adaptationField = MpegTsAdaptationField()
        if let PCR {
            packet.adaptationField!.pcr = TSProgramClockReference.encode(PCR, 0)
        }
        var payloadOffset = packet.setPayload(payload)
        packets.append(packet)
        // middle
        packet = MpegTsPacket(pid: PID)
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
            var packet = MpegTsPacket(pid: PID)
            packet.adaptationField = MpegTsAdaptationField()
            _ = packet.setPayload(remain)
            packets.append(packet)
            packet = MpegTsPacket(pid: PID)
            packet.adaptationField = MpegTsAdaptationField()
            _ = packet.setPayload(Data([payload[payload.count - 1]]))
            packets.append(packet)
        default:
            let remain = payload.subdata(in: payload.count - rest ..< payload.count)
            var packet = MpegTsPacket(pid: PID)
            packet.adaptationField = MpegTsAdaptationField()
            _ = packet.setPayload(remain)
            packets.append(packet)
        }
        return packets
    }
}
