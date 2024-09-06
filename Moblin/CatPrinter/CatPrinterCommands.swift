// Based on https://github.com/rbaron/catprinter
// MIT License

import CrcSwift
import Foundation

private func packCommand(command: UInt8, data: Data) -> Data {
    if data.count > 0xFF {
        logger.info("Command data too big (\(data.count) > 255)")
        return Data()
    }
    let header = [0x51, 0x78, command, 0x00, UInt8(data.count), 0x00]
    let footer = [CrcSwift.computeCrc8(data), 0xFF]
    return Data(header + data + footer)
}

private func packGetDeviceState() -> Data {
    return packCommand(command: 0xA3, data: Data([0x00]))
}

private func packLatticeStart() -> Data {
    return packCommand(command: 0xA6, data: Data([
        0xAA, 0x55, 0x17, 0x38, 0x44, 0x5F, 0x5F, 0x5F, 0x44, 0x38, 0x2C,
    ]))
}

private func packLatticeEnd() -> Data {
    return packCommand(command: 0xA6, data: Data([
        0xAA, 0x55, 0x17, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x17,
    ]))
}

private func packSetPaper() -> Data {
    return packCommand(command: 0xA1, data: Data([0x30, 0x00]))
}

private func packSetQuality(_ value: UInt8) -> Data {
    return packCommand(command: 0xA4, data: Data([value]))
}

private func packSetEnergy(_ value: UInt16) -> Data {
    return packCommand(command: 0xAF, data: Data([UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]))
}

private func packFeedPaper(_ value: UInt8) -> Data {
    return packCommand(command: 0xBD, data: Data([value]))
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
    return packCommand(command: 0xA2, data: encodeImageRow(imageRow))
}

// One bit per pixel, often 384 pixels wide.
func packPrintImageCommands(image: [[Bool]]) -> Data {
    var data = packGetDeviceState()
    data += packSetQuality(0x32) // Test 0x33 amd 0x35 as well.
    data += packLatticeStart()
    data += packSetEnergy(0x3000)
    for imageRow in image {
        data += packDrawRow(imageRow)
    }
    data += packFeedPaper(25)
    data += packSetPaper()
    data += packLatticeEnd()
    data += packGetDeviceState()
    return data
}
