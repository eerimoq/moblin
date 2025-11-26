import AVFoundation
import Collections
import ImagePlayground
import SDWebImage
import SwiftUI
import Vision
import WrappingHStack

private let backgroundFaceImageWidth = 130.0
private let backgroundFaceImageHeight = 160.0

private struct BackgroundLandmarkRectangle {
    let topLeftX: Double
    let topLeftY: Double
    let bottomRightX: Double
    let bottomRightY: Double

    init(topLeftX: Double,
         topLeftY: Double,
         bottomRightX: Double,
         bottomRightY: Double)
    {
        self.topLeftX = topLeftX / backgroundFaceImageWidth
        self.topLeftY = topLeftY / backgroundFaceImageHeight
        self.bottomRightX = bottomRightX / backgroundFaceImageWidth
        self.bottomRightY = bottomRightY / backgroundFaceImageHeight
    }

    func width() -> Double {
        return bottomRightX - topLeftX
    }

    func height() -> Double {
        return bottomRightY - topLeftY
    }
}

private let backgroundLeftEyeRectangle = BackgroundLandmarkRectangle(
    topLeftX: 40,
    topLeftY: 89,
    bottomRightX: 62,
    bottomRightY: 103
)
private let backgroundRightEyeRectangle = BackgroundLandmarkRectangle(
    topLeftX: 72,
    topLeftY: 89,
    bottomRightX: 94,
    bottomRightY: 103
)
private let backgroundMouthRectangle = BackgroundLandmarkRectangle(
    topLeftX: 50,
    topLeftY: 120,
    bottomRightX: 82,
    bottomRightY: 130
)
private let backgroundFaceRectangle = BackgroundLandmarkRectangle(
    topLeftX: 25,
    topLeftY: 80,
    bottomRightX: 105,
    bottomRightY: 147
)

private struct Word: Identifiable {
    let id: UUID = .init()
    let text: String
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

private enum MediaItem {
    case bundledName(String)
    case customUrl(URL)
    case image(CIImage)
}

private struct GifImage {
    let image: CIImage
    let timeOffset: Double
}

private class Medias: @unchecked Sendable {
    var images: Deque<GifImage> = []
    var soundUrl: URL?

    func updateSoundUrl(sound: MediaItem) {
        switch sound {
        case let .bundledName(name):
            soundUrl = Bundle.main.url(forResource: "Alerts.bundle/\(name)", withExtension: "mp3")
        case let .customUrl(url):
            if (try? url.checkResourceIsReachable()) == true {
                soundUrl = url
            } else {
                soundUrl = nil
            }
        case .image:
            break
        }
    }

    func updateImages(image: MediaItem, loopCount: Int) {
        DispatchQueue.global().async {
            var images: Deque<GifImage> = []
            switch image {
            case let .bundledName(name):
                if let url = Bundle.main.url(forResource: "Alerts.bundle/\(name)", withExtension: "gif") {
                    images = self.loadImages(url: url, loopCount: loopCount)
                }
            case let .customUrl(url):
                images = self.loadImages(url: url, loopCount: loopCount)
            case let .image(image):
                images = self.loadImages(image: image, loopCount: loopCount)
            }
            processorPipelineQueue.async {
                self.images = images
            }
        }
    }

    private func loadImages(url: URL, loopCount: Int) -> Deque<GifImage> {
        var timeOffset = 0.0
        var images: Deque<GifImage> = []
        for _ in 0 ..< loopCount {
            if let data = try? Data(contentsOf: url), let animatedImage = SDAnimatedImage(data: data) {
                for index in 0 ..< animatedImage.animatedImageFrameCount {
                    if let cgImage = animatedImage.animatedImageFrame(at: index)?.cgImage {
                        timeOffset += animatedImage.animatedImageDuration(at: index)
                        images.append(GifImage(image: CIImage(cgImage: cgImage), timeOffset: timeOffset))
                    }
                }
            }
        }
        return images
    }

