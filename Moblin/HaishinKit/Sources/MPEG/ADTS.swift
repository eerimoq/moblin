import CoreMedia
import Foundation

struct ADTSHeader: Equatable {
    static let size: Int = 7

    var profile: UInt8 = 0
    var sampleFrequencyIndex: UInt8 = 0
    var channelConfiguration: UInt8 = 0
    var home = false

    init() {}

    init(data: Data) {
        self.data = data
    }

    var data: Data {
        get {
            Data()
        }
        set {
            guard ADTSHeader.size <= newValue.count else {
                return
            }
            profile = newValue[2] >> 6 & 0b11
            sampleFrequencyIndex = (newValue[2] >> 2) & 0b0000_1111
            channelConfiguration = ((newValue[2] & 0b1) << 2) | newValue[3] >> 6
            home = (newValue[3] & 0b0001_0000) == 0b0001_0000
        }
    }
}
