import Foundation
import Combine
import HaishinKit
import PhotosUI
import SwiftUI
import VideoToolbox
import TwitchChat

enum LiveState {
    case goLive
    case stop
}

final class Model: ObservableObject {
    let maxRetryCount: Int = 5

    private var rtmpConnection = RTMPConnection()
    @Published var rtmpStream: RTMPStream!
    @Published var currentPosition: AVCaptureDevice.Position = .back
    private var retryCount: Int = 0
    @Published var liveState: LiveState = .goLive
    @Published var fps: String = "FPS"
    private var nc = NotificationCenter.default
    var subscriptions = Set<AnyCancellable>()
    var startDate: Date? = nil
    @Published var uptime: String = ""

    @Published var numberOfScenes = 0
    @Published var numberOfWidgets = 0
    @Published var numberOfVariables = 0
    @Published var numberOfConnections = 0
    var widgets = ["Sub goal", "Earnings", "Chat", "Back camera", "Front camera", "Recording"]
    var settings: Settings = Settings()
    @Published var currentTime: String = Date().formatted(date: .omitted, time: .shortened)
    var selectedScene: String = "Main"

    var uptimeFormatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }

    var updateTimer: Timer? = nil

    var frameRate: String = "30.0" {
        willSet {
            rtmpStream.frameRate = Float64(newValue) ?? 30.0
            objectWillChange.send()
        }
    }

    private var twitchChat: TwitchChatMobs?
    private var twitchPubSub: TwitchPubSub?
    @Published var twitchChatPosts: [Post] = []
    @Published var numberOfViewers = ""

    func store() {
        settings.store()
    }

    var database: Database {
        get {
            settings.database
        }
    }

    func reloadConnection() {
        twitchChat = TwitchChatMobs(channelName: selectedConnection().twitchChannelName, model: self)
        twitchChat!.start()
        twitchPubSub = TwitchPubSub(model: self)
        twitchPubSub!.start(channelId: selectedConnection().twitchChannelId)
    }
    
    func selectedConnection() -> SettingsConnection {
        for connection in database.connections {
            if connection.enabled {
                return connection
            }
        }
        return database.connections[0]
    }

    func config(settings: Settings) {
        self.settings = settings
        numberOfScenes = database.scenes.count
        numberOfWidgets = database.widgets.count
        numberOfVariables = database.variables.count
        numberOfConnections = database.connections.count
        rtmpStream = RTMPStream(connection: rtmpConnection)
        rtmpStream.videoOrientation = .landscapeRight
        rtmpStream.sessionPreset = .hd1280x720
        rtmpStream.mixer.recorder.delegate = self
        checkDeviceAuthorization()
        twitchChat = TwitchChatMobs(channelName: selectedConnection().twitchChannelName, model: self)
        twitchChat!.start()
        twitchPubSub = TwitchPubSub(model: self)
        twitchPubSub!.start(channelId: selectedConnection().twitchChannelId)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            DispatchQueue.main.async {
                let now = Date()
                self.updateUptime(now: now)
                self.updateCurrentTime(now: now)
            }
        })
    }

    func updateUptimeFromNonMain() {
        DispatchQueue.main.async {
            self.updateUptime(now: Date())
        }
    }

    func updateUptime(now: Date) {
        if self.startDate == nil {
            self.uptime = ""
        } else {
            let elapsed = now.timeIntervalSince(self.startDate!)
            self.uptime = self.uptimeFormatter.string(from: elapsed)!
        }
    }

    func updateCurrentTime(now: Date) {
        self.currentTime = now.formatted(date: .omitted, time: .shortened)
    }

    func checkDeviceAuthorization() {
        let requiredAccessLevel: PHAccessLevel = .readWrite
        PHPhotoLibrary.requestAuthorization(for: requiredAccessLevel) { authorizationStatus in
            switch authorizationStatus {
            case .limited:
                print("limited authorization granted")
            case .authorized:
                print("authorization granted")
            default:
                print("Unimplemented")
            }
        }
    }

    func registerForPublishEvent() {
        rtmpStream.attachAudio(AVCaptureDevice.default(for: .audio)) { error in
            print(error)
        }
        rtmpStream.attachCamera(AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition)) { error in
            print(error)
        }
        rtmpStream.publisher(for: \.currentFPS)
            .sink { [weak self] currentFPS in
                guard let self = self else {
                    return
                }
                DispatchQueue.main.async {
                    self.fps = self.liveState == .goLive ? "" : "\(currentFPS)"
                }
            }
            .store(in: &subscriptions)

        nc.publisher(for: AVAudioSession.interruptionNotification, object: nil)
            .sink { notification in
                print(notification)
            }
            .store(in: &subscriptions)

        nc.publisher(for: AVAudioSession.routeChangeNotification, object: nil)
            .sink { notification in
                print(notification)
            }
            .store(in: &subscriptions)
    }

    func unregisterForPublishEvent() {
        rtmpStream.close()
    }

    func startPublish() {
        UIApplication.shared.isIdleTimerDisabled = true
        rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
        rtmpConnection.addEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
        rtmpConnection.connect(rtmpUri())
    }

    func rtmpUri() -> String {
        var url = URL(string: selectedConnection().rtmpUrl)!
        var components = url.pathComponents
        components.removeFirst()
        components.removeLast()
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let path = components.joined(separator: "/")
        urlComponents.path = "/\(path)"
        url = urlComponents.url!
        return "\(url)"
    }

    func rtmpStreamName() -> String {
        let parts = selectedConnection().rtmpUrl.split(separator: "/")
        return String(parts[parts.count - 1])
    }

    func stopPublish() {
        UIApplication.shared.isIdleTimerDisabled = false
        rtmpConnection.close()
        rtmpConnection.removeEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
        rtmpConnection.removeEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
        startDate = nil
        updateUptimeFromNonMain()
    }

    func toggleLight() {
        rtmpStream.torch.toggle()
    }

    func toggleMute() {
        rtmpStream.hasAudio.toggle();
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
            print("while locking device for ramp: \(error)")
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
    private func rtmpErrorHandler(_ notification: Notification) {
        rtmpConnection.connect(rtmpUri())
    }
}

extension Model: IORecorderDelegate {
    func recorder(_ recorder: IORecorder, errorOccured error: IORecorder.Error) {
        print(error)
    }

    func recorder(_ recorder: IORecorder, finishWriting writer: AVAssetWriter) {
        PHPhotoLibrary.shared().performChanges({() -> Void in
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: writer.outputURL)
        }, completionHandler: { _, error -> Void in
            do {
                try FileManager.default.removeItem(at: writer.outputURL)
            } catch {
                print(error)
            }
        })
    }
}