    private func loadImages(image: CIImage, loopCount: Int) -> Deque<GifImage> {
        var timeOffset = 0.0
        var images: Deque<GifImage> = []
        for _ in 0 ..< loopCount {
            timeOffset += 1
            images.append(GifImage(image: image, timeOffset: timeOffset))
        }
        return images
    }
}

private enum FaceLandmark {
    case face
    case leftEye
    case rightEye
    case mouth
}

private struct LandmarkSettings {
    let landmark: FaceLandmark
    let height: Double
    let centerX: Double
    let centerY: Double
}

final class AlertsEffect: VideoEffect, @unchecked Sendable {
    private var images: Deque<GifImage> = []
    private var basePresentationTimeStamp: Double?
    private var messageImage: CIImage?
    private var audioPlayer: AVAudioPlayer?
    private var rate: Float = 0.4
    private var volume: Float = 1.0
    private var synthesizer = createSpeechSynthesizer()
    private var alertsQueue: Deque<AlertsEffectAlert> = .init()
    private weak var delegate: (any AlertsEffectDelegate)?
    private var enabled: Bool = false
    private var isPlaying: Bool = false
    private var delayAfterPlaying = 3.0
    private var settings: SettingsWidgetAlerts
    private var x: Double = 0
    private var y: Double = 0
    private let mediaStorage: AlertMediaStorage
    private var twitchFollow = Medias()
    private var twitchSubscribe = Medias()
    private var twitchRaid = Medias()
    private var twitchCheers: [Medias] = []
    private var kickSubscription = Medias()
    private var kickGiftedSubscriptions = Medias()
    private var kickHost = Medias()
    private var kickReward = Medias()
    private var kickGifts: [Medias] = []
    private var chatBotCommands: [Medias] = []
    private var speechToTextStrings: [Medias] = []
    private let bundledImages: [SettingsAlertsMediaGalleryItem]
    private let bundledSounds: [SettingsAlertsMediaGalleryItem]
    private var landmarkSettings: LandmarkSettings?
    private var aiBaseUrl: URL?

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
        return (landmarkSettings != nil, nil, nil)
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        let (alertImage, messageImage, x, y, landmarkSettings) = getNext(info.presentationTimeStamp.seconds)
        guard let alertImage, let messageImage else {
            return image
        }
        if let landmarkSettings {
            return executePositionFace(image, info.sceneFaceDetections(), alertImage, landmarkSettings)
        } else {
            return executePositionScene(image, alertImage, messageImage, x, y)
        }
    }

