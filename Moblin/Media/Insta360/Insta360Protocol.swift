import Foundation

enum Insta360ProtocolError: Error {
    case invalidPacketLength
    case invalidVideoPacket
    case invalidNalUnit
    case videoBufferTooLarge
}

enum Insta360Packet: Equatable {
    case sync
    case keepAlive
    case response(code: UInt16, sequence: UInt32)
    case video(Data)
    case unknown
}

struct Insta360Protocol {
    static let syncPayload = Data([6, 0, 0]) + Data("syNceNdinS".utf8)
    private var buffer = Data()

    static func frame(_ payload: Data) -> Data {
        var length = UInt32(payload.count + 4).littleEndian
        return withUnsafeBytes(of: &length) { Data($0) } + payload
    }

    static func command(id: UInt16, sequence: UInt32) -> Data {
        frame(Data([
            4, 0, 0,
            UInt8(truncatingIfNeeded: id), UInt8(truncatingIfNeeded: id >> 8), 2,
            UInt8(truncatingIfNeeded: sequence), UInt8(truncatingIfNeeded: sequence >> 8),
            UInt8(truncatingIfNeeded: sequence >> 16), 0x80, 0, 0,
        ]))
    }

    mutating func append(_ data: Data) throws -> [Insta360Packet] {
        buffer.append(data)
        var offset = 0
        var packets: [Insta360Packet] = []
        while buffer.count - offset >= 4 {
            let length = Int(UInt32(buffer[offset]) | UInt32(buffer[offset + 1]) << 8
                | UInt32(buffer[offset + 2]) << 16 | UInt32(buffer[offset + 3]) << 24)
            guard (7 ... 16 * 1024 * 1024).contains(length) else {
                throw Insta360ProtocolError.invalidPacketLength
            }
            guard buffer.count - offset >= length else {
                break
            }
            try packets.append(Self.parse(Data(buffer[(offset + 4) ..< (offset + length)])))
            offset += length
        }
        if offset > 0 {
            buffer = Data(buffer.dropFirst(offset))
        }
        return packets
    }

    private static func parse(_ payload: Data) throws -> Insta360Packet {
        if payload == syncPayload {
            return .sync
        }
        switch Array(payload.prefix(3)) {
        case [5, 0, 0]:
            return .keepAlive
        case [4, 0, 0] where payload.count >= 12:
            return .response(code: UInt16(payload[3]) | UInt16(payload[4]) << 8,
                             sequence: UInt32(payload[6]) | UInt32(payload[7]) << 8
                                 | UInt32(payload[8]) << 16)
        case [1, 0, 0]:
            guard payload.count > 12 else {
                throw Insta360ProtocolError.invalidVideoPacket
            }
            return .video(Data(payload.dropFirst(12)))
        default:
            return .unknown
        }
    }
}

struct Insta360HevcFrame: Equatable {
    let nalUnits: [Data]

    var isKeyframe: Bool {
        nalUnits.contains { (16 ... 21).contains(($0[0] >> 1) & 0x3F) }
    }

    func lengthPrefixedData() -> Data {
        var data = Data()
        for nalUnit in nalUnits {
            var length = UInt32(nalUnit.count).bigEndian
            data.append(withUnsafeBytes(of: &length) { Data($0) })
            data.append(nalUnit)
        }
        return data
    }
}

struct Insta360HevcStream {
    private var buffer = Data()
    private var searchOffset = 0
    private var nalStart: Int?
    private var frame: [Data] = []
    private var frameSize = 0
    private var hasPicture = false

    mutating func append(_ data: Data) throws -> [Insta360HevcFrame] {
        buffer.append(data)
        var frames: [Insta360HevcFrame] = []
        while let startCode = findStartCode(from: searchOffset) {
            if let nalStart, startCode.offset > nalStart {
                try appendNalUnit(Data(buffer[nalStart ..< startCode.offset]), frames: &frames)
            }
            nalStart = startCode.offset + startCode.length
            searchOffset = nalStart!
        }
        if let nalStart {
            buffer = Data(buffer.dropFirst(nalStart))
            self.nalStart = 0
        }
        searchOffset = max(0, buffer.count - 3)
        guard buffer.count + frameSize <= 16 * 1024 * 1024 else {
            throw Insta360ProtocolError.videoBufferTooLarge
        }
        return frames
    }

    mutating func finish() throws -> [Insta360HevcFrame] {
        var frames: [Insta360HevcFrame] = []
        if let nalStart, buffer.count > nalStart {
            try appendNalUnit(Data(buffer.dropFirst(nalStart)), frames: &frames)
        }
        flushFrame(into: &frames)
        self = .init()
        return frames
    }

    private func findStartCode(from offset: Int) -> (offset: Int, length: Int)? {
        var index = offset
        while index + 2 < buffer.count {
            if buffer[index] == 0, buffer[index + 1] == 0 {
                if buffer[index + 2] == 1 {
                    return (index, 3)
                }
                if index + 3 < buffer.count, buffer[index + 2] == 0, buffer[index + 3] == 1 {
                    return (index, 4)
                }
            }
            index += 1
        }
        return nil
    }

    private mutating func appendNalUnit(_ data: Data, frames: inout [Insta360HevcFrame]) throws {
        var nalUnit = data
        while nalUnit.last == 0 {
            nalUnit.removeLast()
        }
        guard nalUnit.count >= 2, nalUnit[0] & 0x80 == 0, nalUnit[1] & 7 != 0 else {
            throw Insta360ProtocolError.invalidNalUnit
        }
        let type = (nalUnit[0] >> 1) & 0x3F
        if type <= 31 {
            guard nalUnit.count >= 3 else {
                throw Insta360ProtocolError.invalidNalUnit
            }
            if nalUnit[2] & 0x80 != 0, hasPicture {
                flushFrame(into: &frames)
            }
            hasPicture = true
        } else if [32, 33, 34, 35, 39].contains(type), hasPicture {
            flushFrame(into: &frames)
        }
        frame.append(nalUnit)
        frameSize += nalUnit.count
        guard frameSize <= 16 * 1024 * 1024 else {
            throw Insta360ProtocolError.videoBufferTooLarge
        }
    }

    private mutating func flushFrame(into frames: inout [Insta360HevcFrame]) {
        if hasPicture {
            frames.append(Insta360HevcFrame(nalUnits: frame))
        }
        frame = []
        frameSize = 0
        hasPicture = false
    }
}
