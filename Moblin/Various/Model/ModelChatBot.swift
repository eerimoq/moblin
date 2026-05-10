import AVFoundation
import Foundation
import NaturalLanguage

private let askedByLanguage = [
    "ar": "سأل",
    "bg": "попита",
    "ca": "va preguntar",
    "cs": "se zeptal",
    "da": "spurgte",
    "de": "fragte",
    "en": "asked",
    "el": "ερωτηθείς",
    "es": "preguntó",
    "fi": "kysyi",
    "fr": "demandée",
    "he": "שאל",
    "hi": "पूछा",
    "hr": "pitao",
    "hu": "kérdezte",
    "id": "diminta",
    "it": "chiesto",
    "ja": "尋ねた",
    "ko": "질문",
    "ms": "bertanya",
    "nb": "spurte",
    "nl": "vroeg",
    "no": "spurte",
    "pl": "zapytał",
    "pt": "perguntou",
    "ro": "a întrebat",
    "ru": "спросил",
    "sk": "sa spýtal",
    "sl": "vprašal",
    "sv": "frågade",
    "ta": "என்று கேட்டார்",
    "th": "ถาม",
    "tr": "sordu",
    "uk": "запитав",
    "vi": "yêu cầu",
    "zh": "问",
]

private let answerByLanguage = [
    "ar": "إجابة",
    "bg": "отговор",
    "ca": "Respon",
    "cs": "Odpověď",
    "da": "Svar",
    "de": "Antwort",
    "en": "Answer",
    "el": "Ερωτηθείς",
    "es": "Respuesta",
    "fi": "Vastaus",
    "fr": "Répondre",
    "he": "תְשׁוּבָה",
    "hi": "उत्तर",
    "hr": "Odgovor",
    "hu": "Válasz",
    "id": "Menjawab",
    "it": "Risposta",
    "ja": "答え",
    "ko": "답변",
    "ms": "Jawab",
    "nb": "Svare",
    "nl": "Antwoord",
    "no": "Svare",
    "pl": "Odpowiedź",
    "pt": "Resposta",
    "ro": "Răspuns",
    "ru": "Отвечать",
    "sk": "Odpoveď",
    "sl": "Odgovori",
    "sv": "Svar",
    "ta": "பதில்",
    "th": "คำตอบ",
    "tr": "Cevap",
    "uk": "Відповідь",
    "vi": "Trả lời",
    "zh": "回答",
]

private func getAsked(_ language: String) -> String {
    askedByLanguage[language] ?? ""
}

