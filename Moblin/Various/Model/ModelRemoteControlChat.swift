import Foundation

private struct ChatUpdateEffects {
    var chats = ChangeTracker()
    var messages = ChangeTracker()
    var customCommands = ChangeTracker()
    var textToSpeechOff = false
    var bluetoothSpeakerOnly = ChangeTracker()
}

private func updatePermissions(_ permissions: SettingsChatBotPermissionsCommand,
                               _ new: SettingsChatBotPermissionsCommand)
{
    permissions.moderatorsEnabled = new.moderatorsEnabled
    permissions.subscribersEnabled = new.subscribersEnabled
    permissions.minimumSubscriberTier = new.minimumSubscriberTier
    permissions.othersEnabled = new.othersEnabled
    permissions.sendChatMessages = new.sendChatMessages
    permissions.cooldown = new.cooldown
}

func updateChatBotPermissions(_ permissions: SettingsChatBotPermissions, _ new: SettingsChatBotPermissions) {
    for (command, newCommand) in zip(permissions.all(), new.all()) {
        updatePermissions(command, newCommand)
    }
}

extension Model {
    func remoteControlGetChat(secrets: Bool) -> SettingsChat? {
        guard let copy = database.chat.deepCopy() else {
            return nil
        }
        if !secrets {
            copy.removeSecrets()
        }
        return copy
    }

    func remoteControlUpdateChat(chat new: SettingsChat, secrets: Bool) -> Bool {
        let chat = database.chat
        if !secrets {
            new.keepSecrets(from: chat)
        }
        guard isValidRemoteControlChatUpdate(chat: chat, new: new) else {
            return false
        }
        var effects = ChatUpdateEffects()
        effects.chats.apply(&chat.enabled, new.enabled)
        chat.activityFeed = new.activityFeed
        chat.background = new.background
        updateChatAppearance(chat, new, &effects)
        updateChatLayout(chat, new, &effects)
        chat.filters = new.filters
        var nicknames = chat.nicknames.nicknames.map { [$0.id.uuidString, $0.user, $0.nickname] }
        effects.messages.apply(
            &nicknames,
            new.nicknames.nicknames.map { [$0.id.uuidString, $0.user, $0.nickname] }
        )
        chat.nicknames.nicknames = new.nicknames.nicknames
        chat.maximumAge = new.maximumAge
        chat.maximumAgeEnabled = new.maximumAgeEnabled
        effects.messages.apply(&chat.showDeletedMessages, new.showDeletedMessages)
        updateChatTextToSpeech(chat, new, &effects)
        updateChatBot(chat, new, &effects)
        if effects.chats.changed {
            reloadChats()
        }
        if effects.messages.changed {
            reloadChatMessages()
        }
        if effects.customCommands.changed {
            chatBotCustomCommandsTextChanged()
        }
        if effects.textToSpeechOff {
            chatTextToSpeech.reset(running: true)
        }
        chatTextToSpeech.setRate(rate: chat.textToSpeechRate)
        chatTextToSpeech.setVolume(volume: chat.textToSpeechSayVolume)
        chatTextToSpeech.setVoices(voices: chat.textToSpeechLanguageVoices)
        chatTextToSpeech.setSayUsername(value: chat.textToSpeechSayUsername)
        chatTextToSpeech.setDefaultLanguage(value: chat.textToSpeechDefaultLanguage)
        chatTextToSpeech.setDetectLanguagePerMessage(value: chat.textToSpeechDetectLanguagePerMessage)
        chatTextToSpeech.setFilter(value: chat.textToSpeechFilter)
        chatTextToSpeech.setFilterMentions(value: chat.textToSpeechFilterMentions)
        chatTextToSpeech.setPauseBetweenMessages(value: chat.textToSpeechPauseBetweenMessages)
        if effects.bluetoothSpeakerOnly.changed {
            stopTextToSpeechIfOutputNotAllowed()
        }
        return true
    }

    private func updateChatAppearance(_ chat: SettingsChat,
                                      _ new: SettingsChat,
                                      _ effects: inout ChatUpdateEffects)
    {
        effects.messages.apply(&chat.fontSize, new.fontSize)
        effects.messages.apply(&chat.font, new.font)
        effects.messages.apply(&chat.boldUsername, new.boldUsername)
        effects.messages.apply(&chat.boldMessage, new.boldMessage)
        effects.messages.apply(&chat.bigGifScale, new.bigGifScale)
        chat.displayStyle = new.displayStyle
        effects.messages.apply(&chat.timestampColorEnabled, new.timestampColorEnabled)
        effects.messages.apply(&chat.badges, new.badges)
        effects.messages.apply(&chat.animatedEmotes, new.animatedEmotes)
        effects.messages.apply(&chat.sharedChatIcons, new.sharedChatIcons)
        effects.messages.apply(&chat.compactEvents, new.compactEvents)
        if effects.messages.apply(&chat.timestampColor, new.timestampColor) {
            chat.timestampColorColor = new.timestampColor.color()
        }
        if effects.messages.apply(&chat.usernameColor, new.usernameColor) {
            chat.usernameColorColor = new.usernameColor.color()
        }
        chat.sameUsernameColor = new.sameUsernameColor
        if effects.messages.apply(&chat.messageColor, new.messageColor) {
            chat.messageColorColor = new.messageColor.color()
        }
        if effects.messages.apply(&chat.backgroundColor, new.backgroundColor) {
            chat.backgroundColorColor = new.backgroundColor.color()
        }
        effects.messages.apply(&chat.backgroundColorEnabled, new.backgroundColorEnabled)
        if effects.messages.apply(&chat.shadowColor, new.shadowColor) {
            chat.shadowColorColor = new.shadowColor.color()
        }
        effects.messages.apply(&chat.shadowColorEnabled, new.shadowColorEnabled)
        chat.meInUsernameColor = new.meInUsernameColor
    }

