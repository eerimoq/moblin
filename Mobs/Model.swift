import Combine
import Foundation
import HaishinKit
import Network
import PhotosUI
import SRTHaishinKit
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

final class Model: ObservableObject, NetStreamDelegate, SrtlaDelegate {
    private var rtmpConnection = RTMPConnection()
    private var srtConnection = SRTConnection()
    private var rtmpStream: RTMPStream!
    private var srtStream: SRTStream!
    private var srtla: Srtla?
    private var srtTotalByteCount: Int64 = 0
    private var srtPreviousTotalByteCount: Int64 = 0
    private var srtSpeed: Int64 = 0
    var netStream: NetStream!
    private var streamState: StreamState = .disconnected
    private var streaming = false
    private var streamStartDate: Date?
    private var srtConnectedObservation: NSKeyValueObservation?
    @Published var isLive = false
    private var subscriptions = Set<AnyCancellable>()
    @Published var uptime = noValue
    @Published var currentConnectionType = noValue
    var settings = Settings()
    var digitalClock = noValue
    var selectedSceneId = UUID()
    private var twitchChat: TwitchChatMobs!
    private var twitchPubSub: TwitchPubSub?
    @Published var twitchChatPosts: [Post] = []
    var numberOfTwitchChatPosts = 0
    @Published var twitchChatPostsPerSecond = 0.0
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
    var log: [String] = []
    var imageStorage = ImageStorage()
    @Published var buttonPairs: [ButtonPair] = []
    private var reconnectTimer: Timer?
    private var reconnectTime = firstReconnectTime

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
        if log.count > 100 {
            log.removeFirst()
        }
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        log.append("\(timestamp) \(message)")
    }

    func setup(settings: Settings) {
        mthkView.videoGravity = .resizeAspect
        logger.setLogHandler(handler: debugLog)
        updateDigitalClock(now: Date())
        self.settings = settings
        checkDeviceAuthorization()
        twitchChat = TwitchChatMobs(model: self)
        reloadStream()
        resetSelectedScene()
        setupPeriodicTimer()
        setupThermalState()
        updateButtonStates()
        sceneUpdated(imageEffectChanged: true, store: false)
        removeUnusedImages()
    }

    func setupPeriodicTimer() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            DispatchQueue.main.async {
                let now = Date()
                self.updateUptime(now: now)
                self.updateDigitalClock(now: now)
                self.updateBatteryLevel()
                self.updateTwitchChatSpeed()
                self.updateSrtSpeed()
                self.updateSpeed()
                self.updateTwitchPubSub(now: now)
            }
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
                logger.info("model: Removing unused image \(id)")
                imageStorage.remove(id: id)
            }
        }
    }

    func updateTwitchPubSub(now: Date) {
        if numberOfViewersUpdateDate + 60 < now {
            numberOfViewers = noValue
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
        logger.info("stream: \(netStream.videoSettings)")
        logger.info("stream: \(netStream.audioSettings)")
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
    }

    func startNetStream() {
        streamState = .connecting
        switch stream.getProtocol() {
        case .rtmp:
            rtmpStartStream()
        case .srt:
            srtStartStream()
        }
        updateSpeed()
    }

    func stopNetStream() {
        reconnectTimer?.invalidate()
        rtmpStopStream()
        srtStopStream()
        streamStartDate = nil
        updateUptime(now: Date())
        updateSpeed()
        currentConnectionType = noValue
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
    }

    func reloadStreamIfEnabled(stream: SettingsStream) {
        store()
        if stream.enabled {
            reloadStream()
            sceneUpdated()
        }
    }

    func setNetStream() {
        switch stream.getProtocol() {
        case .rtmp:
            srtStream = nil
            rtmpStream = RTMPStream(connection: rtmpConnection)
            netStream = rtmpStream
        case .srt:
            rtmpStream = nil
            srtStream = SRTStream(srtConnection)
            netStream = srtStream
        }
        netStream.delegate = self
        netStream.videoOrientation = .landscapeRight
        updateTorch()
        updateMute()
        mthkView.attachStream(netStream)
    }

    func setStreamResolution() {
        switch stream.resolution {
        case .r1920x1080:
            netStream.sessionPreset = .hd1920x1080
            netStream.videoSettings.videoSize = .init(width: 1920, height: 1080)
        case .r1280x720:
            netStream.sessionPreset = .hd1280x720
            netStream.videoSettings.videoSize = .init(width: 1280, height: 720)
        case .r854x480:
            netStream.sessionPreset = .hd1280x720
            netStream.videoSettings.videoSize = .init(width: 854, height: 480)
        case .r640x360:
            netStream.sessionPreset = .hd1280x720
            netStream.videoSettings.videoSize = .init(width: 640, height: 360)
        case .r426x240:
            netStream.sessionPreset = .hd1280x720
            netStream.videoSettings.videoSize = .init(width: 426, height: 240)
        }
    }

    func setStreamFPS() {
        netStream.frameRate = Double(stream.fps)
    }

    func setStreamBitrate(stream: SettingsStream) {
        netStream.videoSettings.bitRate = stream.bitrate
    }

    func setStreamCodec() {
        switch stream.codec {
        case .h264avc:
            netStream.videoSettings
                .profileLevel = kVTProfileLevel_H264_High_AutoLevel as String
        case .h265hevc:
            netStream.videoSettings
                .profileLevel = kVTProfileLevel_HEVC_Main_AutoLevel as String
        }
    }

    func isTwitchChatConnected() -> Bool {
        return twitchChat?.isConnected() ?? false
    }

    func isTwitchPubSubConnected() -> Bool {
        return twitchPubSub?.isConnected() ?? false
    }

    func isStreamOk() -> Bool {
        return streamState != .disconnected
    }

    func isStreamConnceted() -> Bool {
        return streamState == .connected
    }

    func isStreaming() -> Bool {
        return streaming
    }

    func reloadTwitchChat() {
        twitchChat.stop()
        twitchChat.start(channelName: stream.twitchChannelName)
        twitchChatPostsPerSecond = 0
        twitchChatPosts = []
        numberOfTwitchChatPosts = 0
    }

    func reloadTwitchPubSub() {
        twitchPubSub?.stop()
        numberOfViewers = noValue
        twitchPubSub = TwitchPubSub(model: self, channelId: stream.twitchChannelId)
        twitchPubSub!.start()
    }

    func twitchChannelNameUpdated() {
        reloadTwitchChat()
    }

    func twitchChannelIdUpdated() {
        reloadTwitchPubSub()
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
            _ = netStream.unregisterVideoEffect(imageEffect)
        }
    }

    func sceneUpdatedOn(scene: SettingsScene) {
        netStream.attachAudio(AVCaptureDevice.default(for: .audio)) { error in
            logger.error("stream: Attach audio error: \(error)")
        }
        for sceneWidget in scene.widgets.filter({ widget in widget.enabled }) {
            guard let widget = findWidget(id: sceneWidget.widgetId) else {
                logger.error("model: Widget not found.")
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
                    _ = netStream.registerVideoEffect(imageEffect)
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
        sceneUpdatedOff()
        if imageEffectChanged {
            reloadImageEffects()
        }
        if store {
            self.store()
        }
        updateButtonStates()
        guard let scene = findEnabledScene(id: selectedSceneId) else {
            return
        }
        sceneUpdatedOn(scene: scene)
    }

    func updateUptimeFromNonMain() {
        DispatchQueue.main.async {
            self.updateUptime(now: Date())
        }
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

    func updateTwitchChatSpeed() {
        twitchChatPostsPerSecond = twitchChatPostsPerSecond * 0.8 +
            Double(numberOfTwitchChatPosts) * 0.2
        numberOfTwitchChatPosts = 0
    }

    func updateSrtSpeed() {
        srtSpeed = srtTotalByteCount - srtPreviousTotalByteCount
        srtPreviousTotalByteCount = srtTotalByteCount
    }

    func streamSpeed() -> Int64 {
        if netStream === rtmpStream {
            return Int64(8 * rtmpStream.info.currentBytesPerSecond)
        } else {
            return 8 * srtSpeed
        }
    }

    func streamTotal() -> Int64 {
        if netStream === rtmpStream {
            return rtmpStream.info.byteCount.value
        } else {
            return srtTotalByteCount
        }
    }

    func updateSpeed() {
        if isLive {
            let speed = formatBytesPerSecond(speed: streamSpeed())
            let total = sizeFormatter.string(fromByteCount: streamTotal())
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
                    logger.warning("model: limited authorization granted")
                case .authorized:
                    logger.info("model: authorization granted")
                default:
                    logger.error("model: Unimplemented")
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
        logger.info("model: Thermal state is \(thermalState.string())")
    }

    func attachCamera(position: AVCaptureDevice.Position) {
        let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position
        )
        netStream.attachCamera(device) { error in
            logger.error("stream: Attach camera error: \(error)")
        }
        zoomLevel = Double(device?.videoZoomFactor ?? 1.0)
        setCameraZoomLevel(level: zoomLevel)
    }

    func rtmpStartStream() {
        rtmpConnection.addEventListener(
            .rtmpStatus,
            selector: #selector(rtmpStatusHandler),
            observer: self
        )
        rtmpConnection.connect(rtmpUri())
    }

    func rtmpStopStream() {
        rtmpConnection.removeEventListener(
            .rtmpStatus,
            selector: #selector(rtmpStatusHandler),
            observer: self
        )
        rtmpConnection.close()
    }

    func rtmpUri() -> String {
        return makeRtmpUri(url: stream.rtmpUrl)
    }

    func rtmpStreamName() -> String {
        return makeRtmpStreamName(url: stream.rtmpUrl)
    }

    func toggleTorch() {
        isTorchOn.toggle()
        updateTorch()
    }

    func updateTorch() {
        netStream.torch = isTorchOn
    }

    func toggleMute() {
        isMuteOn.toggle()
        updateMute()
    }

    func updateMute() {
        netStream.hasAudio = !isMuteOn
    }

    func grayScaleEffectOn() {
        _ = netStream.registerVideoEffect(grayScaleEffect)
    }

    func grayScaleEffectOff() {
        _ = netStream.unregisterVideoEffect(grayScaleEffect)
    }

    func movieEffectOn() {
        _ = netStream.registerVideoEffect(movieEffect)
    }

    func movieEffectOff() {
        _ = netStream.unregisterVideoEffect(movieEffect)
    }

    func seipaEffectOn() {
        _ = netStream.registerVideoEffect(seipaEffect)
    }

    func seipaEffectOff() {
        _ = netStream.unregisterVideoEffect(seipaEffect)
    }

    func bloomEffectOn() {
        _ = netStream.registerVideoEffect(bloomEffect)
    }

    func bloomEffectOff() {
        _ = netStream.unregisterVideoEffect(bloomEffect)
    }

    func setCameraZoomLevel(level: Double) {
        guard let device = netStream.videoCapture(for: 0)?.device,
              level >= 1 && level < device.activeFormat.videoMaxZoomFactor
        else {
            return
        }
        do {
            try device.lockForConfiguration()
            device.ramp(toVideoZoomFactor: level, withRate: 5.0)
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.warning("model: while locking device for ramp: \(error)")
        }
    }

    @objc
    private func rtmpStatusHandler(_ notification: Notification) {
        let e = Event.from(notification)
        guard let data: ASObject = e.data as? ASObject,
              let code: String = data["code"] as? String
        else {
            return
        }
        DispatchQueue.main.async {
            switch code {
            case RTMPConnection.Code.connectSuccess.rawValue:
                self.rtmpStream.publish(self.rtmpStreamName())
                self.onConnected()
            case RTMPConnection.Code.connectFailed.rawValue,
                 RTMPConnection.Code.connectClosed.rawValue:
                self.onDisconnected()
            default:
                break
            }
        }
    }

    func onConnected() {
        logger.info("stream: Connected")
        reconnectTime = firstReconnectTime
        streamStartDate = Date()
        streamState = .connected
        updateUptime(now: Date())
    }

    func onDisconnected() {
        logger.info("stream: Disconnected")
        guard streaming else {
            return
        }
        streamState = .disconnected
        stopNetStream()
        reconnectTimer = Timer
            .scheduledTimer(withTimeInterval: reconnectTime, repeats: false) { _ in
                logger.info("stream: Reconnecting")
                self.startNetStream()
                self.reconnectTime = nextReconnectTime(self.reconnectTime)
            }
    }

    // NetStreamDelegate
    func stream(
        _: NetStream,
        didOutput _: AVAudioBuffer,
        presentationTimeStamp _: CMTime
    ) {
        logger.debug("stream: Playback an audio packet incoming.")
    }

    func stream(_: NetStream, didOutput _: CMSampleBuffer) {
        logger.debug("stream: Playback a video packet incoming.")
    }

    #if os(iOS)
        func stream(
            _: NetStream,
            sessionWasInterrupted _: AVCaptureSession,
            reason _: AVCaptureSession.InterruptionReason?
        ) {
            logger.info("stream: Session was interrupted.")
        }

        func stream(_: NetStream, sessionInterruptionEnded _: AVCaptureSession) {
            logger.info("stream: Session interrupted ended.")
        }
    #endif

    func stream(_: NetStream, videoCodecErrorOccurred error: VideoCodec.Error) {
        logger.error("stream: Video codec error: \(error)")
    }

    func stream(_: NetStream,
                audioCodecErrorOccurred error: HaishinKit.AudioCodec.Error)
    {
        logger.error("stream: Audio codec error: \(error)")
    }

    func streamWillDropFrame(_: NetStream) -> Bool {
        // logger.warning("stream: Drop video frame.")
        return false
    }

    func streamDidOpen(_: NetStream) {
        // logger.info("stream: Stream opened.")
    }

    /// SRT
    func setupSrtConnectionStateListener() {
        srtConnectedObservation = srtConnection.observe(\.connected, options: [
            .new,
            .old,
        ]) { [weak self] _, connected in
            guard let self else {
                return
            }
            DispatchQueue.main.async {
                if connected.newValue! {
                    self.onConnected()
                } else {
                    self.onDisconnected()
                }
            }
        }
    }

    func srtStartStream() {
        srtTotalByteCount = 0
        srtPreviousTotalByteCount = 0
        srtla?.stop()
        srtla = Srtla(delegate: self, passThrough: !stream.isSrtla())
        srtla!.start(uri: stream.srtUrl)
    }

    func srtStopStream() {
        srtConnectedObservation = nil
        srtConnection.close()
        srtla?.stop()
        srtla = nil
    }

    func srtlaReady(port: UInt16) {
        DispatchQueue.main.async {
            self.setupSrtConnectionStateListener()
            DispatchQueue(label: "com.eerimoq.srt").async {
                do {
                    try self.srtConnection.open(URL(string: "srt://localhost:\(port)")!)
                    self.srtStream?.publish()
                } catch {
                    DispatchQueue.main.async {
                        self.onDisconnected()
                    }
                }
            }
        }
    }

    func srtlaError() {
        logger.info("stream: srtla: listener error")
    }

    func srtlaPacketSent(byteCount: Int) {
        DispatchQueue.main.async {
            self.srtTotalByteCount += Int64(byteCount)
        }
    }

    func srtlaPacketReceived(byteCount: Int) {
        DispatchQueue.main.async {
            self.srtTotalByteCount += Int64(byteCount)
        }
    }

    func srtlaConnectionTypeChanged(type: String) {
        DispatchQueue.main.async {
            self.currentConnectionType = type
        }
    }
}
