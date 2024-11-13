import CoreMedia
import Foundation

protocol NalUnit {
    init(_ data: Data)
}

final class NALUnitReader {
    func readH264(_ data: Data) -> [AvcNalUnit] {
        return read(data)
    }

    func readH265(_ data: Data) -> [HevcNalUnit] {
        return read(data)
    }

    private func read<T: NalUnit>(_ data: Data) -> [T] {
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
}
