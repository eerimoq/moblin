import Foundation
@testable import Moblin
import Testing

private let ntpUnixEpochSeconds: UInt64 = 2_208_988_800

struct WebrtcIngestClientSuite {
    @Test(arguments: [
        UInt64(0),
        UInt64(1) << 32,
        ntpUnixEpochSeconds,
        (ntpUnixEpochSeconds - 1) << 32 | 0xFFFF_FFFF,
    ])
    func decodeNtpTimestampBeforeUnixEpoch(_ value: UInt64) {
        #expect(decodeNtpTimestamp(v: value) == nil)
    }

    @Test
    func decodeNtpTimestampAtUnixEpoch() throws {
        let timestamp = try #require(decodeNtpTimestamp(v: ntpUnixEpochSeconds << 32))
        #expect(timestamp == 0)
    }

    @Test
    func decodeNtpTimestampWithFraction() throws {
        let timestamp = try #require(decodeNtpTimestamp(v: (ntpUnixEpochSeconds + 10) << 32 | 0x8000_0000))
        #expect(isEqual(timestamp, 10.5, epsilon: 1e-9))
    }
}
