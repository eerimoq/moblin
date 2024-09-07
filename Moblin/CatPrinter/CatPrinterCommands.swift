// Based on https://github.com/rbaron/catprinter
// MIT License

import CrcSwift
import Foundation

enum CatPrinterCommand: UInt8 {
    case setPaper = 0xA1
    case drawRow = 0xA2
    case getDeviceState = 0xA3
    case setQuality = 0xA4
    case lattice = 0xA6
    case setEnergy = 0xAF
    case feedPaper = 0xBD
    case setDrawMode = 0xBE
}

private enum DrawMode: UInt8 {
    case image = 0
    case text = 1
}

private func packCommand(_ command: CatPrinterCommand, _ data: Data) -> Data {
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

private func packGetDeviceState() -> Data {
    return packCommand(.getDeviceState, Data([0x00]))
}

private func packLatticeStart() -> Data {
    return packCommand(.lattice, Data([
        0xAA, 0x55, 0x17, 0x38, 0x44, 0x5F, 0x5F, 0x5F, 0x44, 0x38, 0x2C,
    ]))
}

private func packLatticeEnd() -> Data {
    return packCommand(.lattice, Data([
        0xAA, 0x55, 0x17, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x17,
    ]))
}

private func packSetPaper() -> Data {
    return packCommand(.setPaper, Data([0x30, 0x00]))
}

private func packSetQuality(_ value: UInt8) -> Data {
    return packCommand(.setQuality, Data([value]))
}

private func packSetEnergy(_ value: UInt16) -> Data {
    return packCommand(.setEnergy, ByteArray().writeUInt16Le(value).data)
}

private func packFeedPaper(_ value: UInt8) -> Data {
    return packCommand(.feedPaper, Data([value]))
}

private func packSetDrawMode(_ value: DrawMode) -> Data {
    return packCommand(.setDrawMode, Data([value.rawValue]))
}

private func encodeImageRow(_ imageRow: [Bool]) -> Data {
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

private func packDrawRow(_ imageRow: [Bool]) -> Data {
    return packCommand(.drawRow, encodeImageRow(imageRow))
}

// One bit per pixel, often 384 pixels wide.
func packPrintImageCommands(image: [[Bool]]) -> Data {
    var data = packGetDeviceState()
    data += packSetQuality(0x33)
    data += packLatticeStart()
    data += packSetEnergy(0x3000)
    data += packSetDrawMode(.image)
    for imageRow in image {
        data += packDrawRow(imageRow)
    }
    data += packFeedPaper(25)
    data += packSetPaper()
    data += packLatticeEnd()
    data += packGetDeviceState()
    return data
}
