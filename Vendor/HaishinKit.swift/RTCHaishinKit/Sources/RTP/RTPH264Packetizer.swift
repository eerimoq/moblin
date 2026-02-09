import AVFAudio
import CoreMedia
import Foundation
import HaishinKit

private let RTPH264Packetizer_startCode = Data([0x00, 0x00, 0x00, 0x01])

/// https://datatracker.ietf.org/doc/html/rfc3984
final class RTPH264Packetizer<T: RTPPacketizerDelegate>: RTPPacketizer {
    let ssrc: UInt32
    let payloadType: UInt8
    weak var delegate: T?
    var formatParameter = RTPFormatParameter()
    private var sequenceNumber: UInt16 = 0
    private var buffer = Data()
    private var nalUnitReader = NALUnitReader()
    private var pictureParameterSets: Data?
    private var sequenceParameterSets: Data?
    private var formatDescription: CMFormatDescription?

    // for FragmentUnitA
    private var fragmentedBuffer = Data()
    private var fragmentedStarted = false
    private var fragmentedTimestamp: UInt32 = 0
    private var timestamp: RTPTimestamp = .init(90000)

    private lazy var jitterBuffer: RTPJitterBuffer<RTPH264Packetizer> = {
        let jitterBuffer = RTPJitterBuffer<RTPH264Packetizer>()
        jitterBuffer.delegate = self
        return jitterBuffer
    }()

    init(ssrc: UInt32, payloadType: UInt8) {
        self.ssrc = ssrc
        self.payloadType = payloadType
    }

    func append(_ packet: RTPPacket) {
        jitterBuffer.append(packet)
    }

    func append(_ buffer: CMSampleBuffer, lambda: (RTPPacket) -> Void) {
        let nals = nalUnitReader.read(buffer)
        for i in 0..<nals.count {
            let marker = i == nals.count - 1

            if nals[i].count <= 1200 {
                lambda(.init(
                    version: RTPPacket.version,
                    padding: false,
                    extension: false,
                    cc: 0,
                    marker: marker,
                    payloadType: payloadType,
                    sequenceNumber: sequenceNumber,
                    timestamp: timestamp.convert(buffer.presentationTimeStamp),
                    ssrc: ssrc,
                    payload: nals[i]
                ))
                sequenceNumber &+= 1
            } else {
                // split FragmentUnit A
                let nalHeader = nals[i][0]
                let fuIndicator = (nalHeader & 0xE0) | 28
                let nalType = nalHeader & 0x1F

                var offset = 1
                var first = true
                let length = nals[i].count

                while offset < length {
                    var fuHeader: UInt8 = nalType
                    let fragmentSize = min(1200 - 2, length - offset)
                    if first {
                        fuHeader |= 0x80
                    }
                    if length <= offset + fragmentSize {
                        fuHeader |= 0x40
                    }
                    var payload = Data()
                    payload.append(fuIndicator)
                    payload.append(fuHeader)
                    payload.append(nals[i][offset..<offset + fragmentSize])

                    lambda(RTPPacket(
                        version: RTPPacket.version,
                        padding: false,
                        extension: false,
                        cc: 0,
                        marker: marker && (length <= offset + fragmentSize),
                        payloadType: payloadType,
                        sequenceNumber: sequenceNumber,
                        timestamp: timestamp.convert(buffer.presentationTimeStamp),
                        ssrc: ssrc,
                        payload: payload
                    ))
                    sequenceNumber &+= 1

                    offset += fragmentSize
                    first = false
                }
            }
        }
    }

    func append(_ buffer: AVAudioCompressedBuffer, when: AVAudioTime, lambda: (RTPPacket) -> Void) {
    }

    private func decode(_ packet: RTPPacket) {
        guard !packet.payload.isEmpty else {
            return
        }
        let nalUnitType = packet.payload[0] & 0x1F
        switch nalUnitType {
        case 1...23:
            decodeSingleNALUnit(packet)
        case 24:
            decodeStapA(packet)
        case 28:
            decodeFragmentUnitA(packet)
        default:
            logger.warn("undefined nal unit type = ", nalUnitType)
        }
    }

    /// STAP-A (Single-Time Aggregation Packet)
    /// - SeeAlso: RFC 3984 section 5.7.1
    private func decodeStapA(_ packet: RTPPacket) {
        // payload[0] = STAP-A indicator (F | NRI | Type=24)
        // then: [NALU-size:16][NALU-data] repeating
        let payload = packet.payload
        guard payload.count >= 1 + 2 else {
            return
        }

        var offset = 1
        var nalUnits: [Data] = []
        nalUnits.reserveCapacity(4)

        while offset + 2 <= payload.count {
            let size = (UInt16(payload[offset]) << 8) | UInt16(payload[offset + 1])
            offset += 2
            guard size > 0 else {
                logger.warn("decodeStapA(_:) > invalid nalu size = 0")
                break
            }
            let end = offset + Int(size)
            guard end <= payload.count else {
                logger.warn("decodeStapA(_:) > bufferUnderrun")
                break
            }
            nalUnits.append(Data(payload[offset..<end]))
            offset = end
        }

        guard !nalUnits.isEmpty else {
            return
        }

        for i in 0..<nalUnits.count {
            let isLast = i == nalUnits.count - 1
            decodeSingleNALUnit(RTPPacket(
                version: packet.version,
                padding: packet.padding,
                extension: packet.`extension`,
                cc: packet.cc,
                marker: packet.marker && isLast,
                payloadType: packet.payloadType,
                sequenceNumber: packet.sequenceNumber,
                timestamp: packet.timestamp,
                ssrc: packet.ssrc,
                payload: nalUnits[i]
            ))
        }
    }