    override func isEnabled() -> Bool {
        return enabled
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
            self.x = x
            self.y = y
        }
    }

    @MainActor
    func play(alert: AlertsEffectAlert) {
        alertsQueue.append(alert)
        tryPlayNextAlert()
    }

    private func setChatBotSettings(settings: SettingsWidgetAlerts) {
        chatBotCommands = []
        for command in settings.chatBot.commands {
            let (image, imageLoopCount, sound) = getMediaItems(alert: command.alert)
            let medias = Medias()
            medias.updateImages(image: image, loopCount: imageLoopCount)
            medias.updateSoundUrl(sound: sound)
            chatBotCommands.append(medias)
        }
    }

    private func getMediaItems(alert: SettingsWidgetAlertsAlert) -> (MediaItem, Int, MediaItem) {
        let image: MediaItem
        if let bundledImage = bundledImages.first(where: { $0.id == alert.imageId }) {
            image = .bundledName(bundledImage.name)
        } else {
            image = .customUrl(mediaStorage.makePath(id: alert.imageId))
        }
        let sound: MediaItem
        if let bundledSound = bundledSounds.first(where: { $0.id == alert.soundId }) {
            sound = .bundledName(bundledSound.name)
        } else {
            sound = .customUrl(mediaStorage.makePath(id: alert.soundId))
        }
        return (image, alert.imageLoopCount, sound)
    }

    private func setSpeechToTextSettings(settings: SettingsWidgetAlerts) {
        speechToTextStrings = []
        for string in settings.speechToText.strings {
            let (image, imageLoopCount, sound) = getMediaItems(alert: string.alert)
            let medias = Medias()
            medias.updateImages(image: image, loopCount: imageLoopCount)
            medias.updateSoundUrl(sound: sound)
            speechToTextStrings.append(medias)
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
        guard commandIndex < chatBotCommands.count else {
            return
        }
        let medias = chatBotCommands[commandIndex]
        let settings = settings.chatBot.commands[commandIndex]
        switch settings.imageType {
        case .file:
            play(
                medias: medias,
                username: name,
                message: command,
                settings: settings.alert
            )
        }
    }

    @MainActor
    private func playSpeechToTextString(id: UUID) {
        guard let stringIndex = settings.speechToText.strings.firstIndex(where: { $0.id == id && $0.alert.enabled })
        else {
            return
        }
        guard stringIndex < speechToTextStrings.count else {
            return
        }
        play(
            medias: speechToTextStrings[stringIndex],
            username: "",
            message: "",
            settings: settings.speechToText.strings[stringIndex].alert,
            delayAfterPlaying: 0.0
        )
    }

    @MainActor
    private func play(
        medias: Medias,
        username: String,
        message: String,
        settings: SettingsWidgetAlertsAlert,
        delayAfterPlaying: Double = 3.0
    ) {
        isPlaying = true
        self.delayAfterPlaying = delayAfterPlaying
        let messageImage = renderMessage(username: username, message: message, settings: settings)
        let landmarkSettings = calculateLandmarkSettings(settings: settings)
        let images = medias.images
        let soundUrl = medias.soundUrl
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
                        self.play(images: images,
                                  soundUrl: soundUrl,
                                  username: username,
                                  message: message,
                                  messageImage: messageImage,
                                  landmarkSettings: landmarkSettings,
                                  settings: settings)
                    }
                }
        } else {
            play(images: images,
                 soundUrl: soundUrl,
                 username: username,
                 message: message,
                 messageImage: messageImage,
                 landmarkSettings: landmarkSettings,
                 settings: settings)
        }
    }

    private func play(images: Deque<GifImage>,
                      soundUrl: URL?,
                      username: String,
                      message: String,
                      messageImage: CIImage?,
                      landmarkSettings: LandmarkSettings?,
                      settings: SettingsWidgetAlertsAlert)
    {
        processorPipelineQueue.async {
            self.images = images
            self.basePresentationTimeStamp = nil
            self.messageImage = messageImage
            self.enabled = true
            self.landmarkSettings = landmarkSettings
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

    private func isInRectangle(_ x: Double, _ y: Double, _ rectangle: BackgroundLandmarkRectangle) -> Bool {
        return x > rectangle.topLeftX && x < rectangle.bottomRightX && y > rectangle.topLeftY && y < rectangle
            .bottomRightY
    }

    private func calculateLandmark(settings: SettingsWidgetAlertsAlert) -> FaceLandmark {
        let centerX = settings.facePosition.x + settings.facePosition.width / 2
        let centerY = settings.facePosition.y + settings.facePosition.height / 2
        if isInRectangle(centerX, centerY, backgroundLeftEyeRectangle) {
            return .leftEye
        } else if isInRectangle(centerX, centerY, backgroundRightEyeRectangle) {
            return .rightEye
        } else if isInRectangle(centerX, centerY, backgroundMouthRectangle) {
            return .mouth
        } else {
            return .face
        }
    }

    private func calculateLandmarkSettings(settings: SettingsWidgetAlertsAlert) -> LandmarkSettings? {
        if settings.positionType == .face {
            let landmark = calculateLandmark(settings: settings)
            let centerX = settings.facePosition.x + settings.facePosition.width / 2
            let centerY = settings.facePosition.y + settings.facePosition.height / 2
            let landmarkRectangle: BackgroundLandmarkRectangle
            switch landmark {
            case .face:
                landmarkRectangle = backgroundFaceRectangle
            case .leftEye:
                landmarkRectangle = backgroundLeftEyeRectangle
            case .rightEye:
                landmarkRectangle = backgroundRightEyeRectangle
            case .mouth:
                landmarkRectangle = backgroundMouthRectangle
            }
            let x = (centerX - landmarkRectangle.topLeftX) / landmarkRectangle.width()
            let y = (centerY - landmarkRectangle.topLeftY) / landmarkRectangle.height()
            let height = settings.facePosition.height / backgroundFaceRectangle.height()
            return LandmarkSettings(landmark: landmark, height: height, centerX: x, centerY: y)
        } else {
            return nil
        }
    }

    private func getNext(_ presentationTimeStamp: Double) -> (CIImage?, CIImage?, Double, Double, LandmarkSettings?) {
        defer {
            enabled = !images.isEmpty
            if !enabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + delayAfterPlaying) {
                    self.isPlaying = false
                    self.tryPlayNextAlert()
                }
            }
        }
        if basePresentationTimeStamp == nil {
            basePresentationTimeStamp = presentationTimeStamp
        }
        let timeOffset = presentationTimeStamp - basePresentationTimeStamp!
        while let image = images.first {
            if timeOffset >= image.timeOffset {
                images.removeFirst()
                continue
            }
            return (image.image, messageImage, x, y, landmarkSettings)
        }
        return (nil, nil, x, y, landmarkSettings)
    }

    private func executePositionFace(
        _ image: CIImage,
        _ faceDetections: [VNFaceObservation]?,
        _ alertImage: CIImage,
        _ landmarkSettings: LandmarkSettings
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
        twitchFollow.updateImages(image: image, loopCount: imageLoopCount)
        twitchFollow.updateSoundUrl(sound: sound)
        (image, imageLoopCount, sound) = getMediaItems(alert: twitch.subscriptions)
        twitchSubscribe.updateImages(image: image, loopCount: imageLoopCount)
        twitchSubscribe.updateSoundUrl(sound: sound)
        (image, imageLoopCount, sound) = getMediaItems(alert: twitch.raids)
        twitchRaid.updateImages(image: image, loopCount: imageLoopCount)
        twitchRaid.updateSoundUrl(sound: sound)
        twitchCheers = []
        for cheerBits in twitch.cheerBits {
            (image, imageLoopCount, sound) = getMediaItems(alert: cheerBits.alert)
            let medias = Medias()
            medias.updateImages(image: image, loopCount: imageLoopCount)
            medias.updateSoundUrl(sound: sound)
            twitchCheers.append(medias)
        }
    }

    @MainActor
    private func playTwitchFollow(event: TwitchEventSubNotificationChannelFollowEvent) {
        guard settings.twitch.follows.enabled else {
            return
        }
        play(
            medias: twitchFollow,
            username: event.user_name,
            message: String(localized: "just followed!"),
            settings: settings.twitch.follows
        )
    }

    @MainActor
    private func playTwitchSubscribe(event: TwitchEventSubNotificationChannelSubscribeEvent) {
        guard settings.twitch.subscriptions.enabled else {
            return
        }
        play(
            medias: twitchSubscribe,
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
        play(
            medias: twitchSubscribe,
            username: event.user_name ?? "Anomymous",
            message: String(
                localized: "just gifted \(event.total) tier \(event.tierAsNumber()) subscriptions!"
            ),
            settings: settings.twitch.subscriptions
        )
    }

    @MainActor
    private func playTwitchResubscribe(event: TwitchEventSubNotificationChannelSubscriptionMessageEvent) {
        guard settings.twitch.subscriptions.enabled else {
            return
        }
        play(
            medias: twitchSubscribe,
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
        play(
            medias: twitchRaid,
            username: event.from_broadcaster_user_name,
            message: String(localized: "raided with a party of \(event.viewers)!"),
            settings: settings.twitch.raids
        )
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
            guard index < twitchCheers.count else {
                return
            }
            let bits = countFormatter.format(event.bits)
            play(
                medias: twitchCheers[index],
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
        kickSubscription.updateImages(image: image, loopCount: imageLoopCount)
        kickSubscription.updateSoundUrl(sound: sound)
        (image, imageLoopCount, sound) = getMediaItems(alert: kick.giftedSubscriptions)
        kickGiftedSubscriptions.updateImages(image: image, loopCount: imageLoopCount)
        kickGiftedSubscriptions.updateSoundUrl(sound: sound)
        (image, imageLoopCount, sound) = getMediaItems(alert: kick.hosts)
        kickHost.updateImages(image: image, loopCount: imageLoopCount)
        kickHost.updateSoundUrl(sound: sound)
        (image, imageLoopCount, sound) = getMediaItems(alert: kick.rewards)
        kickReward.updateImages(image: image, loopCount: imageLoopCount)
        kickReward.updateSoundUrl(sound: sound)
        kickGifts = []
        for kickGift in kick.kickGifts {
            (image, imageLoopCount, sound) = getMediaItems(alert: kickGift.alert)
            let medias = Medias()
            medias.updateImages(image: image, loopCount: imageLoopCount)
            medias.updateSoundUrl(sound: sound)
            kickGifts.append(medias)
        }
    }

    @MainActor
    private func playKickSubscription(event: KickPusherSubscriptionEvent) {
        guard settings.kick.subscriptions.enabled else {
            return
        }
        play(
            medias: kickSubscription,
            username: event.username,
            message: String(localized: "just subscribed! They've been subscribed for \(event.months) months!"),
            settings: settings.kick.subscriptions
        )
    }

    @MainActor
    private func playKickGiftedSubscriptions(event: KickPusherGiftedSubscriptionsEvent) {
        guard settings.kick.giftedSubscriptions.enabled else {
            return
        }
        play(
            medias: kickGiftedSubscriptions,
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
        play(
            medias: kickHost,
            username: event.host_username,
            message: String(localized: "is now hosting with \(event.number_viewers) viewers!"),
            settings: settings.kick.hosts
        )
    }

    @MainActor
    private func playKickReward(event: KickPusherRewardRedeemedEvent) {
        guard settings.kick.rewards.enabled else {
            return
        }
        let baseMessage = String(localized: "redeemed \(event.reward_title)")
        let message = event.user_input.isEmpty ? baseMessage : "\(baseMessage): \(event.user_input)"
        play(
            medias: kickReward,
            username: event.username,
            message: message,
            settings: settings.kick.rewards
        )
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
            guard index < kickGifts.count else {
                return
            }
            let formattedAmount = countFormatter.format(event.gift.amount)
            play(
                medias: kickGifts[index],
                username: event.sender.username,
                message: String(localized: "sent \(event.gift.name) \(formattedAmount) Kicks!"),
                settings: kickGift.alert
            )
            break
        }
    }
}
