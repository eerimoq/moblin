import CoreMedia
import Foundation

package enum H264NALUnitType: UInt8, Equatable {
    case unspec = 0
    case slice = 1 // P frame
    case dpa = 2
    case dpb = 3
    case dpc = 4
    case idr = 5 // I frame
    case sei = 6
    case sps = 7
    case pps = 8
    case aud = 9
    case eoseq = 10
    case eostream = 11
    case fill = 12
}

// MARK: -
package struct H264NALUnit: NALUnit, Equatable {
    package let refIdc: UInt8
    package let type: H264NALUnitType
    package let payload: Data

    init(_ data: Data, length: Int) {
        self.refIdc = data[0] >> 5
        self.type = H264NALUnitType(rawValue: data[0] & 0x1f) ?? .unspec
        self.payload = data.subdata(in: 1..<length)
    }

    package init(_ data: Data) {
        self.init(data, length: data.count)
    }

    package var data: Data {
        var result = Data()
        result.append(refIdc << 5 | self.type.rawValue)
        result.append(payload)
        return result
    }
}
