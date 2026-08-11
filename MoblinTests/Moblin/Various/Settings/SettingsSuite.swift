import Foundation
@testable import Moblin
import Testing

struct SettingsSuite {
    @Test
    func streamUrlSchemeSelectsProtocol() {
        let stream = SettingsStream(name: "Test")
        stream.url = "mobcam://localhost:7777"
        #expect(stream.getProtocol() == .mobcam)
        #expect(stream.getDetailedProtocol() == .mobcam)
        #expect(stream.protocolString() == "Mobcam")
        #expect(stream.mobcamPort() == 7777)
        #expect(!stream.isBonding())
        stream.url = "mobcam://localhost"
        #expect(stream.mobcamPort() == DefaultTcpPorts.mobcamStream)
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

    @Test
    func streamChatEnabledDefaultsToTrueForOldSettings() throws {
        let json = Data(#"{"name":"My stream","twitchChannelName":"foo"}"#.utf8)
        let stream = try JSONDecoder().decode(SettingsStream.self, from: json)
        #expect(stream.twitchChatEnabled)
        #expect(stream.kickChatEnabled)
        #expect(stream.youTubeChatEnabled)
        #expect(stream.soopChatEnabled)
        #expect(stream.openStreamingPlatformChatEnabled)
    }

    @Test
    func streamChatEnabledSurvivesRoundTrip() throws {
        let stream = SettingsStream(name: "My stream")
        stream.twitchChatEnabled = false
        stream.kickChatEnabled = false
        stream.youTubeChatEnabled = false
        stream.soopChatEnabled = false
        stream.openStreamingPlatformChatEnabled = false
        let data = try JSONEncoder().encode(stream)
        let decoded = try JSONDecoder().decode(SettingsStream.self, from: data)
        #expect(!decoded.twitchChatEnabled)
        #expect(!decoded.kickChatEnabled)
        #expect(!decoded.youTubeChatEnabled)
        #expect(!decoded.soopChatEnabled)
        #expect(!decoded.openStreamingPlatformChatEnabled)
    }

    @Test
    func streamCloneCopiesChatEnabled() {
        let stream = SettingsStream(name: "My stream")
        stream.kickChatEnabled = false
        let new = stream.clone()
        #expect(!new.kickChatEnabled)
        #expect(new.twitchChatEnabled)
    }
}
