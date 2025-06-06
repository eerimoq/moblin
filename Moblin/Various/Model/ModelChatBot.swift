import AVFoundation
import Foundation

extension Model {
    func executeChatBotMessage() {
        guard let message = chatBotMessages.popFirst() else {
            return
        }
        handleChatBotMessage(message: message)
    }

    private func handleChatBotMessage(message: ChatBotMessage) {
        guard let command = ChatBotCommand(message: message) else {
            return
        }
        switch command.rest() {
        case "help":
            handleChatBotMessageHelp()
        case "tts on":
            handleChatBotMessageTtsOn(command: command)
        case "tts off":
            handleChatBotMessageTtsOff(command: command)
        case "obs fix":
            handleChatBotMessageObsFix(command: command)
        case "map zoom out":
            handleChatBotMessageMapZoomOut(command: command)
        case "snapshot":
            handleChatBotMessageSnapshot(command: command)
        case "mute":
            handleChatBotMessageMute(command: command)
        case "unmute":
            handleChatBotMessageUnmute(command: command)
        default:
            switch command.popFirst() {
            case "alert":
                handleChatBotMessageAlert(command: command)
            case "fax":
                handleChatBotMessageFax(command: command)
            case "filter":
                handleChatBotMessageFilter(command: command)
            case "say":
                handleChatBotMessageTtsSay(command: command)
            case "tesla":
                handleChatBotMessageTesla(command: command)
            case "snapshot":
                handleChatBotMessageSnapshotWithMessage(command: command)
            case "reaction":
                handleChatBotMessageReaction(command: command)
            case "scene":
                handleChatBotMessageScene(command: command)
            case "stream":
                handleChatBotMessageStream(command: command)
            default:
                break
            }
        }
    }

    private func handleChatBotMessageHelp() {
        sendChatMessage(
            message: """
            Moblin chat bot help: \
            https://github.com/eerimoq/moblin/blob/main/docs/chat-bot-help.md#moblin-chat-bot-help
            """
        )
    }