    private func decodeSingleNALUnit(_ packet: RTPPacket) {
        let nalUnitType = packet.payload[0] & 0x1F
        switch nalUnitType {
        case 5: // idr
            buffer.append(RTPH264Packetizer_startCode)
            buffer.append(packet.payload)
        case 7: // sps
            if sequenceParameterSets == nil {
                sequenceParameterSets = packet.payload
            }
        case 8: // pps
            if pictureParameterSets == nil {
                pictureParameterSets = packet.payload
            }
        default:
            buffer.append(RTPH264Packetizer_startCode)
            buffer.append(packet.payload)
        }
        if formatDescription == nil && sequenceParameterSets != nil && pictureParameterSets != nil {
            formatDescription = makeFormatDescription()
        }
        if packet.marker {
            if let sampleBuffer = makeSampleBuffer(&buffer, timestamp: packet.timestamp) {
                delegate?.packetizer(self, didOutput: sampleBuffer)
            }
            buffer.removeAll(keepingCapacity: false)
        }
    }

    private func decodeFragmentUnitA(_ packet: RTPPacket) {
        let indicator = packet.payload[0]
        // S | E | R | Type(original)
        let header = packet.payload[1]

        let start = (header & 0x80) != 0
        let end = (header & 0x40) != 0
        let h264NALUnitType = header & 0x1F

        if fragmentedTimestamp != packet.timestamp, fragmentedStarted {
            // fragmentedBuffer.removeAll(keepingCapacity: false)
            // fragmentedStarted = false
            fragmentedTimestamp = packet.timestamp
        }

        if start {
            fragmentedBuffer.removeAll(keepingCapacity: false)
            fragmentedBuffer.append(RTPH264Packetizer_startCode)
            fragmentedBuffer.append(indicator & 0x60 | indicator & 0x80 | h264NALUnitType)
            fragmentedBuffer.append(packet.payload[2...])
            fragmentedStarted = true
        } else if fragmentedStarted {
            fragmentedBuffer.append(packet.payload[2...])
        }

        if end && fragmentedStarted {
            if let buffer = makeSampleBuffer(&fragmentedBuffer, timestamp: fragmentedTimestamp) {
                delegate?.packetizer(self, didOutput: buffer)
            }
            // flush buffers
            fragmentedBuffer.removeAll(keepingCapacity: false)
            fragmentedStarted = false
        }
    }

    private func makeSampleBuffer(_ buffer: inout Data, timestamp: UInt32) -> CMSampleBuffer? {
        guard formatDescription != nil else {
            return nil
        }
        let presentationTimeStamp: CMTime = self.timestamp.convert(timestamp)
        let units = nalUnitReader.read(&buffer, type: H264NALUnit.self)
        var blockBuffer: CMBlockBuffer?
        ISOTypeBufferUtil.toNALFileFormat(&buffer)
        blockBuffer = buffer.makeBlockBuffer()
        var sampleSizes: [Int] = []
        var sampleBuffer: CMSampleBuffer?
        var timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: .invalid
        )
        sampleSizes.append(buffer.count)
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
                sampleBufferOut: &sampleBuffer) == noErr else {
            return nil
        }
        sampleBuffer?.isNotSync = !units.contains { $0.type == .idr }
        return sampleBuffer
    }

    private func makeFormatDescription() -> CMFormatDescription? {
        guard let pictureParameterSets, let sequenceParameterSets else {
            return nil
        }
        let pictureParameterSetArray = [pictureParameterSets.bytes]
        let sequenceParameterSetArray = [sequenceParameterSets.bytes]
        return pictureParameterSetArray[0].withUnsafeBytes { (ppsBuffer: UnsafeRawBufferPointer) -> CMFormatDescription? in
            guard let ppsBaseAddress = ppsBuffer.baseAddress else {
                return nil
            }
            return sequenceParameterSetArray[0].withUnsafeBytes { (spsBuffer: UnsafeRawBufferPointer) -> CMFormatDescription? in
                guard let spsBaseAddress = spsBuffer.baseAddress else {
                    return nil
                }
                let pointers: [UnsafePointer<UInt8>] = [
                    spsBaseAddress.assumingMemoryBound(to: UInt8.self),
                    ppsBaseAddress.assumingMemoryBound(to: UInt8.self)
                ]
                let sizes: [Int] = [spsBuffer.count, ppsBuffer.count]
                let nalUnitHeaderLength: Int32 = 4
                var formatDescriptionOut: CMFormatDescription?
                CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: kCFAllocatorDefault,
                    parameterSetCount: pointers.count,
                    parameterSetPointers: pointers,
                    parameterSetSizes: sizes,
                    nalUnitHeaderLength: nalUnitHeaderLength,
                    formatDescriptionOut: &formatDescriptionOut
                )
                return formatDescriptionOut
            }
        }
    }
}

extension RTPH264Packetizer: RTPJitterBufferDelegate {
    // MARK: RTPJitterBufferDelegate
    func jitterBuffer(_ buffer: RTPJitterBuffer<RTPH264Packetizer>, sequenced: RTPPacket) {
        decode(sequenced)
    }
}
