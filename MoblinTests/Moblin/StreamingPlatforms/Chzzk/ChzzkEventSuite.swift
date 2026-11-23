import Foundation
@testable import Moblin
import Testing

struct ChzzkEventSuite {
    @Test(arguments: ["86400", #""86400""#])
    func tokenLifetime(seconds: String) throws {
        let json = """
        {"accessToken":"access","refreshToken":"refresh","expiresIn":\(seconds)}
        """
        let token = try JSONDecoder().decode(ChzzkTokenResponse.self, from: Data(json.utf8))
        #expect(token.expiresIn == 86400)
    }

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

    @Test
    func moderationIdentifiers() throws {
        let payload = """
        {"channelId":"host","senderChannelId":"viewer","chatChannelId":"room",
         "messageTime":1795410000123,"profile":{"nickname":"Viewer"},"content":"hello"}
        """
        let message = try JSONDecoder().decode(ChzzkChatMessage.self, from: Data(payload.utf8))
        #expect(message.moderationTarget.channelId == "host")
        #expect(message.moderationTarget.senderChannelId == "viewer")
        #expect(message.moderationTarget.chatChannelId == "room")
        #expect(message.moderationTarget.messageTime == 1_795_410_000_123)
        #expect(message.moderationTarget.messageId == "chzzk:host:room:viewer:1795410000123")
    }

    @Test(arguments: ["CLOSE", "CLOSED"])
    func offlineLiveStatus(status: String) throws {
        #expect(try ChzzkLiveStatus(status: status, concurrentUserCount: nil).platformStatus() == .offline)
    }

    @Test(arguments: [0, 12, 100_000])
    func directViewerCount(count: Int) throws {
        #expect(try ChzzkLiveStatus(status: "OPEN", concurrentUserCount: count).platformStatus()
            == .live(viewerCount: count))
    }

    @Test
    func missingViewerCountIsNotZero() {
        #expect(throws: (any Error).self) {
            try ChzzkLiveStatus(status: "OPEN", concurrentUserCount: nil).platformStatus()
        }
    }
}
