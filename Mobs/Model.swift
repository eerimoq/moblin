import AlertToast
import Collections
import Combine
import Foundation
import HaishinKit
import PhotosUI
import SwiftUI
import TwitchChat
import VideoToolbox

let noValue = ""

class ButtonState {
    var isOn: Bool
    var button: SettingsButton

    init(isOn: Bool, button: SettingsButton) {
        self.isOn = isOn
        self.button = button
    }
}

enum StreamState {
    case connecting
    case connected
    case disconnected
}

struct ButtonPair: Identifiable {
    var id: Int
    var first: ButtonState
    var second: ButtonState?
}

struct LogEntry: Identifiable {
    var id: Int
    var message: String
}

final class Model: ObservableObject {
    private let media = Media()
    var streamState = StreamState.disconnected {
        didSet {
            logger.info("stream: State \(oldValue) -> \(streamState)")
        }
    }

    private var streaming = false
    private var wasStreamingWhenDidEnterBackground = false
    private var streamStartDate: Date?
    @Published var isLive = false
    private var subscriptions = Set<AnyCancellable>()
    @Published var uptime = noValue
    @Published var currentConnectionType = noValue
    @Published var audioLevel = noValue
    var settings = Settings()
    var digitalClock = noValue
    var selectedSceneId = UUID()
    private var twitchChat: TwitchChatMobs!
    private var twitchPubSub: TwitchPubSub?
    private var kickPusher: KickPusher?
    private var chatPostId = 0
    @Published var chatPosts: Deque<Post> = []
    var numberOfChatPosts = 0
    @Published var chatPostsPerSecond = 0.0
    @Published var numberOfViewers = noValue
    var numberOfViewersUpdateDate = Date()
    @Published var batteryLevel = Double(UIDevice.current.batteryLevel)
    @Published var speedAndTotal = noValue
    @Published var thermalState = ProcessInfo.processInfo.thermalState
    @Published var zoomLevel = 1.0
    var mthkView = MTHKView(frame: .zero)
    private var grayScaleEffect = GrayScaleEffect()
    private var movieEffect = MovieEffect()
    private var seipaEffect = SeipaEffect()
    private var bloomEffect = BloomEffect()
    private var imageEffects: [UUID: ImageEffect] = [:]
    @Published var sceneIndex = 0
    private var isTorchOn = false
    private var isMuteOn = false
    var log: Deque<LogEntry> = []
    var imageStorage = ImageStorage()
    @Published var buttonPairs: [ButtonPair] = []
    private var reconnectTimer: Timer?
    private var reconnectTime = firstReconnectTime
    private var logId = 1
    @Published var showToast = false
    @Published var toast = AlertToast(type: .regular, title: "") {
        didSet {
            showToast.toggle()
        }
    }

    var database: Database {
        settings.database
    }

    var stream: SettingsStream {
        for stream in database.streams where stream.enabled {
            return stream
        }
        fatalError("stream: There is no stream!")
    }

    var enabledScenes: [SettingsScene] {
        database.scenes.filter { scene in scene.enabled }
    }

    func findButton(id: UUID) -> SettingsButton? {
        return database.buttons.first(where: { button in button.id == id })
    }

    func makeToast(title: String) {
        toast = AlertToast(type: .regular, title: title)
        showToast = true
    }

    func makeErrorToast(title: String, font: Font? = nil, subTitle: String? = nil) {
        toast = AlertToast(
            type: .regular,
            title: title,
            subTitle: subTitle,
            style: .style(titleColor: .red, titleFont: font)
        )
        showToast = true
    }

    func updateButtonStates() {
        guard let scene = findEnabledScene(id: selectedSceneId) else {
            buttonPairs = []
            return
        }
        let states = scene
            .buttons
            .filter { button in button.enabled }
            .prefix(8)
            .map { button in
                let button = findButton(id: button.buttonId)!
                return ButtonState(isOn: button.isOn, button: button)
            }
        var pairs: [ButtonPair] = []
        for index in stride(from: 0, to: states.count, by: 2) {
            if states.count - index > 1 {
                pairs.append(ButtonPair(
                    id: index / 2,
                    first: states[index],
                    second: states[index + 1]
                ))
            } else {
                pairs.append(ButtonPair(id: index / 2, first: states[index]))
            }
        }
        buttonPairs = pairs.reversed()
    }

