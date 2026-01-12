@testable import Moblin
import Testing

struct ChatBotCommandSuite {
    @Test
    func simplePopFirst() async throws {
        let message = createMessage(text: "!moblin widget Foo enable")
        let command = ChatBotCommand(message: message, aliases: [])!
        #expect(command.rest() == "widget Foo enable")
        #expect(command.popFirst() == "widget")
        #expect(command.popFirst() == "Foo")
        #expect(command.popFirst() == "enable")
        #expect(command.popFirst() == nil)
        #expect(command.rest() == "")
    }

    @Test
    func simplePopAll() async throws {
        let message = createMessage(text: "!moblin widget Foo enable")
        let command = ChatBotCommand(message: message, aliases: [])!
        #expect(command.rest() == "widget Foo enable")
        #expect(command.popAll() == ["widget", "Foo", "enable"])
        #expect(command.rest() == "")
    }

    @Test
    func quotesPopFirst() async throws {
        let message = createMessage(text: "!moblin widget \"My Foo 1\" enable \"\" a")
        let command = ChatBotCommand(message: message, aliases: [])!
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
    func quotesPopAll() async throws {
        let message = createMessage(text: "!moblin widget \"My Foo 1\" enable \"\" a")
        let command = ChatBotCommand(message: message, aliases: [])!
        #expect(command.popAll() == ["widget", "My Foo 1", "enable", "", "a"])
        #expect(command.rest() == "")
    }

    @Test
    func whitespaces() async throws {
        let message = createMessage(text: "!moblin  widget  \"My   Foo 1\"  enable \"    \"  a")
        let command = ChatBotCommand(message: message, aliases: [])!
        #expect(command.popAll() == ["widget", "My Foo 1", "enable", " ", "a"])
        #expect(command.rest() == "")
    }

    private func createMessage(text: String) -> ChatBotMessage {
        return ChatBotMessage(platform: .twitch,
                              user: "erik",
                              isOwner: true,
                              isModerator: true,
                              isSubscriber: false,
                              userId: "1234",
                              segments: makeChatPostTextSegments(text: text))
    }
}
