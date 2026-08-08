import AVFoundation
@testable import Moblin
import Testing

struct TwitchChatSuite {
    @Test
    func emptyMessage() {
        let message = try? TwitchChatMessage(string: "")
        #expect(message == nil)
    }

    @Test
    func basicMessage() throws {
        let message = try TwitchChatMessage(string: """
        @badge-info=subscriber/13;\
        badges=broadcaster/1,subscriber/0,turbo/1;\
        client-nonce=11b2e915221ab4bcfb44714bda0fb575;\
        color=;\
        display-name=eerimoq;\
        emotes=;\
        first-msg=0;\
        flags=;\
        id=52db2f3d-cc5a-46ea-ba0b-bd910579c248;\
        mod=0;\
        returning-chatter=0;\
        room-id=63482386;\
        subscriber=1;\
        tmi-sent-ts=1760946171865;\
        turbo=1;\
        user-id=63482386;\
        user-type= \
        :eerimoq!eerimoq@eerimoq.tmi.twitch.tv \
        PRIVMSG \
        #eerimoq \
        :hi all
        """)
        #expect(message.command == .privateMessage)
        #expect(message.parameters == ["#eerimoq", "hi all"])
        #expect(message.displayName == "eerimoq")
        #expect(message.user == "eerimoq")
        #expect(message.userId == "63482386")
        #expect(message.color == nil)
        #expect(message.emotes.isEmpty)
        #expect(message.badges == ["broadcaster/1", "subscriber/0", "turbo/1"])
        #expect(message.messageId == nil)
        #expect(message.id == "52db2f3d-cc5a-46ea-ba0b-bd910579c248")
        #expect(!message.firstMessage)
        #expect(message.subscriber)
        #expect(!message.moderator)
        #expect(message.bits == nil)
        #expect(message.replySender == nil)
        #expect(message.replyText == nil)
        #expect(message.targetMessageId == nil)
        #expect(message.targetUserId == nil)
    }

    @Test
    func botRixMessage() throws {
        let message = try TwitchChatMessage(string: """
        @badge-info=;\
        badges=moderator/1,bot-badge/1;\
        color=#179451;\
        display-name=BotRixOficial;\
        emotes=;\
        first-msg=0;\
        flags=;\
        id=b8dc3c37-cb4b-4f7a-a011-52eeae902cb2;\
        mod=1;\
        returning-chatter=0;\
        room-id=63482386;\
        subscriber=0;\
        tmi-sent-ts=1786194630483;\
        turbo=0;\
        user-id=646848961;\
        user-type=mod \
        :botrixoficial!botrixoficial@botrixoficial.tmi.twitch.tv \
        PRIVMSG \
        #eerimoq \
        :the test message
        """)
        #expect(message.command == .privateMessage)
        #expect(message.parameters == ["#eerimoq", "the test message"])
        #expect(message.displayName == "BotRixOficial")
        #expect(message.user == "botrixoficial")
        #expect(message.userId == "646848961")
        #expect(message.color == "#179451")
        #expect(message.emotes.isEmpty)
        #expect(message.badges == ["moderator/1", "bot-badge/1"])
        #expect(message.messageId == nil)
        #expect(message.id == "b8dc3c37-cb4b-4f7a-a011-52eeae902cb2")
        #expect(!message.firstMessage)
        #expect(!message.subscriber)
        #expect(message.moderator)
        #expect(message.bits == nil)
        #expect(message.replySender == nil)
        #expect(message.replyText == nil)
        #expect(message.targetMessageId == nil)
        #expect(message.targetUserId == nil)
    }
}
