import Foundation

private func isValidChange<T: Equatable>(_ old: T, _ new: T, _ isValid: (T) -> Bool) -> Bool {
    old == new || isValid(new)
}

func isValidChatBotAlias(alias: String) -> Bool {
    alias.starts(with: "!")
        && alias.count > 1
        && !alias.starts(with: "!moblin")
        && alias.split(separator: " ").count == 1
}

func isValidChatBotAliasReplacement(replacement: String) -> Bool {
    replacement.starts(with: "!moblin") && replacement.split(separator: " ").count > 1
}

func isValidRemoteControlChatUpdate(chat: SettingsChat, new: SettingsChat) -> Bool {
    isValidChange(chat.fontSize, new.fontSize) { (10 ... 30).contains($0) }
        && isValidChange(chat.bigGifScale, new.bigGifScale) { (1 ... 10).contains($0) }
        && isValidChange(chat.height, new.height) { (0.2 ... 1).contains($0) }
        && isValidChange(chat.width, new.width) { (0.2 ... 1).contains($0) }
        && isValidChange(chat.bottomPoints, new.bottomPoints) { (0 ... 200).contains($0) }
        && isValidChange(chat.maximumAge, new.maximumAge) { $0 > 0 }
        && isValidChange(chat.textToSpeechSayVolume, new.textToSpeechSayVolume) { (0.3 ... 1).contains($0) }
        && isValidChange(chat.textToSpeechRate, new.textToSpeechRate) { (0.3 ... 0.6).contains($0) }
        && isValidChange(chat.textToSpeechPauseBetweenMessages, new.textToSpeechPauseBetweenMessages) {
            (0.5 ... 15).contains($0)
        }
        && hasUniqueIds(new.filters.map(\.id))
        && hasUniqueIds(new.nicknames.nicknames.map(\.id))
        && isValidBotUpdate(chat, new)
}

private func hasUniqueIds(_ ids: [UUID]) -> Bool {
    Set(ids).count == ids.count
}

private func isValidBotUpdate(_ chat: SettingsChat, _ new: SettingsChat) -> Bool {
    isValidChange(chat.botCommandAi.baseUrl, new.botCommandAi.baseUrl) { isValidHttpUrl(url: $0) == nil }
        && isValidChange(chat.botCommandSnapshot.webRemoteControlUrl,
                         cleanUrl(url: new.botCommandSnapshot.webRemoteControlUrl))
        {
            isValidHttpUrl(url: $0) == nil
        }
        && zip(chat.botCommandPermissions.all(), new.botCommandPermissions.all())
        .allSatisfy { isValidPermissionsUpdate($0, $1) }
        && hasUniqueIds(new.customCommands.map(\.id))
        && new.customCommands.allSatisfy { isValidCustomCommand(chat, $0) }
        && new.aliases.allSatisfy { isValidAlias(chat, $0) }
}

private func isValidPermissionsUpdate(_ permissions: SettingsChatBotPermissionsCommand,
                                      _ new: SettingsChatBotPermissionsCommand) -> Bool
{
    isValidChange(permissions.minimumSubscriberTier, new.minimumSubscriberTier) { (1 ... 3).contains($0) }
        && isValidChange(permissions.cooldown, new.cooldown) {
            $0 == nil || [1, 2, 3, 5, 10, 15, 30, 60].contains($0)
        }
}

private func isValidCustomCommand(_ chat: SettingsChat, _ new: SettingsChatBotCustomCommand) -> Bool {
    guard let customCommand = chat.customCommands.first(where: { $0.id == new.id }) else {
        return !new.name.isEmpty && isValidPermissionsUpdate(.init(), new.permissions)
    }
    return isValidChange(customCommand.name, new.name) { !$0.isEmpty }
        && isValidPermissionsUpdate(customCommand.permissions, new.permissions)
}

private func isValidAlias(_ chat: SettingsChat, _ new: SettingsChatBotAlias) -> Bool {
    (chat.aliases.contains { $0.alias == new.alias } || isValidChatBotAlias(alias: new.alias))
        && (chat.aliases.contains { $0.replacement == new.replacement }
            || isValidChatBotAliasReplacement(replacement: new.replacement))
}
