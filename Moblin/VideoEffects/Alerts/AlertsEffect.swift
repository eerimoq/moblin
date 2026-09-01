import AVFoundation
import Collections
import MetalPetal
import SwiftUI
import Vision
import WrappingHStack

private struct Word: Identifiable {
    let id: UUID = .init()
    let text: String
}

enum AlertsEffectAlert {
    case twitchFollow(TwitchEventSubNotificationChannelFollowEvent)
    case twitchSubscribe(TwitchEventSubNotificationChannelSubscribeEvent)
    case twitchSubscrptionGift(TwitchEventSubNotificationChannelSubscriptionGiftEvent)
    case twitchResubscribe(TwitchEventSubNotificationChannelSubscriptionMessageEvent)
    case twitchSubscriptionUpgrade(TwitchEventSubNotificationChannelSubscriptionUpgradeEvent)
    case twitchRaid(TwitchEventSubChannelRaidEvent)
    case twitchRedemption(TwitchEventSubNotificationChannelPointsCustomRewardRedemptionAddEvent)
    case twitchCheer(TwitchEventSubChannelCheerEvent)
    case kickSubscription(event: KickPusherSubscriptionEvent)
    case kickGiftedSubscriptions(event: KickPusherGiftedSubscriptionsEvent)
    case kickHost(event: KickPusherStreamHostEvent)
    case kickReward(event: KickPusherRewardRedeemedEvent)
    case kickKicks(event: KickPusherKicksGiftedEvent)
    case chatBotCommand(String, String)
    case speechToTextString(UUID)
    case quickButton
}

protocol AlertsEffectDelegate: AnyObject {
    func alertsMakeErrorToast(title: String)
}

private struct Pipeline {
    var playing: Bool = false
    var messageImage: EffectImageCiImage?
    var images: any AlertsEffectImages = AlertsEffectGifImages()
    var x: Double = 0
    var y: Double = 0
    var landmarkSettings: AlertsEffectLandmarkSettings?

    mutating func getImage(_ presentationTimeStamp: Double) -> EffectImageCiImage? {
        defer {
            playing = !images.isEmpty()
        }
        return images.getImage(presentationTimeStamp)
    }
}

final class AlertsEffect: VideoEffect, @unchecked Sendable {
    private var audioPlayer: AudioPlayer?
    private var rate: Float = 0.4
    private var volume: Float = 1.0
    private var synthesizer = createSpeechSynthesizer()
    private var alertsQueue: Deque<AlertsEffectAlert> = .init()
    private weak var delegate: (any AlertsEffectDelegate)?
    private var isPlaying: Bool = false
    private var delayAfterPlaying = 3.0
    private var settings: SettingsWidgetAlerts
    private let mediaStorage: AlertMediaStorage
    private var twitchFollowMedia = AlertsEffectMedia()
    private var twitchSubscribeMedia = AlertsEffectMedia()
    private var twitchRaidMedia = AlertsEffectMedia()
    private var twitchCheersMedias: [AlertsEffectMedia] = []
    private var twitchRedemptionMedias: [AlertsEffectMedia] = []
    private var kickSubscriptionMedia = AlertsEffectMedia()
    private var kickGiftedSubscriptionsMedias = AlertsEffectMedia()
    private var kickHostMedia = AlertsEffectMedia()
    private var kickRewardMedia = AlertsEffectMedia()
    private var kickGiftsMedias: [AlertsEffectMedia] = []
    private var chatBotCommandsMedias: [AlertsEffectMedia] = []
    private var speechToTextStringsMedias: [AlertsEffectMedia] = []
    private var quickButtonMedias = AlertsEffectMedia()
    private let bundledImages: [SettingsAlertsMediaGalleryItem]
    private let bundledSounds: [SettingsAlertsMediaGalleryItem]
    private var aiBaseUrl: URL?
    private var pipeline = Pipeline()

