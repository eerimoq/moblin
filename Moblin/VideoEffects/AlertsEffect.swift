import AVFoundation
import Collections
import MetalPetal
import SDWebImage
import SwiftUI
import Vision
import WrappingHStack

private let lockQueue = DispatchQueue(label: "com.eerimoq.Moblin.Alerts")

private struct Word: Identifiable {
    let id: UUID = .init()
    let text: String
}

enum AlertsEffectAlert {
    case twitchFollow(TwitchEventSubNotificationChannelFollowEvent)
    case twitchSubscribe(TwitchEventSubNotificationChannelSubscribeEvent)
}

protocol AlertsEffectDelegate: AnyObject {
    func alertsPlayerRegisterVideoEffect(effect: VideoEffect)
}

private class Medias {
    var images: [CIImage] = []
    var soundUrl: URL?
    var fps: Double = 1.0

    func updateSoundUrl(url: URL) {
        if (try? url.checkResourceIsReachable()) == true {
            soundUrl = url
        } else {
            soundUrl = Bundle.main.url(forResource: "Alerts.bundle/sparkle", withExtension: "mp3")
        }
    }

    func updateImages(url: URL) {
        DispatchQueue.global().async {
            var images = self.loadImages(url: url)
            if images.isEmpty {
                if let url = Bundle.main.url(forResource: "Alerts.bundle/pixels", withExtension: "gif") {
                    images = self.loadImages(url: url)
                }
            }
            lockQueue.sync {
                self.images = images
            }
        }
    }

    private func loadImages(url: URL) -> [CIImage] {
        var fpsTime = 0.0
        var gifTime = 0.0
        var images: [CIImage] = []
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
        return images
    }
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
    private var x: Double = 0
    private var y: Double = 0
    private let mediaStorage: AlertMediaStorage
    private var twitchFollow = Medias()
    private var twitchSubscribe = Medias()

    init(
        settings: SettingsWidgetAlerts,
        fps: Int,
        delegate: AlertsEffectDelegate,
        mediaStorage: AlertMediaStorage
    ) {
        self.settings = settings
        self.delegate = delegate
        self.mediaStorage = mediaStorage
        twitchFollow.fps = Double(fps)
        twitchSubscribe.fps = Double(fps)
        audioPlayer = nil
        super.init()
        twitchFollow.updateImages(url: mediaStorage.makePath(id: settings.twitch!.follows.imageId))
        twitchFollow.updateSoundUrl(url: mediaStorage.makePath(id: settings.twitch!.follows.soundId))
        twitchSubscribe.updateImages(url: mediaStorage.makePath(id: settings.twitch!.subscriptions.imageId))
        twitchSubscribe.updateSoundUrl(url: mediaStorage.makePath(id: settings.twitch!.subscriptions.soundId))
    }

    func setSettings(settings: SettingsWidgetAlerts) {
        let twitch = settings.twitch!
        twitchFollow.updateImages(url: mediaStorage.makePath(id: twitch.follows.imageId))
        twitchFollow.updateSoundUrl(url: mediaStorage.makePath(id: twitch.follows.soundId))
        twitchSubscribe.updateImages(url: mediaStorage.makePath(id: twitch.subscriptions.imageId))
        twitchSubscribe.updateSoundUrl(url: mediaStorage.makePath(id: twitch.subscriptions.soundId))
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
            message: "just followed!",
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
            message: "just subscribed!",
            settings: settings.twitch!.subscriptions
        )
    }

    @MainActor
    private func play(
        medias: Medias,
        username: String,
        message: String,
        settings: SettingsWidgetAlertsTwitchAlert
    ) {
        isPlaying = true
        let messageImage = renderMessage(username: username, message: message, settings: settings)
        lockQueue.sync {
            self.images = medias.images
            imageIndex = 0
            self.messageImage = messageImage
            toBeRemoved = false
        }
        delegate?.alertsPlayerRegisterVideoEffect(effect: self)
        if let soundUrl = medias.soundUrl {
            audioPlayer = try? AVAudioPlayer(contentsOf: soundUrl)
            audioPlayer?.play()
        }
        if settings.ttsEnabled! {
            let utterance = AVSpeechUtterance(string: "\(username) \(message)")
            utterance.rate = rate
            utterance.pitchMultiplier = 0.8
            utterance.preUtteranceDelay = settings.ttsDelay!
            utterance.volume = volume
            synthesizer.speak(utterance)
        }
    }

    @MainActor
    private func renderMessage(username: String, message: String,
                               settings: SettingsWidgetAlertsTwitchAlert) -> CIImage?
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

    override func getName() -> String {
        return "Alert widget"
    }

    override func execute(_ image: CIImage, _: [VNFaceObservation]?, _: Bool) -> CIImage {
        let (alertImage, messageImage, x, y) = lockQueue.sync {
            guard imageIndex < images.count else {
                return (image, self.messageImage, self.x, self.y)
            }
            defer {
                self.imageIndex += 1
                self.toBeRemoved = imageIndex == images.count
            }
            return (images[imageIndex], self.messageImage, self.x, self.y)
        }
        guard let messageImage else {
            return image
        }
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

    override func executeMetalPetal(_ image: MTIImage?, _: [VNFaceObservation]?, _: Bool) -> MTIImage? {
        return lockQueue.sync {
            guard imageIndex < images.count else {
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
