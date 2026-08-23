@testable import Moblin
import Testing

struct SettingsSuite {
    @Test
    func streamUrlSchemeSelectsProtocol() {
        let stream = SettingsStream(name: "Test")
        stream.url = "usb://localhost:7777"
        #expect(stream.getProtocol() == .usb)
        #expect(stream.getDetailedProtocol() == .usb)
        #expect(stream.protocolString() == "USB")
        #expect(stream.usbPort() == 7777)
        #expect(!stream.isBonding())
        stream.url = "usb://localhost"
        #expect(stream.usbPort() == 7777)
    }

    @Test
    func chatFilter() {
        let filter = SettingsChatFilter()
        filter.enabled = true
        filter.user = ""
        filter.messageStartWords = ["!"]
        #expect(filter.isMatching(user: "erik", segments: [.init(id: 0, text: "!moblin")]))
        #expect(filter.isMatching(user: "erik", segments: [.init(id: 0, text: "!")]))
        #expect(!filter.isMatching(user: "erik", segments: [.init(id: 0, text: "@foo")]))
        #expect(!filter.isMatching(user: "erik", segments: [.init(id: 0, text: "@")]))
        filter.messageStartWords = ["hell", "h"]
        #expect(filter.isMatching(user: "erik",
                                  segments: [
                                      .init(id: 0, text: "hell"),
                                      .init(id: 0, text: "hi"),
                                      .init(id: 0, text: "ho"),
                                  ]))
        #expect(!filter.isMatching(user: "erik",
                                   segments: [
                                       .init(id: 0, text: "hello"),
                                       .init(id: 0, text: "hi"),
                                       .init(id: 0, text: "ho"),
                                   ]))
    }
}