    init(
        settings: SettingsWidgetAlerts,
        delegate: any AlertsEffectDelegate,
        mediaStorage: AlertMediaStorage,
        bundledImages: [SettingsAlertsMediaGalleryItem],
        bundledSounds: [SettingsAlertsMediaGalleryItem]
    ) {
        self.settings = settings
        self.delegate = delegate
        self.mediaStorage = mediaStorage
        self.bundledImages = bundledImages
        self.bundledSounds = bundledSounds
        super.init()
        setSettings(settings: settings)
    }

    override func needsFaceDetections(_: Double) -> VideoEffectDetectionsMode {
        if pipeline.landmarkSettings != nil {
            .now(nil)
        } else {
            .off
        }
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        let (alertImage, messageImage) = getNext(info.presentationTimeStamp.seconds)
        guard let alertImage, let messageImage else {
            return image
        }
        if let landmarkSettings = pipeline.landmarkSettings {
            return executePositionFace(image,
                                       info.sceneFaceDetections(),
                                       alertImage.getCiImage(),
                                       landmarkSettings)
        } else {
            return executePositionScene(image,
                                        alertImage.getCiImage(),
                                        messageImage.getCiImage(),
                                        pipeline.x,
                                        pipeline.y)
        }
    }

    override func executeMetalPetal(_ image: MTIImage, _ info: VideoEffectInfo) -> MTIImage {
        let (alertImage, messageImage) = getNext(info.presentationTimeStamp.seconds)
        guard let alertImage, let messageImage else {
            return image
        }
        if let landmarkSettings = pipeline.landmarkSettings {
            return executePositionFaceMetalPetal(image,
                                                 info.sceneFaceDetections(),
                                                 alertImage.getMetalPetalImage(),
                                                 landmarkSettings)
        } else {
            return executePositionSceneMetalPetal(image,
                                                  alertImage.getMetalPetalImage(),
                                                  messageImage.getMetalPetalImage(),
                                                  pipeline.x,
                                                  pipeline.y)
        }
    }

    override func isEnabled() -> Bool {
        pipeline.playing
    }

    func setSettings(settings: SettingsWidgetAlerts) {
        setTwitchSettings(twitch: settings.twitch)
        setKickSettings(kick: settings.kick)
        setChatBotSettings(settings: settings)
        setSpeechToTextSettings(settings: settings)
        setQuickButtonSettings(alert: settings.quickButton)
        aiBaseUrl = URL(string: settings.ai.baseUrl)
        self.settings = settings
    }

    func getSettings() -> SettingsWidgetAlerts {
        settings
    }

    func setPosition(x: Double, y: Double) {
        processorPipelineQueue.async {
            self.pipeline.x = x
            self.pipeline.y = y
        }
    }

    @MainActor
    func play(alert: AlertsEffectAlert) {
        guard shouldAppendAlert(alert: alert) else {
            return
        }
        alertsQueue.append(alert)
        tryPlayNextAlert()
    }

    private func shouldAppendAlert(alert: AlertsEffectAlert) -> Bool {
        guard case .quickButton = alert else {
            return true
        }
        return !isPlaying
    }

    private func setChatBotSettings(settings: SettingsWidgetAlerts) {
        chatBotCommandsMedias = []
        for command in settings.chatBot.commands {
            let media = AlertsEffectMedia()
            media.update(command.alert, mediaStorage, bundledImages, bundledSounds)
            chatBotCommandsMedias.append(media)
        }
    }

    private func setSpeechToTextSettings(settings: SettingsWidgetAlerts) {
        speechToTextStringsMedias = []
        for string in settings.speechToText.strings {
            let media = AlertsEffectMedia()
            media.update(string.alert, mediaStorage, bundledImages, bundledSounds)
            speechToTextStringsMedias.append(media)
        }
    }

