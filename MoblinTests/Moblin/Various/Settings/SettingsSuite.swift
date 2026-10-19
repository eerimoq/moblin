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
    func textToSpeechSayEmotesDefaultsToOff() throws {
        let chat = try JSONDecoder().decode(SettingsChat.self, from: Data("{}".utf8))
        #expect(!chat.textToSpeechSayEmotes)
    }

    @Test
    func textToSpeechSayEmotesIsPersisted() throws {
        let chat = SettingsChat()
        chat.textToSpeechSayEmotes = true
        let decoded = try JSONDecoder().decode(SettingsChat.self, from: JSONEncoder().encode(chat))
        #expect(decoded.textToSpeechSayEmotes)
    }

    @Test(arguments: ["{}", "{\"botCommandPrefixes\":null}", "{\"botCommandPrefixes\":[]}",
                      "{\"botCommandPrefixes\":[\"?\"]}", "{\"botCommandPrefixes\":true}",
                      "{\"botCommandPrefixes\":[1]}"])
    func chatPrefixesDefaultToBang(json: String) throws {
        let chat = try JSONDecoder().decode(SettingsChat.self, from: Data(json.utf8))
        #expect(chat.botCommandPrefixes == ["!"])
        #expect(SettingsChat().effectiveBotCommandPrefixes == ["!"])
    }

    @Test(arguments: [["!"], ["."], ["/"], ["!", "."], ["!", "/"], [".", "/"], ["!", ".", "/"]])
    func chatPrefixesRoundTrip(prefixes: [String]) throws {
        let chat = SettingsChat()
        chat.botCommandPrefixes = prefixes
        let alias = SettingsChatBotAlias()
        alias.alias = "!screen"
        alias.replacement = "!moblin scene Screen"
        chat.aliases = [alias]
        let decoded = try JSONDecoder().decode(SettingsChat.self, from: JSONEncoder().encode(chat))
        #expect(decoded.botCommandPrefixes == prefixes)
        #expect(decoded.aliases.first?.alias == alias.alias)
        #expect(decoded.aliases.first?.replacement == alias.replacement)
    }

    @Test
    func chatPrefixesNormalizeOnImportAndExport() throws {
        let json = "{\"botCommandPrefixes\":[\"/\",\"?\",\".\",\"/\"]}"
        let chat = try JSONDecoder().decode(SettingsChat.self, from: Data(json.utf8))
        #expect(chat.botCommandPrefixes == [".", "/"])
        chat.botCommandPrefixes = ["/", "/", "!", "?"]
        #expect(chat.effectiveBotCommandPrefixes == ["!", "/"])
        let decoded = try JSONDecoder().decode(SettingsChat.self, from: JSONEncoder().encode(chat))
        #expect(decoded.botCommandPrefixes == ["!", "/"])
    }
}
