import Foundation
@testable import Moblin
import Testing

private func modified(_ chat: SettingsChat, _ edit: (SettingsChat) -> Void = { _ in
}) -> SettingsChat {
    let chat = try! JSONDecoder().decode(SettingsChat.self, from: JSONEncoder().encode(chat))
    edit(chat)
    return chat
}

private func alias(_ alias: String, _ replacement: String) -> SettingsChatBotAlias {
    let botAlias = SettingsChatBotAlias()
    botAlias.alias = alias
    botAlias.replacement = replacement
    return botAlias
}

private func customCommand(_ name: String) -> SettingsChatBotCustomCommand {
    let customCommand = SettingsChatBotCustomCommand()
    customCommand.name = name
    return customCommand
}

private func encoded(_ value: some Encodable) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    return try! String(bytes: encoder.encode(value), encoding: .utf8)!
}

private func withCommands(_ chat: SettingsChat,
                          _ edit: (inout [String: Any], String) -> Void) -> SettingsChat
{
    var json = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(chat)) as! [String: Any]
    var commands = json["botCommandPermissions"] as! [String: [String: Any]]
    for name in commands.keys {
        edit(&commands[name]!, name)
    }
    json["botCommandPermissions"] = commands
    return try! JSONDecoder().decode(SettingsChat.self, from: JSONSerialization.data(withJSONObject: json))
}

private let commandNames = (try! JSONSerialization.jsonObject(
    with: JSONEncoder().encode(SettingsChatBotPermissions())
) as! [String: Any]).keys.sorted()

struct RemoteControlChatConfigValidationSuite {
    final class Fixture {
        let chat = SettingsChat()

        init() {
            chat.filters = [SettingsChatFilter(), SettingsChatFilter()]
            chat.nicknames.nicknames = [SettingsChatNickname(), SettingsChatNickname()]
            chat.aliases = [alias("!myalias", "!moblin")]
            chat.customCommands = [customCommand("first"), customCommand("")]
            chat.botCommandSnapshot.webRemoteControlUrl = ""
            chat.botCommandPermissions.fix.cooldown = 7
        }
    }

    struct ChatCase: CustomTestStringConvertible {
        let testDescription: String
        let edit: @Sendable (SettingsChat) -> Void

        init(_ description: String, edit: @escaping @Sendable (SettingsChat) -> Void) {
            testDescription = description
            self.edit = edit
        }
    }

