import Foundation
@testable import Moblin
import Testing

struct RemoteControlTallySuite {
    @Test
    func startsOff() {
        #expect(!RemoteControlTallyLeases().on)
        #expect(RemoteControlTallyLeases().nextExpiry == nil)
    }

    @Test
    func expiresWithoutRefresh() {
        var tally = RemoteControlTallyLeases()
        tally.set(on: true, sourceId: UUID(), now: 100)
        tally.expire(now: 109)
        #expect(tally.on)
        tally.expire(now: 110)
        #expect(!tally.on)
    }

    @Test
    func refreshExtendsLease() {
        var tally = RemoteControlTallyLeases()
        let source = UUID()
        tally.set(on: true, sourceId: source, now: 100)
        tally.set(on: true, sourceId: source, now: 105)
        tally.expire(now: 110)
        #expect(tally.on)
        tally.expire(now: 115)
        #expect(!tally.on)
    }

    @Test
    func offOrDisconnectClearsOnlyThatController() {
        var tally = RemoteControlTallyLeases()
        let assistant = UUID()
        let web = UUID()
        tally.set(on: true, sourceId: assistant, now: 100)
        tally.set(on: true, sourceId: web, now: 101)
        #expect(tally.nextExpiry == 110)
        tally.set(on: false, sourceId: assistant, now: 102)
        #expect(tally.on)
        #expect(tally.nextExpiry == 111)
        tally.set(on: false, sourceId: web, now: 103)
        #expect(!tally.on)
    }

    @Test
    func commandAlsoDiscardsExpiredControllers() {
        var tally = RemoteControlTallyLeases()
        tally.set(on: true, sourceId: UUID(), now: 100)
        tally.set(on: false, sourceId: UUID(), now: 111)
        #expect(!tally.on)
    }

    @Test(arguments: [true, false])
    func requestRoundTrip(on: Bool) throws {
        let encoded = try JSONEncoder().encode(RemoteControlRequest.setTally(on: on))
        let object = try JSONSerialization.jsonObject(with: encoded) as? [String: [String: Bool]]
        #expect(object == ["setTally": ["on": on]])
        let decoded = try JSONDecoder().decode(RemoteControlRequest.self, from: encoded)
        guard case let .setTally(on: restored) = decoded else {
            Issue.record("Unexpected request")
            return
        }
        #expect(restored == on)
    }

    @Test
    func oldSettingsDoNotAdvertiseTally() throws {
        let data = Data("""
        {"streams":[],"scenes":[],"bitratePresets":[],"mics":[],
         "srt":{"connectionPrioritiesEnabled":false,"connectionPriorities":[]}}
        """.utf8)
        var settings = try JSONDecoder().decode(RemoteControlSettings.self, from: data)
        #expect(settings.supportsTally == nil)
        settings.supportsTally = true
        let restored = try JSONDecoder().decode(RemoteControlSettings.self,
                                                from: JSONEncoder().encode(settings))
        #expect(restored.supportsTally == true)
    }
}