    private func handleChatBotMessageTtsOn(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.tts,
            command: command
        ) {
            self.makeToast(
                title: String(localized: "Chat bot"),
                subTitle: String(localized: "Turning on chat text to speech")
            )
            self.database.chat.textToSpeechEnabled = true
        }
    }

    private func handleChatBotMessageTtsOff(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.tts,
            command: command
        ) {
            self.makeToast(
                title: String(localized: "Chat bot"),
                subTitle: String(localized: "Turning off chat text to speech")
            )
            self.database.chat.textToSpeechEnabled = false
            self.chatTextToSpeech.reset(running: true)
        }
    }

    private func handleChatBotMessageTtsSay(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.tts,
            command: command
        ) {
            let user = command.user() ?? "Unknown"
            self.chatTextToSpeech.say(user: user, message: command.rest(), isRedemption: false)
        }
    }

    private func handleChatBotMessageObsFix(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.fix,
            command: command
        ) {
            if self.obsWebSocket != nil {
                self.makeToast(
                    title: String(localized: "Chat bot"),
                    subTitle: String(localized: "Fixing OBS input")
                )
                self.obsFixStream()
            } else {
                self.makeErrorToast(
                    title: String(localized: "Chat bot"),
                    subTitle: String(
                        localized: "Cannot fix OBS input. OBS remote control is not configured."
                    )
                )
            }
        }
    }

    private func handleChatBotMessageMapZoomOut(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.map,
            command: command
        ) {
            self.makeToast(
                title: String(localized: "Chat bot"),
                subTitle: String(localized: "Zooming out map")
            )
            for mapEffect in self.mapEffects.values {
                mapEffect.zoomOutTemporarily()
            }
        }
    }

    private func handleChatBotMessageSnapshot(command: ChatBotCommand) {
        let permissions = database.chat.botCommandPermissions.snapshot!
        executeIfUserAllowedToUseChatBot(
            permissions: permissions,
            command: command
        ) {
            if let user = command.user() {
                if permissions.sendChatMessages! {
                    self.sendChatMessage(message: self.formatSnapshotTakenSuccessfully(user: user))
                }
                self.takeSnapshot(isChatBot: true, message: self.formatSnapshotTakenBy(user: user))
            } else {
                self.takeSnapshot(isChatBot: true)
            }
        } onNotAllowed: {
            if permissions.sendChatMessages!, let user = command.user() {
                self.sendChatMessage(message: self.formatSnapshotTakenNotAllowed(user: user))
            }
        }
    }

    private func handleChatBotMessageSnapshotWithMessage(command: ChatBotCommand) {
        let permissions = database.chat.botCommandPermissions.snapshot!
        executeIfUserAllowedToUseChatBot(
            permissions: permissions,
            command: command
        ) {
            if permissions.sendChatMessages!, let user = command.user() {
                self.sendChatMessage(message: self.formatSnapshotTakenSuccessfully(user: user))
            }
            self.takeSnapshotWithCountdown(
                isChatBot: true,
                message: command.rest(),
                user: command.user()
            )
        } onNotAllowed: {
            if permissions.sendChatMessages!, let user = command.user() {
                self.sendChatMessage(message: self.formatSnapshotTakenNotAllowed(user: user))
            }
        }
    }

    private func handleChatBotMessageMute(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.audio!,
            command: command
        ) {
            guard !self.isMuteOn else {
                return
            }
            self.makeToast(
                title: String(localized: "Chat bot"),
                subTitle: String(localized: "Muting audio")
            )
            self.setMuted(value: true)
            self.setGlobalButtonState(type: .mute, isOn: true)
            self.updateQuickButtonStates()
        }
    }

    private func handleChatBotMessageUnmute(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.audio!,
            command: command
        ) {
            guard self.isMuteOn else {
                return
            }
            self.makeToast(
                title: String(localized: "Chat bot"),
                subTitle: String(localized: "Unmuting audio")
            )
            self.setMuted(value: false)
            self.setGlobalButtonState(type: .mute, isOn: false)
            self.updateQuickButtonStates()
        }
    }

    private func handleChatBotMessageReaction(command: ChatBotCommand) {
        guard #available(iOS 17, *) else {
            return
        }
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.reaction!,
            command: command
        ) {
            let reaction: AVCaptureReactionType
            switch command.popFirst() {
            case "fireworks":
                reaction = .fireworks
            case "balloons":
                reaction = .balloons
            case "hearts":
                reaction = .heart
            case "confetti":
                reaction = .confetti
            case "lasers":
                reaction = .lasers
            case "rain":
                reaction = .rain
            default:
                return
            }
            guard let scene = self.getSelectedScene() else {
                return
            }
            for device in self.getBuiltinCameraDevices(scene: scene, sceneDevice: self.cameraDevice).devices
                where device.device?.availableReactionTypes.contains(reaction) == true {
                    device.device?.performEffect(for: reaction)
                }
        }
    }

    private func handleChatBotMessageScene(command: ChatBotCommand) {
        guard let sceneName = command.popFirst() else {
            return
        }
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.scene!,
            command: command
        ) {
            self.selectSceneByName(name: sceneName)
        }
    }

    private func handleChatBotMessageStream(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.stream!,
            command: command
        ) {
            switch command.popFirst() {
            case "title":
                self.handleChatBotMessageStreamTitle(command: command)
            default:
                break
            }
        }
    }

    private func handleChatBotMessageStreamTitle(command: ChatBotCommand) {
        guard let title = command.popFirst() else {
            return
        }
        setTwitchStreamTitle(stream: stream, title: title)
    }

    private func handleChatBotMessageAlert(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.alert!,
            command: command
        ) {
            guard let alert = command.popFirst() else {
                return
            }
            let prompt = command.rest()
            DispatchQueue.main.async {
                self.playAlert(alert: .chatBotCommand(alert, command.user() ?? "Unknown", prompt))
            }
        }
    }

    private func handleChatBotMessageFax(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.fax!,
            command: command
        ) {
            if let url = command.peekFirst(), let url = URL(string: url) {
                self.faxReceiver.add(url: url)
            }
        }
    }

    private func handleChatBotMessageFilter(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.filter!,
            command: command
        ) {
            guard let filter = command.popFirst(), let state = command.popFirst() else {
                return
            }
            let type: SettingsQuickButtonType
            switch filter {
            case "movie":
                type = .movie
            case "grayscale":
                type = .grayScale
            case "sepia":
                type = .sepia
            case "triple":
                type = .triple
            case "twin":
                type = .twin
            case "pixellate":
                type = .pixellate
            case "4:3":
                type = .fourThree
            default:
                return
            }
            self.setGlobalButtonState(type: type, isOn: state == "on")
            self.sceneUpdated(updateRemoteScene: false)
            self.updateQuickButtonStates()
        }
    }

    private func handleChatBotMessageTesla(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.tesla!,
            command: command
        ) {
            switch command.popFirst() {
            case "trunk":
                self.handleChatBotMessageTeslaTrunk(command: command)
            case "media":
                self.handleChatBotMessageTeslaMedia(command: command)
            default:
                break
            }
        }
    }

    private func handleChatBotMessageTeslaTrunk(command: ChatBotCommand) {
        switch command.popFirst() {
        case "open":
            teslaVehicle?.openTrunk()
        case "close":
            teslaVehicle?.closeTrunk()
        default:
            break
        }
    }

    private func handleChatBotMessageTeslaMedia(command: ChatBotCommand) {
        switch command.popFirst() {
        case "next":
            teslaVehicle?.mediaNextTrack()
        case "previous":
            teslaVehicle?.mediaPreviousTrack()
        case "toggle-playback":
            teslaVehicle?.mediaTogglePlayback()
        default:
            break
        }
    }

    private func executeIfUserAllowedToUseChatBot(
        permissions: SettingsChatBotPermissionsCommand,
        command: ChatBotCommand,
        onCompleted: @escaping () -> Void,
        onNotAllowed: (() -> Void)? = nil
    ) {
        var onNotAllowed = onNotAllowed
        if permissions.sendChatMessages!, onNotAllowed == nil {
            onNotAllowed = {
                if permissions.sendChatMessages!, let user = command.user() {
                    self
                        .sendChatMessage(
                            message: String(
                                localized: "\(user) Sorry, you are not allowed to use this chat bot command 😢"
                            )
                        )
                }
            }
        }
        if command.message.isModerator, permissions.moderatorsEnabled {
            onCompleted()
            return
        }
        if command.message.isSubscriber, permissions.subscribersEnabled! {
            if command.message.platform == .twitch {
                if permissions.minimumSubscriberTier! > 1 {
                    if let userId = command.message.userId {
                        TwitchApi(stream.twitchAccessToken, urlSession).getBroadcasterSubscriptions(
                            broadcasterId: stream.twitchChannelId,
                            userId: userId
                        ) { data in
                            DispatchQueue.main.async {
                                if let tier = data?.tierAsNumber(),
                                   tier >= permissions.minimumSubscriberTier!
                                {
                                    onCompleted()
                                    return
                                }
                                self.executeIfUserAllowedToUseChatBotAfterSubscribeCheck(
                                    permissions: permissions,
                                    command: command,
                                    onCompleted: onCompleted,
                                    onNotAllowed: onNotAllowed
                                )
                            }
                        }
                        return
                    }
                } else {
                    onCompleted()
                    return
                }
            } else {
                onCompleted()
                return
            }
        }
        executeIfUserAllowedToUseChatBotAfterSubscribeCheck(
            permissions: permissions,
            command: command,
            onCompleted: onCompleted,
            onNotAllowed: onNotAllowed
        )
    }

    private func executeIfUserAllowedToUseChatBotAfterSubscribeCheck(
        permissions: SettingsChatBotPermissionsCommand,
        command: ChatBotCommand,
        onCompleted: @escaping () -> Void,
        onNotAllowed: (() -> Void)?
    ) {
        guard let user = command.user() else {
            return
        }
        switch command.message.platform {
        case .twitch:
            if isTwitchUserAllowedToUseChatBot(permissions: permissions, user: user) {
                onCompleted()
                return
            }
        case .kick:
            if isKickUserAllowedToUseChatBot(permissions: permissions, user: user) {
                onCompleted()
                return
            }
        default:
            break
        }
        onNotAllowed?()
    }

    private func isTwitchUserAllowedToUseChatBot(permissions: SettingsChatBotPermissionsCommand,
                                                 user: String) -> Bool
    {
        if permissions.othersEnabled {
            return true
        }
        return user.lowercased() == stream.twitchChannelName.lowercased()
    }

    private func isKickUserAllowedToUseChatBot(permissions: SettingsChatBotPermissionsCommand,
                                               user: String) -> Bool
    {
        if permissions.othersEnabled {
            return true
        }
        return user.lowercased() == stream.kickChannelName.lowercased()
    }
}
