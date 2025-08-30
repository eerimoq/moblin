import Testing
@testable import Moblin
import AVFoundation

struct MoblinTests {
    @Test func wrappingTimestamp() async throws {
        let timestamp = WrappingTimestamp(name: "Test", maximumTimestamp: CMTime(seconds: 1024))
        #expect(timestamp.update(CMTime(seconds: 30)).seconds == 30)
        #expect(timestamp.update(CMTime(seconds: 1023)).seconds == -1)
        #expect(timestamp.update(CMTime(seconds: 500)).seconds == 500)
        #expect(timestamp.update(CMTime(seconds: 700)).seconds == 700)
        #expect(timestamp.update(CMTime(seconds: 1000)).seconds == 1000)
        #expect(timestamp.update(CMTime(seconds: 30)).seconds == 1054)
        #expect(timestamp.update(CMTime(seconds: 1000)).seconds == 1000)
        #expect(timestamp.update(CMTime(seconds: 500)).seconds == 1524)
        #expect(timestamp.update(CMTime(seconds: 1000)).seconds == 2024)
        #expect(timestamp.update(CMTime(seconds: 0)).seconds == 2048)
        #expect(timestamp.update(CMTime(seconds: 1022)).seconds == 2046)
        #expect(timestamp.update(CMTime(seconds: 1022)).seconds == 2046)
    }
}
