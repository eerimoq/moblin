import Foundation
@testable import Moblin
import Testing

struct UtilsSuite {
    @Test
    func fullDuration() {
        #expect(formatFullDuration(seconds: 0) == "0 seconds")
        #expect(formatFullDuration(seconds: 1) == "1 second")
        #expect(formatFullDuration(seconds: 30) == "30 seconds")
        #expect(formatFullDuration(seconds: 60) == "1 minute")
        #expect(formatFullDuration(seconds: 120) == "2 minutes")
        #expect(formatFullDuration(seconds: 3600) == "1 hour")
        #expect(formatFullDuration(seconds: 86400) == "1 day")
        #expect(formatFullDuration(seconds: 7 * 86400) == "7 days")
        #expect(formatFullDuration(seconds: 30 * 86400) == "30 days")
        #expect(formatFullDuration(seconds: 90 * 86400) == "90 days")
    }

    @Test
    func uuidAddEmpty() throws {
        let original = try #require(UUID(uuidString: "00000000-1111-2222-3333-000000000000"))
        let extra = Data()
        let result = try #require(UUID(uuidString: "00000000-1111-2222-3333-000000000000"))
        #expect(original.add(data: extra) == result)
    }

    @Test
    func uuidAddShort() throws {
        let original = try #require(UUID(uuidString: "07080000-0000-0000-0000-010203040506"))
        let extra = Data([0x01, 0x23, 0x45, 0x67])
        let result = try #require(UUID(uuidString: "07080000-0000-0000-0000-010204274A6D"))
        #expect(original.add(data: extra) == result)
    }

    @Test
    func uuidAddLong() throws {
        let original = try #require(UUID(uuidString: "07080000-0000-0000-0000-010203040506"))
        let extra = Data([0x01, 0x23, 0x45, 0x67]) + Data(count: 15)
        let result = try #require(UUID(uuidString: "6E080000-0000-0000-0000-01020305284B"))
        #expect(original.add(data: extra) == result)
    }

    @Test
    func uuidAddByteWrap() throws {
        let original = try #require(UUID(uuidString: "00010000-0000-0000-0000-FAFBFCFDFEFF"))
        let extra = Data([0x01, 0x23, 0x45, 0x67])
        let result = try #require(UUID(uuidString: "00010000-0000-0000-0000-FAFBFD204366"))
        #expect(original.add(data: extra) == result)
    }
}
