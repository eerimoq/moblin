import Foundation
import Combine
import HaishinKit
import PhotosUI
import SwiftUI
import VideoToolbox
import TwitchChat
import Network

enum LiveState {
    case stopped
    case live
}

class ButtonState {
    var isOn: Bool
    var button: SettingsButton
    
    init(isOn: Bool, button: SettingsButton) {
        self.isOn = isOn
        self.button = button
    }
}

struct ButtonPair: Identifiable {
    var id: Int
    var first: ButtonState
    var second: ButtonState? = nil
}

final class Model: ObservableObject {
    private let maxRetryCount: Int = 5
    private var rtmpConnection = RTMPConnection()
    @Published var rtmpStream: RTMPStream!
    private var retryCount: Int = 0
    @Published var liveState: LiveState = .stopped
    @Published var fps: String = "FPS"
    private var nc = NotificationCenter.default
    private var subscriptions = Set<AnyCancellable>()
    private var startDate: Date? = nil
    @Published var uptime: String = ""
    var settings: Settings = Settings()
    var currentTime: String = ""
    var selectedSceneId = UUID()
    private var uptimeFormatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }
    private var currentTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
    private var sizeFormatter : ByteCountFormatter {
        let formatter = ByteCountFormatter()
        formatter.allowsNonnumericFormatting = false
        formatter.countStyle = .decimal
        return formatter
    }
    private var twitchChat: TwitchChatMobs?
    private var twitchPubSub: TwitchPubSub?
    @Published var twitchChatPosts: [Post] = []
    var numberOfTwitchChatPosts: Int = 0
    @Published var twitchChatPostsPerSecond: Float = 0.0
    @Published var numberOfViewers = ""
    @Published var batteryLevel = UIDevice.current.batteryLevel
    @Published var speed = ""
    @Published var thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    private var monochromeEffect: MonochromeEffect = MonochromeEffect()
    private var movieEffect: MovieEffect = MovieEffect()
    var stream: SettingsStream? {
        get {
            for stream in database.streams {
                if stream.enabled {
                    return stream
                }
            }
            return nil
        }
    }
    private var srtla = Srtla()
    private var srtDummySender: DummySender?
    @Published var sceneIndex = 0
    var isTorchOn = false
    var isMuteOn = false
    var isMovieOn = false
    var log: [String] = []
    var location: Location = Location()
    
    var database: Database {
        get {
            settings.database
        }
    }
    
    var enabledScenes: [SettingsScene] {
        get {
            database.scenes.filter({scene in scene.enabled})
        }
    }
    
    var sceneButtons: [SettingsButton] {
        get {
            database.buttons.filter({button in button.enabled && button.scenes.contains(selectedSceneId)})
        }
    }
    
    @Published var buttonPairs: [ButtonPair] = []
    
    func updateButtonStates() {
        let states = sceneButtons
            .prefix(8)
            .map({button in ButtonState(isOn: button.isOn, button: button)})
        var pairs: [ButtonPair] = []
        for index in stride(from: 0, to: states.count, by: 2) {
            if states.count - index > 1 {
                pairs.append(ButtonPair(id: index / 2, first: states[index], second: states[index + 1]))
            } else {
                pairs.append(ButtonPair(id: index / 2, first: states[index]))
            }
        }
        self.buttonPairs = pairs.reversed()
    }
    
    func debugLog(message: String) {
        if log.count > 100 {
            log.removeFirst()
        }
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        log.append("\(timestamp) \(message)")
    }
    
    func setStreamResolution() {
        guard let stream = stream else {
            logger.warning("Cannot set stream resolution.")
            return
        }
        switch stream.resolution {
        case "1920x1080":
            rtmpStream.sessionPreset = .hd1920x1080
        case "1280x720":
            rtmpStream.sessionPreset = .hd1280x720
        default:
            logger.error("Unknown resolution \(stream.resolution).")
        }
    }
    
    func setStreamFPS() {
        guard let stream = stream else {
            logger.warning("Cannot set stream FPS.")
            return
        }
        rtmpStream.frameRate = Double(stream.fps)
    }
    
    func setup(settings: Settings) {
        logger.setLogHandler(handler: debugLog)
        updateCurrentTime(now: Date())
        self.settings = settings
        rtmpStream = RTMPStream(connection: rtmpConnection)
        rtmpStream.videoOrientation = .landscapeRight
        setStreamResolution()
        setStreamFPS()
        rtmpStream.mixer.recorder.delegate = self
        checkDeviceAuthorization()
        twitchChat = TwitchChatMobs(model: self)
        if let stream = stream {
            twitchChat!.start(channelName: stream.twitchChannelName)
            twitchPubSub = TwitchPubSub(model: self, channelId: stream.twitchChannelId)
            twitchPubSub!.start()
        }
        resetSelectedScene()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            DispatchQueue.main.async {
                let now = Date()
                self.updateUptime(now: now)
                self.updateCurrentTime(now: now)
                self.updateBatteryLevel()
                self.updateTwitchChatSpeed()
                self.updateSpeed()
                self.srtDummySender!.sendPacket()
            }
        })
        srtla.start(uri: "srt://192.168.50.72:10000")
        srtDummySender = DummySender(srtla: srtla)
        updateThermalState()
        
        nc.publisher(for: ProcessInfo.thermalStateDidChangeNotification, object: nil)
            .sink { _ in
                DispatchQueue.main.async {
                    self.updateThermalState()
                }
            }
            .store(in: &subscriptions)
        
        rtmpStream.publisher(for: \.currentFPS)
            .sink { [weak self] currentFPS in
                guard let self = self else {
                    return
                }
                DispatchQueue.main.async {
                    self.fps = self.liveState == .stopped ? "" : "\(currentFPS)"
                }
            }
            .store(in: &subscriptions)
        
        rtmpStream.attachAudio(AVCaptureDevice.default(for: .audio)) { error in
            logger.error("model: Attach audio error: \(error)")
        }
        
        attachCamera(position: .back)
        updateButtonStates()
        //location.start()
    }
    
    func resetSelectedScene() {
        if !enabledScenes.isEmpty {
            selectedSceneId = enabledScenes[0].id
            sceneIndex = 0
        }
        sceneUpdated()
    }
    
    func store() {
        settings.store()
    }

    func startStream() {
        liveState = .live
        startPublish()
        updateSpeed()
    }
    
    func stopStream() {
        liveState = .stopped
        stopPublish()
        updateSpeed()
    }

    func reloadStream() {
        stopStream()
        setStreamResolution()
        setStreamFPS()
        reloadTwitchChat()
        reloadTwitchViewers()
    }
    
    func reloadTwitchChat() {
        twitchChat!.stop()
        guard let stream = stream else {
            return
        }
        twitchChat!.start(channelName: stream.twitchChannelName)
        twitchChatPosts = []
        twitchChatPostsPerSecond = 0.0
        numberOfTwitchChatPosts = 0
    }
    
    func reloadTwitchViewers() {
        guard let stream = stream else {
            return
        }
        if let twitchPubSub = twitchPubSub {
            twitchPubSub.stop()
        }
        twitchPubSub = TwitchPubSub(model: self, channelId: stream.twitchChannelId)
        twitchPubSub!.start()
        numberOfViewers = ""
    }

    func rtmpUrlChanged() {
        stopStream()
    }

    func srtUrlChanged() {
        stopStream()
    }

    func srtlaChanged() {
        stopStream()
    }

    func twitchChannelNameUpdated() {
        reloadTwitchChat()
    }

    func twitchChannelIdUpdated() {
        reloadTwitchViewers()
    }

    func findWidget(id: UUID) -> SettingsWidget? {
        for widget in database.widgets {
            if widget.id == id {
                return widget
            }
        }
        return nil
    }
    
    func findEnabledScene(id: UUID) -> SettingsScene? {
        for scene in enabledScenes {
            if id == scene.id {
                return scene
            }
        }
        return nil
    }
    
    func getButtonForWidgetControlledByScene(widget: SettingsWidget, scene: SettingsScene) -> SettingsButton? {
        for button in database.buttons {
            if button.scenes.contains(scene.id) {
                if widget.id == button.widget.widgetId {
                    return button
                }
            }
        }
        return nil
    }

    func sceneUpdatedOff(scene: SettingsScene) {
        for widget in database.widgets {
            switch widget.type {
            case "Camera":
                break
            case "Video effect":
                if let button = getButtonForWidgetControlledByScene(widget: widget, scene: scene) {
                    if button.isOn {
                        continue
                    }
                }
                switch widget.videoEffect.type {
                case "Movie":
                    movieEffectOff()
                default:
                    logger.error("model: Unknown video effect \(widget.videoEffect.type).")
                }
            default:
                logger.error("model: Unknown widget type \(widget.type)")
            }
        }
    }
    
    func sceneUpdatedOn(scene: SettingsScene) {
        for sceneWidget in scene.widgets {
            if let widget = findWidget(id: sceneWidget.widgetId) {
                switch widget.type {
                case "Camera":
                    switch widget.camera.direction {
                    case "Back":
                        attachCamera(position: .back)
                    case "Front":
                        attachCamera(position: .front)
                    default:
                        logger.error("model: Unknown camera widget type \(widget.type).")
                    }
                case "Video effect":
                    if let button = getButtonForWidgetControlledByScene(widget: widget, scene: scene) {
                        if !button.isOn {
                            continue
                        }
                    }
                    switch widget.videoEffect.type {
                    case "Movie":
                        movieEffectOn()
                    default:
                        logger.error("model: Unknown video effect \(widget.videoEffect.type).")
                    }
                default:
                    logger.error("model: Unknown widget type \(widget.type)")
                }
            } else {
                logger.error("model: Widget not found.")
            }
        }
    }
    
    func sceneUpdated() {
        updateButtonStates()
        guard let scene = findEnabledScene(id: selectedSceneId) else {
            return
        }
        sceneUpdatedOff(scene: scene)
        sceneUpdatedOn(scene: scene)
    }
    
    func updateUptimeFromNonMain() {
        DispatchQueue.main.async {
            self.updateUptime(now: Date())
        }
    }

    func updateUptime(now: Date) {
        if self.startDate == nil {
            uptime = ""
        } else {
            let elapsed = now.timeIntervalSince(startDate!)
            uptime = uptimeFormatter.string(from: elapsed)!
        }
    }

    func updateCurrentTime(now: Date) {
        currentTime = currentTimeFormatter.string(from: now)
    }

    func updateBatteryLevel() {
        batteryLevel = UIDevice.current.batteryLevel
    }
    
    func updateTwitchChatSpeed() {
        twitchChatPostsPerSecond = twitchChatPostsPerSecond * 0.8 + Float(numberOfTwitchChatPosts) * 0.2
        numberOfTwitchChatPosts = 0
    }

    func updateSpeed() {
        if liveState == .live {
            var speed = sizeFormatter.string(fromByteCount: Int64(8 * rtmpStream.info.currentBytesPerSecond))
            speed = speed.replacingOccurrences(of: "bytes", with: "b")
            speed = speed.replacingOccurrences(of: "B", with: "b")
            let total = sizeFormatter.string(fromByteCount: rtmpStream.info.byteCount.value)
            self.speed = "\(speed)ps (\(total))"
        } else {
            self.speed = ""
        }
    }

    func checkDeviceAuthorization() {
        let requiredAccessLevel: PHAccessLevel = .readWrite
        PHPhotoLibrary.requestAuthorization(for: requiredAccessLevel) { authorizationStatus in
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
        logger.info("model: Thermal state is \(thermalState)")
    }
    
    func attachCamera(position: AVCaptureDevice.Position) {
        rtmpStream.attachCamera(AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)) { error in
            logger.error("model: Attach camera error: \(error)")
        }
    }

    func startPublish() {
        UIApplication.shared.isIdleTimerDisabled = true
        rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
        rtmpConnection.addEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
        rtmpConnection.connect(rtmpUri())
    }

    func rtmpUri() -> String {
        guard let stream = stream else {
            return ""
        }
        return makeRtmpUri(url: stream.rtmpUrl)
    }

    func rtmpStreamName() -> String {
        guard let stream = stream else {
            return ""
        }
        return makeRtmpStreamName(url: stream.rtmpUrl)
    }

    func stopPublish() {
        UIApplication.shared.isIdleTimerDisabled = false
        rtmpConnection.close()
        rtmpConnection.removeEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
        rtmpConnection.removeEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
        startDate = nil
        updateUptimeFromNonMain()
    }

    func toggleTorch() {
        isTorchOn.toggle()
        rtmpStream.torch.toggle()
    }

    func toggleMute() {
        isMuteOn.toggle()
        rtmpStream.hasAudio.toggle()
    }

    func monochromeEffectOn() {
        _ = rtmpStream.registerVideoEffect(monochromeEffect)
    }

    func monochromeEffectOff() {
        _ = rtmpStream.unregisterVideoEffect(monochromeEffect)
    }

    func movieEffectOn() {
        isMovieOn = true
        _ = rtmpStream.registerVideoEffect(movieEffect)
    }

    func movieEffectOff() {
        isMovieOn = false
        _ = rtmpStream.unregisterVideoEffect(movieEffect)
    }

    func setBackCameraZoomLevel(level: CGFloat) {
        guard let device = rtmpStream.videoCapture(for: 0)?.device, 1 <= level && level < device.activeFormat.videoMaxZoomFactor else {
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
        guard let data: ASObject = e.data as? ASObject, let code: String = data["code"] as? String else {
            return
        }
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            retryCount = 0
            rtmpStream.publish(rtmpStreamName())
            startDate = Date()
            updateUptimeFromNonMain()
        case RTMPConnection.Code.connectFailed.rawValue, RTMPConnection.Code.connectClosed.rawValue:
            startDate = nil
            updateUptimeFromNonMain()
            guard retryCount <= maxRetryCount else {
                return
            }
            Thread.sleep(forTimeInterval: pow(2.0, Double(retryCount)))
            rtmpConnection.connect(rtmpUri())
            retryCount += 1
        default:
            break
        }
    }

    @objc
    private func rtmpErrorHandler(_: Notification) {
        rtmpConnection.connect(rtmpUri())
    }
}

extension Model: IORecorderDelegate {
    func recorder(_ recorder: IORecorder, errorOccured error: IORecorder.Error) {
        logger.error("model: \(error)")
    }

    func recorder(_ recorder: IORecorder, finishWriting writer: AVAssetWriter) {
        PHPhotoLibrary.shared().performChanges({() -> Void in
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: writer.outputURL)
        }, completionHandler: { _, error -> Void in
            do {
                try FileManager.default.removeItem(at: writer.outputURL)
            } catch {
                logger.error("model: \(error)")
            }
        })
    }
}