    @MainActor
    private func tryPlayNextAlert() {
        guard !isPlaying else {
            return
        }
        guard let alert = alertsQueue.popFirst() else {
            return
        }
        switch alert {
        case let .twitchFollow(event):
            playTwitchFollow(event: event)
        case let .twitchSubscribe(event):
            playTwitchSubscribe(event: event)
        case let .twitchSubscrptionGift(event):
            playTwitchSubscriptionGift(event: event)
        case let .twitchResubscribe(event):
            playTwitchResubscribe(event: event)
        case let .twitchSubscriptionUpgrade(event):
            playTwitchSubscriptionUpgrade(event: event)
        case let .twitchRaid(event):
            playTwitchRaid(event: event)
        case let .twitchRedemption(event: event):
            playTwitchRedemption(event: event)
        case let .twitchCheer(event):
            playTwitchCheer(event: event)
        case let .kickSubscription(event):
            playKickSubscription(event: event)
        case let .kickGiftedSubscriptions(event):
            playKickGiftedSubscriptions(event: event)
        case let .kickHost(event):
            playKickHost(event: event)
        case let .kickReward(event):
            playKickReward(event: event)
        case let .kickKicks(event):
            playKickKicks(event: event)
        case let .chatBotCommand(command, name):
            playChatBotCommand(command: command, name: name)
        case let .speechToTextString(id):
            playSpeechToTextString(id: id)
        case .quickButton:
            playQuickButton()
        }
    }

    @MainActor
    private func playChatBotCommand(command: String, name: String) {
        guard let commandIndex = settings.chatBot.commands
            .firstIndex(where: { command == $0.name && $0.alert.enabled })
        else {
            return
        }
        guard commandIndex < chatBotCommandsMedias.count else {
            return
        }
        let media = chatBotCommandsMedias[commandIndex]
        let settings = settings.chatBot.commands[commandIndex]
        switch settings.imageType {
        case .file:
            play(media: media, username: name, message: command, settings: settings.alert)
        }
    }

    @MainActor
    private func playSpeechToTextString(id: UUID) {
        guard let stringIndex = settings.speechToText.strings
            .firstIndex(where: { $0.id == id && $0.alert.enabled })
        else {
            return
        }
        guard stringIndex < speechToTextStringsMedias.count else {
            return
        }
        play(
            media: speechToTextStringsMedias[stringIndex],
            username: "",
            message: "",
            settings: settings.speechToText.strings[stringIndex].alert,
            delayAfterPlaying: 0.0
        )
    }

    @MainActor
    private func play(
        media: AlertsEffectMedia,
        username: String,
        message: String,
        settings: SettingsWidgetAlertsAlert,
        delayAfterPlaying: Double = 3.0
    ) {
        isPlaying = true
        self.delayAfterPlaying = delayAfterPlaying
        let messageImage = renderMessage(username: username, message: message, settings: settings)
        let landmarkSettings = calculateLandmarkSettings(settings: settings)
        let player = media.getPlayer()
        let ai = self.settings.ai
        if self.settings.aiEnabled, let aiBaseUrl, ai.isConfigured() {
            OpenAi(baseUrl: aiBaseUrl, apiKey: ai.apiKey)
                .ask(message, model: ai.model, role: ai.personality) { result in
                    var message = message
                    switch result {
                    case let .success(answer):
                        message += ". " + answer
                    case let .failure(error):
                        self.delegate?
                            .alertsMakeErrorToast(
                                title: String(localized: "Got no AI response: \(error.description)")
                            )
                    }
                    self.play(player: player,
                              username: username,
                              message: message,
                              messageImage: messageImage,
                              landmarkSettings: landmarkSettings,
                              settings: settings)
                }
        } else {
            play(player: player,
                 username: username,
                 message: message,
                 messageImage: messageImage,
                 landmarkSettings: landmarkSettings,
                 settings: settings)
        }
    }

    private func play(player: AlertsEffectPlayer,
                      username: String,
                      message: String,
                      messageImage: EffectImageCiImage?,
                      landmarkSettings: AlertsEffectLandmarkSettings?,
                      settings: SettingsWidgetAlertsAlert)
    {
        processorPipelineQueue.async {
            self.pipeline.images = player.images
            self.pipeline.messageImage = messageImage
            self.pipeline.playing = true
            self.pipeline.landmarkSettings = landmarkSettings
        }
        if let soundUrl = player.soundUrl {
            audioPlayer = try? AudioPlayer(contentsOf: soundUrl)
            audioPlayer?.play()
        }
        if settings.textToSpeechEnabled {
            say(username: username, message: message, settings: settings)
        }
    }

