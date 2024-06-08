import CoreMedia
import Foundation

protocol NalUnit {
    init(_ data: Data)
}

final class NALUnitReader {
    static let defaultNALUnitHeaderLength: Int32 = 4
    var nalUnitHeaderLength: Int32 = NALUnitReader.defaultNALUnitHeaderLength

    func read<T: NalUnit>(_ data: inout Data, type _: T.Type) -> [T] {
        var units: [T] = .init()
        var lastIndexOf = data.count - 1
        for i in (2 ..< data.count).reversed() {
            guard data[i] == 1, data[i - 1] == 0, data[i - 2] == 0 else {
                continue
            }
            let startCodeLength = i - 3 >= 0 && data[i - 3] == 0 ? 4 : 3
            units.append(T(data.subdata(in: (i + 1) ..< lastIndexOf + 1)))
            lastIndexOf = i - startCodeLength
        }
        return units
    }

    func makeFormatDescription(_ data: inout Data, type: ElementaryStreamType) -> CMFormatDescription? {
        switch type {
        case .h264:
            let units = read(&data, type: AvcNalUnit.self)
            return units.makeFormatDescription(nalUnitHeaderLength)
        case .h265:
            let units = read(&data, type: HevcNalUnit.self)
            return units.makeFormatDescription(nalUnitHeaderLength)
        default:
            return nil
        }
    }
}
