import AVFoundation
import Foundation
import Testing

@testable import RTCHaishinKit

@Suite struct RTPTimestampTests {
    @Test func convertRTPPacketTimestamp_H264() throws {
        var timestamp = RTPTimestamp(90000.0)
        #expect(timestamp.convert(CMTime(value: 511364443358833, timescale: 1000000000)) == 0)
        #expect(timestamp.convert(CMTime(value: 511364476594833, timescale: 1000000000)) == 2991)
        #expect(timestamp.convert(CMTime(value: 511364509930833, timescale: 1000000000)) == 5991)
    }
}
