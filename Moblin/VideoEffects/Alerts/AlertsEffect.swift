import AVFoundation
import Collections
import SwiftUI
import Vision
import WrappingHStack

private struct Word: Identifiable {
    let id: UUID = .init()
    let text: String
}

private class GifImages {
    private var images: Deque<AlertsEffectGifImage> = []
    private var basePresentationTimeStamp: Double?

    init() {}

    init(images: Deque<AlertsEffectGifImage>) {
        self.images = images
    }

    func getImage(_ presentationTimeStamp: Double) -> CIImage? {
        if basePresentationTimeStamp == nil {
            basePresentationTimeStamp = presentationTimeStamp
        }
        let timeOffset = presentationTimeStamp - basePresentationTimeStamp!
        while let image = images.first {
            if timeOffset >= image.timeOffset {
                images.removeFirst()
                continue
            }
            return image.image
        }
        return nil
    }

    func isEmpty() -> Bool {
        return images.isEmpty
    }
}

enum AlertsEffectAlert {
    case twitchFollow(TwitchEventSubNotificationChannelFollowEvent)
    case twitchSubscribe(TwitchEventSubNotificationChannelSubscribeEvent)
    case twitchSubscrptionGift(TwitchEventSubNotificationChannelSubscriptionGiftEvent)
    case twitchResubscribe(TwitchEventSubNotificationChannelSubscriptionMessageEvent)
    case twitchRaid(TwitchEventSubChannelRaidEvent)
    case twitchCheer(TwitchEventSubChannelCheerEvent)
    case kickSubscription(event: KickPusherSubscriptionEvent)
    case kickGiftedSubscriptions(event: KickPusherGiftedSubscriptionsEvent)
    case kickHost(event: KickPusherStreamHostEvent)
    case kickReward(event: KickPusherRewardRedeemedEvent)
    case kickKicks(event: KickPusherKicksGiftedEvent)
    case chatBotCommand(String, String)
    case speechToTextString(UUID)
}

protocol AlertsEffectDelegate: AnyObject {
    func alertsMakeErrorToast(title: String)
}

private struct Pipeline {
    var playing: Bool = false
    var messageImage: CIImage?
    var gifImages = GifImages()
    var x: Double = 0
    var y: Double = 0
    var landmarkSettings: AlertsEffectLandmarkSettings?

    mutating func getImage(_ presentationTimeStamp: Double) -> CIImage? {
        defer {
            playing = !gifImages.isEmpty()
        }
        return gifImages.getImage(presentationTimeStamp)
    }
}

final class AlertsEffect: VideoEffect, @unchecked Sendable {
    private var audioPlayer: AVAudioPlayer?
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
    private var kickSubscriptionMedia = AlertsEffectMedia()
    private var kickGiftedSubscriptionsMedias = AlertsEffectMedia()
    private var kickHostMedia = AlertsEffectMedia()
    private var kickRewardMedia = AlertsEffectMedia()
    private var kickGiftsMedias: [AlertsEffectMedia] = []
    private var chatBotCommandsMedias: [AlertsEffectMedia] = []
    private var speechToTextStringsMedias: [AlertsEffectMedia] = []
    private let bundledImages: [SettingsAlertsMediaGalleryItem]
    private let bundledSounds: [SettingsAlertsMediaGalleryItem]
    private var aiBaseUrl: URL?
    private var pipeline = Pipeline()

