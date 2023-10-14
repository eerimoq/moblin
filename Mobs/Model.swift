import AlertToast
import Collections
import Combine
import HaishinKit
import Network
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
    @Published var mic = mics[0]
    // private var wasStreamingWhenDidEnterBackground = false
    private var streamStartDate: Date?
    @Published var isLive = false
    private var subscriptions = Set<AnyCancellable>()
    @Published var uptime = noValue
    @Published var srtlaConnectionStatistics = noValue
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
    var mthkView = MTHKView(frame: .zero)
    private var textEffects: [UUID: TextEffect] = [:]
    private var imageEffects: [UUID: ImageEffect] = [:]
    private var videoEffects: [UUID: VideoEffect] = [:]
    private var browserEffects: [UUID: BrowserEffect] = [:]
    @Published var sceneIndex = 0
    private var isTorchOn = false
    private var isMuteOn = false
    var log: Deque<LogEntry> = []
    var imageStorage = ImageStorage()
    @Published var buttonPairs: [ButtonPair] = []
    private var reconnectTimer: Timer?
    private var reconnectTime = firstReconnectTime
    private var logId = 1
    @Published var showingToast = false
    @Published var toast = AlertToast(type: .regular, title: "") {
        didSet {
            showingToast.toggle()
        }
    }

    @Published var showingBitrate = false
    @Published var showingMic = false
    @Published var iconImage: String = plainIcon.image
    @Published var manualFocusPoint: CGPoint?
    private var zoomPresets: [SettingsZoomPreset] = []
    @Published var backZoomPresetId = UUID()
    @Published var frontZoomPresetId = UUID()
    @Published var zoomLevel = 1.0
    var zoomLevelPinch = 1.0
    private var backZoomLevel = 1.0
    private var frontZoomLevel = 1.0
    var cameraPosition: AVCaptureDevice.Position?
    var database: Database {
        settings.database
    }

    var cameraDevice: AVCaptureDevice?
    @Published var srtDebugLines: [String] = []

    var stream: SettingsStream {
        for stream in database.streams where stream.enabled {
            return stream
        }
        fatalError("stream: There is no stream!")
    }

    private let networkPathMonitor = NWPathMonitor()

    var enabledScenes: [SettingsScene] {
        database.scenes.filter { scene in scene.enabled }
    }

    func findButton(id: UUID) -> SettingsButton? {
        return database.buttons.first(where: { button in button.id == id })
    }

    func makeToast(title: String, subTitle: String? = nil) {
        toast = AlertToast(type: .regular, title: title, subTitle: subTitle)
        showingToast = true
    }

    func makeErrorToast(title: String, font: Font? = nil, subTitle: String? = nil) {
        toast = AlertToast(
            type: .regular,
            title: title,
            subTitle: subTitle,
            style: .style(titleColor: .red, titleFont: font)
        )
        showingToast = true
    }

    func updateButtonStates() {
        guard let scene = findEnabledScene(id: selectedSceneId) else {
            buttonPairs = []
            return
        }
        let states = scene
            .buttons
            .filter { button in button.enabled }
            .prefix(10)
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
            self.log.append(LogEntry(id: self.logId, message: message))
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

    func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                options: [.mixWithOthers]
            )
            try session.setActive(true)
        } catch {
            logger.error("app: Session error \(error)")
        }
        for input in session.availableInputs ?? [] {
            logger.info("Input: \(input)")
        }
        for input in session.inputDataSources ?? [] {
            logger.info("Source: \(input)")
        }
    }

    func selectMic(orientation: String, showToast: Bool = false) {
        let avOrientation = AVAudioSession.Orientation(rawValue: orientation)
        let session = AVAudioSession.sharedInstance()
        do {
            for inputSource in session.inputDataSources ?? [] {
                if let inputSourceOrientation = inputSource.orientation {
                    if inputSourceOrientation == avOrientation {
                        media.attachAudio(device: nil)
                        setupAudioSession()
                        try session.setInputDataSource(inputSource)
                        media
                            .attachAudio(device: AVCaptureDevice.default(for: .audio))
                        logger.info("\(orientation) mic")
                        if showToast {
                            makeToast(title: orientation)
                        }
                    }
                }
            }
            mic = orientation
        } catch {
            logger.error("Failed to select mic: \(error)")
            makeErrorToast(title: "Failed to select mic", subTitle: "\(error)")
        }
    }

    func setup() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        updateBatteryLevel()
        settings.load()
        media.onSrtConnected = handleSrtConnected
        media.onSrtDisconnected = handleSrtDisconnected
        media.onRtmpConnected = handleRtmpConnected
        media.onRtmpDisconnected = handleRtmpDisconnected
        media.onAudioMuteChange = updateAudioLevel
        updateIconImageFromDatabase()
        setupAudioSession()
        selectMic(orientation: mics[0])
        zoomPresets = database.zoom!.back
        backZoomPresetId = zoomPresets[0].id
        frontZoomPresetId = database.zoom!.front[0].id
        mthkView.videoGravity = .resizeAspect
        logger.handler = debugLog(message:)
        updateDigitalClock(now: Date())
        twitchChat = TwitchChatMobs(model: self)
        reloadStream()
        resetSelectedScene()
        setupPeriodicTimers()
        setupThermalState()
        updateButtonStates()
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
        networkPathMonitor.pathUpdateHandler = handleNetworkPathUpdate(path:)
        networkPathMonitor.start(queue: DispatchQueue.main)
    }

    private func handleNetworkPathUpdate(path: NWPath) {
        logger
            .debug("Network: \(path.debugDescription), All: \(path.availableInterfaces)")
    }

    @objc private func didEnterBackground(animated _: Bool) {
        logger.debug("Did enter background")
    }

    @objc private func willEnterForeground(animated _: Bool) {
        logger.debug("Will enter foreground")
    }

    func updateIconImageFromDatabase() {
        if !isInMyIcons(image: database.iconImage!) {
            logger.warning("Database icon image \(database.iconImage!) is not mine")
            database.iconImage = plainIcon.image
            store()
        }
        iconImage = database.iconImage!
    }

    func handleSettingsUrls(urls: Set<UIOpenURLContext>) {
        for url in urls {
            guard url.url.path.isEmpty else {
                logger.warning("Custom URL path is not empty")
                continue
            }
            guard let query = url.url.query(percentEncoded: false) else {
                logger.warning("Custom URL query is missing")
                continue
            }
            do {
                let query = try MobsSettingsUrl.fromString(query: query)
                var streamCount = 0
                for stream in query.streams ?? [] {
                    let newStream = SettingsStream(name: stream.name)
                    newStream.url = stream.url
                    if let video = stream.video {
                        if let codec = video.codec {
                            newStream.codec = codec
                        }
                    }
                    database.streams.append(newStream)
                    logger.info("Created stream \(newStream.name)")
                    streamCount += 1
                }
                store()
                makeToast(
                    title: "URL import successful",
                    subTitle: "Created \(streamCount) stream(s)"
                )
            } catch {
                logger.error("Failed to import URL with error: \(error)")
                makeErrorToast(title: "URL import failed", subTitle: "\(error)")
            }
        }
    }

    private func setupPeriodicTimers() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            let now = Date()
            self.updateUptime(now: now)
            self.updateDigitalClock(now: now)
            self.updateChatSpeed()
            self.media.updateSrtSpeed()
            self.updateSpeed()
            self.updateTwitchPubSub(now: now)
            self.updateAudioLevel()
            self.updateSrtlaConnectionStatistics()
        })
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true, block: { _ in
            self.updateBatteryLevel()
            self.media.logStatistics()
        })
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { _ in
            self.updateSrtDebugLines()
        })
        takeBrowserSnapshots()
    }

    private func updateSrtDebugLines() {
        if logger.debugEnabled {
            srtDebugLines = media.getSrtStats()
        } else {
            srtDebugLines = []
        }
    }

    private func takeBrowserSnapshots() {
        // Take browser snapshots at about 5 Hz for now.
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false, block: { _ in
            var finisedBrowserEffects = 0
            let browserEffects = self.browserEffectsInCurrentScene()
            if browserEffects.isEmpty {
                self.takeBrowserSnapshots()
                return
            }
            for browserEffect in browserEffects {
                browserEffect.browser.wkwebView.takeSnapshot(with: nil) { image, error in
                    if let error {
                        logger.warning("Browser snapshot error: \(error)")
                    } else if let image {
                        browserEffect.setImage(image: image)
                    } else {
                        logger.warning("No browser image")
                    }
                    finisedBrowserEffects += 1
                    if finisedBrowserEffects == browserEffects.count {
                        self.takeBrowserSnapshots()
                    }
                }
            }
        })
    }

    private func browserEffectsInCurrentScene() -> [BrowserEffect] {
        guard let scene = findEnabledScene(id: selectedSceneId) else {
            return []
        }
        var sceneBrowserEffects: [BrowserEffect] = []
        for widget in scene.widgets where widget.enabled {
            guard let realWidget = findWidget(id: widget.widgetId) else {
                continue
            }
            if realWidget.type != .browser {
                continue
            }
            if let browserEffect = browserEffects[widget.id] {
                sceneBrowserEffects.append(browserEffect)
            } else {
                logger.warning("Browser effect not found")
            }
        }
        return sceneBrowserEffects
    }

    private func removeUnusedImages() {
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

    private func updateTwitchPubSub(now: Date) {
        if numberOfViewersUpdateDate + 60 < now {
            numberOfViewers = noValue
        }
    }

    private func updateAudioLevel() {
        let newAudioLevel = media.getAudioLevel()
        if newAudioLevel.isNaN {
            audioLevel = String("Muted")
        } else {
            audioLevel = "\(Int(newAudioLevel)) dB"
        }
    }

    private func updateSrtlaConnectionStatistics() {
        if isStreamConnceted(), let statistics = media.srtlaConnectionStatistics() {
            srtlaConnectionStatistics = statistics
        } else {
            srtlaConnectionStatistics = noValue
        }
    }

    private func reloadImageEffects() {
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

    private func addVideoEffect(widget: SettingsWidget) {
        switch widget.videoEffect.type {
        case .movie:
            videoEffects[widget.id] = MovieEffect()
        case .grayScale:
            videoEffects[widget.id] = GrayScaleEffect()
        case .sepia:
            videoEffects[widget.id] = SepiaEffect()
        case .bloom:
            videoEffects[widget.id] = BloomEffect()
        case .random:
            videoEffects[widget.id] = RandomEffect()
        case .triple:
            videoEffects[widget.id] = TripleEffect()
        case .noiseReduction:
            videoEffects[widget.id] = NoiseReductionEffect()
        case .seipa:
            videoEffects[widget.id] = SepiaEffect()
        }
    }

    func resetSelectedScene() {
        if !enabledScenes.isEmpty {
            selectedSceneId = enabledScenes[0].id
            sceneIndex = 0
        }
        for videoEffect in videoEffects.values {
            media.unregisterEffect(videoEffect)
        }
        videoEffects.removeAll()
        for widget in database.widgets {
            if widget.type != .videoEffect {
                continue
            }
            addVideoEffect(widget: widget)
        }
        for textEffect in textEffects.values {
            media.unregisterEffect(textEffect)
        }
        textEffects.removeAll()
        for widget in database.widgets {
            if widget.type != .time {
                continue
            }
            textEffects[widget.id] = TextEffect(
                format: widget.text.formatString,
                fontSize: 40)
        }
        for browserEffect in browserEffects.values {
            media.unregisterEffect(browserEffect)
        }
        browserEffects.removeAll()
        for widget in database.widgets {
            if widget.type != .browser {
                continue
            }
            for scene in enabledScenes {
                for sceneWidget in scene.widgets where sceneWidget.widgetId == widget.id {
                    let videoSize = media.getVideoSize()
                    browserEffects[sceneWidget.id] = BrowserEffect(
                        url: URL(string: widget.browser!.url)!,
                        widget: sceneWidget,
                        videoSize: CGSize(
                            width: Double(videoSize.width),
                            height: Double(videoSize.height)
                        )
                    )
                }
            }
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

    private func startNetStream() {
        streamState = .connecting
        makeGoingLiveToast()
        switch stream.getProtocol() {
        case .rtmp:
            rtmpStartStream()
        case .srt:
            media.srtStartStream(
                isSrtla: stream.isSrtla(),
                url: stream.url,
                reconnectTime: reconnectTime,
                targetBitrate: stream.bitrate,
                adaptiveBitrate: stream.adaptiveBitrate!
            )
        }
        updateSpeed()
    }

    private func stopNetStream() {
        reconnectTimer?.invalidate()
        rtmpStopStream()
        media.srtStopStream()
        streamStartDate = nil
        updateUptime(now: Date())
        updateSpeed()
        updateAudioLevel()
        srtlaConnectionStatistics = noValue
        makeStreamEndedToast()
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

    private func setNetStream() {
        media.setNetStream(proto: stream.getProtocol())
        updateTorch()
        updateMute()
        mthkView.attachStream(media.getNetStream())
    }

    private func setStreamResolution() {
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

    func setAdaptiveBitrate(stream: SettingsStream) {
        media.setAdaptiveBitrate(enabled: stream.adaptiveBitrate!)
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

    private func reloadTwitchPubSub() {
        twitchPubSub?.stop()
        numberOfViewers = noValue
        if stream.twitchChannelId != "" {
            twitchPubSub = TwitchPubSub(model: self, channelId: stream.twitchChannelId)
            twitchPubSub!.start()
        } else {
            logger.info("Twitch channel id not configured. No viewers.")
        }
    }

    private func reloadKickPusher() {
        kickPusher?.stop()
        kickPusher = nil
        if stream.kickChatroomId != "" {
            kickPusher = KickPusher(model: self, channelId: stream.kickChatroomId)
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

    private func findEnabledScene(id: UUID) -> SettingsScene? {
        for scene in enabledScenes where id == scene.id {
            return scene
        }
        return nil
    }

    private func getEnabledButtonForWidgetControlledByScene(
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

    private func sceneUpdatedOff() {
        for videoEffect in videoEffects.values {
            media.unregisterEffect(videoEffect)
        }
        for imageEffect in imageEffects.values {
            media.unregisterEffect(imageEffect)
        }
        for textEffect in textEffects.values {
            media.unregisterEffect(textEffect)
        }
        for browserEffect in browserEffects.values {
            media.unregisterEffect(browserEffect)
        }
    }

    private func sceneUpdatedOn(scene: SettingsScene) {
        switch scene.cameraType {
        case .back:
            attachCamera(position: .back)
        case .front:
            attachCamera(position: .front)
        case nil:
            logger.error("Camera type is nil?")
        }
        for sceneWidget in scene.widgets.filter({ widget in widget.enabled }) {
            guard let widget = findWidget(id: sceneWidget.widgetId) else {
                logger.error("Widget not found")
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
                logger.error("Found camera widget")
            case .image:
                if let imageEffect = imageEffects[sceneWidget.id] {
                    media.registerEffect(imageEffect)
                }
            case .time:
                if let textEffect = textEffects[widget.id] {
                    textEffect.x = sceneWidget.x
                    textEffect.y = sceneWidget.y
                    media.registerEffect(textEffect)
                }
            case .videoEffect:
                if var videoEffect = videoEffects[widget.id] {
                    if let noiseReductionEffect = videoEffect as? NoiseReductionEffect {
                        noiseReductionEffect.noiseLevel = widget.videoEffect
                            .noiseReductionNoiseLevel!
                        noiseReductionEffect.sharpness = widget.videoEffect
                            .noiseReductionSharpness!
                    } else if videoEffect is RandomEffect {
                        videoEffect = RandomEffect()
                        videoEffects[widget.id] = videoEffect
                    }
                    media.registerEffect(videoEffect)
                }
            case .webPage:
                logger.error("Found web page widget")
            case .browser:
                if let browserEffect = browserEffects[sceneWidget.id] {
                    media.registerEffect(browserEffect)
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

    private func updateUptime(now: Date) {
        if streamStartDate != nil && isStreamConnceted() {
            let elapsed = now.timeIntervalSince(streamStartDate!)
            uptime = uptimeFormatter.string(from: elapsed)!
        } else {
            uptime = noValue
        }
    }

    private func updateDigitalClock(now: Date) {
        digitalClock = digitalClockFormatter.string(from: now)
    }

    private func updateBatteryLevel() {
        batteryLevel = Double(UIDevice.current.batteryLevel)
    }

    private func updateChatSpeed() {
        chatPostsPerSecond = chatPostsPerSecond * 0.8 +
            Double(numberOfChatPosts) * 0.2
        numberOfChatPosts = 0
    }

    private func updateSpeed() {
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

    private func setupThermalState() {
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

    private func updateThermalState() {
        thermalState = ProcessInfo.processInfo.thermalState
        logger.info("Thermal state is \(thermalState.string())")
    }

    private func attachCamera(position: AVCaptureDevice.Position) {
        guard position != cameraPosition else {
            return
        }
        setAutoFocus()
        cameraDevice = preferredCamera(position: position)
        var isMirrored = false
        cameraPosition = position
        switch position {
        case .back:
            zoomPresets = database.zoom!.back
            zoomLevel = backZoomLevel
            isMirrored = false
        case .front:
            zoomPresets = database.zoom!.front
            zoomLevel = frontZoomLevel
            isMirrored = true
        default:
            break
        }
        media.attachCamera(device: cameraDevice, onSuccess: {
            self.mthkView.isMirrored = isMirrored
        })
        _ = media.setCameraZoomLevel(level: zoomLevel, ramp: true)
        zoomLevelPinch = zoomLevel
    }

    private func rtmpStartStream() {
        media.rtmpStartStream(url: stream.url)
    }

    private func rtmpStopStream() {
        media.rtmpStopStream()
    }

    func toggleTorch() {
        isTorchOn.toggle()
        updateTorch()
    }

    private func updateTorch() {
        media.setTorch(on: isTorchOn)
    }

    func toggleMute() {
        isMuteOn.toggle()
        updateMute()
    }

    private func updateMute() {
        media.setMute(on: isMuteOn)
    }

    func setCameraZoomPreset(id: UUID) {
        switch cameraPosition {
        case .back:
            backZoomPresetId = id
        case .front:
            frontZoomPresetId = id
        default:
            break
        }
        if let preset = findZoomPreset(id: id) {
            if media.setCameraZoomLevel(level: Double(preset.level), ramp: true) != nil {
                setZoomLevel(level: Double(preset.level))
            }
        }
    }

    private func setZoomLevel(level: Double, setPinch: Bool = true) {
        switch cameraPosition {
        case .back:
            backZoomLevel = level
        case .front:
            frontZoomLevel = level
        default:
            break
        }
        zoomLevel = level
        if setPinch {
            zoomLevelPinch = zoomLevel
        }
    }

    func changeZoomLevel(amount: Double) {
        clearZoomId()
        if let level = media.setCameraZoomLevel(
            level: zoomLevelPinch * amount,
            ramp: false
        ) {
            setZoomLevel(level: level, setPinch: false)
        }
    }

    func commitZoomLevel(amount: Double) {
        clearZoomId()
        if let level = media.setCameraZoomLevel(
            level: zoomLevelPinch * amount,
            ramp: false
        ) {
            setZoomLevel(level: level)
        }
    }

    func zoomX() -> Float {
        return factorToX(position: cameraPosition ?? .back, factor: Float(zoomLevel))
    }

    private func clearZoomId() {
        switch cameraPosition {
        case .back:
            backZoomPresetId = UUID()
        case .front:
            frontZoomPresetId = UUID()
        default:
            break
        }
    }

    private func findZoomPreset(id: UUID) -> SettingsZoomPreset? {
        return zoomPresets.first { preset in
            preset.id == id
        }
    }

    private func handleRtmpConnected() {
        onConnected()
    }

    private func handleRtmpDisconnected(message: String) {
        onDisconnected(reason: "RTMP disconnected with message \(message)")
    }

    private func onConnected() {
        makeYouAreLiveToast()
        reconnectTime = firstReconnectTime
        streamStartDate = Date()
        streamState = .connected
        updateUptime(now: Date())
    }

    private func onDisconnected(reason: String) {
        guard streaming else {
            return
        }
        logger.info("stream: Disconnected with reason \(reason)")
        streamState = .disconnected
        stopNetStream()
        makeFffffToast(reason: reason)
        reconnectTimer = Timer
            .scheduledTimer(withTimeInterval: reconnectTime, repeats: false) { _ in
                logger.info("stream: Reconnecting")
                self.startNetStream()
                self.reconnectTime = nextReconnectTime(self.reconnectTime)
            }
    }

    private func handleSrtConnected() {
        onConnected()
    }

    private func handleSrtDisconnected(reason: String) {
        onDisconnected(reason: reason)
    }

    func backZoomUpdated() {
        if !database.zoom!.back.contains(where: { level in
            level.id == backZoomPresetId
        }) {
            backZoomPresetId = database.zoom!.back[0].id
        }
        sceneUpdated(store: true)
    }

    func frontZoomUpdated() {
        if !database.zoom!.front.contains(where: { level in
            level.id == frontZoomPresetId
        }) {
            frontZoomPresetId = database.zoom!.front[0].id
        }
        sceneUpdated(store: true)
    }

    private func makeGoingLiveToast() {
        makeToast(title: "😎 Going live at \(stream.name) 😎")
    }

    private func makeYouAreLiveToast() {
        makeToast(title: "🎉 You are LIVE at \(stream.name) 🎉")
    }

    private func makeStreamEndedToast() {
        makeToast(title: "🤟 Stream ended 🤟")
    }

    private func makeFffffToast(reason: String) {
        makeErrorToast(
            title: "😢 FFFFF 😢",
            font: .system(size: 64).bold(),
            subTitle: reason
        )
    }

    func setFocusPointOfInterest(focusPoint: CGPoint) {
        guard
            let device = cameraDevice, device.isFocusPointOfInterestSupported,
            device.isExposurePointOfInterestSupported
        else {
            logger.warning("Tap to focus not supported for this camera")
            makeErrorToast(title: "Tap to focus not supported for this camera")
            return
        }
        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = focusPoint
            device.focusMode = .autoFocus
            // device.exposurePointOfInterest = focusPoint
            // device.exposureMode = .autoExpose
            device.unlockForConfiguration()
            manualFocusPoint = focusPoint
        } catch let error as NSError {
            logger.error("while locking device for focusPointOfInterest: \(error)")
        }
    }

    func setAutoFocus() {
        if manualFocusPoint == nil {
            return
        }
        guard
            let device = cameraDevice, device.isFocusPointOfInterestSupported
        else {
            logger.warning("Tap to focus not supported for this camera")
            makeErrorToast(title: "Tap to focus not supported for this camera")
            return
        }
        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            device.focusMode = .continuousAutoFocus
            // device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
            // device.exposureMode = .continuousAutoExposure
            device.unlockForConfiguration()
            makeToast(title: "Auto focus")
            manualFocusPoint = nil
        } catch let error as NSError {
            logger.error("while locking device for focusPointOfInterest: \(error)")
        }
    }
}
