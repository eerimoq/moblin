import Combine
import Foundation
import HaishinKit
import Network
import PhotosUI
import SRTHaishinKit
import SwiftUI
import TwitchChat
import VideoToolbox

let unknownNumberOfViewers = ""

class ButtonState {
    var isOn: Bool
    var button: SettingsButton

    init(isOn: Bool, button: SettingsButton) {
        self.isOn = isOn
        self.button = button
    }
}

enum NetStreamState {
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
    private var retryCount: Int = 0
    private let maxRetryCount: Int = 5
    private var rtmpConnection = RTMPConnection()
    private var srtConnection = SRTConnection()
    private var rtmpStream: RTMPStream?
    private var srtStream: SRTStream?
    var netStream: NetStream!
    private var netStreamState: NetStreamState = .disconnected
    private var srtConnectedObservation: NSKeyValueObservation?
    @Published var isLive = false
    private var notificationCenter = NotificationCenter.default
    private var subscriptions = Set<AnyCancellable>()
    private var publishing = false
    private var startDate: Date?
    @Published var uptime = ""
    var settings = Settings()
    var currentTime = ""
    var selectedSceneId = UUID()
    private var twitchChat: TwitchChatMobs!
    private var twitchPubSub: TwitchPubSub?
    @Published var twitchChatPosts: [Post] = []
    var numberOfTwitchChatPosts = 0
    @Published var twitchChatPostsPerSecond: Float = 0
    @Published var numberOfViewers = unknownNumberOfViewers
    var numberOfViewersDate = Date()
    @Published var batteryLevel = UIDevice.current.batteryLevel
    @Published var speed = ""
    @Published var thermalState = ProcessInfo.processInfo.thermalState
    @Published var zoomLevel: CGFloat = 1.0
    private var grayScaleEffect = GrayScaleEffect()
    private var movieEffect = MovieEffect()
    private var seipaEffect = SeipaEffect()
    private var bloomEffect = BloomEffect()
    private var imageEffects: [UUID: ImageEffect] = [:]
    @Published var sceneIndex = 0
    private var isTorchOn = false
    private var isMuteOn = false
    var log: [String] = []
    private var location = Location()
    var imageStorage = ImageStorage()
    @Published var buttonPairs: [ButtonPair] = []
    var mthkView = MTHKView(frame: .zero)
    private var srtla: Srtla?
    private var srtTotalByteCount: Int64 = 0
    private var srtPreviousTotalByteCount: Int64 = 0
    private var srtSpeed: Int64 = 0
    
    var database: Database {
        settings.database
    }

