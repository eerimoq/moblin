import CoreMedia
import Foundation

struct ADTSHeader: Equatable {
    static let size: Int = 7

    var profile: UInt8 = 0
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
            home = (newValue[3] & 0b0001_0000) == 0b0001_0000
        }
    }
}
