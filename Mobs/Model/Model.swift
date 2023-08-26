import Foundation
import Combine
import HaishinKit
import PhotosUI
import SwiftUI
import VideoToolbox
import TwitchChat

final class Model: ObservableObject {
    let maxRetryCount: Int = 5

    private var rtmpConnection = RTMPConnection()
    @Published var rtmpStream: RTMPStream!
    @Published var currentPosition: AVCaptureDevice.Position = .back
    private var retryCount: Int = 0
    @Published var published = false
    @Published var fps: String = "FPS"
    private var nc = NotificationCenter.default
    var subscriptions = Set<AnyCancellable>()
    
    var scenes = ["Back", "Front", "Back and front", "Play recording"]
    var widgets = ["Sub goal", "Earnings", "Chat", "Back camera", "Front camera", "Recording"]
    var variables = ["subGoal", "earnings"]
    var connections = ["Home", "Twitch"]
    @AppStorage("isConnectionOn") var isConnectionOn = true
    var sceneWidgets = ["Sub goal", "Earnings", "Chat", "Front camera", "Back camera"]
    @AppStorage("variableName") var variableName: String = "earnings"
    @AppStorage("textVariableValue") var textVariableValue: String = "10.0"
    @AppStorage("httpUrlVariableValue") var httpUrlVariableValue: String = "https://foo.com"
    @AppStorage("twitchPubSubVariableValue") var twitchPubSubVariableValue: String = ""
    @AppStorage("websocketUrlVariableValue") var websocketUrlVariableValue: String = "wss://foo.com/ws"
    @AppStorage("websocketPatternVariableValue") var websocketPatternVariableValue: String = ".data"
    @AppStorage("variableSelectedKind") var variableSelectedKind = "Text"
    @AppStorage("sceneName") var sceneName: String = "Back"
    @AppStorage("isSceneOn") var isSceneOn = true
    @AppStorage("widgetName") var widgetName: String = "Earnings"
    @AppStorage("widgetTextFormatString") var widgetTextFormatString: String = "Earnings: ${earnings}"
    @AppStorage("widgetImageUrl") var widgetImageUrl: String = "https://foo.com/bar.png"
    @AppStorage("widgetVideoUrl") var widgetVideoUrl: String = "https://foo.com/bar.mp4"
    @AppStorage("widgetCameraDirection") var widgetCameraDirection: String = "Back"
    @AppStorage("widgetChatChannelName") var widgetChatChannelName: String = "jinnytty"
    @AppStorage("widgetWebviewUrl") var widgetWebviewUrl: String = "https://foo.com/index.html"
    @AppStorage("widgetSelectedKind")  var widgetSelectedKind = "Text"
    @AppStorage("isChatOn") var isChatOn = true
    @AppStorage("isViewersOn") var isViewersOn = true
    @AppStorage("isUptimeOn") var isUptimeOn = true
    private var settings: Settings? = nil
    
    var selectedScene: String = "Back"
    
    var frameRate: String = "30.0" {
        willSet {
            rtmpStream.frameRate = Float64(newValue) ?? 30.0
            objectWillChange.send()
        }
    }

    private var twitchChat: TwitchChatMobs = {
        let twitchChat = TwitchChatMobs(channelName: defaultConfig.twitchChatChannel)
        twitchChat.start()
        return twitchChat
    }()

    private var twitchPubSub: TwitchPubSub = {
        let pubSub = TwitchPubSub()
        pubSub.start(channelId: defaultConfig.twitchChannelId)
        return pubSub
    }()

    func config(settings: Settings) {
        self.settings = settings
        rtmpStream = RTMPStream(connection: rtmpConnection)
        rtmpStream.videoOrientation = .landscapeRight
        rtmpStream.sessionPreset = .hd1280x720
        rtmpStream.mixer.recorder.delegate = self
        checkDeviceAuthorization()
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
                    self.fps = self.published == true ? "\(currentFPS)" : "FPS"
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
        rtmpConnection.connect(defaultConfig.uri)
    }

    func stopPublish() {
        UIApplication.shared.isIdleTimerDisabled = false
        rtmpConnection.close()
        rtmpConnection.removeEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
        rtmpConnection.removeEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
    }

    func toggleLight() {
        rtmpStream.torch.toggle()
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
            rtmpStream.publish(defaultConfig.streamName)
        case RTMPConnection.Code.connectFailed.rawValue, RTMPConnection.Code.connectClosed.rawValue:
            guard retryCount <= maxRetryCount else {
                return
            }
            Thread.sleep(forTimeInterval: pow(2.0, Double(retryCount)))
            rtmpConnection.connect(defaultConfig.uri)
            retryCount += 1
        default:
            break
        }
    }

    @objc
    private func rtmpErrorHandler(_ notification: Notification) {
        rtmpConnection.connect(defaultConfig.uri)
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
