import Foundation
@testable import Moblin
import Testing

struct SettingsMoblinkSuite {
    @Test
    func relayUrlWithoutSchemeIsReplacedWithDefault() throws {
        let json = #"{"enabled": true, "name": "Relay", "url": "//1.2.3.4:5678", "manual": true}"#
        let relay = try JSONDecoder().decode(SettingsMoblinkRelay.self, from: Data(json.utf8))
        #expect(relay.enabled)
        #expect(relay.name == "Relay")
        #expect(relay.url == "")
        #expect(relay.manual)
    }

    @Test
    func validRelayUrlIsKept() throws {
        let json = #"{"url": "ws://1.2.3.4:5678"}"#
        let relay = try JSONDecoder().decode(SettingsMoblinkRelay.self, from: Data(json.utf8))
        #expect(relay.url == "ws://1.2.3.4:5678")
    }
}