    private func say(username: String, message: String, settings: SettingsWidgetAlertsAlert) {
        guard let voice = getVoice(settings: settings) else {
            return
        }
        let utterance = AVSpeechUtterance(string: "\(username) \(message)")
        utterance.rate = rate
        utterance.pitchMultiplier = 0.8
        utterance.volume = volume
        utterance.voice = voice
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.textToSpeechDelay) {
            self.synthesizer.speak(utterance)
            KeepSpeakerAlivePlayer.shared.audioPlayed()
        }
    }

    private func getVoice(settings: SettingsWidgetAlertsAlert) -> AVSpeechSynthesisVoice? {
        guard let language = Locale.current.language.languageCode?.identifier else {
            return nil
        }
        if let voiceIdentifier = settings.textToSpeechLanguageVoices[language]?.apple.voice {
            return AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        } else if let voice = AVSpeechSynthesisVoice.speechVoices()
            .filter({ $0.language.starts(with: language) }).first
        {
            return AVSpeechSynthesisVoice(identifier: voice.identifier)
        }
        return nil
    }

    @MainActor
    private func renderMessage(username: String,
                               message: String,
                               settings: SettingsWidgetAlertsAlert) -> EffectImageCiImage?
    {
        let words = message.split(separator: " ").map { Word(text: String($0)) }
        let message = WrappingHStack(
            alignment: .leading,
            horizontalSpacing: 0,
            verticalSpacing: 0,
            fitContentWidth: true
        ) {
            Text("\(username) ")
                .foregroundStyle(settings.accentColor.color())
            ForEach(words) { word in
                Text("\(word.text) ")
                    .foregroundStyle(settings.textColor.color())
            }
        }
        .font(.system(
            size: CGFloat(settings.fontSize),
            weight: settings.fontWeight.toSystem(),
            design: settings.fontDesign.toSystem()
        ))
        .stroke(color: .black, width: 2)
        .frame(width: 1000)
        let renderer = ImageRenderer(content: message)
        guard let image = renderer.uiImage, let image = CIImage(image: image) else {
            return nil
        }
        return image.toEffectImage(isOpaque: false)
    }

    private func isInRectangle(_ x: Double,
                               _ y: Double,
                               _ rectangle: AlertsEffectBackgroundLandmarkRectangle) -> Bool
    {
        x > rectangle.topLeftX && x < rectangle.bottomRightX && y > rectangle.topLeftY && y < rectangle
            .bottomRightY
    }

    private func calculateLandmark(settings: SettingsWidgetAlertsAlert) -> AlertsEffectFaceLandmark {
        let centerX = settings.facePosition.x + settings.facePosition.width / 2
        let centerY = settings.facePosition.y + settings.facePosition.height / 2
        if isInRectangle(centerX, centerY, alertsEffectBackgroundLeftEyeRectangle) {
            return .leftEye
        } else if isInRectangle(centerX, centerY, alertsEffectBackgroundRightEyeRectangle) {
            return .rightEye
        } else if isInRectangle(centerX, centerY, alertsEffectBackgroundMouthRectangle) {
            return .mouth
        } else {
            return .face
        }
    }

    private func calculateLandmarkSettings(settings: SettingsWidgetAlertsAlert)
        -> AlertsEffectLandmarkSettings?
    {
        if settings.positionType == .face {
            let landmark = calculateLandmark(settings: settings)
            let centerX = settings.facePosition.x + settings.facePosition.width / 2
            let centerY = settings.facePosition.y + settings.facePosition.height / 2
            let landmarkRectangle: AlertsEffectBackgroundLandmarkRectangle = switch landmark {
            case .face:
                alertsEffectBackgroundFaceRectangle
            case .leftEye:
                alertsEffectBackgroundLeftEyeRectangle
            case .rightEye:
                alertsEffectBackgroundRightEyeRectangle
            case .mouth:
                alertsEffectBackgroundMouthRectangle
            }
            let x = (centerX - landmarkRectangle.topLeftX) / landmarkRectangle.width()
            let y = (centerY - landmarkRectangle.topLeftY) / landmarkRectangle.height()
            let height = settings.facePosition.height / alertsEffectBackgroundFaceRectangle.height()
            return AlertsEffectLandmarkSettings(landmark: landmark, height: height, centerX: x, centerY: y)
        } else {
            return nil
        }
    }

    private func getNext(_ presentationTimeStamp: Double) -> (EffectImageCiImage?, EffectImageCiImage?) {
        defer {
            if !pipeline.playing {
                pipeline.landmarkSettings = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + delayAfterPlaying) {
                    self.isPlaying = false
                    self.tryPlayNextAlert()
                }
            }
        }
        if let image = pipeline.getImage(presentationTimeStamp) {
            return (image, pipeline.messageImage)
        } else {
            return (nil, nil)
        }
    }

    private func calcFacePlacement(
        _ detection: VNFaceObservation,
        _ imageSize: CGSize,
        _ landmarkSettings: AlertsEffectLandmarkSettings
    ) -> (center: CGPoint, height: Double, rotation: CGFloat)? {
        guard let rotationAngle = detection.calcFaceAngle(imageSize: imageSize) else {
            return nil
        }
        guard let boundingBox = detection.stableBoundingBox(
            imageSize: imageSize,
            rotationAngle: rotationAngle
        ) else {
            return nil
        }
        let faceMinX = boundingBox.minX
        let faceMaxY = boundingBox.maxY
        let faceWidth = boundingBox.width
        let faceHeight = boundingBox.height
        let alertImageHeight = faceHeight * landmarkSettings.height
        var centerX: Double
        var centerY: Double
        switch landmarkSettings.landmark {
        case .face:
            centerX = faceMinX + landmarkSettings.centerX * faceWidth
            centerY = faceMaxY - landmarkSettings.centerY * faceHeight
        case .leftEye:
            guard let leftEye = detection.landmarks?.leftEye else {
                return nil
            }
            var points = leftEye.pointsInImage(imageSize: imageSize)
            points = rotateFace(allPoints: points, rotationAngle: -rotationAngle)
            guard let boundingBox = calcBoundingBox(points: points) else {
                return nil
            }
            centerX = boundingBox.minX + landmarkSettings.centerX * boundingBox.width
            centerY = boundingBox.minY - landmarkSettings.centerY * boundingBox.height
        case .rightEye:
            guard let rightEye = detection.landmarks?.rightEye else {
                return nil
            }
            var points = rightEye.pointsInImage(imageSize: imageSize)
            points = rotateFace(allPoints: points, rotationAngle: -rotationAngle)
            guard let boundingBox = calcBoundingBox(points: points) else {
                return nil
            }
            centerX = boundingBox.minX + landmarkSettings.centerX * boundingBox.width
            centerY = boundingBox.minY - landmarkSettings.centerY * boundingBox.height
        case .mouth:
            guard let outerLips = detection.landmarks?.outerLips else {
                return nil
            }
            var points = outerLips.pointsInImage(imageSize: imageSize)
            points = rotateFace(allPoints: points, rotationAngle: -rotationAngle)
            guard let boundingBox = calcBoundingBox(points: points) else {
                return nil
            }
            centerX = boundingBox.minX + landmarkSettings.centerX * boundingBox.width
            centerY = boundingBox.minY - landmarkSettings.centerY * boundingBox.height
        }
        return (CGPoint(x: centerX, y: centerY), alertImageHeight, rotationAngle)
    }

    private func executePositionFace(
        _ image: CIImage,
        _ faceDetections: [VNFaceObservation]?,
        _ alertImage: CIImage,
        _ landmarkSettings: AlertsEffectLandmarkSettings
    ) -> CIImage {
        guard let faceDetections else {
            return image
        }
        var outputImage = image
        for detection in faceDetections {
            guard let placement = calcFacePlacement(detection, image.extent.size, landmarkSettings) else {
                continue
            }
            let scale = placement.height / alertImage.extent.height
            let moblinImage = alertImage.scaled(x: scale, y: scale)
            let centerPoint = rotatePoint(
                point: .init(x: placement.center.x - moblinImage.extent.midX,
                             y: placement.center.y - moblinImage.extent.midY),
                alpha: placement.rotation
            )
            outputImage = moblinImage
                .transformed(by: CGAffineTransform(rotationAngle: placement.rotation))
                .translated(x: centerPoint.x, y: centerPoint.y)
                .composited(over: outputImage)
        }
        return outputImage.cropped(to: image.extent)
    }

    private func executePositionFaceMetalPetal(
        _ image: MTIImage,
        _ faceDetections: [VNFaceObservation]?,
        _ alertImage: MTIImage,
        _ landmarkSettings: AlertsEffectLandmarkSettings
    ) -> MTIImage {
        guard let faceDetections else {
            return image
        }
        let imageSize = image.extent.size
        let layers: [MTILayer] = faceDetections.compactMap { detection in
            guard let placement = calcFacePlacement(detection, imageSize, landmarkSettings) else {
                return nil
            }
            let scale = placement.height / alertImage.extent.height
            let size = CGSize(width: alertImage.extent.width * scale, height: placement.height)
            let centerPoint = rotatePoint(point: .init(x: placement.center.x - size.width / 2,
                                                       y: placement.center.y - size.height / 2),
                                          alpha: placement.rotation)
            let rotatedCenter = rotatePoint(point: .init(x: size.width / 2, y: size.height / 2),
                                            alpha: placement.rotation)
            let center = CGPoint(x: rotatedCenter.x + centerPoint.x, y: rotatedCenter.y + centerPoint.y)
            return .init(content: alertImage,
                         position: CGPoint(x: center.x, y: imageSize.height - center.y),
                         size: size,
                         rotation: Float(-placement.rotation))
        }
        guard !layers.isEmpty else {
            return image
        }
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = layers
        return filter.outputImage ?? image
    }

    private func executePositionScene(
        _ image: CIImage,
        _ alertImage: CIImage,
        _ messageImage: CIImage,
        _ x: Double,
        _ y: Double
    ) -> CIImage {
        let xPos = toPixels(x, image.extent.width)
        let yPos = image.extent.height - toPixels(y, image.extent.height) - alertImage.extent.height
        return messageImage
            .translated(x: -(messageImage.extent.width - alertImage.extent.width) / 2,
                        y: -messageImage.extent.height)
            .composited(over: alertImage)
            .translated(x: xPos, y: yPos)
            .composited(over: image)
            .cropped(to: image.extent)
    }

    private func executePositionSceneMetalPetal(
        _ image: MTIImage,
        _ alertImage: MTIImage,
        _ messageImage: MTIImage,
        _ x: Double,
        _ y: Double
    ) -> MTIImage {
        let alertSize = alertImage.extent.size
        let messageSize = messageImage.extent.size
        let xPos = toPixels(x, image.extent.width)
        let yPos = toPixels(y, image.extent.height)
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [
            .init(content: alertImage,
                  position: CGPoint(x: xPos + alertSize.width / 2,
                                    y: yPos + alertSize.height / 2)),
            .init(content: messageImage,
                  position: CGPoint(x: xPos + alertSize.width / 2,
                                    y: yPos + alertSize.height + messageSize.height / 2)),
        ]
        return filter.outputImage ?? image
    }
}