    @Test(arguments: commandNames)
    func tierOfEveryCommandIsChecked(name: String) {
        let chat = SettingsChat()
        #expect(!isValidRemoteControlChatUpdate(chat: chat, new: withCommands(chat) { command, commandName in
            if commandName == name {
                command["minimumSubscriberTier"] = 4
            }
        }))
    }

    @Test
    func everyCommandIsUpdated() {
        let chat = SettingsChat()
        let new = withCommands(chat) { command, _ in
            command["othersEnabled"] = true
            command["cooldown"] = 5
        }
        updateChatBotPermissions(chat.botCommandPermissions, new.botCommandPermissions)
        #expect(encoded(chat.botCommandPermissions) == encoded(new.botCommandPermissions))
    }

    @Test
    func echoIsAccepted() {
        let fixture = Fixture()
        #expect(isValidRemoteControlChatUpdate(chat: fixture.chat, new: modified(fixture.chat)))
    }

    @Test(arguments: [
        ChatCase("Font size too small") { $0.fontSize = 9 },
        ChatCase("Font size too big") { $0.fontSize = 31 },
        ChatCase("Big GIF scale too small") { $0.bigGifScale = 0 },
        ChatCase("Big GIF scale too big") { $0.bigGifScale = 11 },
        ChatCase("Height too small") { $0.height = 0.1 },
        ChatCase("Height too big") { $0.height = 1.1 },
        ChatCase("Width too small") { $0.width = 0.1 },
        ChatCase("Bottom negative") { $0.bottomPoints = -5 },
        ChatCase("Bottom too big") { $0.bottomPoints = 205 },
        ChatCase("Maximum age zero") { $0.maximumAge = 0 },
        ChatCase("Volume too low") { $0.textToSpeechSayVolume = 0.2 },
        ChatCase("Rate too high") { $0.textToSpeechRate = 0.7 },
        ChatCase("Pause too short") { $0.textToSpeechPauseBetweenMessages = 0 },
        ChatCase("Pause too long") { $0.textToSpeechPauseBetweenMessages = 15.5 },
        ChatCase("Two filters with the same id") { $0.filters[1].id = $0.filters[0].id },
        ChatCase("Two nicknames with the same id") {
            $0.nicknames.nicknames[1].id = $0.nicknames.nicknames[0].id
        },
        ChatCase("Two custom commands with the same id") { $0.customCommands[1].id = $0.customCommands[0].id
        },
        ChatCase("Malformed AI base URL") { $0.botCommandAi.baseUrl = "no url" },
        ChatCase("Malformed snapshot URL") { $0.botCommandSnapshot.webRemoteControlUrl = "no url" },
        ChatCase("Subscriber tier too low") { $0.botCommandPermissions.tts.minimumSubscriberTier = 0 },
        ChatCase("Subscriber tier too high") { $0.botCommandPermissions.vibrate.minimumSubscriberTier = 4 },
        ChatCase("Cooldown not in list") { $0.botCommandPermissions.scene.cooldown = 4 },
        ChatCase("Renamed custom command to empty") { $0.customCommands[0].name = "" },
        ChatCase("New custom command without name") { $0.customCommands.append(customCommand("")) },
        ChatCase("Custom command cooldown not in list") { $0.customCommands[0].permissions.cooldown = 4 },
        ChatCase("New custom command with tier too high") {
            let command = customCommand("second")
            command.permissions.minimumSubscriberTier = 4
            $0.customCommands.append(command)
        },
        ChatCase("Alias without !") { $0.aliases[0].alias = "alias" },
        ChatCase("Alias of only !") { $0.aliases[0].alias = "!" },
        ChatCase("Alias starting with !moblin") { $0.aliases[0].alias = "!moblinx" },
        ChatCase("Alias of two words") { $0.aliases[0].alias = "!my alias" },
        ChatCase("Replacement not starting with !moblin") { $0.aliases[0].replacement = "!other tts on" },
        ChatCase("New replacement of one word") { $0.aliases.append(alias("!other", "!moblinx")) },
    ])
    func invalidChangeIsRefused(testCase: ChatCase) {
        let fixture = Fixture()
        #expect(!isValidRemoteControlChatUpdate(chat: fixture.chat,
                                                new: modified(fixture.chat, testCase.edit)))
    }

    @Test(arguments: [
        ChatCase("Font size at the limits") { $0.fontSize = 30 },
        ChatCase("Height at the lower limit") { $0.height = 0.2 },
        ChatCase("Bottom at the upper limit") { $0.bottomPoints = 200 },
        ChatCase("Rate at the upper limit") { $0.textToSpeechRate = 0.6 },
        ChatCase("Empty AI base URL") { $0.botCommandAi.baseUrl = "" },
        ChatCase("Snapshot URL") { $0.botCommandSnapshot.webRemoteControlUrl = "http://192.168.1.10:80" },
        ChatCase("Cooldown") { $0.botCommandPermissions.scene.cooldown = 60 },
        ChatCase("No cooldown") { $0.botCommandPermissions.fix.cooldown = nil },
        ChatCase("Other field of a command with an old cooldown") {
            $0.botCommandPermissions.fix.othersEnabled = true
        },
        ChatCase("Text of a custom command with an old empty name") {
            $0.customCommands[1].formatString = "Hi"
        },
        ChatCase("New custom command") { $0.customCommands.append(customCommand("second")) },
        ChatCase("Removed custom command") { $0.customCommands.removeFirst() },
        ChatCase("New alias") { $0.aliases.append(alias("!scene", "!moblin scene Main")) },
        ChatCase("Alias next to an old one word replacement") { $0.aliases[0].alias = "!other" },
        ChatCase("Removed filter") { $0.filters.removeLast() },
        ChatCase("Reordered nicknames") { $0.nicknames.nicknames.reverse() },
    ])
    func validChangeIsAccepted(testCase: ChatCase) {
        let fixture = Fixture()
        #expect(isValidRemoteControlChatUpdate(chat: fixture.chat,
                                               new: modified(fixture.chat, testCase.edit)))
    }
}
