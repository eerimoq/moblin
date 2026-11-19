import Foundation
@testable import Moblin
import Testing

struct ChzzkEventSuite {
    @Test
    func connectedSessionWithStringPayload() throws {
        let json = #"["SYSTEM","{\"type\":\"connected\",\"data\":{\"sessionKey\":\"test-session\"}}"]"#
        let event = try JSONDecoder().decode(ChzzkEvent.self, from: Data(json.utf8))
        guard case let .system(system) = event else {
            Issue.record("Expected a system event")
            return
        }
        #expect(system.type == "connected")
        #expect(system.data.sessionKey == "test-session")
    }

    @Test
    func chatWithNestedRoleAndKoreanText() throws {
        let payload = """
        {
            "channelId":"host","senderChannelId":"viewer",
            "profile":{"nickname":"방송매니저","userRoleCode":"streaming_chat_manager"},
            "content":"어서 오세요 {:wave:}","emojis":{"wave":"https://example.com/wave.png"}
        }
        """
        let data = try JSONEncoder().encode(["CHAT", payload])
        let event = try JSONDecoder().decode(ChzzkEvent.self, from: data)
        guard case let .chat(message) = event else {
            Issue.record("Expected a chat message")
            return
        }
        #expect(message.content == "어서 오세요 {:wave:}")
        #expect(message.profile.nickname == "방송매니저")
        #expect(message.userRoleCode == "streaming_chat_manager")
        #expect(message.emojis?["wave"] == "https://example.com/wave.png")
    }

    @Test(arguments: ["1000", #""1000""#])
    func anonymousDonation(amount: String) throws {
        let json = """
        ["DONATION", {"channelId":"host","donatorChannelId":"anonymous",
                      "donatorNickname":"","payAmount":\(amount)}]
        """
        let event = try JSONDecoder().decode(ChzzkEvent.self, from: Data(json.utf8))
        guard case let .donation(donation) = event else {
            Issue.record("Expected a donation")
            return
        }
        #expect(donation.payAmount == "1000")
        #expect(donation.donatorChannelId == "anonymous")
        #expect(donation.donationText == nil)
    }
}
