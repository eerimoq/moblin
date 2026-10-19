import Foundation
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

    @Test(arguments: [
        ("rain", .rain),
        ("rai", .rain),
        ("balloons", .balloons),
        ("balons", .balloons),
    ] as [(String, ChatBotReactionArgument?)])
    func fuzzyMatchReaction(word: String, expected: ChatBotReactionArgument?) throws {
        let message = createMessage(text: "!moblin \(word)")
        let command = try #require(ChatBotCommand(message: message, aliases: []))
        #expect(command.popFirstArgument(ChatBotReactionArgument.self) == expected)
    }

    @Test(arguments: ["!", ".", "/"])
    func enabledPrefix(prefix: String) throws {
        let message = createMessage(text: "\(prefix)MOBLIN scene \"Main Camera\"")
        let command = try #require(ChatBotCommand(message: message, aliases: [], prefixes: [prefix]))
        #expect(command.popFirstArgument(ChatBotMainArgument.self) == .scene)
        #expect(command.popFirst() == "Main Camera")
        #expect(command.message.segments.first?.text?.trim() == "\(prefix)MOBLIN")
    }

    @Test(arguments: ["!", ".", "/"])
    func aliasUsesEveryEnabledPrefix(prefix: String) throws {
        let alias = SettingsChatBotAlias()
        alias.alias = "!screen"
        alias.replacement = "!moblin scene \"Main Camera\""
        let message = createMessage(text: "\(prefix)SCREEN extra")
        let command = try #require(ChatBotCommand(message: message, aliases: [alias], prefixes: [prefix]))
        #expect(command.popAll() == ["scene", "Main Camera", "extra"])
        #expect(alias.alias == "!screen")
        #expect(alias.replacement == "!moblin scene \"Main Camera\"")
    }

    @Test(arguments: ["!", ".", "/"])
    func disabledPrefixes(prefix: String) {
        let alias = SettingsChatBotAlias()
        alias.alias = "!screen"
        alias.replacement = "!moblin scene Screen"
        let enabled = ChatBotPrefix.supported.filter { $0 != prefix }
        for text in ["\(prefix)moblin scene Screen", "\(prefix)screen"] {
            #expect(ChatBotCommand(message: createMessage(text: text), aliases: [alias], prefixes: enabled) ==
                nil)
            #expect(ChatBotPrefix.commandName(text.components(separatedBy: " ")[0], prefixes: enabled) == nil)
        }
    }

    @Test(arguments: ["", "!", ".", "/", "!!moblin", "./moblin", "//moblin", "moblin", "?moblin",
                      ". moblin", ".moblinx scene Screen", "/unknown", ".hello/world"])
    func invalidCommand(text: String) {
        #expect(ChatBotCommand(message: createMessage(text: text), aliases: [],
                               prefixes: ChatBotPrefix.supported) == nil)
    }

    @Test
    func aliasPreservesArguments() throws {
        let alias = SettingsChatBotAlias()
        alias.alias = "!announce"
        alias.replacement = "!moblin say Keep !This .That /Here https://Example.org/Foo"
        let command = try #require(ChatBotCommand(message: createMessage(text: ".announce MoreText"),
                                                  aliases: [alias], prefixes: ["."]))
        #expect(command.popAll() == [
            "say",
            "Keep",
            "!This",
            ".That",
            "/Here",
            "https://Example.org/Foo",
            "MoreText",
        ])
    }

    @Test
    func legacyAliasPrecedence() throws {
        let imported = SettingsChatBotAlias()
        imported.alias = "/SCREEN"
        imported.replacement = "/moblin scene Imported"
        let original = SettingsChatBotAlias()
        original.alias = "!screen"
        original.replacement = "!moblin scene Original"
        let message = createMessage(text: ".screen")
        let command = try #require(ChatBotCommand(
            message: message,
            aliases: [imported, original],
            prefixes: ["."]
        ))
        #expect(command.popAll() == ["scene", "Original"])
        let fallback = try #require(ChatBotCommand(message: message, aliases: [imported], prefixes: ["."]))
        #expect(fallback.popAll() == ["scene", "Imported"])
    }

    @Test(arguments: ["!moblinx scene Screen", "!screen scene Screen", "!moblin", "!moblin   "])
    func malformedAliasReplacement(replacement: String) {
        let alias = SettingsChatBotAlias()
        alias.alias = "!screen"
        alias.replacement = replacement
        #expect(ChatBotCommand(message: createMessage(text: ".screen"), aliases: [alias], prefixes: ["."]) ==
            nil)
    }

    @Test
    func canonicalEditorValues() {
        #expect(ChatBotPrefix.canonicalAlias("/SCREEN") == "!screen")
        #expect(ChatBotPrefix.canonicalAlias(".moblinOther") == nil)
        #expect(ChatBotPrefix.canonicalAlias(".two words") == nil)
        #expect(ChatBotPrefix.canonicalReplacement("/MOBLIN say \"Keep Case!\" /Here")
            == "!moblin say \"Keep Case!\" /Here")
    }

    @Test
    func currentSettingsRejectQueuedPrefixAfterItIsDisabled() {
        let chat = SettingsChat()
        chat.botCommandPrefixes = ["!", "."]
        let message = createMessage(text: ".moblin scene Main")
        #expect(ChatBotCommand(message: message, aliases: [], prefixes: chat.effectiveBotCommandPrefixes) !=
            nil)
        chat.botCommandPrefixes = ["!"]
        #expect(ChatBotCommand(message: message, aliases: [], prefixes: chat.effectiveBotCommandPrefixes) ==
            nil)
    }

    @Test(arguments: ["!", ".", "/"])
    func customCommandAlias(prefix: String) throws {
        let alias = SettingsChatBotAlias()
        alias.alias = "!hello"
        alias.replacement = "!moblin custom Hello"
        for text in ["\(prefix)moblin custom Hello", "\(prefix)hello"] {
            let command = try #require(ChatBotCommand(message: createMessage(text: text), aliases: [alias],
                                                      prefixes: [prefix]))
            #expect(command.popFirstArgument(ChatBotMainArgument.self) == .custom)
            #expect(command.popFirst() == "Hello")
        }
    }

    @Test
    func nonTextFirstSegmentIsNotACommand() {
        let message = ChatBotMessage(platform: .twitch, user: nil, isOwner: false, isModerator: false,
                                     isSubscriber: false, userId: nil,
                                     segments: [.init(id: 0), .init(id: 1, text: "!moblin ")])
        #expect(ChatBotCommand(message: message, aliases: [], prefixes: ChatBotPrefix.supported) == nil)
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
