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
    func textToSpeechVoicesWithoutElevenLabsDecode() throws {
        let json = """
        {"textToSpeechLanguageVoices":{"en":{"type":"ttsMonster","apple":{"voice":""},\
        "ttsMonster":{"name":"Axel","voiceId":"abc"}}}}
        """
        let chat = try JSONDecoder().decode(SettingsChat.self, from: Data(json.utf8))
        let voice = try #require(chat.textToSpeechLanguageVoices["en"])
        #expect(voice.type == .ttsMonster)
        #expect(voice.ttsMonster.voiceId == "abc")
        #expect(voice.elevenLabs.voiceId == "")
    }

    @Test
    func textToSpeechElevenLabsVoiceRoundTrips() throws {
        let chat = SettingsChat()
        chat.elevenLabs.apiKey = "key"
        let voice = SettingsVoice()
        voice.type = .elevenLabs
        voice.elevenLabs.name = "Rachel"
        voice.elevenLabs.voiceId = "21m00Tcm4TlvDq8ikWAM"
        chat.textToSpeechLanguageVoices["en"] = voice
        let decoded = try JSONDecoder().decode(SettingsChat.self, from: JSONEncoder().encode(chat))
        #expect(decoded.elevenLabs.apiKey == "key")
        let decodedVoice = try #require(decoded.textToSpeechLanguageVoices["en"])
        #expect(decodedVoice.type == .elevenLabs)
        #expect(decodedVoice.elevenLabs.name == "Rachel")
        #expect(decodedVoice.elevenLabs.voiceId == "21m00Tcm4TlvDq8ikWAM")
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
}
