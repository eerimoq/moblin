import CrcSwift
import Foundation

private enum CatPrinterCommandId: UInt8 {
    case getVersion = 0xB1
    case foo = 0xA1
    case print = 0xA9
    case printComplete = 0xAA
}

enum CatPrinterCommandMxw01 {
    case getVersionRequest
    case getVersionResponse(value: String)
    case fooResponse(value: Data)
    case printRequest(count: UInt16)
    case printResponse(value: Data)
    case printCompleteIndication(value: Data)

    init?(data: Data) {
        do {
            let (command, data) = try Self.unpack(data: data)
            switch command {
            case .getVersion:
                self = .getVersionResponse(value: String(bytes: data, encoding: .utf8) ?? "unknown")
            case .foo:
                self = .fooResponse(value: data)
            case .print:
                self = .printResponse(value: data)
            case .printComplete:
                self = .printCompleteIndication(value: data)
            }
        } catch {
            logger.info("cat-printer: Unpack failed with \(error)")
            return nil
        }
    }

    func pack() -> Data {
        let command: CatPrinterCommandId
        let data: Data
        switch self {
        case .getVersionRequest:
            command = .getVersion
            data = Data([0x00])
        case let .printRequest(count: count):
            command = .print
            data = ByteArray()
                .writeUInt16Le(count)
                .writeUInt8(0x30)
                .writeUInt8(0)
                .data
        default:
            return Data()
        }
        return Self.packCommand(command, data)
    }

    private static func packCommand(_ command: CatPrinterCommandId, _ data: Data) -> Data {
        if data.count > 0xFFFF {
            logger.info("Command data too big (\(data.count) > 0xFFFF)")
            return Data()
        }
        return ByteArray()
            .writeUInt8(0x22)
            .writeUInt8(0x21)
            .writeUInt8(command.rawValue)
            .writeUInt8(0x00)
            .writeUInt16Le(UInt16(data.count))
            .writeBytes(data)
            .writeUInt8(CrcSwift.computeCrc8(data))
            .writeUInt8(0xFF)
            .data
    }

    private static func unpack(data: Data) throws -> (CatPrinterCommandId, Data) {
        let reader = ByteArray(data: data)
        guard try reader.readUInt8() == 0x22 else {
            throw "Wrong first byte"
        }
        guard try reader.readUInt8() == 0x21 else {
            throw "Wrong second byte"
        }
        guard let command = try CatPrinterCommandId(rawValue: reader.readUInt8()) else {
            throw "Unsupported command."
        }
        _ = try reader.readUInt8()
        let length = try reader.readUInt16Le()
        let data = try reader.readBytes(Int(length))
        return (command, data)
    }
}

func catPrinterEncodeImageRow(_ imageRow: [Bool]) -> Data {
    var data = Data(count: imageRow.count / 8)
    for byteIndex in 0 ..< data.count {
        var byte: UInt8 = 0
        for bitIndex in 0 ..< 8 where imageRow[8 * byteIndex + bitIndex] {
            byte |= (1 << bitIndex)
        }
        data[byteIndex] = byte
    }
    return data
}

// One bit per pixel, often 384 pixels wide.
func catPrinterPackPrintImageCommandsMxw01(image: [[Bool]]) -> Data {
    var data = Data()
    for imageRow in image {
        data.append(catPrinterEncodeImageRow(imageRow))
    }
    // Doesn't print if smaller. There is probably a better way than this.
    while data.count < 90 * 384 / 8 {
        data += Data([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        data += Data([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        data += Data([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        data += Data([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        data += Data([0, 0, 0, 0, 0, 0, 0, 0])
    }
    return data
}
