import CoreMedia

let nalUnitStartCode = Data([0x00, 0x00, 0x00, 0x01])

struct NalUnitInfo {
    let startCodeOffset: Int
    let startCodeLength: Int
    let dataLength: Int

    func dataOffset() -> Int {
        return startCodeOffset + startCodeLength
    }
}

func getNalUnits(data: Data) -> [NalUnitInfo] {
    var nalUnits: [NalUnitInfo] = []
    parseNalUnits(data) { startCodeIndex, startCodeLength, dataLength in
        nalUnits.append(NalUnitInfo(startCodeOffset: startCodeIndex,
                                    startCodeLength: startCodeLength,
                                    dataLength: dataLength))
    }
    return nalUnits
}

// Should escape as well?
func addNalUnitStartCodes(_ data: inout Data) {
    var index = 0
    while index < data.count {
        let length = data.getFourBytesBe(offset: index)
        data.replaceSubrange(index ..< index + 4, with: nalUnitStartCode)
        index += Int(length) + 4
    }
}

// Should unescape as well?
func removeNalUnitStartCodes(_ data: inout Data, _ nalUnits: [NalUnitInfo]) {
    var numberOfThreeBytesStartCodes = nalUnits.count(where: { $0.startCodeLength != 4 })
    if numberOfThreeBytesStartCodes == 0 {
        for nalUnit in nalUnits {
            data.replaceSubrange(nalUnit.startCodeOffset ..< nalUnit.startCodeOffset + 4,
                                 with: Int32(nalUnit.dataLength).bigEndian.data)
        }
    } else {
        data += Data(count: numberOfThreeBytesStartCodes)
        var endOffset = data.count
        for nalUnit in nalUnits {
            let dataOffset = nalUnit.dataOffset()
            if numberOfThreeBytesStartCodes > 0 {
                // Require iOS 18 and later for now.
                if #available(iOS 18, *) {
                    data.moveSubranges(.init(dataOffset ..< dataOffset + nalUnit.dataLength), to: endOffset)
                }
            }
            endOffset -= nalUnit.dataLength
            data.replaceSubrange(endOffset - 4 ..< endOffset, with: Int32(nalUnit.dataLength).bigEndian.data)
            endOffset -= 4
            if nalUnit.startCodeLength != 4 {
                numberOfThreeBytesStartCodes -= 1
            }
        }
    }
}

protocol NalUnit {
    init?(data: Data, offset: Int)
}

func readH264NalUnits(data: Data, nalUnits: [NalUnitInfo], filter: [AvcNalUnitType]) -> [AvcNalUnit] {
    return readNalUnits(data, nalUnits) { byte in
        filter.contains(AvcNalUnitType(rawValue: byte & 0x1F) ?? .unspec)
    }
}

func readH265NalUnits(data: Data, nalUnits: [NalUnitInfo], filter: [HevcNalUnitType]) -> [HevcNalUnit] {
    return readNalUnits(data, nalUnits) { byte in
        filter.contains(HevcNalUnitType(rawValue: (byte & 0x7E) >> 1) ?? .unspec)
    }
}

private func readNalUnits<TNalUnit: NalUnit>(_ data: Data,
                                             _ nalUnits: [NalUnitInfo],
                                             _ filter: (UInt8) -> Bool) -> [TNalUnit]
{
    var units: [TNalUnit] = []
    for nalUnit in nalUnits {
        let dataOffset = nalUnit.dataOffset()
        if filter(data[dataOffset]) {
            if let nalUnit = TNalUnit(data: data.subdata(in: dataOffset ..< dataOffset + nalUnit.dataLength),
                                      offset: 0)
            {
                units.append(nalUnit)
            }
        }
    }
    return units
}

private func parseNalUnits(_ data: Data, _ onNalUnit: (Int, Int, Int) -> Void) {
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
        let dataLength = lastIndexOf - index - 2
        guard dataLength > 0 else {
            index -= 1
            continue
        }
        let startCodeIndex = index + 3 - startCodeLength
        onNalUnit(startCodeIndex, startCodeLength, dataLength)
        lastIndexOf = startCodeIndex - 1
        index = lastIndexOf
    }
}