    var stream: SettingsStream? {
        for stream in database.streams where stream.enabled {
            return stream
        }
        return nil
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
        updateCurrentTime(now: Date())
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
                self.updateCurrentTime(now: now)
                self.updateBatteryLevel()
                self.updateTwitchChatSpeed()
                self.updateSrtSpeed()
                self.updateSpeed()
                self.updateTwitchPubSub()
            }
        })
    }

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
                    logger.info("model: srt: Connected")
                    self.srtStream!.publish()
                    self.startDate = Date()
                    self.netStreamState = .connected
                    self.updateUptimeFromNonMain()
                    self.retryCount = 0
                } else {
                    logger.info("model: srt: Disconnected")
                    self.startDate = nil
                    self.netStreamState = .disconnected
                    self.updateUptimeFromNonMain()
                    self.srtReconnect()
                }
            }
        }
    }

    func setupThermalState() {
        updateThermalState()
        notificationCenter.publisher(
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

    func updateTwitchPubSub() {
        if numberOfViewersDate + 60 < Date() {
            numberOfViewers = unknownNumberOfViewers
        }
    }

    func setupImageEffects(scene: SettingsScene) {
        imageEffects.removeAll()
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
        isLive = true
        startPublish()
        updateSpeed()
    }

    func stopStream() {
        isLive = false
        stopPublish()
        updateSpeed()
    }

    func reloadStream() {
        stopStream()
        if let stream {
            setNetStream(stream: stream)
            setStreamResolution(stream: stream)
            setStreamFPS(stream: stream)
            setStreamCodec(stream: stream)
            setStreamBitrate(stream: stream)
        }
        reloadTwitchChat()
        reloadTwitchViewers()
    }

    func reloadStreamIfEnabled(stream: SettingsStream) {
        store()
        if stream.enabled {
            reloadStream()
        }
    }

    func setNetStream(stream: SettingsStream) {
        switch stream.proto {
        case .rtmp:
            srtStream = nil
            rtmpStream = RTMPStream(connection: rtmpConnection)
            netStream = rtmpStream!
        case .srt:
            rtmpStream = nil
            srtStream = SRTStream(srtConnection)
            netStream = srtStream!
        }
        netStream.delegate = self
        netStream.videoOrientation = .landscapeRight
        mthkView.attachStream(netStream)
    }

    func setStreamResolution(stream: SettingsStream) {
        switch stream.resolution {
        case .r1920x1080:
            netStream.sessionPreset = .hd1920x1080
            netStream.videoSettings.videoSize = .init(width: 1920, height: 1080)
        case .r1280x720:
            netStream.sessionPreset = .hd1280x720
            netStream.videoSettings.videoSize = .init(width: 1280, height: 720)
        }
    }

    func setStreamFPS(stream: SettingsStream) {
        netStream.frameRate = Double(stream.fps)
    }

    func setStreamBitrate(stream: SettingsStream) {
        netStream.videoSettings.bitRate = stream.bitrate
    }

    func setStreamCodec(stream: SettingsStream) {
        switch stream.codec {
        case .h264avc:
            netStream.videoSettings
                .profileLevel = kVTProfileLevel_H264_Baseline_3_1 as String
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

    func isNetStreamOk() -> Bool {
        return netStreamState != .disconnected
    }

    func isNetStreamConnceted() -> Bool {
        return netStreamState == .connected
    }

    func isPublishing() -> Bool {
        return publishing
    }

    func reloadTwitchChat() {
        twitchChat.stop()
        if let stream {
            twitchChat.start(channelName: stream.twitchChannelName)
        }
        twitchChatPostsPerSecond = 0
        twitchChatPosts = []
        numberOfTwitchChatPosts = 0
    }

    func reloadTwitchViewers() {
        if let twitchPubSub {
            twitchPubSub.stop()
        }
        numberOfViewers = unknownNumberOfViewers
        guard let stream else {
            return
        }
        twitchPubSub = TwitchPubSub(model: self, channelId: stream.twitchChannelId)
        twitchPubSub!.start()
    }

    func twitchChannelNameUpdated() {
        reloadTwitchChat()
    }

    func twitchChannelIdUpdated() {
        reloadTwitchViewers()
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
            logger.error("model: Attach audio error: \(error)")
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
        if store {
            self.store()
        }
        updateButtonStates()
        guard let scene = findEnabledScene(id: selectedSceneId) else {
            return
        }
        sceneUpdatedOff()
        if imageEffectChanged {
            setupImageEffects(scene: scene)
        }
        sceneUpdatedOn(scene: scene)
    }

    func updateUptimeFromNonMain() {
        DispatchQueue.main.async {
            self.updateUptime(now: Date())
        }
    }

    func updateUptime(now: Date) {
        if startDate != nil && isNetStreamConnceted() {
            let elapsed = now.timeIntervalSince(startDate!)
            uptime = uptimeFormatter.string(from: elapsed)!
        } else {
            uptime = ""
        }
    }

    func updateCurrentTime(now: Date) {
        currentTime = currentTimeFormatter.string(from: now)
    }

    func updateBatteryLevel() {
        batteryLevel = UIDevice.current.batteryLevel
    }

    func updateTwitchChatSpeed() {
        twitchChatPostsPerSecond = twitchChatPostsPerSecond * 0.8 +
            Float(numberOfTwitchChatPosts) * 0.2
        numberOfTwitchChatPosts = 0
    }

    func updateSrtSpeed() {
        srtSpeed = srtTotalByteCount - srtPreviousTotalByteCount
        srtPreviousTotalByteCount = srtTotalByteCount
    }
    
    func streamSpeed() -> Int64 {
        if netStreamState != .connected {
            return 0
        }
        if netStream === rtmpStream {
            return Int64(8 * rtmpStream!.info.currentBytesPerSecond)
        } else {
            return 8 * srtSpeed
        }
    }
    
    func streamTotal() -> Int64 {
        if netStreamState != .connected {
            return 0
        }
        if netStream === rtmpStream {
            return rtmpStream!.info.byteCount.value
        } else {
            return srtTotalByteCount
        }
    }

    func updateSpeed() {
        if isLive {
            let speed = formatBytesPerSecond(speed: streamSpeed())
            let total = sizeFormatter.string(fromByteCount: streamTotal())
            self.speed = "\(speed) (\(total))"
        } else {
            speed = ""
        }
    }

    func checkDeviceAuthorization() {
        let requiredAccessLevel: PHAccessLevel = .readWrite
        PHPhotoLibrary
            .requestAuthorization(for: requiredAccessLevel) { authorizationStatus in
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
            logger.error("model: Attach camera error: \(error)")
        }
        zoomLevel = device?.videoZoomFactor ?? 1.0
        setCameraZoomLevel(level: zoomLevel)
    }

    func srtConnect() {
        srtTotalByteCount = 0
        srtPreviousTotalByteCount = 0
        srtla?.stop()
        srtla = Srtla(delegate: self, passThrough: !stream!.srtla)
        srtla!.start(uri: stream!.srtUrl)
    }
    
    func srtReconnect() {
        guard retryCount <= maxRetryCount else {
            logger.error("model: srt: Failed to connect to server")
            return
        }
        Thread.sleep(forTimeInterval: 2.0)
        logger.info("model: srt: Reconnecting")
        retryCount += 1
        srtConnect()
    }
    
    func startPublish() {
        publishing = true
        netStreamState = .connecting
        UIApplication.shared.isIdleTimerDisabled = true
        switch stream?.proto {
        case .rtmp:
            rtmpConnection.addEventListener(
                .rtmpStatus,
                selector: #selector(rtmpStatusHandler),
                observer: self
            )
            rtmpConnection.addEventListener(
                .ioError,
                selector: #selector(rtmpErrorHandler),
                observer: self
            )
            rtmpConnection.connect(rtmpUri())
        case .srt:
            srtConnect()
        case nil:
            break
        }
    }

    func stopPublish() {
        if !publishing {
            return
        }
        publishing = false
        UIApplication.shared.isIdleTimerDisabled = false
        rtmpConnection.removeEventListener(
            .rtmpStatus,
            selector: #selector(rtmpStatusHandler),
            observer: self
        )
        rtmpConnection.removeEventListener(
            .ioError,
            selector: #selector(rtmpErrorHandler),
            observer: self
        )
        rtmpConnection.close()
        srtConnectedObservation = nil
        srtConnection.close()
        srtla?.stop()
        srtla = nil
        startDate = nil
        updateUptime(now: Date())
    }

    func rtmpUri() -> String {
        guard let stream else {
            return ""
        }
        return makeRtmpUri(url: stream.rtmpUrl)
    }

    func rtmpStreamName() -> String {
        guard let stream else {
            return ""
        }
        return makeRtmpStreamName(url: stream.rtmpUrl)
    }

    func toggleTorch() {
        isTorchOn.toggle()
        netStream.torch.toggle()
    }

    func toggleMute() {
        isMuteOn.toggle()
        netStream.hasAudio.toggle()
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

    func setCameraZoomLevel(level: CGFloat) {
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
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            logger.info("model: rtmp: Connected")
            retryCount = 0
            rtmpStream!.publish(rtmpStreamName())
            startDate = Date()
            netStreamState = .connected
            updateUptimeFromNonMain()
        case RTMPConnection.Code.connectFailed.rawValue,
             RTMPConnection.Code.connectClosed.rawValue:
            logger.info("model: rtmp: Disconnected")
            netStreamState = .disconnected
            startDate = nil
            updateUptimeFromNonMain()
            guard retryCount <= maxRetryCount else {
                logger.error("model: rtmp: Failed to connect to server")
                return
            }
            Thread.sleep(forTimeInterval: 2.0)
            logger.info("model: rtmp: Reconnecting")
            rtmpConnection.connect(rtmpUri())
            retryCount += 1
        default:
            break
        }
    }

    @objc
    private func rtmpErrorHandler(_: Notification) {
        logger.error("model: rtmp: error")
        rtmpConnection.connect(rtmpUri())
    }
}

extension Model: IORecorderDelegate {
    func recorder(_: IORecorder, errorOccured error: IORecorder.Error) {
        logger.error("model: \(error)")
    }

    func recorder(_: IORecorder, finishWriting writer: AVAssetWriter) {
        PHPhotoLibrary.shared().performChanges({ () in
            PHAssetChangeRequest
                .creationRequestForAssetFromVideo(atFileURL: writer.outputURL)
        }, completionHandler: { _, error in
            do {
                try FileManager.default.removeItem(at: writer.outputURL)
            } catch {
                logger.error("model: \(error)")
            }
        })
    }

    // NetStreamDelegate
    func stream(
        _: NetStream,
        didOutput _: AVAudioBuffer,
        presentationTimeStamp _: CMTime
    ) {
        logger.debug("model: Playback an audio packet incoming.")
    }

    func stream(_: NetStream, didOutput _: CMSampleBuffer) {
        logger.debug("model: Playback a video packet incoming.")
    }

    #if os(iOS)
        func stream(
            _: NetStream,
            sessionWasInterrupted _: AVCaptureSession,
            reason _: AVCaptureSession.InterruptionReason?
        ) {
            logger.info("model: Session was interrupted.")
        }

        func stream(_: NetStream, sessionInterruptionEnded _: AVCaptureSession) {
            logger.info("model: Session interrupted ended.")
        }
    #endif

    func stream(_: NetStream, videoCodecErrorOccurred error: VideoCodec.Error) {
        logger.error("model: Video codec error: \(error)")
    }

    func stream(_: NetStream,
                audioCodecErrorOccurred error: HaishinKit.AudioCodec.Error)
    {
        logger.error("model: Audio codec error: \(error)")
    }

    func streamWillDropFrame(_: NetStream) -> Bool {
        // logger.warning("model: Drop video frame.")
        return false
    }

    func streamDidOpen(_: NetStream) {
        // logger.info("model: Stream opened.")
    }
    
    func listenerReady(port: UInt16) {
        DispatchQueue.main.async {
            self.setupSrtConnectionStateListener()
            self.srtConnection.open(URL(string: "srt://localhost:\(port)")!)
        }
    }
    
    func listenerError() {
        logger.info("model: srtla: listener error")
    }
    
    func packetSent(byteCount: Int) {
        DispatchQueue.main.async {
            self.srtTotalByteCount += Int64(byteCount)
        }
    }
    
    func packetReceived(byteCount: Int) {
        DispatchQueue.main.async {
            self.srtTotalByteCount += Int64(byteCount)
        }
    }
}
