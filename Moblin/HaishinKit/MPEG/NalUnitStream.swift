import CoreMedia
import Foundation

let nalUnitStartCode = Data([0x00, 0x00, 0x00, 0x01])

// Should escape as well?
func addNalUnitStartCodes(_ data: inout Data) {
    var index = 0
    while index < data.count {
        let length = data.getFourBytesBe(offset: index)
        data.replaceSubrange(index ..< index + 4, with: nalUnitStartCode)
        index += Int(length) + 4
    }
}

// Should unescape as well? Why can length be 3 or 4 bytes? Correct?
func removeNalUnitStartCodes(_ data: inout Data) {
    var lastIndexOf = data.count - 1
    var index = lastIndexOf - 2
    while index >= 0 {
        guard data[index] <= 1 else {
            index -= 3
            continue
        }
        guard data[index + 2] == 1, data[index + 1] == 0, data[index] == 0 else {
            index -= 1
            continue
        }
        let startCodeLength = index - 1 >= 0 && data[index - 1] == 0 ? 4 : 3
        let length = lastIndexOf - index - 2
        guard length > 0 else {
            index -= 1
            continue
        }
        let startCodeIndex = index + 3 - startCodeLength
        data.replaceSubrange(
            startCodeIndex ..< startCodeIndex + startCodeLength,
            with: Int32(length).bigEndian.data[(4 - startCodeLength)...]
        )
        lastIndexOf = startCodeIndex - 1
        index = lastIndexOf
    }
}

protocol NalUnit {
    init(_ data: Data)
}

func readH264NalUnits(_ data: Data, _ filter: [AVCNALUnitType]) -> [AvcNalUnit] {
    return readNalUnits(data) { byte in
        filter.contains(AVCNALUnitType(rawValue: byte & 0x1F) ?? .unspec)
    }
}

func readH265NalUnits(_ data: Data, _ filter: [HevcNalUnitType]) -> [HevcNalUnit] {
    return readNalUnits(data) { byte in
        filter.contains(HevcNalUnitType(rawValue: (byte & 0x7E) >> 1) ?? .unspec)
    }
}

private func readNalUnits<T: NalUnit>(_ data: Data, _ filter: (UInt8) -> Bool) -> [T] {
    var units: [T] = []
    var lastIndexOf = data.count - 1
    var index = lastIndexOf - 2
    while index >= 0 {
        guard data[index] <= 1 else {
            index -= 3
            continue
        }
        guard data[index + 2] == 1, data[index + 1] == 0, data[index] == 0 else {
            index -= 1
            continue
        }
        let startCodeLength = index - 1 >= 0 && data[index - 1] == 0 ? 4 : 3
        let length = lastIndexOf - index - 2
        guard length > 0 else {
            index -= 1
            continue
        }
        let startCodeIndex = index + 3 - startCodeLength
        let nalUnitIndex = startCodeIndex + startCodeLength
        if filter(data[nalUnitIndex]) {
            units.append(T(data.subdata(in: nalUnitIndex ..< lastIndexOf + 1)))
        }
        lastIndexOf = startCodeIndex - 1
        index = lastIndexOf
    }
    return units
}