extension AlertsEffect {
    private func setTwitchSettings(twitch: SettingsWidgetAlertsTwitch) {
        twitchFollowMedia.update(twitch.follows, mediaStorage, bundledImages, bundledSounds)
        twitchSubscribeMedia.update(twitch.subscriptions, mediaStorage, bundledImages, bundledSounds)
        twitchRaidMedia.update(twitch.raids, mediaStorage, bundledImages, bundledSounds)
        twitchCheersMedias.removeAll()
        for cheerBits in twitch.cheerBits {
            let media = AlertsEffectMedia()
            media.update(cheerBits.alert, mediaStorage, bundledImages, bundledSounds)
            twitchCheersMedias.append(media)
        }
        twitchRedemptionMedias.removeAll()
        for redemption in twitch.redemptions {
            let media = AlertsEffectMedia()
            media.update(redemption, mediaStorage, bundledImages, bundledSounds)
            twitchRedemptionMedias.append(media)
        }
    }

    @MainActor
    private func playTwitchFollow(event: TwitchEventSubNotificationChannelFollowEvent) {
        guard settings.twitch.follows.enabled else {
            return
        }
        play(media: twitchFollowMedia,
             username: event.user_name,
             message: String(localized: "just followed!"),
             settings: settings.twitch.follows)
    }

