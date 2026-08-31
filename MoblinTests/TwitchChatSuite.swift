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

    @Test
    func unescapedTagValues() throws {
        let message = try TwitchChatMessage(string: """
        @display-name=eerimoq;\
        reply-parent-display-name=someone;\
        reply-parent-msg-body=a\\sb\\:c\\rd\\ne\\\\f\\qg \
        :eerimoq!eerimoq@eerimoq.tmi.twitch.tv \
        PRIVMSG \
        #eerimoq \
        :hi
        """)
        #expect(message.replySender == "someone")
        #expect(message.replyText == "a b;c\rd\ne\\fqg")
    }

    @Test
    func unescapedTagValueEndingInBackslash() throws {
        let message = try TwitchChatMessage(string: """
        @reply-parent-msg-body=a\\sb\\ \
        :eerimoq!eerimoq@eerimoq.tmi.twitch.tv \
        PRIVMSG \
        #eerimoq \
        :hi
        """)
        #expect(message.replyText == "a b")
    }

    @Test
    func unescapedTagValueWithoutEscapes() throws {
        let message = try TwitchChatMessage(string: """
        @reply-parent-msg-body=hello;\
        display-name=eerimoq \
        :eerimoq!eerimoq@eerimoq.tmi.twitch.tv \
        PRIVMSG \
        #eerimoq \
        :hi
        """)
        #expect(message.replyText == "hello")
        #expect(message.displayName == "eerimoq")
    }

    @Test
    func emotesTag() throws {
        let message = try TwitchChatMessage(string: """
        @display-name=eerimoq;\
        emotes=25:0-4,12-16/1902:6-10 \
        :eerimoq!eerimoq@eerimoq.tmi.twitch.tv \
        PRIVMSG \
        #eerimoq \
        :Kappa Keepo Kappa
        """)
        #expect(message.emotes.map(\.range) == [0 ... 4, 12 ... 16, 6 ... 10])
        #expect(message.emotes.map(\.url.absoluteString) == [
            "https://static-cdn.jtvnw.net/emoticons/v2/25/default/dark/3.0",
            "https://static-cdn.jtvnw.net/emoticons/v2/25/default/dark/3.0",
            "https://static-cdn.jtvnw.net/emoticons/v2/1902/default/dark/3.0",
        ])
    }

    @Test
    func clearMessage() throws {
        let message = try TwitchChatMessage(string: """
        @login=eerimoq;\
        target-msg-id=8b4f-4dda-a4e6 \
        :tmi.twitch.tv \
        CLEARMSG \
        #eerimoq \
        :bye
        """)
        #expect(message.command == .clearMsg)
        #expect(message.targetMessageId == "8b4f-4dda-a4e6")
    }

    @Test
    func clearChat() throws {
        let message = try TwitchChatMessage(string: """
        @target-user-id=63482386 \
        :tmi.twitch.tv \
        CLEARCHAT \
        #eerimoq \
        :baduser
        """)
        #expect(message.command == .clearChat)
        #expect(message.targetUserId == "63482386")
    }

    @Test
    func ping() throws {
        let message = try TwitchChatMessage(string: "PING :tmi.twitch.tv")
        #expect(message.command == .ping)
        #expect(message.parameters == ["tmi.twitch.tv"])
    }

    @Test
    func unknownCommand() {
        #expect((try? TwitchChatMessage(string: ":tmi.twitch.tv 001 eerimoq :Welcome")) == nil)
    }
}
