@testable import Moblin
import Testing

struct UtilsSuite {
    @Test
    func fullDuration() async throws {
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
}
