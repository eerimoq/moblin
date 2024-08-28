import AVFoundation
import Collections
import MetalPetal
import SDWebImage
import SwiftUI
import Vision
import WrappingHStack

private let lockQueue = DispatchQueue(label: "com.eerimoq.Moblin.Alerts")

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
    case chatBotCommand(String, String)
}

protocol AlertsEffectDelegate: AnyObject {
    func alertsPlayerRegisterVideoEffect(effect: VideoEffect)
}

private enum MediaItem {
    case bundledName(String)
    case customUrl(URL)
}

private class Medias {
    var images: [CIImage] = []
    var soundUrl: URL?
    var fps: Double = 1.0

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
        }
    }

    func updateImages(image: MediaItem, loopCount: Int) {
        DispatchQueue.global().async {
            var images: [CIImage] = []
            switch image {
            case let .bundledName(name):
                if let url = Bundle.main.url(forResource: "Alerts.bundle/\(name)", withExtension: "gif") {
                    images = self.loadImages(url: url, loopCount: loopCount)
                }
            case let .customUrl(url):
                images = self.loadImages(url: url, loopCount: loopCount)
            }
            lockQueue.sync {
                self.images = images
            }
        }
    }

    private func loadImages(url: URL, loopCount: Int) -> [CIImage] {
        var fpsTime = 0.0
        var gifTime = 0.0
        var images: [CIImage] = []
        for _ in 0 ..< loopCount {
            if let data = try? Data(contentsOf: url), let animatedImage = SDAnimatedImage(data: data) {
                for index in 0 ..< animatedImage.animatedImageFrameCount {
                    if let cgImage = animatedImage.animatedImageFrame(at: index)?.cgImage {
                        gifTime += animatedImage.animatedImageDuration(at: index)
                        let image = CIImage(cgImage: cgImage)
                        while fpsTime < gifTime {
                            images.append(image)
                            fpsTime += 1 / fps
                        }
                    }
                }
            }
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

final class AlertsEffect: VideoEffect {
    private var images: [CIImage] = []
    private var imageIndex: Int = 0
    private var messageImage: CIImage?
    private var audioPlayer: AVAudioPlayer?
    private var rate: Float = 0.4
    private var volume: Float = 1.0
    private var synthesizer = AVSpeechSynthesizer()
    private var alertsQueue: Deque<AlertsEffectAlert> = .init()
    private weak var delegate: (any AlertsEffectDelegate)?
    private var toBeRemoved: Bool = true
    private var isPlaying: Bool = false
    private var settings: SettingsWidgetAlerts
    private var fps: Double
    private var x: Double = 0
    private var y: Double = 0
    private let mediaStorage: AlertMediaStorage
    private var twitchFollow = Medias()
    private var twitchSubscribe = Medias()
    private var chatBotCommands: [Medias] = []
    private let bundledImages: [SettingsAlertsMediaGalleryItem]
    private let bundledSounds: [SettingsAlertsMediaGalleryItem]
    private var landmarkSettings: LandmarkSettings?

    init(
        settings: SettingsWidgetAlerts,
        fps: Int,
        delegate: AlertsEffectDelegate,
        mediaStorage: AlertMediaStorage,
        bundledImages: [SettingsAlertsMediaGalleryItem],
        bundledSounds: [SettingsAlertsMediaGalleryItem]
    ) {
        self.settings = settings
        self.fps = Double(fps)
        self.delegate = delegate
        self.mediaStorage = mediaStorage
        self.bundledImages = bundledImages
        self.bundledSounds = bundledSounds
        twitchFollow.fps = self.fps
        twitchSubscribe.fps = self.fps
        audioPlayer = nil
        super.init()
        setSettings(settings: settings)
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
        return (image, alert.imageLoopCount!, sound)
    }

    func setSettings(settings: SettingsWidgetAlerts) {
        let twitch = settings.twitch!
        var (image, imageLoopCount, sound) = getMediaItems(alert: twitch.follows)
        twitchFollow.updateImages(image: image, loopCount: imageLoopCount)
        twitchFollow.updateSoundUrl(sound: sound)
        (image, imageLoopCount, sound) = getMediaItems(alert: twitch.subscriptions)
        twitchSubscribe.updateImages(image: image, loopCount: imageLoopCount)
        twitchSubscribe.updateSoundUrl(sound: sound)
        chatBotCommands = []
        for command in settings.chatBot!.commands {
            (image, imageLoopCount, sound) = getMediaItems(alert: command.alert)
            var medias = Medias()
            medias.fps = fps
            medias.updateImages(image: image, loopCount: imageLoopCount)
            medias.updateSoundUrl(sound: sound)
            chatBotCommands.append(medias)
        }
        self.settings = settings
    }

    func setPosition(x: Double, y: Double) {
        lockQueue.sync {
            self.x = x
            self.y = y
        }
    }

    @MainActor
    func play(alert: AlertsEffectAlert) {
        alertsQueue.append(alert)
        tryPlayNextAlert()
    }

    func shoudRegisterEffect() -> Bool {
        return lockQueue.sync { !toBeRemoved }
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
        case let .chatBotCommand(command, name):
            playChatBotCommand(command: command, name: name)
        }
    }

    @MainActor
    private func playTwitchFollow(event: TwitchEventSubNotificationChannelFollowEvent) {
        guard settings.twitch!.follows.enabled else {
            return
        }
        play(
            medias: twitchFollow,
            username: event.user_name,
            message: String(localized: "just followed!"),
            settings: settings.twitch!.follows
        )
    }

    @MainActor
    private func playTwitchSubscribe(event: TwitchEventSubNotificationChannelSubscribeEvent) {
        guard settings.twitch!.subscriptions.enabled else {
            return
        }
        play(
            medias: twitchSubscribe,
            username: event.user_name,
            message: String(localized: "just subscribed!"),
            settings: settings.twitch!.subscriptions
        )
    }

    @MainActor
    private func playChatBotCommand(command: String, name: String) {
        guard let commandSettings = settings.chatBot!.commands
            .first(where: { command == $0.command && $0.alert.enabled })
        else {
            return
        }
        guard let commandIndex = settings.chatBot!.commands.firstIndex(where: { command == $0.command })
        else {
            return
        }
        guard commandIndex < chatBotCommands.count else {
            return
        }
        play(
            medias: chatBotCommands[commandIndex],
            username: name,
            message: command,
            settings: commandSettings.alert
        )
    }

    @MainActor
    private func play(
        medias: Medias,
        username: String,
        message: String,
        settings: SettingsWidgetAlertsAlert
    ) {
        isPlaying = true
        let messageImage = renderMessage(username: username, message: message, settings: settings)
        let landmarkSettings = calculateLandmarkSettings(settings: settings)
        lockQueue.sync {
            self.images = medias.images
            imageIndex = 0
            self.messageImage = messageImage
            toBeRemoved = false
            self.landmarkSettings = landmarkSettings
        }
        delegate?.alertsPlayerRegisterVideoEffect(effect: self)
        if let soundUrl = medias.soundUrl {
            audioPlayer = try? AVAudioPlayer(contentsOf: soundUrl)
            audioPlayer?.play()
        }
        if settings.textToSpeechEnabled! {
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
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.textToSpeechDelay!) {
            self.synthesizer.speak(utterance)
        }
    }

    private func getVoice(settings: SettingsWidgetAlertsAlert) -> AVSpeechSynthesisVoice? {
        guard let language = Locale.current.language.languageCode?.identifier else {
            return nil
        }
        if let voiceIdentifier = settings.textToSpeechLanguageVoices![language] {
            return AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        } else if let voice = AVSpeechSynthesisVoice.speechVoices()
            .filter({ $0.language.starts(with: language) }).first
        {
            return AVSpeechSynthesisVoice(identifier: voice.identifier)
        }
        return nil
    }

    @MainActor
    private func renderMessage(username: String, message: String,
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
                .foregroundColor(settings.accentColor.color())
            ForEach(words) { word in
                Text("\(word.text) ")
                    .foregroundColor(settings.textColor.color())
            }
        }
        .font(.system(
            size: CGFloat(settings.fontSize),
            weight: settings.fontWeight.toSystem(),
            design: settings.fontDesign.toSystem()
        ))
        .shadow(color: .black, radius: 0, x: 1, y: 0)
        .shadow(color: .black, radius: 0, x: -1, y: 0)
        .shadow(color: .black, radius: 0, x: 0, y: 1)
        .shadow(color: .black, radius: 0, x: 0, y: -1)
        .shadow(color: .black, radius: 0, x: -2, y: -2)
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
        let centerX = settings.facePosition!.x + settings.facePosition!.width / 2
        let centerY = settings.facePosition!.y + settings.facePosition!.height / 2
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
            let centerX = settings.facePosition!.x + settings.facePosition!.width / 2
            let centerY = settings.facePosition!.y + settings.facePosition!.height / 2
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
            let height = settings.facePosition!.height / backgroundFaceRectangle.height()
            return LandmarkSettings(landmark: landmark, height: height, centerX: x, centerY: y)
        } else {
            return nil
        }
    }

    override func getName() -> String {
        return "Alert widget"
    }

    override func needsFaceDetections() -> Bool {
        return landmarkSettings != nil
    }

    private func getNext(image: CIImage)
        -> (CIImage, CIImage?, Double, Double, LandmarkSettings?)
    {
        guard imageIndex < images.count else {
            toBeRemoved = true
            return (image, nil, x, y, landmarkSettings)
        }
        defer {
            imageIndex += 1
            toBeRemoved = imageIndex == images.count
        }
        return (images[imageIndex], messageImage, x, y, landmarkSettings)
    }

    private func calcMinXMaxYWidthHeight(points: [CGPoint]) -> (CGFloat, CGFloat, CGFloat, CGFloat)? {
        guard let firstPoint = points.first else {
            return nil
        }
        var minX = firstPoint.x
        var maxX = firstPoint.x
        var minY = firstPoint.y
        var maxY = firstPoint.y
        for point in points {
            minX = min(point.x, minX)
            maxX = max(point.x, maxX)
            minY = min(point.y, minY)
            maxY = max(point.y, maxY)
        }
        let width = maxX - minX
        let height = maxY - minY
        return (minX, maxY, width, height)
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
            var centerX: Double
            var centerY: Double
            var alertImageHeight: Double
            guard let allPoints = detection.landmarks?.allPoints else {
                continue
            }
            let points = allPoints.pointsInImage(imageSize: image.extent.size)
            guard let firstPoint = points.first else {
                continue
            }
            var faceMinX = firstPoint.x
            var faceMaxX = firstPoint.x
            var faceMinY = firstPoint.y
            var faceMaxY = firstPoint.y
            for point in points {
                faceMinX = min(point.x, faceMinX)
                faceMaxX = max(point.x, faceMaxX)
                faceMinY = min(point.y, faceMinY)
                faceMaxY = max(point.y, faceMaxY)
            }
            let faceWidth = faceMaxX - faceMinX
            let faceHeight = faceMaxY - faceMinY
            alertImageHeight = faceHeight * landmarkSettings.height
            switch landmarkSettings.landmark {
            case .face:
                centerX = faceMinX + landmarkSettings.centerX * faceWidth
                centerY = faceMaxY - landmarkSettings.centerY * faceHeight
            case .leftEye:
                guard let leftEye = detection.landmarks?.leftEye else {
                    continue
                }
                let points = leftEye.pointsInImage(imageSize: image.extent.size)
                guard let (minX, maxY, width, height) = calcMinXMaxYWidthHeight(points: points) else {
                    continue
                }
                centerX = minX + landmarkSettings.centerX * width
                centerY = maxY - landmarkSettings.centerY * height
            case .rightEye:
                guard let rightEye = detection.landmarks?.rightEye else {
                    continue
                }
                let points = rightEye.pointsInImage(imageSize: image.extent.size)
                guard let (minX, maxY, width, height) = calcMinXMaxYWidthHeight(points: points) else {
                    continue
                }
                centerX = minX + landmarkSettings.centerX * width
                centerY = maxY - landmarkSettings.centerY * height
            case .mouth:
                guard let outerLips = detection.landmarks?.outerLips else {
                    continue
                }
                let points = outerLips.pointsInImage(imageSize: image.extent.size)
                guard let (minX, maxY, width, height) = calcMinXMaxYWidthHeight(points: points) else {
                    continue
                }
                centerX = minX + landmarkSettings.centerX * width
                centerY = maxY - landmarkSettings.centerY * height
            }
            let moblinImage = alertImage
                .transformed(by: CGAffineTransform(
                    scaleX: alertImageHeight / alertImage.extent.height,
                    y: alertImageHeight / alertImage.extent.height
                ))
            centerX -= moblinImage.extent.width / 2
            centerY -= moblinImage.extent.height / 2
            outputImage = moblinImage
                .transformed(by: CGAffineTransform(translationX: centerX, y: centerY))
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
            .transformed(by: CGAffineTransform(
                translationX: -(messageImage.extent.width - alertImage.extent.width) / 2,
                y: -messageImage.extent.height
            ))
            .composited(over: alertImage)
            .transformed(by: CGAffineTransform(translationX: xPos, y: yPos))
            .composited(over: image)
            .cropped(to: image.extent)
    }

    override func execute(_ image: CIImage, _ faceDetections: [VNFaceObservation]?, _: Bool) -> CIImage {
        let (alertImage, messageImage, x, y, landmarkSettings) = lockQueue.sync {
            getNext(image: image)
        }
        guard let messageImage else {
            return image
        }
        if let landmarkSettings {
            return executePositionFace(image, faceDetections, alertImage, landmarkSettings)
        } else {
            return executePositionScene(image, alertImage, messageImage, x, y)
        }
    }

    override func executeMetalPetal(_ image: MTIImage?, _: [VNFaceObservation]?, _: Bool) -> MTIImage? {
        return lockQueue.sync {
            guard imageIndex < images.count else {
                self.toBeRemoved = true
                return image
            }
            defer {
                self.imageIndex += 1
                self.toBeRemoved = imageIndex == images.count
            }
            return image
        }
    }

    override func shouldRemove() -> Bool {
        return toBeRemoved
    }

    override func removed() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.isPlaying = false
            self.tryPlayNextAlert()
        }
    }
}