    @MainActor
    private func playTwitchSubscribe(event: TwitchEventSubNotificationChannelSubscribeEvent) {
        guard settings.twitch.subscriptions.enabled else {
            return
        }
        let message = if event.isPrime() {
            String(localized: "just subscribed with Prime!")
        } else {
            String(localized: "just subscribed tier \(event.tierAsNumber())!")
        }
        play(
            media: twitchSubscribeMedia,
            username: event.user_name,
            message: message,
            settings: settings.twitch.subscriptions
        )
    }

    @MainActor
    private func playTwitchSubscriptionGift(event: TwitchEventSubNotificationChannelSubscriptionGiftEvent) {
        guard settings.twitch.subscriptions.enabled else {
            return
        }
        play(media: twitchSubscribeMedia,
             username: event.user_name ?? "Anomymous",
             message: String(
                 localized: "just gifted \(event.total) tier \(event.tierAsNumber()) subscriptions!"
             ),
             settings: settings.twitch.subscriptions)
    }

    @MainActor
    private func playTwitchResubscribe(event: TwitchEventSubNotificationChannelSubscriptionMessageEvent) {
        guard settings.twitch.subscriptions.enabled else {
            return
        }
        let message = if let streakMonths = event.streak_months {
            String(localized: """
            just resubscribed tier \(event.tierAsNumber()) for \(event.cumulative_months) months, \
            \(streakMonths) in a row! \(event.message.text)
            """)
        } else {
            String(localized: """
            just resubscribed tier \(event.tierAsNumber()) for \(event.cumulative_months) \
            months! \(event.message.text)
            """)
        }
        play(
            media: twitchSubscribeMedia,
            username: event.user_name,
            message: message,
            settings: settings.twitch.subscriptions
        )
    }

