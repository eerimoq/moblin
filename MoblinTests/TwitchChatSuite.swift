import AVFoundation
@testable import Moblin
import Testing

struct TwitchChatSuite {
    @Test func emptyMessage() async throws {
        let message = try? TwitchChatMessage(string: "")
        #expect(message == nil)
    }

    @Test func basicMessage() async throws {
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
        #expect(message.tags == ["badge-info": "subscriber/13",
                                 "subscriber": "1",
                                 "room-id": "63482386",
                                 "client-nonce": "11b2e915221ab4bcfb44714bda0fb575",
                                 "user-id": "63482386",
                                 "id": "52db2f3d-cc5a-46ea-ba0b-bd910579c248",
                                 "first-msg": "0",
                                 "badges": "broadcaster/1,subscriber/0,turbo/1",
                                 "turbo": "1",
                                 "mod": "0",
                                 "tmi-sent-ts": "1760946171865",
                                 "display-name": "eerimoq",
                                 "returning-chatter": "0"])
        #expect(message.sourceString == "eerimoq!eerimoq@eerimoq.tmi.twitch.tv")
        #expect(message.command == .privateMessage)
        #expect(message.parameters == ["#eerimoq", "hi all"])
    }
}
