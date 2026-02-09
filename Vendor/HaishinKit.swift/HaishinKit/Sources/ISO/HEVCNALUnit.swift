import CoreMedia
import Foundation

package enum HEVCNALUnitType: UInt8 {
    case codedSliceTrailN = 0
    case codedSliceTrailR = 1
    case codedSliceTsaN = 2
    case codedSliceTsaR = 3
    case codedSliceStsaN = 4
    case codedSliceStsaR = 5
    case codedSliceRadlN = 6
    case codedSliceRadlR = 7
    case codedSliceRaslN = 8
    case codedSliceRsslR = 9
    /// 10...15 Reserved
    case vps = 32
    case sps = 33
    case pps = 34
    case accessUnitDelimiter = 35
    case unspec = 0xFF
}

package struct HEVCNALUnit: NALUnit, Equatable {
    package let type: HEVCNALUnitType
    package let temporalIdPlusOne: UInt8
    package let payload: Data

    init(_ data: Data, length: Int) {
        self.type = HEVCNALUnitType(rawValue: (data[0] & 0x7e) >> 1) ?? .unspec
        self.temporalIdPlusOne = data[1] & 0b00011111
        self.payload = data.subdata(in: 2..<length)
    }

    package init(_ data: Data) {
        self.init(data, length: data.count)
    }

    package var data: Data {
        var result = Data()
        result.append(type.rawValue << 1)
        result.append(temporalIdPlusOne)
        result.append(payload)
        return result
    }
}