    @MainActor
    private func playTwitchSubscriptionUpgrade(
        event: TwitchEventSubNotificationChannelSubscriptionUpgradeEvent
    ) {
        guard settings.twitch.subscriptions.enabled else {
            return
        }
        let message = if let tier = event.tierAsNumber() {
            String(localized: "just converted their Prime subscription to tier \(tier)!")
        } else {
            String(localized: "just continued their gift subscription!")
        }
        play(
            media: twitchSubscribeMedia,
            username: event.user_name,
            message: message,
            settings: settings.twitch.subscriptions
        )
    }

    @MainActor
    private func playTwitchRaid(event: TwitchEventSubChannelRaidEvent) {
        guard settings.twitch.raids.enabled else {
            return
        }
        play(media: twitchRaidMedia,
             username: event.from_broadcaster_user_name,
             message: String(localized: "raided with a party of \(event.viewers)!"),
             settings: settings.twitch.raids)
    }

    @MainActor
    private func playTwitchRedemption(
        event: TwitchEventSubNotificationChannelPointsCustomRewardRedemptionAddEvent
    ) {
        for (index, redemption) in settings.twitch.redemptions.enumerated() where redemption.enabled {
            play(
                media: twitchRedemptionMedias[index],
                username: event.user_name,
                message: String(localized: "redeemed \(event.reward.title)!"),
                settings: redemption
            )
            break
        }
    }

    @MainActor
    private func playTwitchCheer(event: TwitchEventSubChannelCheerEvent) {
        for (index, cheerBit) in settings.twitch.cheerBits.enumerated() where cheerBit.alert.enabled {
            switch cheerBit.comparisonOperator {
            case .equal:
                guard event.bits == cheerBit.bits else {
                    continue
                }
            case .greaterEqual:
                guard event.bits >= cheerBit.bits else {
                    continue
                }
            }
            guard index < twitchCheersMedias.count else {
                return
            }
            let bits = countFormatter.format(event.bits)
            play(
                media: twitchCheersMedias[index],
                username: event.user_name ?? "Anonymous",
                message: String(localized: "cheered \(bits) bits! \(event.message)"),
                settings: cheerBit.alert
            )
            break
        }
    }
}

