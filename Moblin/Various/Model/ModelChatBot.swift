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
        guard let command = ChatBotCommand(message: message, aliases: database.chat.aliases) else {
            return
        }
        switch command.rest() {
        case "help":
            handleChatBotMessageHelp(platform: message.platform)
        case "tts on":
            handleChatBotMessageTtsOn(command: command)
        case "tts off":
            handleChatBotMessageTtsOff(command: command)
        case "obs fix":
            handleChatBotMessageObsFix(command: command)
        case "map zoom out":
            handleChatBotMessageMapZoomOut(command: command)
        case "location data reset":
            handleChatBotMessageLocationDataReset(command: command)
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
            case "widget":
                handleChatBotMessageWidget(command: command)
            default:
                break
            }
        }
    }

    private func handleChatBotMessageHelp(platform: Platform) {
        sendChatBotReply(message: """
                         Moblin chat bot help: \
                         https://github.com/eerimoq/moblin/blob/main/docs/chat-bot-help.md#moblin-chat-bot-help
                         """,
                         platform: platform)
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
            self.chatTextToSpeech.say(
                messageId: nil,
                user: user,
                userId: nil,
                message: command.rest(),
                isRedemption: false
            )
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

    private func handleChatBotMessageLocationDataReset(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.location,
            command: command
        ) {
            self.resetLocationData()
        }
    }

    private func handleChatBotMessageSnapshot(command: ChatBotCommand) {
        let permissions = database.chat.botCommandPermissions.snapshot
        executeIfUserAllowedToUseChatBot(
            permissions: permissions,
            command: command
        ) {
            if let user = command.user() {
                if permissions.sendChatMessages {
                    self.sendChatBotReply(message: self.formatSnapshotTakenSuccessfully(user: user),
                                          platform: command.message.platform)
                }
                self.takeSnapshot(isChatBot: true, message: self.formatSnapshotTakenBy(user: user))
            } else {
                self.takeSnapshot(isChatBot: true)
            }
        } onNotAllowed: {
            if permissions.sendChatMessages, let user = command.user() {
                self.sendChatBotReply(message: self.formatSnapshotTakenNotAllowed(user: user),
                                      platform: command.message.platform)
            }
        }
    }

    private func handleChatBotMessageSnapshotWithMessage(command: ChatBotCommand) {
        let permissions = database.chat.botCommandPermissions.snapshot
        executeIfUserAllowedToUseChatBot(
            permissions: permissions,
            command: command
        ) {
            if permissions.sendChatMessages, let user = command.user() {
                self.sendChatBotReply(message: self.formatSnapshotTakenSuccessfully(user: user),
                                      platform: command.message.platform)
            }
            self.takeSnapshotWithCountdown(
                isChatBot: true,
                message: command.rest(),
                user: command.user()
            )
        } onNotAllowed: {
            if permissions.sendChatMessages, let user = command.user() {
                self.sendChatBotReply(message: self.formatSnapshotTakenNotAllowed(user: user),
                                      platform: command.message.platform)
            }
        }
    }

    private func handleChatBotMessageMute(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.audio,
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
            permissions: database.chat.botCommandPermissions.audio,
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
            permissions: database.chat.botCommandPermissions.reaction,
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
            permissions: database.chat.botCommandPermissions.scene,
            command: command
        ) {
            self.selectSceneByName(name: sceneName)
        }
    }

    private func handleChatBotMessageStream(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.stream,
            command: command
        ) {
            switch command.popFirst() {
            case "title":
                self.handleChatBotMessageStreamTitle(command: command)
            case "category":
                self.handleChatBotMessageStreamCategory(command: command)
            default:
                break
            }
        }
    }

    private func handleChatBotMessageStreamTitle(command: ChatBotCommand) {
        setTwitchStreamTitle(stream: stream, title: command.rest())
    }

    private func handleChatBotMessageStreamCategory(command: ChatBotCommand) {
        fetchTwitchGameId(name: command.rest()) { gameId in
            guard let gameId else {
                return
            }
            self.setTwitchStreamCategory(stream: self.stream, categoryId: gameId)
        }
    }

    private func handleChatBotMessageWidget(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.widget,
            command: command
        ) {
            guard let name = command.popFirst() else {
                return
            }
            guard let widget = self.findWidget(name: name) else {
                return
            }
            switch command.popFirst() {
            case "timer":
                self.handleChatBotMessageWidgetTimer(command: command, widget: widget)
            default:
                break
            }
        }
    }

    private func handleChatBotMessageWidgetTimer(command: ChatBotCommand, widget: SettingsWidget) {
        guard let textEffect = getTextEffect(id: widget.id) else {
            return
        }
        guard let number = command.popFirst(), var index = Int(number) else {
            return
        }
        index -= 1
        guard index < widget.text.timers.count else {
            return
        }
        let timer = widget.text.timers[index]
        switch command.popFirst() {
        case "add":
            guard let delta = command.popFirst(), let delta = Double(delta) else {
                return
            }
            timer.add(delta: delta.clamped(to: -3600 ... 3600))
            textEffect.setEndTime(index: index, endTime: timer.textEffectEndTime())
        default:
            break
        }
    }

    private func handleChatBotMessageAlert(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.alert,
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
            permissions: database.chat.botCommandPermissions.fax,
            command: command
        ) {
            if let url = command.peekFirst(), let url = URL(string: url) {
                self.faxReceiver.add(url: url)
            }
        }
    }

    private func handleChatBotMessageFilter(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.filter,
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
                self.streamOverlay.showingPixellate = state == "on"
            case "4:3":
                type = .fourThree
            case "whirlpool":
                type = .whirlpool
                self.streamOverlay.showingWhirlpool = state == "on"
            case "pinch":
                type = .pinch
                self.streamOverlay.showingPinch = state == "on"
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
            permissions: database.chat.botCommandPermissions.tesla,
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
            tesla.vehicle?.openTrunk()
        case "close":
            tesla.vehicle?.closeTrunk()
        default:
            break
        }
    }

    private func handleChatBotMessageTeslaMedia(command: ChatBotCommand) {
        switch command.popFirst() {
        case "next":
            tesla.vehicle?.mediaNextTrack()
        case "previous":
            tesla.vehicle?.mediaPreviousTrack()
        case "toggle-playback":
            tesla.vehicle?.mediaTogglePlayback()
        default:
            break
        }
    }

    private func sendChatBotReply(message: String, platform: Platform) {
        switch platform {
        case .twitch:
            sendTwitchChatMessage(message: message)
        case .kick:
            sendKickChatMessage(message: message)
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
        let now = ContinuousClock.now
        if isChannelOwner(command: command) {
            permissions.latestExecutionTime = now
            onCompleted()
            return
        }
        if command.message.isModerator, permissions.moderatorsEnabled {
            permissions.latestExecutionTime = now
            onCompleted()
            return
        }
        let onCompleted = {
            if let cooldown = permissions.cooldown, let latestExecutionTime = permissions.latestExecutionTime {
                let elapsed = latestExecutionTime.duration(to: now)
                let timeLeftOfCooldown = .seconds(cooldown) - elapsed
                guard timeLeftOfCooldown < .seconds(0) else {
                    if permissions.sendChatMessages, let user = command.user() {
                        self.sendChatBotReply(message: String(localized: """
                        \(user) Sorry, but this chat bot command is on cooldown for \(Int(timeLeftOfCooldown.seconds)) \
                        seconds. 😢
                        """), platform: command.message.platform)
                    }
                    return
                }
            }
            permissions.latestExecutionTime = now
            onCompleted()
        }
        var onNotAllowed = onNotAllowed
        if permissions.sendChatMessages, onNotAllowed == nil {
            onNotAllowed = {
                if permissions.sendChatMessages, let user = command.user() {
                    self.sendChatBotReply(message: String(localized: """
                    \(user) Sorry, you are not allowed to use this chat bot command 😢
                    """), platform: command.message.platform)
                }
            }
        }
        if command.message.isSubscriber, permissions.subscribersEnabled {
            if command.message.platform == .twitch {
                if permissions.minimumSubscriberTier > 1 {
                    if let userId = command.message.userId {
                        TwitchApi(stream.twitchAccessToken, urlSession).getBroadcasterSubscriptions(
                            broadcasterId: stream.twitchChannelId,
                            userId: userId
                        ) { data in
                            DispatchQueue.main.async {
                                if let tier = data?.tierAsNumber(), tier >= permissions.minimumSubscriberTier {
                                    onCompleted()
                                    return
                                }
                                self.executeIfUserAllowedToUseChatBotAfterSubscribeCheck(
                                    permissions: permissions,
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
            onCompleted: onCompleted,
            onNotAllowed: onNotAllowed
        )
    }

    private func isChannelOwner(command: ChatBotCommand) -> Bool {
        guard let user = command.user() else {
            return false
        }
        switch command.message.platform {
        case .twitch:
            return user.lowercased() == stream.twitchChannelName.lowercased()
        case .kick:
            return user.lowercased() == stream.kickChannelName.lowercased()
        case .youTube:
            return command.message.isOwner
        default:
            return false
        }
    }

    private func executeIfUserAllowedToUseChatBotAfterSubscribeCheck(
        permissions: SettingsChatBotPermissionsCommand,
        onCompleted: @escaping () -> Void,
        onNotAllowed: (() -> Void)?
    ) {
        if permissions.othersEnabled {
            onCompleted()
            return
        }
        onNotAllowed?()
    }
}
