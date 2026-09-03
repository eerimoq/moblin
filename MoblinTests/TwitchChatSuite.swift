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
    func gifMessage() throws {
        let message = try TwitchChatMessage(string: """
        @badge-info=subscriber/24;\
        badges=broadcaster/1,subscriber/0,sub-gifter/1;\
        color=;\
        display-name=eerimoq;\
        emotes=;\
        first-msg=0;\
        flags=;\
        gifs=0-34|l0MYDEPLWRWbJoRuU|https://media3.giphy.com/media/l0MYDEPLWRWbJoRuU/giphy.gif?\
        cid=095d7a5dpq5y4f8xwwlqk053r89k5ezmzgauu6wyjbrun0k0&ep=v1_gifs_trending&rid=giphy.gif&ct=g;\
        id=f44b10f3-dd19-4b1b-b8be-e99c4e5502e5;\
        mod=0;\
        returning-chatter=0;\
        room-id=63482386;\
        subscriber=1;\
        tmi-sent-ts=1788449914571;\
        turbo=0;\
        user-id=63482386;\
        user-type= \
        :eerimoq!eerimoq@eerimoq.tmi.twitch.tv \
        PRIVMSG \
        #eerimoq \
        :[George Costanza Hello GIF by HULU]
        """)
        #expect(message.command == .privateMessage)
        #expect(message.parameters == ["#eerimoq", "[George Costanza Hello GIF by HULU]"])
        #expect(message.emotes.count == 1)
        let gif = try #require(message.emotes.first)
        #expect(gif.isGif)
        #expect(gif.range == 0 ... 34)
        #expect(gif.url.absoluteString == """
        https://media3.giphy.com/media/l0MYDEPLWRWbJoRuU/100.gif?\
        cid=095d7a5dpq5y4f8xwwlqk053r89k5ezmzgauu6wyjbrun0k0&ep=v1_gifs_trending&rid=giphy.gif&ct=g
        """)
    }

    @Test
    func gifAndEmotesMessage() throws {
        let message = try TwitchChatMessage(string: """
        @gifs=6-10|abc|https://media.giphy.com/media/abc/giphy.gif;\
        emotes=25:0-4 \
        :eerimoq!eerimoq@eerimoq.tmi.twitch.tv \
        PRIVMSG \
        #eerimoq \
        :Kappa [gif]
        """)
        #expect(message.emotes.count == 2)
        #expect(message.emotes.map(\.isGif) == [true, false])
        #expect(message.emotes.map(\.range) == [6 ... 10, 0 ... 4])
    }

    @Test
    func gigantifiedEmoteMessage() throws {
        let message = try TwitchChatMessage(string: """
        @badge-info=;\
        badges=;\
        color=;\
        display-name=eerimoq;\
        emotes=25:0-4,12-16/1902:6-10;\
        id=f44b10f3-dd19-4b1b-b8be-e99c4e5502e5;\
        msg-id=gigantified-emote-message;\
        user-id=63482386 \
        :eerimoq!eerimoq@eerimoq.tmi.twitch.tv \
        PRIVMSG \
        #eerimoq \
        :Kappa Keepo Kappa
        """)
        #expect(message.command == .privateMessage)
        #expect(message.emotes.count == 3)
        #expect(message.emotes.map(\.range) == [0 ... 4, 12 ... 16, 6 ... 10])
        #expect(message.emotes.map(\.isGif) == [false, true, false])
        #expect(message.emotes[1].url.absoluteString ==
            "https://static-cdn.jtvnw.net/emoticons/v2/25/default/dark/3.0")
    }

    @Test
    func gigantifiedEmoteMessageWithGif() throws {
        let message = try TwitchChatMessage(string: """
        @msg-id=gigantified-emote-message;\
        gifs=6-10|abc|https://media.giphy.com/media/abc/giphy.gif;\
        emotes=25:0-4 \
        :eerimoq!eerimoq@eerimoq.tmi.twitch.tv \
        PRIVMSG \
        #eerimoq \
        :Kappa [gif]
        """)
        #expect(message.emotes.map(\.range) == [6 ... 10, 0 ... 4])
        #expect(message.emotes.map(\.isGif) == [true, true])
    }

    @Test
    func malformedGifTag() throws {
        let message = try TwitchChatMessage(string: """
        @gifs=0-4|abc \
        :eerimoq!eerimoq@eerimoq.tmi.twitch.tv \
        PRIVMSG \
        #eerimoq \
        :[gif]
        """)
        #expect(message.emotes.isEmpty)
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
    func announcement() throws {
        let message = try TwitchChatMessage(string: """
        @badge-info=subscriber/24;\
        badges=broadcaster/1,subscriber/0,sub-gifter/1;\
        color=;\
        display-name=eerimoq;\
        emotes=;\
        flags=;\
        id=e60e8de0-eb07-49b1-aa77-96cb5f5fabb1;\
        login=eerimoq;\
        mod=0;\
        msg-id=announcement;\
        msg-param-color=PRIMARY;\
        room-id=63482386;\
        subscriber=1;\
        system-msg=;\
        tmi-sent-ts=1788339928132;\
        user-id=63482386;\
        user-type=;\
        vip=0 \
        :tmi.twitch.tv \
        USERNOTICE \
        #eerimoq \
        :foobar
        """)
        #expect(message.command == .userNotice)
        #expect(message.parameters == ["#eerimoq", "foobar"])
        #expect(message.displayName == "eerimoq")
        #expect(message.user == "eerimoq")
        #expect(message.userId == "63482386")
        #expect(message.messageId == "announcement")
        #expect(message.id == "e60e8de0-eb07-49b1-aa77-96cb5f5fabb1")
        #expect(message.badges == ["broadcaster/1", "subscriber/0", "sub-gifter/1"])
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