private func getAnswer(_ language: String) -> String {
    answerByLanguage[language] ?? ""
}

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
            case "zoom":
                handleChatBotMessageZoom(command: command)
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
            case "ai":
                handleChatBotMessageAi(command: command)
            case "twitch":
                handleChatBotMessageTwitch(command: command)
            case "gimbal":
                handleChatBotMessageGimbal(command: command)
            case "macro":
                handleChatBotMessageMacro(command: command)
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

    @MainActor
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

    @MainActor
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

    @MainActor
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

    @MainActor
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

    @MainActor
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

    @MainActor
    private func handleChatBotMessageLocationDataReset(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.location,
            command: command
        ) {
            self.resetLocationData()
        }
    }

    @MainActor
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

    @MainActor
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

    @MainActor
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
            self.setQuickButton(type: .mute, isOn: true)
            self.updateQuickButtonStates()
        }
    }

    @MainActor
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
            self.setQuickButton(type: .mute, isOn: false)
            self.updateQuickButtonStates()
        }
    }

    @MainActor
    private func handleChatBotMessageAi(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.ai,
            command: command
        ) {
            switch command.popFirst() {
            case "ask":
                self.handleChatBotMessageAiAsk(command: command)
            default:
                break
            }
        }
    }

    private func handleChatBotMessageAiAsk(command: ChatBotCommand) {
        var question = command.rest()
        let ai = database.chat.botCommandAi
        guard let baseUrl = URL(string: ai.baseUrl) else {
            return
        }
        OpenAi(baseUrl: baseUrl, apiKey: ai.apiKey)
            .ask(question, model: ai.model, role: ai.personality) { answer in
                guard let answer else {
                    return
                }
                guard let user = command.message.user else {
                    return
                }
                let recognizer = NLLanguageRecognizer()
                recognizer.processString(question)
                let language = recognizer.dominantLanguage?.rawValue ?? Locale.current.language.languageCode?
                    .identifier
                guard let language else {
                    return
                }
                if question.last?.isPunctuation != true {
                    question += ","
                }
                let message = "\(user) \(getAsked(language)): \(question) \(getAnswer(language)): \(answer)"
                self.sendChatBotReply(message: "\(message)", platform: command.message.platform)
            }
    }

    @MainActor
    private func handleChatBotMessageTwitch(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.twitch,
            command: command
        ) {
            switch command.popFirst() {
            case "raid":
                self.handleChatBotMessageTwitchRaid(command: command)
            default:
                break
            }
        }
    }

    private func handleChatBotMessageTwitchRaid(command: ChatBotCommand) {
        let channelName = command.rest()
        searchTwitchChannel(stream: stream, channelName: channelName) { channel in
            guard let channel else {
                self.makeErrorToast(title: String(localized: "Raid failed"),
                                    subTitle: String(localized: "Channel \(channelName) not found"))
                return
            }
            self.startRaidTwitchChannel(channelId: channel.id) {
                switch $0 {
                case .success:
                    break
                default:
                    self.makeErrorToast(title: String(localized: "Failed to raid \(channelName)"))
                }
            }
        }
    }

    @MainActor
    private func handleChatBotMessageGimbal(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.gimbal,
            command: command
        ) {
            switch command.popFirst() {
            case "preset":
                self.handleChatBotMessageGimbalPreset(command: command)
            default:
                break
            }
        }
    }

    private func handleChatBotMessageGimbalPreset(command: ChatBotCommand) {
        guard let presetName = command.popFirst() else {
            return
        }
        guard let preset = database.gimbal.presets.first(where: {
            $0.name.lowercased() == presetName.lowercased()
        }) else {
            return
        }
        moveToGimbalPreset(id: preset.id)
    }

    private func handleChatBotMessageMacro(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.macro,
            command: command
        ) {
            guard let subcommand = command.popFirst(),
                  let macroName = command.popFirst(),
                  let macro = self.database.macros.macros.first(where: {
                      $0.name.lowercased() == macroName.lowercased()
                  })
            else {
                return
            }
            switch subcommand {
            case "run":
                self.handleChatBotMessageMacroRun(macro: macro)
            case "cancel":
                self.handleChatBotMessageMacroCancel(macro: macro)
            default:
                break
            }
        }
    }

    private func handleChatBotMessageMacroRun(macro: SettingsMacrosMacro) {
        startMacro(macro: macro)
    }

    private func handleChatBotMessageMacroCancel(macro: SettingsMacrosMacro) {
        stopMacro(macro: macro)
    }

    @MainActor
    private func handleChatBotMessageReaction(command: ChatBotCommand) {
        guard #available(iOS 17, *) else {
            return
        }
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.reaction,
            command: command
        ) {
            guard let reaction = SettingsReaction(value: command.popFirst()) else {
                return
            }
            self.triggerReaction(reaction: reaction)
        }
    }

    @available(iOS 17, *)
    func triggerReaction(reaction: SettingsReaction) {
        if let reaction = reaction.toSystem() {
            triggerAppleReaction(reaction: reaction)
        } else {
            switch reaction {
            case .glasses:
                triggerGlasses()
            case .sparkle:
                triggerSparkle()
            default:
                break
            }
        }
    }

    @available(iOS 17, *)
    private func triggerAppleReaction(reaction: AVCaptureReactionType) {
        guard let scene = getSelectedScene() else {
            return
        }
        for device in getBuiltinCameraDevices(scene: scene, sceneDevice: cameraDevice).devices
            where device.device.availableReactionTypes.contains(reaction)
        {
            device.device.performEffect(for: reaction)
        }
    }

    @MainActor
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

    @MainActor
    private func handleChatBotMessageStream(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.stream,
            command: command
        ) {
            switch command.popFirst() {
            case "start":
                self.handleChatBotMessageStreamStart()
            case "stop":
                self.handleChatBotMessageStreamStop()
            case "title":
                self.handleChatBotMessageStreamTitle(command: command)
            case "category":
                self.handleChatBotMessageStreamCategory(command: command)
            default:
                break
            }
        }
    }

    private func handleChatBotMessageStreamStart() {
        startStream()
    }

    private func handleChatBotMessageStreamStop() {
        _ = stopStream()
    }

    private func handleChatBotMessageStreamTitle(command: ChatBotCommand) {
        setTwitchStreamTitle(stream: stream, title: command.rest())
    }

    private func handleChatBotMessageStreamCategory(command: ChatBotCommand) {
        fetchTwitchGameId(stream: stream, name: command.rest()) { gameId in
            guard let gameId else {
                return
            }
            self.setTwitchStreamCategory(stream: self.stream, categoryId: gameId)
        }
    }

    @MainActor
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
            case "enable":
                self.handleChatBotMessageWidgetEnable(widget: widget)
            case "disable":
                self.handleChatBotMessageWidgetDisable(widget: widget)
            case "timer":
                self.handleChatBotMessageWidgetTimer(command: command, widget: widget)
            case "wheelofluck":
                self.handleChatBotMessageWidgetWheelOfLuck(command: command, widget: widget)
            default:
                break
            }
        }
    }

    private func handleChatBotMessageWidgetEnable(widget: SettingsWidget) {
        widget.enabled = true
        reloadSpeechToText()
        sceneUpdated(attachCamera: isCaptureDeviceWidget(widget: widget))
    }

    private func handleChatBotMessageWidgetDisable(widget: SettingsWidget) {
        widget.enabled = false
        reloadSpeechToText()
        sceneUpdated(attachCamera: isCaptureDeviceWidget(widget: widget))
    }

    private func handleChatBotMessageWidgetTimer(command: ChatBotCommand, widget: SettingsWidget) {
        let effects = getTextEffects(id: widget.id)
        guard !effects.isEmpty else {
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
            for effect in effects {
                effect.setEndTime(index: index, endTime: timer.textEffectEndTime())
            }
        default:
            break
        }
    }

    private func handleChatBotMessageWidgetWheelOfLuck(command: ChatBotCommand, widget: SettingsWidget) {
        guard let effect = getWheelOfLuckEffect(id: widget.id) else {
            return
        }
        switch command.popFirst() {
        case "spin":
            effect.spin()
        case "options":
            let options = command.popAll()
            widget.wheelOfLuck.optionsFromText(text: options.joined(separator: "\n"))
            getWheelOfLuckEffect(id: widget.id)?.setSettings(settings: widget.wheelOfLuck)
        default:
            break
        }
    }

    @MainActor
    private func handleChatBotMessageAlert(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.alert,
            command: command
        ) {
            guard let alert = command.popFirst() else {
                return
            }
            self.playAlert(alert: .chatBotCommand(alert, command.user() ?? "Unknown"))
        }
    }

    @MainActor
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

    @MainActor
    private func handleChatBotMessageFilter(command: ChatBotCommand) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions.filter,
            command: command
        ) {
            guard let filter = command.popFirst(), let state = command.popFirst() else {
                return
            }
            let on = state == "on"
            switch filter {
            case "movie":
                self.setFilterQuickButton(type: .movie, on: on)
            case "grayscale":
                self.setFilterQuickButton(type: .grayScale, on: on)
            case "sepia":
                self.setFilterQuickButton(type: .sepia, on: on)
            case "triple":
                self.setFilterQuickButton(type: .triple, on: on)
            case "twin":
                self.setFilterQuickButton(type: .twin, on: on)
            case "pixellate":
                self.setPixellateQuickButton(on: on)
            case "4:3":
                self.setFilterQuickButton(type: .fourThree, on: on)
            case "whirlpool":
                self.setWhirlpoolQuickButton(on: on)
            case "pinch":
                self.setPinchQuickButton(on: on)
            default:
                break
            }
        }
    }

    @MainActor
    private func handleChatBotMessageZoom(command: ChatBotCommand) {
        let permissions = database.chat.botCommandPermissions.zoom
        executeIfUserAllowedToUseChatBot(
            permissions: permissions,
            command: command
        ) {
            guard let x = Float(command.rest()) else {
                guard permissions.sendChatMessages else {
                    return
                }
                self.sendChatBotReply(
                    message: String(localized: "Sorry, zoom x must be a number."),
                    platform: command.message.platform
                )
                return
            }
            self.setZoomX(x: x, rate: self.database.zoom.speed)
        }
    }

    @MainActor
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
            sendTwitchChatMessage(message: message) { _ in }
        case .kick:
            sendKickChatMessage(message: message)
        default:
            break
        }
    }

    @MainActor
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
            if let cooldown = permissions.cooldown,
               let latestExecutionTime = permissions.latestExecutionTime
            {
                let elapsed = latestExecutionTime.duration(to: now)
                let timeLeftOfCooldown = .seconds(cooldown) - elapsed
                guard timeLeftOfCooldown < .seconds(0) else {
                    if permissions.sendChatMessages, let user = command.user() {
                        self.sendChatBotReply(message: String(localized: """
                        \(user) Sorry, but this chat bot command is on cooldown for \(Int(timeLeftOfCooldown
                                .seconds)) \
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
                        createTwitchApi(stream: stream).getBroadcasterSubscriptions(
                            broadcasterId: stream.twitchChannelId,
                            userId: userId
                        ) { data in
                            DispatchQueue.main.async {
                                if let tier = data?.tierAsNumber(),
                                   tier >= permissions.minimumSubscriberTier
                                {
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
