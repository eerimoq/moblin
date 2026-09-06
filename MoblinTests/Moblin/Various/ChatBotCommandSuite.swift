@testable import Moblin
import Testing

struct ChatBotCommandSuite {
    @Test
    func simplePopFirst() throws {
        let message = createMessage(text: "!moblin widget Foo enable")
        let command = try #require(ChatBotCommand(message: message, aliases: []))
        #expect(command.rest() == "widget Foo enable")
        #expect(command.popFirst() == "widget")
        #expect(command.popFirst() == "Foo")
        #expect(command.popFirst() == "enable")
        #expect(command.popFirst() == nil)
        #expect(command.rest() == "")
    }

    @Test
    func simplePopAll() throws {
        let message = createMessage(text: "!moblin widget Foo enable")
        let command = try #require(ChatBotCommand(message: message, aliases: []))
        #expect(command.rest() == "widget Foo enable")
        #expect(command.popAll() == ["widget", "Foo", "enable"])
        #expect(command.rest() == "")
    }

    @Test
    func quotesPopFirst() throws {
        let message = createMessage(text: "!moblin widget \"My Foo 1\" enable \"\" a")
        let command = try #require(ChatBotCommand(message: message, aliases: []))
        #expect(command.rest() == "widget \"My Foo 1\" enable \"\" a")
        #expect(command.popFirst() == "widget")
        #expect(command.popFirst() == "My Foo 1")
        #expect(command.popFirst() == "enable")
        #expect(command.rest() == "\"\" a")
        #expect(command.popFirst() == "")
        #expect(command.popFirst() == "a")
        #expect(command.popFirst() == nil)
        #expect(command.rest() == "")
    }

    @Test
    func quotesPopAll() throws {
        let message = createMessage(text: "!moblin widget \"My Foo 1\" enable \"\" a")
        let command = try #require(ChatBotCommand(message: message, aliases: []))
        #expect(command.popAll() == ["widget", "My Foo 1", "enable", "", "a"])
        #expect(command.rest() == "")
    }

    @Test
    func whitespaces() throws {
        let message = createMessage(text: "!moblin  widget  \"My   Foo 1\"  enable \"    \"  a")
        let command = try #require(ChatBotCommand(message: message, aliases: []))
        #expect(command.popAll() == ["widget", "My Foo 1", "enable", " ", "a"])
        #expect(command.rest() == "")
    }

    @Test
    func fuzzyPopFirst() throws {
        let message = createMessage(text: "!moblin Snapshto hello")
        let command = try #require(ChatBotCommand(message: message, aliases: []))
        #expect(command.popFirstArgument(ChatBotMainArgument.self) == .snapshot)
        #expect(command.popFirstArgument(ChatBotMainArgument.self) == nil)
        #expect(command.popFirstArgument(ChatBotMainArgument.self) == nil)
    }

    @Test(arguments: [
        ("snapshot", .snapshot),
        ("SNAPSHOT", .snapshot),
        ("snapsht", .snapshot),
        ("snapshhot", .snapshot),
        ("snpashot", .snapshot),
        ("snap", nil),
        ("hot", nil),
        ("s", nil),
        ("zom", .zoom),
        ("zoomm", .zoom),
        ("mure", .mute),
        ("mtue", nil),
        ("umute", nil),
        ("unmtue", .unmute),
        ("sey", .say),
        ("scen", .scene),
        ("fliter", .filter),
        ("hepl", .help),
        ("hello", nil),
        ("a", nil),
        ("ai", .ai),
        ("raid", nil),
    ] as [(String, ChatBotMainArgument?)])
    func fuzzyMatch(word: String, expected: ChatBotMainArgument?) throws {
        let message = createMessage(text: "!moblin \(word)")
        let command = try #require(ChatBotCommand(message: message, aliases: []))
        #expect(command.popFirstArgument(ChatBotMainArgument.self) == expected)
    }

    @Test(arguments: [
        ("on", .on),
        ("onn", .on),
        ("of", .off),
        ("no", nil),
        ("o", nil),
    ] as [(String, ChatBotOnOffArgument?)])
    func fuzzyMatchShortWords(word: String, expected: ChatBotOnOffArgument?) throws {
        let message = createMessage(text: "!moblin \(word)")
        let command = try #require(ChatBotCommand(message: message, aliases: []))
        #expect(command.popFirstArgument(ChatBotOnOffArgument.self) == expected)
    }

    @Test(arguments: [
        ("pixellate", .pixellate),
        ("pixele", .pixellate),
        ("pixlate", .pixellate),
        ("pixeelaate", .pixellate),
        ("4:3", .fourThree),
        ("greyscle", .grayscale),
        ("movi", .movie),
    ] as [(String, ChatBotFilterArgument?)])
    func fuzzyMatchFilter(word: String, expected: ChatBotFilterArgument?) throws {
        let message = createMessage(text: "!moblin \(word)")
        let command = try #require(ChatBotCommand(message: message, aliases: []))
        #expect(command.popFirstArgument(ChatBotFilterArgument.self) == expected)
    }

    private func createMessage(text: String) -> ChatBotMessage {
        ChatBotMessage(platform: .twitch,
                       user: "erik",
                       isOwner: true,
                       isModerator: true,
                       isSubscriber: false,
                       userId: "1234",
                       segments: makeChatPostTextSegments(text: text))
    }
}