    func debugLog(message: String) {
        DispatchQueue.main.async {
            if self.log.count > 500 {
                self.log.removeFirst()
            }
            let timestamp = Date()
                .formatted(.dateTime.hour().minute().second()
                    .secondFraction(.fractional(3)))
            self.log.append(LogEntry(id: self.logId, message: "\(timestamp) \(message)"))
            self.logId += 1
        }
    }

    func clearLog() {
        log = []
    }

    func copyLog() {
        var data = "Version: \(version())\n"
        data += "Debug: \(logger.debugEnabled)\n\n"
        data += log.map { e in e.message }.joined(separator: "\n")
        UIPasteboard.general.string = data
    }

    func setup(settings: Settings) {
        media.onSrtConnected = handleSrtConnected
        media.onSrtDisconnected = handleSrtDisconnected
        media.onRtmpConnected = handleRtmpConnected
        media.onRtmpDisconnected = handleRtmpDisconnected
        media.onAudioMuteChange = updateAudioLevel
        self.settings = settings
        mthkView.videoGravity = .resizeAspect
        logger.handler = debugLog(message:)
        logger.info("Setup")
        updateDigitalClock(now: Date())
        twitchChat = TwitchChatMobs(model: self)
        reloadStream()
        resetSelectedScene()
        setupPeriodicTimers()
        setupThermalState()
        updateButtonStates()
        sceneUpdated(imageEffectChanged: true, store: false)
        removeUnusedImages()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterBackground),
            name: UIScene.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willEnterForeground),
            name: UIScene.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc func didEnterBackground(animated _: Bool) {
        wasStreamingWhenDidEnterBackground = streaming
        stopStream()
        logger.debug("Did enter background")
    }

    @objc func willEnterForeground(animated _: Bool) {
        logger.debug("Will enter foreground")
        updateThermalState()
        if wasStreamingWhenDidEnterBackground {
            stopStream()
            startStream()
        } else {
            stopStream()
        }
    }

    func setupPeriodicTimers() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            let now = Date()
            self.updateUptime(now: now)
            self.updateDigitalClock(now: now)
            self.updateChatSpeed()
            self.media.updateSrtSpeed()
            self.updateSpeed()
            self.updateTwitchPubSub(now: now)
            self.updateAudioLevel()
            self.updateBestSrtlaConnectionType()
        })
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true, block: { _ in
            self.updateBatteryLevel()
            self.media.logStatistics()
        })
    }

    func removeUnusedImages() {
        for id in imageStorage.ids() {
            var used = false
            for widget in database.widgets {
                if widget.type != .image {
                    continue
                }
                if widget.id == id {
                    used = true
                    break
                }
            }
            if !used {
                logger.info("Removing unused image \(id)")
                imageStorage.remove(id: id)
            }
        }
    }

    func updateTwitchPubSub(now: Date) {
        if numberOfViewersUpdateDate + 60 < now {
            numberOfViewers = noValue
        }
    }

    func updateAudioLevel() {
        let newAudioLevel = media.getAudioLevel()
        if newAudioLevel.isNaN {
            audioLevel = String("Muted")
        } else {
            audioLevel = "\(Int(newAudioLevel)) dB"
        }
    }

    func updateBestSrtlaConnectionType() {
        if isStreamConnceted(), let type = media.getBestSrtlaConnectionType() {
            currentConnectionType = type
        } else {
            currentConnectionType = noValue
        }
    }

    func reloadImageEffects() {
        imageEffects.removeAll()
        for scene in database.scenes {
            for widget in scene.widgets {
                guard let realWidget = findWidget(id: widget.widgetId) else {
                    continue
                }
                if realWidget.type != .image {
                    continue
                }
                guard let data = imageStorage.read(id: widget.widgetId) else {
                    continue
                }
                guard let image = UIImage(data: data) else {
                    continue
                }
                imageEffects[widget.id] = ImageEffect(
                    image: image,
                    x: widget.x,
                    y: widget.y,
                    width: widget.width,
                    height: widget.height
                )
            }
        }
    }

    func resetSelectedScene() {
        if !enabledScenes.isEmpty {
            selectedSceneId = enabledScenes[0].id
            sceneIndex = 0
        }
        sceneUpdated(imageEffectChanged: true, store: false)
    }

    func store() {
        settings.store()
    }

    func startStream() {
        logger.info("stream: Start")
        isLive = true
        streaming = true
        reconnectTime = firstReconnectTime
        UIApplication.shared.isIdleTimerDisabled = true
        startNetStream()
    }

    func stopStream() {
        isLive = false
        if !streaming {
            return
        }
        logger.info("stream: Stop")
        streaming = false
        UIApplication.shared.isIdleTimerDisabled = false
        stopNetStream()
        streamState = .disconnected
    }

    func startNetStream() {
        streamState = .connecting
        makeToast(title: "😎 Going live at \(stream.name) 😎")
        switch stream.getProtocol() {
        case .rtmp:
            rtmpStartStream()
        case .srt:
            media.srtStartStream(
                isSrtla: stream.isSrtla(),
                url: stream.url!,
                reconnectTime: reconnectTime
            )
        }
        updateSpeed()
    }

    func stopNetStream() {
        reconnectTimer?.invalidate()
        rtmpStopStream()
        media.srtStopStream()
        streamStartDate = nil
        updateUptime(now: Date())
        updateSpeed()
        updateAudioLevel()
        currentConnectionType = noValue
        makeToast(title: "🤟 Stream ended 🤟")
    }

    func reloadStream() {
        stopStream()
        setNetStream()
        setStreamResolution()
        setStreamFPS()
        setStreamCodec()
        setStreamBitrate(stream: stream)
        reloadTwitchChat()
        reloadTwitchPubSub()
        reloadKickPusher()
    }

    func reloadStreamIfEnabled(stream: SettingsStream) {
        store()
        if stream.enabled {
            reloadStream()
            sceneUpdated()
        }
    }

    func setNetStream() {
        media.setNetStream(proto: stream.getProtocol())
        updateTorch()
        updateMute()
        mthkView.attachStream(media.getNetStream())
    }

    func setStreamResolution() {
        switch stream.resolution {
        case .r1920x1080:
            media.setVideoSessionPreset(preset: .hd1920x1080)
            media.setVideoSize(size: .init(width: 1920, height: 1080))
        case .r1280x720:
            media.setVideoSessionPreset(preset: .hd1280x720)
            media.setVideoSize(size: .init(width: 1280, height: 720))
        case .r854x480:
            media.setVideoSessionPreset(preset: .hd1280x720)
            media.setVideoSize(size: .init(width: 854, height: 480))
        case .r640x360:
            media.setVideoSessionPreset(preset: .hd1280x720)
            media.setVideoSize(size: .init(width: 640, height: 360))
        case .r426x240:
            media.setVideoSessionPreset(preset: .hd1280x720)
            media.setVideoSize(size: .init(width: 426, height: 240))
        }
    }

    func setStreamFPS() {
        media.setStreamFPS(fps: stream.fps)
    }

    func setStreamBitrate(stream: SettingsStream) {
        media.setVideoStreamBitrate(bitrate: stream.bitrate)
    }

    func setStreamCodec() {
        switch stream.codec {
        case .h264avc:
            media.setVideoProfile(profile: kVTProfileLevel_H264_High_AutoLevel)
        case .h265hevc:
            media.setVideoProfile(profile: kVTProfileLevel_HEVC_Main_AutoLevel)
        }
    }

    func isChatConfigured() -> Bool {
        return stream.twitchChannelName != "" || stream.kickChatroomId != ""
    }

    func isViewersConfigured() -> Bool {
        return stream.twitchChannelId != ""
    }

    func isTwitchChatConnected() -> Bool {
        return twitchChat?.isConnected() ?? false
    }

    func isTwitchPubSubConnected() -> Bool {
        return twitchPubSub?.isConnected() ?? false
    }

    func isKickPusherConnected() -> Bool {
        return kickPusher?.isConnected() ?? false
    }

    func isChatConnected() -> Bool {
        return isTwitchChatConnected() || isKickPusherConnected()
    }

    func isStreamConnceted() -> Bool {
        return streamState == .connected
    }

    func isStreaming() -> Bool {
        return streaming
    }

    func reloadTwitchChat() {
        twitchChat.stop()
        if stream.twitchChannelName != "" {
            twitchChat.start(channelName: stream.twitchChannelName)
        } else {
            logger.info("Twitch channel name not configured. No Twitch chat.")
        }
        chatPostsPerSecond = 0
        chatPosts = []
        numberOfChatPosts = 0
    }

    func reloadTwitchPubSub() {
        twitchPubSub?.stop()
        numberOfViewers = noValue
        if stream.twitchChannelId != "" {
            twitchPubSub = TwitchPubSub(model: self, channelId: stream.twitchChannelId)
            twitchPubSub!.start()
        } else {
            logger.info("Twitch channel id not configured. No viewers.")
        }
    }

    func reloadKickPusher() {
        kickPusher?.stop()
        kickPusher = nil
        if stream.kickChatroomId != "" {
            kickPusher = KickPusher(model: self, channelId: stream.kickChatroomId!)
            kickPusher!.start()
        } else {
            logger.info("Kick chatroom id not configured. No Kick chat.")
        }
    }

    func twitchChannelNameUpdated() {
        reloadTwitchChat()
    }

    func twitchChannelIdUpdated() {
        reloadTwitchPubSub()
    }

    func kickChatroomIdUpdated() {
        reloadKickPusher()
    }

    func appendChatMessage(user: String, message: String) {
        if chatPosts.count > 6 {
            chatPosts.removeFirst()
        }
        let post = Post(
            id: chatPostId,
            user: user,
            message: message
        )
        chatPosts.append(post)
        numberOfChatPosts += 1
        chatPostId += 1
    }

    func findWidget(id: UUID) -> SettingsWidget? {
        for widget in database.widgets where widget.id == id {
            return widget
        }
        return nil
    }

    func findEnabledScene(id: UUID) -> SettingsScene? {
        for scene in enabledScenes where id == scene.id {
            return scene
        }
        return nil
    }

    func getEnabledButtonForWidgetControlledByScene(
        widget: SettingsWidget,
        scene: SettingsScene
    ) -> SettingsButton? {
        for button in scene.buttons {
            if !button.enabled {
                continue
            }
            if let button = findButton(id: button.buttonId) {
                if widget.id == button.widget.widgetId {
                    return button
                }
            }
        }
        return nil
    }

    func sceneUpdatedOff() {
        for widget in database.widgets {
            switch widget.type {
            case .camera:
                break
            case .image:
                break
            case .videoEffect:
                switch widget.videoEffect.type {
                case .movie:
                    movieEffectOff()
                case .grayScale:
                    grayScaleEffectOff()
                case .seipa:
                    seipaEffectOff()
                case .bloom:
                    bloomEffectOff()
                }
            }
        }
        for imageEffect in imageEffects.values {
            media.unregisterVideoEffect(imageEffect)
        }
    }

    func sceneUpdatedOn(scene: SettingsScene) {
        for sceneWidget in scene.widgets.filter({ widget in widget.enabled }) {
            guard let widget = findWidget(id: sceneWidget.widgetId) else {
                logger.error("Widget not found.")
                continue
            }
            if let button = getEnabledButtonForWidgetControlledByScene(
                widget: widget,
                scene: scene
            ) {
                if !button.isOn {
                    continue
                }
            }
            switch widget.type {
            case .camera:
                switch widget.camera.type {
                case .main:
                    attachCamera(position: .back)
                case .front:
                    attachCamera(position: .front)
                }
            case .image:
                if let imageEffect = imageEffects[sceneWidget.id] {
                    media.registerVideoEffect(imageEffect)
                }
            case .videoEffect:
                switch widget.videoEffect.type {
                case .movie:
                    movieEffectOn()
                case .grayScale:
                    grayScaleEffectOn()
                case .seipa:
                    seipaEffectOn()
                case .bloom:
                    bloomEffectOn()
                }
            }
        }
    }

    func sceneUpdated(imageEffectChanged: Bool = false, store: Bool = true) {
        if store {
            self.store()
        }
        updateButtonStates()
        sceneUpdatedOff()
        if imageEffectChanged {
            reloadImageEffects()
        }
        guard let scene = findEnabledScene(id: selectedSceneId) else {
            return
        }
        sceneUpdatedOn(scene: scene)
    }

    func updateUptime(now: Date) {
        if streamStartDate != nil && isStreamConnceted() {
            let elapsed = now.timeIntervalSince(streamStartDate!)
            uptime = uptimeFormatter.string(from: elapsed)!
        } else {
            uptime = noValue
        }
    }

    func updateDigitalClock(now: Date) {
        digitalClock = digitalClockFormatter.string(from: now)
    }

    func updateBatteryLevel() {
        batteryLevel = Double(UIDevice.current.batteryLevel)
    }

    func updateChatSpeed() {
        chatPostsPerSecond = chatPostsPerSecond * 0.8 +
            Double(numberOfChatPosts) * 0.2
        numberOfChatPosts = 0
    }

    func updateSpeed() {
        if isLive {
            let speed = formatBytesPerSecond(speed: media.streamSpeed())
            let total = sizeFormatter.string(fromByteCount: media.streamTotal())
            speedAndTotal = "\(speed) (\(total))"
        } else {
            speedAndTotal = noValue
        }
    }

    func checkDeviceAuthorization() {
        PHPhotoLibrary
            .requestAuthorization(for: .readWrite) { authorizationStatus in
                switch authorizationStatus {
                case .limited:
                    logger.warning("photo-auth: limited authorization granted")
                case .authorized:
                    logger.info("photo-auth: authorization granted")
                default:
                    logger.error("photo-auth: Status \(authorizationStatus)")
                }
            }
    }

    func setupThermalState() {
        updateThermalState()
        NotificationCenter.default.publisher(
            for: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
        .sink { _ in
            DispatchQueue.main.async {
                self.updateThermalState()
            }
        }
        .store(in: &subscriptions)
    }

    func updateThermalState() {
        thermalState = ProcessInfo.processInfo.thermalState
        logger.info("Thermal state is \(thermalState.string())")
    }

    func attachCamera(position: AVCaptureDevice.Position) {
        let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position
        )
        media.attachCamera(device: device)
        zoomLevel = Double(device?.videoZoomFactor ?? 1.0)
        setCameraZoomLevel(level: zoomLevel)
    }

    func rtmpStartStream() {
        media.rtmpStartStream(url: stream.url!)
    }

    func rtmpStopStream() {
        media.rtmpStopStream()
    }

    func toggleTorch() {
        isTorchOn.toggle()
        updateTorch()
    }

    func updateTorch() {
        media.setTorch(on: isTorchOn)
    }

    func toggleMute() {
        isMuteOn.toggle()
        updateMute()
    }

    func updateMute() {
        media.setMute(on: isMuteOn)
    }

    func grayScaleEffectOn() {
        media.registerVideoEffect(grayScaleEffect)
    }

    func grayScaleEffectOff() {
        media.unregisterVideoEffect(grayScaleEffect)
    }

    func movieEffectOn() {
        media.registerVideoEffect(movieEffect)
    }

    func movieEffectOff() {
        media.unregisterVideoEffect(movieEffect)
    }

    func seipaEffectOn() {
        media.registerVideoEffect(seipaEffect)
    }

    func seipaEffectOff() {
        media.unregisterVideoEffect(seipaEffect)
    }

    func bloomEffectOn() {
        media.registerVideoEffect(bloomEffect)
    }

    func bloomEffectOff() {
        media.unregisterVideoEffect(bloomEffect)
    }

    func setCameraZoomLevel(level: Double) {
        media.setCameraZoomLevel(level: level)
    }

    func handleRtmpConnected() {
        onConnected()
    }

    func handleRtmpDisconnected(message: String) {
        onDisconnected(reason: "RTMP disconnected with message \(message)")
    }

    func onConnected() {
        makeToast(title: "🎉 You are LIVE at \(stream.name) 🎉")
        reconnectTime = firstReconnectTime
        streamStartDate = Date()
        streamState = .connected
        updateUptime(now: Date())
    }

    func onDisconnected(reason: String) {
        guard streaming else {
            return
        }
        logger.info("stream: Disconnected with reason \(reason)")
        streamState = .disconnected
        stopNetStream()
        makeErrorToast(
            title: "😢 FFFFF 😢",
            font: .system(size: 64).bold(),
            subTitle: reason
        )
        reconnectTimer = Timer
            .scheduledTimer(withTimeInterval: reconnectTime, repeats: false) { _ in
                logger.info("stream: Reconnecting")
                self.startNetStream()
                self.reconnectTime = nextReconnectTime(self.reconnectTime)
            }
    }

    func handleSrtConnected() {
        onConnected()
    }

    func handleSrtDisconnected(reason: String) {
        onDisconnected(reason: reason)
    }
}