    init(
        settings: SettingsWidgetAlerts,
        delegate: AlertsEffectDelegate,
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

    override func getName() -> String {
        return "Alert widget"
    }

    override func needsFaceDetections(_: Double) -> (Bool, UUID?, Double?) {
        return (pipeline.landmarkSettings != nil, nil, nil)
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        let (alertImage, messageImage) = getNext(info.presentationTimeStamp.seconds)
        guard let alertImage, let messageImage else {
            return image
        }
        if let landmarkSettings = pipeline.landmarkSettings {
            return executePositionFace(image, info.sceneFaceDetections(), alertImage, landmarkSettings)
        } else {
            return executePositionScene(image, alertImage, messageImage, pipeline.x, pipeline.y)
        }
    }

    override func isEnabled() -> Bool {
        return pipeline.playing
    }

    func setSettings(settings: SettingsWidgetAlerts) {
        setTwitchSettings(twitch: settings.twitch)
        setKickSettings(kick: settings.kick)
        setChatBotSettings(settings: settings)
        setSpeechToTextSettings(settings: settings)
        aiBaseUrl = URL(string: settings.ai.baseUrl)
        self.settings = settings
    }

    func getSettings() -> SettingsWidgetAlerts {
        return settings
    }

    func setPosition(x: Double, y: Double) {
        processorPipelineQueue.async {
            self.pipeline.x = x
            self.pipeline.y = y
        }
    }

    @MainActor
    func play(alert: AlertsEffectAlert) {
        alertsQueue.append(alert)
        tryPlayNextAlert()
    }

    private func setChatBotSettings(settings: SettingsWidgetAlerts) {
        chatBotCommandsMedias = []
        for command in settings.chatBot.commands {
            let (image, imageLoopCount, sound) = getMediaItems(alert: command.alert)
            let media = AlertsEffectMedia()
            media.updateImages(image: image, loopCount: imageLoopCount)
            media.updateSoundUrl(sound: sound)
            chatBotCommandsMedias.append(media)
        }
    }

    private func getMediaItems(alert: SettingsWidgetAlertsAlert)
        -> (AlertsEffectMediaItem, Int, AlertsEffectMediaItem)
    {
        let image: AlertsEffectMediaItem
        if let bundledImage = bundledImages.first(where: { $0.id == alert.imageId }) {
            image = .bundledName(bundledImage.name)
        } else {
            image = .customUrl(mediaStorage.makePath(id: alert.imageId))
        }
        let sound: AlertsEffectMediaItem
        if let bundledSound = bundledSounds.first(where: { $0.id == alert.soundId }) {
            sound = .bundledName(bundledSound.name)
        } else {
            sound = .customUrl(mediaStorage.makePath(id: alert.soundId))
        }
        return (image, alert.imageLoopCount, sound)
    }

    private func setSpeechToTextSettings(settings: SettingsWidgetAlerts) {
        speechToTextStringsMedias = []
        for string in settings.speechToText.strings {
            let (image, imageLoopCount, sound) = getMediaItems(alert: string.alert)
            let media = AlertsEffectMedia()
            media.updateImages(image: image, loopCount: imageLoopCount)
            media.updateSoundUrl(sound: sound)
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
        case let .twitchRaid(event):
            playTwitchRaid(event: event)
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
        guard let stringIndex = settings.speechToText.strings.firstIndex(where: { $0.id == id && $0.alert.enabled })
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
        let gifImages = GifImages(images: media.images)
        let soundUrl = media.soundUrl
        let ai = self.settings.ai
        if self.settings.aiEnabled, let aiBaseUrl, ai.isConfigured() {
            OpenAi(baseUrl: aiBaseUrl, apiKey: ai.apiKey)
                .ask(message, model: ai.model, role: ai.personality) { answer in
                    DispatchQueue.main.async {
                        var message = message
                        if let answer {
                            message += ". " + answer
                        } else {
                            self.delegate?.alertsMakeErrorToast(title: String(localized: "Got no AI response"))
                        }
                        self.play(gifImages: gifImages,
                                  soundUrl: soundUrl,
                                  username: username,
                                  message: message,
                                  messageImage: messageImage,
                                  landmarkSettings: landmarkSettings,
                                  settings: settings)
                    }
                }
        } else {
            play(gifImages: gifImages,
                 soundUrl: soundUrl,
                 username: username,
                 message: message,
                 messageImage: messageImage,
                 landmarkSettings: landmarkSettings,
                 settings: settings)
        }
    }

    private func play(gifImages: GifImages,
                      soundUrl: URL?,
                      username: String,
                      message: String,
                      messageImage: CIImage?,
                      landmarkSettings: AlertsEffectLandmarkSettings?,
                      settings: SettingsWidgetAlertsAlert)
    {
        processorPipelineQueue.async {
            self.pipeline.gifImages = gifImages
            self.pipeline.messageImage = messageImage
            self.pipeline.playing = true
            self.pipeline.landmarkSettings = landmarkSettings
        }
        if let soundUrl {
            audioPlayer = try? AVAudioPlayer(contentsOf: soundUrl)
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
                               settings: SettingsWidgetAlertsAlert) -> CIImage?
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
        guard let image = renderer.uiImage else {
            return nil
        }
        return CIImage(image: image)
    }

    private func isInRectangle(_ x: Double, _ y: Double, _ rectangle: AlertsEffectBackgroundLandmarkRectangle) -> Bool {
        return x > rectangle.topLeftX && x < rectangle.bottomRightX && y > rectangle.topLeftY && y < rectangle
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

    private func calculateLandmarkSettings(settings: SettingsWidgetAlertsAlert) -> AlertsEffectLandmarkSettings? {
        if settings.positionType == .face {
            let landmark = calculateLandmark(settings: settings)
            let centerX = settings.facePosition.x + settings.facePosition.width / 2
            let centerY = settings.facePosition.y + settings.facePosition.height / 2
            let landmarkRectangle: AlertsEffectBackgroundLandmarkRectangle
            switch landmark {
            case .face:
                landmarkRectangle = alertsEffectBackgroundFaceRectangle
            case .leftEye:
                landmarkRectangle = alertsEffectBackgroundLeftEyeRectangle
            case .rightEye:
                landmarkRectangle = alertsEffectBackgroundRightEyeRectangle
            case .mouth:
                landmarkRectangle = alertsEffectBackgroundMouthRectangle
            }
            let x = (centerX - landmarkRectangle.topLeftX) / landmarkRectangle.width()
            let y = (centerY - landmarkRectangle.topLeftY) / landmarkRectangle.height()
            let height = settings.facePosition.height / alertsEffectBackgroundFaceRectangle.height()
            return AlertsEffectLandmarkSettings(landmark: landmark, height: height, centerX: x, centerY: y)
        } else {
            return nil
        }
    }

    private func getNext(_ presentationTimeStamp: Double) -> (CIImage?, CIImage?) {
        defer {
            if !pipeline.playing {
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
            guard let rotationAngle = detection.calcFaceAngle(imageSize: image.extent.size) else {
                continue
            }
            guard let boundingBox = detection.stableBoundingBox(
                imageSize: image.extent.size,
                rotationAngle: rotationAngle
            ) else {
                continue
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
                    continue
                }
                var points = leftEye.pointsInImage(imageSize: image.extent.size)
                points = rotateFace(allPoints: points, rotationAngle: -rotationAngle)
                guard let boundingBox = calcBoundingBox(points: points) else {
                    continue
                }
                centerX = boundingBox.minX + landmarkSettings.centerX * boundingBox.width
                centerY = boundingBox.minY - landmarkSettings.centerY * boundingBox.height
            case .rightEye:
                guard let rightEye = detection.landmarks?.rightEye else {
                    continue
                }
                var points = rightEye.pointsInImage(imageSize: image.extent.size)
                points = rotateFace(allPoints: points, rotationAngle: -rotationAngle)
                guard let boundingBox = calcBoundingBox(points: points) else {
                    continue
                }
                centerX = boundingBox.minX + landmarkSettings.centerX * boundingBox.width
                centerY = boundingBox.minY - landmarkSettings.centerY * boundingBox.height
            case .mouth:
                guard let outerLips = detection.landmarks?.outerLips else {
                    continue
                }
                var points = outerLips.pointsInImage(imageSize: image.extent.size)
                points = rotateFace(allPoints: points, rotationAngle: -rotationAngle)
                guard let boundingBox = calcBoundingBox(points: points) else {
                    continue
                }
                centerX = boundingBox.minX + landmarkSettings.centerX * boundingBox.width
                centerY = boundingBox.minY - landmarkSettings.centerY * boundingBox.height
            }
            let moblinImage = alertImage
                .scaled(x: alertImageHeight / alertImage.extent.height,
                        y: alertImageHeight / alertImage.extent.height)
            let centerPoint = rotatePoint(
                point: .init(x: centerX - moblinImage.extent.midX, y: centerY - moblinImage.extent.midY),
                alpha: rotationAngle
            )
            outputImage = moblinImage
                .transformed(by: CGAffineTransform(rotationAngle: rotationAngle))
                .translated(x: centerPoint.x, y: centerPoint.y)
                .composited(over: outputImage)
        }
        return outputImage.cropped(to: image.extent)
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
}

private func makeRoundedRectangleMask(_ image: CIImage) -> CIImage? {
    let roundedRectangleGenerator = CIFilter.roundedRectangleGenerator()
    roundedRectangleGenerator.color = .green
    // Slightly smaller to remove ~1px black line around image.
    var extent = image.extent
    extent.origin.x += 1
    extent.origin.y += 1
    extent.size.width -= 2
    extent.size.height -= 2
    roundedRectangleGenerator.extent = extent
    var radiusPixels = Float(min(image.extent.height, image.extent.width))
    radiusPixels /= 2
    radiusPixels *= 100
    roundedRectangleGenerator.radius = radiusPixels
    return roundedRectangleGenerator.outputImage
}

private func makeCircle(_ image: CIImage) -> CIImage {
    let roundedCornersBlender = CIFilter.blendWithMask()
    roundedCornersBlender.inputImage = image
    roundedCornersBlender.maskImage = makeRoundedRectangleMask(image)
    return roundedCornersBlender.outputImage ?? image
}

extension AlertsEffect {
    private func setTwitchSettings(twitch: SettingsWidgetAlertsTwitch) {
        var (image, imageLoopCount, sound) = getMediaItems(alert: twitch.follows)
        twitchFollowMedia.updateImages(image: image, loopCount: imageLoopCount)
        twitchFollowMedia.updateSoundUrl(sound: sound)
        (image, imageLoopCount, sound) = getMediaItems(alert: twitch.subscriptions)
        twitchSubscribeMedia.updateImages(image: image, loopCount: imageLoopCount)
        twitchSubscribeMedia.updateSoundUrl(sound: sound)
        (image, imageLoopCount, sound) = getMediaItems(alert: twitch.raids)
        twitchRaidMedia.updateImages(image: image, loopCount: imageLoopCount)
        twitchRaidMedia.updateSoundUrl(sound: sound)
        twitchCheersMedias = []
        for cheerBits in twitch.cheerBits {
            (image, imageLoopCount, sound) = getMediaItems(alert: cheerBits.alert)
            let media = AlertsEffectMedia()
            media.updateImages(image: image, loopCount: imageLoopCount)
            media.updateSoundUrl(sound: sound)
            twitchCheersMedias.append(media)
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
        play(
            media: twitchSubscribeMedia,
            username: event.user_name,
            message: String(localized: "just subscribed tier \(event.tierAsNumber())!"),
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
        play(
            media: twitchSubscribeMedia,
            username: event.user_name,
            message: String(localized: """
            just resubscribed tier \(event.tierAsNumber()) for \(event.cumulative_months) \
            months! \(event.message.text)
            """),
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
        var (image, imageLoopCount, sound) = getMediaItems(alert: kick.subscriptions)
        kickSubscriptionMedia.updateImages(image: image, loopCount: imageLoopCount)
        kickSubscriptionMedia.updateSoundUrl(sound: sound)
        (image, imageLoopCount, sound) = getMediaItems(alert: kick.giftedSubscriptions)
        kickGiftedSubscriptionsMedias.updateImages(image: image, loopCount: imageLoopCount)
        kickGiftedSubscriptionsMedias.updateSoundUrl(sound: sound)
        (image, imageLoopCount, sound) = getMediaItems(alert: kick.hosts)
        kickHostMedia.updateImages(image: image, loopCount: imageLoopCount)
        kickHostMedia.updateSoundUrl(sound: sound)
        (image, imageLoopCount, sound) = getMediaItems(alert: kick.rewards)
        kickRewardMedia.updateImages(image: image, loopCount: imageLoopCount)
        kickRewardMedia.updateSoundUrl(sound: sound)
        kickGiftsMedias = []
        for kickGift in kick.kickGifts {
            (image, imageLoopCount, sound) = getMediaItems(alert: kickGift.alert)
            let media = AlertsEffectMedia()
            media.updateImages(image: image, loopCount: imageLoopCount)
            media.updateSoundUrl(sound: sound)
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
             message: String(localized: "just subscribed! They've been subscribed for \(event.months) months!"),
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
            let matches: Bool
            switch kickGift.comparisonOperator {
            case .equal:
                matches = event.gift.amount == kickGift.amount
            case .greaterEqual:
                matches = event.gift.amount >= kickGift.amount
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