    private func updateChatLayout(_ chat: SettingsChat,
                                  _ new: SettingsChat,
                                  _ effects: inout ChatUpdateEffects)
    {
        effects.messages.apply(&chat.height, new.height)
        effects.messages.apply(&chat.width, new.width)
        effects.messages.apply(&chat.bottomPoints, new.bottomPoints)
        chat.newMessagesAtTop = new.newMessagesAtTop
        chat.mirrored = new.mirrored
    }

    private func updateChatTextToSpeech(_ chat: SettingsChat,
                                        _ new: SettingsChat,
                                        _ effects: inout ChatUpdateEffects)
    {
        effects.textToSpeechOff = chat.textToSpeechEnabled && !new.textToSpeechEnabled
        chat.textToSpeechEnabled = new.textToSpeechEnabled
        chat.textToSpeechLanguageVoices = new.textToSpeechLanguageVoices
        chat.textToSpeechSayVolume = new.textToSpeechSayVolume
        chat.textToSpeechRate = new.textToSpeechRate
        chat.textToSpeechPauseBetweenMessages = new.textToSpeechPauseBetweenMessages
        chat.textToSpeechDefaultLanguage = new.textToSpeechDefaultLanguage
        chat.textToSpeechDetectLanguagePerMessage = new.textToSpeechDetectLanguagePerMessage
        chat.textToSpeechSayUsername = new.textToSpeechSayUsername
        chat.textToSpeechSayEmotes = new.textToSpeechSayEmotes
        chat.textToSpeechSubscribersOnly = new.textToSpeechSubscribersOnly
        chat.textToSpeechFilter = new.textToSpeechFilter
        chat.textToSpeechFilterMentions = new.textToSpeechFilterMentions
        effects.bluetoothSpeakerOnly.apply(&chat.textToSpeechBluetoothSpeakerOnly,
                                           new.textToSpeechBluetoothSpeakerOnly)
        if chat.ttsMonster.apiToken != new.ttsMonster.apiToken {
            chat.ttsMonster.apiToken = new.ttsMonster.apiToken
            chatTextToSpeech.setTtsMonsterApiToken(apiToken: chat.ttsMonster.apiToken)
        }
        if chat.elevenLabs.apiKey != new.elevenLabs.apiKey {
            chat.elevenLabs.apiKey = new.elevenLabs.apiKey
            chatTextToSpeech.setElevenLabsApiKey(apiKey: chat.elevenLabs.apiKey)
        }
    }

    private func updateChatBot(_ chat: SettingsChat,
                               _ new: SettingsChat,
                               _ effects: inout ChatUpdateEffects)
    {
        effects.customCommands.apply(&chat.botEnabled, new.botEnabled)
        chat.botSendLowBatteryWarning = new.botSendLowBatteryWarning
        updateChatBotPermissions(chat.botCommandPermissions, new.botCommandPermissions)
        chat.botCommandAi.baseUrl = new.botCommandAi.baseUrl
        chat.botCommandAi.apiKey = new.botCommandAi.apiKey
        chat.botCommandAi.model = new.botCommandAi.model
        chat.botCommandAi.personality = new.botCommandAi.personality
        chat.botCommandSnapshot.source = new.botCommandSnapshot.source
        chat.botCommandSnapshot.webRemoteControlMode = new.botCommandSnapshot.webRemoteControlMode
        chat.botCommandSnapshot
            .webRemoteControlUrl = cleanUrl(url: new.botCommandSnapshot.webRemoteControlUrl)
        chat.aliases = new.aliases
        let customCommands = new.customCommands.map { newCustomCommand in
            guard let customCommand = chat.customCommands.first(where: { $0.id == newCustomCommand.id })
            else {
                return newCustomCommand
            }
            customCommand.name = newCustomCommand.name
            effects.customCommands.apply(&customCommand.formatString, newCustomCommand.formatString)
            updatePermissions(customCommand.permissions, newCustomCommand.permissions)
            return customCommand
        }
        effects.customCommands.applyItems(&chat.customCommands, customCommands)
    }
}
