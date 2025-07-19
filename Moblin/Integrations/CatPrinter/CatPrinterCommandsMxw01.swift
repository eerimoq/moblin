import CrcSwift
import Foundation

private enum CatPrinterCommandId: UInt8 {
    case getVersion = 0xB1
    case status = 0xA1
    case print = 0xA9
    case printComplete = 0xAA
}

enum CatPrinterPrintMode: UInt8 {
    case blackAndWhite = 0
    case grayscale = 2
}

enum CatPrinterCommandMxw01 {
    case getVersionRequest
    case getVersionResponse(value: String)
    case statusRequest
    case statusResponse(ok: Bool, tooHot: Bool, hasPaper: Bool)
    case printRequest(printMode: CatPrinterPrintMode, count: UInt16)
    case printResponse(status: UInt8)
    case printCompleteIndication(value: Data)

    init?(data: Data) {
        do {
            let (command, data) = try Self.unpack(data: data)
            switch command {
            case .getVersion:
                self = .getVersionResponse(value: String(bytes: data, encoding: .utf8) ?? "unknown")
            case .status:
                let reader = ByteReader(data: data)
                do {
                    _ = try reader.readBytes(6)
                    let ok = try reader.readUInt8()
                    let reasons = try reader.readUInt8()
                    self = .statusResponse(ok: ok == 0,
                                           tooHot: reasons.isBitSet(index: 2),
                                           hasPaper: !reasons.isBitSet(index: 0))
                } catch {
                    return nil
                }
            case .print:
                guard data.count > 0 else {
                    return nil
                }
                self = .printResponse(status: data[0])
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
        case .statusRequest:
            command = .status
            data = Data([0x00])
        case let .printRequest(printMode: printMode, count: count):
            command = .print
            let writer = ByteWriter()
            writer.writeUInt16Le(count)
            writer.writeUInt8(0x30)
            writer.writeUInt8(printMode.rawValue)
            data = writer.data
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
        let writer = ByteWriter()
        writer.writeUInt8(0x22)
        writer.writeUInt8(0x21)
        writer.writeUInt8(command.rawValue)
        writer.writeUInt8(0x00)
        writer.writeUInt16Le(UInt16(data.count))
        writer.writeBytes(data)
        writer.writeUInt8(CrcSwift.computeCrc8(data)) // Not used? Always zero?
        writer.writeUInt8(0xFF)
        return writer.data
    }

    private static func unpack(data: Data) throws -> (CatPrinterCommandId, Data) {
        let reader = ByteReader(data: data)
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

// One bit per pixel, often 384 pixels wide.
func catPrinterPackPrintImageCommandsMxw01(image: [[UInt8]], printMode: CatPrinterPrintMode) -> Data {
    var data = Data()
    for imageRow in image {
        data.append(catPrinterEncodeImageRow(imageRow, printMode))
    }
    // Doesn't print if smaller. There is probably a better way to do this.
    while data.count < 90 * catPrinterWidthPixels / 8 {
        data += Data([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        data += Data([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        data += Data([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        data += Data([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        data += Data([0, 0, 0, 0, 0, 0, 0, 0])
    }
    return data
}
