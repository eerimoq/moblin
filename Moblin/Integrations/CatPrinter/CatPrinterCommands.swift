// Based on https://github.com/rbaron/catprinter
// MIT License

import CrcSwift
import Foundation

let catPrinterFeedPaperPixels: UInt16 = 50

private enum CatPrinterCommandId: UInt8 {
    case feedPaper = 0xA1
    case drawRow = 0xA2
    case getDeviceState = 0xA3
    case setQuality = 0xA4
    case lattice = 0xA6
    case writePacing = 0xAE
    case setEnergy = 0xAF
    case setDrawMode = 0xBE
}

// periphery:ignore
struct CatPrinterDeviceState {
    let noPaper: Bool
    let coverIsOpen: Bool
    let isOverheated: Bool
    let batteryIsLow: Bool
}

enum CatPrinterDrawMode: UInt8 {
    case image = 0
    case text = 1
}

enum CatPrinterCommand {
    case getDeviceState(state: CatPrinterDeviceState? = nil)
    case writePacing(ready: Bool)
    case setQuality(level: UInt8)
    case setEnergy(energy: UInt16)
    case feedPaper(pixels: UInt16)
    case setDrawMode(mode: CatPrinterDrawMode)
    case drawRow(imageRow: [Bool])
    case lattice(data: Data)

    static let latticeStartData = Data([
        0xAA, 0x55, 0x17, 0x38, 0x44, 0x5F, 0x5F, 0x5F, 0x44, 0x38, 0x2C,
    ])

    static let latticeEndData = Data([
        0xAA, 0x55, 0x17, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x17,
    ])

    init?(data: Data) {
        do {
            let (command, data) = try Self.unpack(data: data)
            switch command {
            case .getDeviceState:
                guard data.count >= 1 else {
                    return nil
                }
                let data = data[0]
                self = .getDeviceState(state: CatPrinterDeviceState(
                    noPaper: data.isBitSet(index: 0),
                    coverIsOpen: data.isBitSet(index: 1),
                    isOverheated: data.isBitSet(index: 2),
                    batteryIsLow: data.isBitSet(index: 3)
                ))
            case .writePacing:
                guard data.count == 1 else {
                    return nil
                }
                self = .writePacing(ready: data[0] == 0x00)
            default:
                return nil
            }
        } catch {
            return nil
        }
    }

    func pack() -> Data {
        let command: CatPrinterCommandId
        let data: Data
        switch self {
        case .getDeviceState:
            command = .getDeviceState
            data = Data([0x00])
        case .writePacing:
            command = .writePacing
            data = Data([0x00])
        case let .setQuality(level):
            command = .setQuality
            data = Data([level])
        case let .setEnergy(energy):
            command = .setEnergy
            data = ByteArray().writeUInt16Le(energy).data
        case let .feedPaper(pixels):
            command = .feedPaper
            data = ByteArray().writeUInt16Le(pixels).data
        case let .setDrawMode(mode):
            command = .setDrawMode
            data = Data([mode.rawValue])
        case let .drawRow(imageRow):
            command = .drawRow
            data = catPrinterEncodeImageRow(imageRow)
        case let .lattice(latticeData):
            command = .lattice
            data = latticeData
        }
        return Self.packCommand(command, data)
    }

    private static func packCommand(_ command: CatPrinterCommandId, _ data: Data) -> Data {
        if data.count > 0xFFFF {
            logger.info("Command data too big (\(data.count) > 0xFFFF)")
            return Data()
        }
        return ByteArray()
            .writeUInt8(0x51)
            .writeUInt8(0x78)
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
        guard try reader.readUInt8() == 0x51 else {
            throw "Wrong first byte"
        }
        guard try reader.readUInt8() == 0x78 else {
            throw "Wrong second byte"
        }
        guard let command = try CatPrinterCommandId(rawValue: reader.readUInt8()) else {
            throw "Unsupported command."
        }
        _ = try reader.readUInt8()
        let length = try reader.readUInt16Le()
        let data = try reader.readBytes(Int(length))
        let crc = try reader.readUInt8()
        guard CrcSwift.computeCrc8(data) == crc else {
            throw "Wrong crc"
        }
        guard try reader.readUInt8() == 0xFF else {
            throw "Wrong last byte"
        }
        return (command, data)
    }
}

// One bit per pixel, often 384 pixels wide.
func catPrinterPackPrintImageCommands(image: [[Bool]], feedPaper: Bool) -> Data {
    var commands: [CatPrinterCommand] = [
        .setQuality(level: 0x35),
        .lattice(data: CatPrinterCommand.latticeStartData),
        .setEnergy(energy: 0x7000),
        .setDrawMode(mode: .image),
    ]
    for imageRow in image {
        commands.append(.drawRow(imageRow: imageRow))
    }
    if feedPaper {
        commands.append(.feedPaper(pixels: catPrinterFeedPaperPixels))
    }
    commands.append(.lattice(data: CatPrinterCommand.latticeEndData))
    return Data(commands.map { $0.pack() }.joined())
}