extension AlertsEffect {
    private func setKickSettings(kick: SettingsWidgetAlertsKick) {
        kickSubscriptionMedia.update(kick.subscriptions, mediaStorage, bundledImages, bundledSounds)
        kickGiftedSubscriptionsMedias.update(
            kick.giftedSubscriptions,
            mediaStorage,
            bundledImages,
            bundledSounds
        )
        kickHostMedia.update(kick.hosts, mediaStorage, bundledImages, bundledSounds)
        kickRewardMedia.update(kick.rewards, mediaStorage, bundledImages, bundledSounds)
        kickGiftsMedias.removeAll()
        for kickGift in kick.kickGifts {
            let media = AlertsEffectMedia()
            media.update(kickGift.alert, mediaStorage, bundledImages, bundledSounds)
            kickGiftsMedias.append(media)
        }
    }

    @MainActor
    private func playKickSubscription(event: KickPusherSubscriptionEvent) {
        guard settings.kick.subscriptions.enabled else {
            return
        }
        play(media: kickSubscriptionMedia,
             username: event.username,
             message: String(
                 localized: "just subscribed! They've been subscribed for \(event.months) months!"
             ),
             settings: settings.kick.subscriptions)
    }

    @MainActor
    private func playKickGiftedSubscriptions(event: KickPusherGiftedSubscriptionsEvent) {
        guard settings.kick.giftedSubscriptions.enabled else {
            return
        }
        play(
            media: kickGiftedSubscriptionsMedias,
            username: event.gifter_username,
            message: String(localized: """
            just gifted \(event.gifted_usernames.count) subscription(s)! They've \
            gifted \(event.gifter_total) in total!
            """),
            settings: settings.kick.giftedSubscriptions
        )
    }

    @MainActor
    private func playKickHost(event: KickPusherStreamHostEvent) {
        guard settings.kick.hosts.enabled else {
            return
        }
        play(media: kickHostMedia,
             username: event.host_username,
             message: String(localized: "is now hosting with \(event.number_viewers) viewers!"),
             settings: settings.kick.hosts)
    }

    @MainActor
    private func playKickReward(event: KickPusherRewardRedeemedEvent) {
        guard settings.kick.rewards.enabled else {
            return
        }
        let baseMessage = String(localized: "redeemed \(event.reward_title)")
        let message = event.user_input.isEmpty ? baseMessage : "\(baseMessage): \(event.user_input)"
        play(media: kickRewardMedia,
             username: event.username,
             message: message,
             settings: settings.kick.rewards)
    }

    @MainActor
    private func playKickKicks(event: KickPusherKicksGiftedEvent) {
        for (index, kickGift) in settings.kick.kickGifts.enumerated() {
            let matches: Bool = switch kickGift.comparisonOperator {
            case .equal:
                event.gift.amount == kickGift.amount
            case .greaterEqual:
                event.gift.amount >= kickGift.amount
            }
            guard matches, kickGift.alert.enabled else {
                continue
            }
            guard index < kickGiftsMedias.count else {
                return
            }
            let formattedAmount = countFormatter.format(event.gift.amount)
            play(
                media: kickGiftsMedias[index],
                username: event.sender.username,
                message: String(localized: "sent \(event.gift.name) \(formattedAmount) Kicks!"),
                settings: kickGift.alert
            )
            break
        }
    }
}

extension AlertsEffect {
    private func setQuickButtonSettings(alert: SettingsWidgetAlertsAlert) {
        quickButtonMedias.update(alert, mediaStorage, bundledImages, bundledSounds)
    }

    @MainActor
    private func playQuickButton() {
        guard settings.quickButton.enabled else {
            return
        }
        play(media: quickButtonMedias,
             username: "",
             message: "",
             settings: settings.quickButton,
             delayAfterPlaying: 0)
    }
}
