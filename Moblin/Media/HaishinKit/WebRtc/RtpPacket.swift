import Foundation

struct RtpHeader {
    var version: UInt8 = 2
    var padding: Bool = false
    var extensionFlag: Bool = false
    var csrcCount: UInt8 = 0
    var marker: Bool = false
    var payloadType: UInt8
    var sequenceNumber: UInt16
    var timestamp: UInt32
    var ssrc: UInt32

    func encode() -> Data {
        var data = Data(count: 12)
        data[0] = (version << 6) | (padding ? 0x20 : 0) | (extensionFlag ? 0x10 : 0) | csrcCount
        data[1] = (marker ? 0x80 : 0) | payloadType
        data[2] = UInt8(sequenceNumber >> 8)
        data[3] = UInt8(sequenceNumber & 0xFF)
        data[4] = UInt8(timestamp >> 24)
        data[5] = UInt8((timestamp >> 16) & 0xFF)
        data[6] = UInt8((timestamp >> 8) & 0xFF)
        data[7] = UInt8(timestamp & 0xFF)
        data[8] = UInt8(ssrc >> 24)
        data[9] = UInt8((ssrc >> 16) & 0xFF)
        data[10] = UInt8((ssrc >> 8) & 0xFF)
        data[11] = UInt8(ssrc & 0xFF)
        return data
    }

    static func decode(from data: Data) -> RtpHeader? {
        guard data.count >= 12 else {
            return nil
        }
        let version = data[0] >> 6
        guard version == 2 else {
            return nil
        }
        return RtpHeader(
            version: version,
            padding: data[0] & 0x20 != 0,
            extensionFlag: data[0] & 0x10 != 0,
            csrcCount: data[0] & 0x0F,
            marker: data[1] & 0x80 != 0,
            payloadType: data[1] & 0x7F,
            sequenceNumber: UInt16(data[2]) << 8 | UInt16(data[3]),
            timestamp: UInt32(data[4]) << 24 | UInt32(data[5]) << 16 |
                UInt32(data[6]) << 8 | UInt32(data[7]),
            ssrc: UInt32(data[8]) << 24 | UInt32(data[9]) << 16 |
                UInt32(data[10]) << 8 | UInt32(data[11])
        )
    }
}

class RtpSequencer {
    private var sequenceNumber: UInt16
    private var timestamp: UInt32 = 0
    let ssrc: UInt32
    let payloadType: UInt8
    let clockRate: UInt32

    init(payloadType: UInt8, clockRate: UInt32, ssrc: UInt32? = nil) {
        self.payloadType = payloadType
        self.clockRate = clockRate
        self.ssrc = ssrc ?? UInt32.random(in: 0 ... UInt32.max)
        sequenceNumber = UInt16.random(in: 0 ... UInt16.max)
    }

    func nextSequenceNumber() -> UInt16 {
        let current = sequenceNumber
        sequenceNumber &+= 1
        return current
    }

    func makeHeader(marker: Bool) -> RtpHeader {
        return RtpHeader(
            payloadType: payloadType,
            sequenceNumber: nextSequenceNumber(),
            timestamp: timestamp,
            ssrc: ssrc
        )
    }

    func setTimestamp(_ value: UInt32) {
        timestamp = value
    }

    func advanceTimestamp(samples: UInt32) {
        timestamp &+= samples
    }
}

func rtpPacketize(header: RtpHeader, payload: Data) -> Data {
    var packet = header.encode()
    packet.append(payload)
    return packet
}
