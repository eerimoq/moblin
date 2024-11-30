import AlertToast
import AppIntents
import Collections
import Combine
import CoreMotion
import GameController
import HealthKit
import Intents
import MapKit
import NaturalLanguage
import Network
import NetworkExtension
import PhotosUI
import ReplayKit
import SDWebImageSwiftUI
import SDWebImageWebPCoder
import StoreKit
import SwiftUI
import TwitchChat
import VideoToolbox
import WatchConnectivity
import WebKit
import WrappingHStack

private let noBackZoomPresetId = UUID()
private let noFrontZoomPresetId = UUID()

private struct ChatBotMessage {
    let platform: Platform
    let user: String?
    let isModerator: Bool
    let isSubscriber: Bool
    let userId: String?
    let segments: [ChatPostSegment]
}

enum ShowingPanel {
    case none
    case settings
    case bitrate
    case mic
    case streamSwitcher
    case luts
    case obs
    case widgets
    case recordings
    case cosmetics
    case chat
}

class Browser: Identifiable {
    var id: UUID = .init()
    var browserEffect: BrowserEffect

    init(browserEffect: BrowserEffect) {
        self.browserEffect = browserEffect
    }
}

class DjiDeviceWrapper {
    let device: DjiDevice
    var autoRestartStreamTimer: DispatchSourceTimer?

    init(device: DjiDevice) {
        self.device = device
    }
}

private let maximumNumberOfChatMessages = 50
private let maximumNumberOfInteractiveChatMessages = 100
private let secondsSuffix = String(localized: "/sec")
private let fallbackStream = SettingsStream(name: "Fallback")
let fffffMessage = String(localized: "😢 FFFFF 😢")
let lowBitrateMessage = String(localized: "Low bitrate")
let lowBatteryMessage = String(localized: "Low battery")
let flameRedMessage = String(localized: "🔥 Flame is red 🔥")
let unknownSad = String(localized: "Unknown 😢")

func formatWarning(_ message: String) -> String {
    return "⚠️ \(message) ⚠️"
}

func failedToConnectMessage(_ name: String) -> String {
    return String(localized: "😢 Failed to connect to \(name) 😢")
}

struct Camera: Identifiable, Equatable {
    var id: String
    var name: String
}

struct Mic: Identifiable, Hashable {
    var id: String {
        "\(inputUid) \(dataSourceID ?? 0)"
    }

    var name: String
    var inputUid: String
    var dataSourceID: NSNumber?
    var builtInOrientation: SettingsMic?
}

struct Icon: Identifiable {
    var name: String
    var id: String
    var price: String

    func imageNoBackground() -> String {
        return "\(id)NoBackground"
    }

    func image() -> String {
        return id
    }
}

private let screenCaptureCameraId = UUID(uuidString: "00000000-cafe-babe-beef-000000000000")!
let builtinCameraId = UUID(uuidString: "00000000-cafe-dead-beef-000000000000")!
let screenCaptureCamera = "Screen capture"

let plainIcon = Icon(name: "Plain", id: "AppIcon", price: "")
private let noMic = Mic(name: "", inputUid: "")

private let globalMyIcons = [
    plainIcon,
    Icon(name: "Halloween", id: "AppIconHalloween", price: "$"),
    Icon(
        name: "Halloween pumpkin",
        id: "AppIconHalloweenPumpkin",
        price: ""
    ),
    Icon(name: "San Diego", id: "AppIconSanDiego", price: "$"),
]

private let iconsProductIds = [
    "AppIconKing",
    "AppIconQueen",
    "AppIconLooking",
    "AppIconPixels",
    "AppIconHeart",
    "AppIconTub",
    "AppIconGoblin",
    "AppIconGoblina",
    "AppIconTetris",
    "AppIconMillionaire",
    "AppIconBillionaire",
    "AppIconTrillionaire",
    "AppIconIreland",
]

struct ChatMessageEmote: Identifiable {
    var id = UUID()
    var url: URL
    var range: ClosedRange<Int>
}

struct ChatPostSegment: Identifiable {
    var id: Int
    var text: String?
    var url: URL?
}

func makeChatPostTextSegments(text: String, id: inout Int) -> [ChatPostSegment] {
    var segments: [ChatPostSegment] = []
    for word in text.split(separator: " ") {
        segments.append(ChatPostSegment(
            id: id,
            text: "\(word) "
        ))
        id += 1
    }
    return segments
}

enum ChatHighlightKind {
    case redemption
    case other
    case firstMessage
    case newFollower
}

struct ChatHighlight {
    let kind: ChatHighlightKind
    let color: Color
    let image: String
    let title: String

    func toWatchProtocol() -> WatchProtocolChatHighlight {
        let watchProtocolKind: WatchProtocolChatHighlightKind
        switch kind {
        case .redemption:
            watchProtocolKind = .redemption
        case .other:
            watchProtocolKind = .other
        case .newFollower:
            watchProtocolKind = .redemption
        case .firstMessage:
            watchProtocolKind = .other
        }
        let color = color.toRgb() ?? .init(red: 0, green: 255, blue: 0)
        return WatchProtocolChatHighlight(
            kind: watchProtocolKind,
            color: .init(red: color.red, green: color.green, blue: color.blue),
            image: image,
            title: title
        )
    }
}

struct ChatPost: Identifiable, Equatable {
    static func == (lhs: ChatPost, rhs: ChatPost) -> Bool {
        return lhs.id == rhs.id
    }

    func isRedemption() -> Bool {
        return highlight?.kind == .redemption || highlight?.kind == .newFollower
    }

    var id: Int
    var user: String?
    var userColor: RgbColor?
    var userBadges: [URL]
    var segments: [ChatPostSegment]
    var timestamp: String
    var timestampTime: ContinuousClock.Instant
    var isAction: Bool
    var isSubscriber: Bool
    var bits: String?
    var highlight: ChatHighlight?
}

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

struct ButtonPair: Identifiable, Equatable {
    static func == (lhs: ButtonPair, rhs: ButtonPair) -> Bool {
        return lhs.id == rhs.id
    }

    var id: UUID
    var first: ButtonState
    var second: ButtonState?
}

struct LogEntry: Identifiable {
    var id: Int
    var message: String
}

enum WizardPlatform {
    case twitch
    case kick
    case youTube
    case afreecaTv
    case custom
}

enum WizardNetworkSetup {
    case none
    case obs
    case belaboxCloudObs
    case irlToolkit
    case direct
    case myServers
}

enum WizardCustomProtocol {
    case none
    case srt
    case rtmp
    case rist

    func toDefaultCodec() -> SettingsStreamCodec {
        switch self {
        case .none:
            return .h264avc
        case .srt:
            return .h265hevc
        case .rtmp:
            return .h264avc
        case .rist:
            return .h265hevc
        }
    }
}

struct ObsSceneInput: Identifiable {
    var id: UUID = .init()
    var name: String
    var muted: Bool?
}

final class Model: NSObject, ObservableObject, @unchecked Sendable {
    private let media = Media()
    var streamState = StreamState.disconnected {
        didSet {
            logger.info("stream: State \(oldValue) -> \(streamState)")
        }
    }

    @Published var scrollQuickButtons: Int = 0
    @Published var bias: Float = 0.0

    private var manualFocusesEnabled: [AVCaptureDevice: Bool] = [:]
    private var manualFocuses: [AVCaptureDevice: Float] = [:]
    @Published var manualFocus: Float = 1.0
    @Published var manualFocusEnabled = false
    var editingManualFocus = false
    private var focusObservation: NSKeyValueObservation?
    @Published var manualFocusPoint: CGPoint?

    private var manualIsosEnabled: [AVCaptureDevice: Bool] = [:]
    private var manualIsos: [AVCaptureDevice: Float] = [:]
    @Published var manualIso: Float = 1.0
    @Published var manualIsoEnabled = false
    var editingManualIso = false
    private var isoObservation: NSKeyValueObservation?

    private var manualWhiteBalancesEnabled: [AVCaptureDevice: Bool] = [:]
    private var manualWhiteBalances: [AVCaptureDevice: Float] = [:]
    @Published var manualWhiteBalance: Float = 0
    @Published var manualWhiteBalanceEnabled = false
    var editingManualWhiteBalance = false
    private var whiteBalanceObservation: NSKeyValueObservation?

    private var manualFocusMotionAttitude: CMAttitude?

    @Published var showingPanel: ShowingPanel = .none
    @Published var blackScreen = false
    @Published var findFace = false
    private var findFaceTimer: Timer?
    private var streaming = false
    @Published var currentMic = noMic
    private var micChange = noMic
    private var streamStartTime: ContinuousClock.Instant?
    @Published var isLive = false
    @Published var isRecording = false
    private var workoutType: WatchProtocolWorkoutType?
    private var currentRecording: Recording?
    @Published var recordingLength = noValue
    @Published var browserWidgetsStatus = noValue
    private var browserWidgetsStatusChanged = false
    private var subscriptions = Set<AnyCancellable>()
    @Published var uptime = noValue
    @Published var bondingStatistics = noValue
    private var bondingStatisticsFormatter = BondingStatisticsFormatter()
    @Published var audioLevel: Float = defaultAudioLevel
    @Published var numberOfAudioChannels: Int = 0
    var settings = Settings()
    @Published var digitalClock = noValue
    private var selectedSceneId = UUID()
    private var twitchChat: TwitchChatMoblin!
    private var twitchPubSub: TwitchPubSub?
    private var twitchEventSub: TwitchEventSub?
    private var kickPusher: KickPusher?
    private var kickViewers: KickViewers?
    private var youTubeLiveChat: YouTubeLiveChat?
    private var afreecaTvChat: AfreecaTvChat?
    private var openStreamingPlatformChat: OpenStreamingPlatformChat!
    private var obsWebSocket: ObsWebSocket?
    private var chatPostId = 0
    @Published var chatPosts: Deque<ChatPost> = []
    private var newChatPosts: Deque<ChatPost> = []
    private var numberOfChatPostsPerTick = 0
    private var chatPostsRatePerSecond = 0.0
    private var chatPostsRatePerMinute = 0.0
    private var numberOfChatPostsPerMinute = 0
    @Published var chatPostsRate = String(localized: "0.0/min")
    @Published var chatPostsTotal: Int = 0
    @Published var interactiveChatPosts: Deque<ChatPost> = []
    private var newInteractiveChatPosts: Deque<ChatPost> = []
    private var pausedInteractiveChatPosts: Deque<ChatPost> = []
    @Published var pausedInteractiveChatPostsCount: Int = 0
    @Published var interactiveChatPaused = false
    @Published var showAllInteractiveChatMessage = true
    @Published var showFirstTimeChatterMessage = true
    @Published var showNewFollowerMessage = true
    @Published var interactiveChatAlertsPosts: Deque<ChatPost> = []
    private var newInteractiveChatAlertsPosts: Deque<ChatPost> = []
    private var pausedInteractiveChatAlertsPosts: Deque<ChatPost> = []
    @Published var pausedInteractiveChatAlertsPostsCount: Int = 0
    @Published var interactiveChatAlertsPaused = false
    private var watchChatPosts: Deque<WatchProtocolChatMessage> = []
    private var nextWatchChatPostId = 1
    private var chatSpeedTicks = 0
    @Published var numberOfViewers = noValue
    @Published var batteryLevel = Double(UIDevice.current.batteryLevel)
    private var batteryLevelLowCounter = -1
    @Published var batteryState: UIDevice.BatteryState = .full
    @Published var speedAndTotal = noValue
    @Published var speedMbpsOneDecimal = noValue
    @Published var bitrateStatusColor: Color = .white
    private var previousBitrateStatusColorSrtDroppedPacketsTotal: Int32 = 0
    private var previousBitrateStatusNumberOfFailedEncodings = 0
    @Published var thermalState = ProcessInfo.processInfo.thermalState
    let streamPreviewView = PreviewView(frame: .zero)
    let cameraPreviewView = CameraPreviewUiView()
    @Published var remoteControlPreview: UIImage?
    @Published var showCameraPreview = false
    private var textEffects: [UUID: TextEffect] = [:]
    private var imageEffects: [UUID: ImageEffect] = [:]
    private var browserEffects: [UUID: BrowserEffect] = [:]
    private var lutEffects: [UUID: LutEffect] = [:]
    private var mapEffects: [UUID: MapEffect] = [:]
    private var qrCodeEffects: [UUID: QrCodeEffect] = [:]
    private var alertsEffects: [UUID: AlertsEffect] = [:]
    private var videoSourceEffects: [UUID: VideoSourceEffect] = [:]
    private var enabledAlertsEffects: [AlertsEffect] = []
    private var drawOnStreamEffect = DrawOnStreamEffect()
    private var lutEffect = LutEffect()
    private var padelScoreboardEffects: [UUID: PadelScoreboardEffect] = [:]
    @Published var browsers: [Browser] = []
    @Published var sceneIndex = 0
    @Published var isTorchOn = false
    @Published var isFrontCameraSelected = false
    private var isMuteOn = false
    var log: Deque<LogEntry> = []
    var remoteControlAssistantLog: Deque<LogEntry> = []
    var imageStorage = ImageStorage()
    var logsStorage = LogsStorage()
    var mediaStorage = MediaPlayerStorage()
    var alertMediaStorage = AlertMediaStorage()
    @Published var buttonPairs: [ButtonPair] = []
    private var reconnectTimer: Timer?
    private var logId = 1
    @Published var showingToast = false
    @Published var toast = AlertToast(type: .regular, title: "") {
        didSet {
            showingToast.toggle()
        }
    }

    @Published var hypeTrainLevel: Int?
    @Published var hypeTrainProgress: Int?
    @Published var hypeTrainGoal: Int?
    @Published var hypeTrainStatus = noValue
    @Published var adsRemainingTimerStatus = noValue
    private var adsEndDate: Date?
    private var hypeTrainTimer = SimpleTimer(queue: .main)
    var urlSession = URLSession.shared

    private var workoutHeartRate: Int?
    private var workoutActiveEnergyBurned: Int?
    private var workoutDistance: Int?
    private var workoutPower: Int?
    private var workoutStepCount: Int?
    private var pollVotes: [Int] = [0, 0, 0]
    private var pollEnabled = false
    private var mediaPlayers: [UUID: MediaPlayer] = [:]
    @Published var showMediaPlayerControls = false
    @Published var mediaPlayerPlaying = false
    @Published var mediaPlayerPosition: Float = 0
    @Published var mediaPlayerTime = "0:00"
    @Published var mediaPlayerFileName = "Media name"
    @Published var mediaPlayerSeeking = false

    @Published var showingCamera = false
    @Published var showingCameraBias = false
    @Published var showingCameraWhiteBalance = false
    @Published var showingCameraIso = false
    @Published var showingCameraFocus = false
    @Published var showingGrid = false
    @Published var showingRemoteControl = false
    @Published var obsScenes: [String] = []
    @Published var obsSceneInputs: [ObsSceneInput] = []
    @Published var obsAudioVolume: String = noValue
    @Published var obsAudioDelay: Int = 0
    private var obsAudioVolumeLatest: String = ""
    @Published var obsCurrentScenePicker: String = ""
    @Published var obsCurrentScene: String = ""
    private var obsSceneBeforeSwitchToBrbScene: String?
    private var previousSrtDroppedPacketsTotal: Int32 = 0
    private var streamBecameBrokenTime: ContinuousClock.Instant?
    @Published var currentStreamId = UUID()
    @Published var obsStreaming = false
    @Published var obsStreamingState: ObsOutputState = .stopped
    @Published var obsRecordingState: ObsOutputState = .stopped
    @Published var obsFixOngoing = false
    @Published var obsScreenshot: CGImage?
    private var obsSourceFetchScreenshot = false
    private var obsSourceScreenshotIsFetching = false
    var obsRecording = false
    @Published var iconImage: String = plainIcon.id
    @Published var backZoomPresetId = UUID()
    @Published var frontZoomPresetId = UUID()
    @Published var zoomX: Float = 1.0
    @Published var hasZoom = true
    private var zoomXPinch: Float = 1.0
    private var backZoomX: Float = 0.5
    private var frontZoomX: Float = 1.0
    var cameraPosition: AVCaptureDevice.Position?
    private let motionManager = CMMotionManager()
    var database: Database {
        settings.database
    }

    private var speechToText = SpeechToText()
    private var keepSpeakerAlivePlayer: AVAudioPlayer?
    private var keepSpeakerAliveLatestPlayed: ContinuousClock.Instant = .now

    @Published var showTwitchAuth = false
    let twitchAuth = TwitchAuth()
    private var twitchAuthOnComplete: ((_ accessToken: String) -> Void)?

    @Published var bondingPieChartPercentages: [BondingPercentage] = []

    @Published var verboseStatuses = false
    @Published var showDrawOnStream = false
    @Published var showFace = false
    @Published var showFaceBeauty = false
    @Published var showFaceBeautyShape = false
    @Published var showFaceBeautySmooth = false
    @Published var showLocalOverlays = true
    @Published var showBrowser = false
    @Published var drawOnStreamLines: [DrawOnStreamLine] = []
    @Published var drawOnStreamSelectedColor: Color = .pink
    @Published var drawOnStreamSelectedWidth: CGFloat = 4
    var drawOnStreamSize: CGSize = .zero
    @Published var webBrowserUrl: String = ""
    private var webBrowser: WKWebView?
    private var lowFpsImageFps: UInt64 = 1

    @Published var isPresentingWizard = false
    @Published var isPresentingSetupWizard = false
    var wizardPlatform: WizardPlatform = .custom
    var wizardNetworkSetup: WizardNetworkSetup = .none
    var wizardCustomProtocol: WizardCustomProtocol = .none
    let wizardTwitchStream = SettingsStream(name: "")
    @Published var wizardShowTwitchAuth = false
    @Published var wizardName = ""
    @Published var wizardTwitchChannelName = ""
    @Published var wizardTwitchChannelId = ""
    var wizardTwitchAccessToken = ""
    var wizardTwitchLoggedIn: Bool = false
    @Published var wizardKickChannelName = ""
    @Published var wizardYouTubeVideoId = ""
    @Published var wizardAfreecaTvChannelName = ""
    @Published var wizardAfreecsTvCStreamId = ""
    @Published var wizardObsAddress = ""
    @Published var wizardObsPort = ""
    @Published var wizardObsRemoteControlEnabled = false
    @Published var wizardObsRemoteControlUrl = ""
    @Published var wizardObsRemoteControlPassword = ""
    @Published var wizardObsRemoteControlSourceName = ""
    @Published var wizardObsRemoteControlBrbScene = ""
    @Published var wizardDirectIngest = ""
    @Published var wizardDirectStreamKey = ""
    @Published var wizardChatBttv = true
    @Published var wizardChatFfz = true
    @Published var wizardChatSeventv = true
    @Published var wizardBelaboxUrl = ""
    @Published var wizardCustomSrtUrl = ""
    @Published var wizardCustomSrtStreamId = ""
    @Published var wizardCustomRtmpUrl = ""
    @Published var wizardCustomRtmpStreamKey = ""
    @Published var wizardCustomRistUrl = ""

    let chatTextToSpeech = ChatTextToSpeech()

    private var teslaVehicle: TeslaVehicle?
    @Published var teslaVehicleState: TeslaVehicleState?

    private var lastAttachCompletedTime: ContinuousClock.Instant?

    @Published var remoteControlGeneral: RemoteControlStatusGeneral?
    @Published var remoteControlTopLeft: RemoteControlStatusTopLeft?
    @Published var remoteControlTopRight: RemoteControlStatusTopRight?
    @Published var remoteControlSettings: RemoteControlSettings?
    var remoteControlState = RemoteControlState()
    @Published var remoteControlScene = UUID()
    @Published var remoteControlMic = ""
    @Published var remoteControlBitrate = UUID()
    @Published var remoteControlZoom = ""
    @Published var remoteControlDebugLogging = false

    private var remoteControlStreamer: RemoteControlStreamer?
    private var remoteControlAssistant: RemoteControlAssistant?
    private var remoteControlRelay: RemoteControlRelay?
    @Published var remoteControlAssistantShowPreview = true
    @Published var remoteControlAssistantShowPreviewFullScreen = false
    private var isRemoteControlAssistantRequestingPreview = false

    private var currentWiFiSsid: String?
    @Published var djiDeviceStreamingState: DjiDeviceState?
    private var currentDjiDeviceSettings: SettingsDjiDevice?
    private var djiDeviceWrappers: [UUID: DjiDeviceWrapper] = [:]

    @Published var catPrinterState: CatPrinterState?
    private var currentCatPrinterSettings: SettingsCatPrinter?
    private var catPrinters: [UUID: CatPrinter] = [:]

    var cameraDevice: AVCaptureDevice?
    var cameraZoomLevelToXScale: Float = 1.0
    var cameraZoomXMinimum: Float = 1.0
    var cameraZoomXMaximum: Float = 1.0
    @Published var debugLines: [String] = []
    private var latestDebugLines: [String] = []
    private var latestDebugActions: [String] = []
    @Published var streamingHistory = StreamingHistory()
    private var streamingHistoryStream: StreamingHistoryStream?

    var backCameras: [Camera] = []
    var frontCameras: [Camera] = []
    var externalCameras: [Camera] = []

    var recordingsStorage = RecordingsStorage()
    private var latestLowBitrateTime = ContinuousClock.now

    private var rtmpServer: RtmpServer?
    @Published var serversSpeedAndTotal = noValue

    private var srtlaServer: SrtlaServer?

    private var gameControllers: [GCController?] = []
    @Published var gameControllersTotal = noValue

    @Published var location = noValue
    @Published var showLoadSettingsFailed = false

    private var distance = 0.0
    private var latestKnownLocation: CLLocation?

    @Published var remoteControlStatus = noValue

    private let sampleBufferReceiver = SampleBufferReceiver()

    private let faxReceiver = FaxReceiver()

    override init() {
        super.init()
        showLoadSettingsFailed = !settings.load()
        streamingHistory.load()
        recordingsStorage.load()
    }

    var stream: SettingsStream {
        for stream in database.streams where stream.enabled {
            return stream
        }
        return fallbackStream
    }

    var enabledScenes: [SettingsScene] {
        database.scenes.filter { scene in scene.enabled }
    }

    var widgetsInCurrentScene: [SettingsWidget] {
        guard let scene = getSelectedScene() else {
            return []
        }
        var found: [UUID] = []
        return getSceneWidgets(scene: scene).filter {
            if found.contains($0.id) {
                return false
            } else {
                found.append($0.id)
                return true
            }
        }
    }

    private func getSceneWidgets(scene: SettingsScene) -> [SettingsWidget] {
        var widgets: [SettingsWidget] = []
        for sceneWidget in scene.widgets {
            guard let widget = findWidget(id: sceneWidget.widgetId) else {
                continue
            }
            widgets.append(widget)
            guard widget.type == .scene else {
                continue
            }
            if let scene = database.scenes.first(where: { $0.id == widget.scene!.sceneId }) {
                widgets += getSceneWidgets(scene: scene)
            }
        }
        return widgets
    }

    @Published var myIcons: [Icon] = []
    @Published var iconsInStore: [Icon] = []
    private var appStoreUpdateListenerTask: Task<Void, Error>?
    private var products: [String: Product] = [:]
    private var streamTotalBytes: UInt64 = 0
    private var streamTotalChatMessages: Int = 0
    private var streamLog: Deque<String> = []
    var ipMonitor = IPMonitor(ipType: .ipv4)
    @Published var ipStatuses: [IPMonitor.Status] = []
    private var faceEffect = FaceEffect(fps: 30)
    private var movieEffect = MovieEffect()
    private var fourThreeEffect = FourThreeEffect()
    private var grayScaleEffect = GrayScaleEffect()
    private var sepiaEffect = SepiaEffect()
    private var tripleEffect = TripleEffect()
    private var pixellateEffect = PixellateEffect()
    private var pollEffect = PollEffect()
    private var locationManager = Location()
    private var realtimeIrl: RealtimeIrl?
    private var failedVideoEffect: String?
    var supportsAppleLog: Bool = false

    private let weatherManager = WeatherManager()
    private let geographyManager = GeographyManager()

    var onDocumentPickerUrl: ((URL) -> Void)?

    private var healthStore = HKHealthStore()

    func setAdaptiveBitrateSrtAlgorithm(stream: SettingsStream) {
        media.srtSetAdaptiveBitrateAlgorithm(
            targetBitrate: stream.bitrate,
            adaptiveBitrateAlgorithm: stream.srt.adaptiveBitrate!.algorithm
        )
    }

    func updateAdaptiveBitrateSrt(stream: SettingsStream) {
        switch stream.srt.adaptiveBitrate!.algorithm {
        case .fastIrl:
            var settings = adaptiveBitrateFastSettings
            settings.packetsInFlight = Int64(stream.srt.adaptiveBitrate!.fastIrlSettings!.packetsInFlight)
            settings
                .minimumBitrate = Int64(stream.srt.adaptiveBitrate!.fastIrlSettings!.minimumBitrate! * 1000)
            media.setAdaptiveBitrateSettings(settings: settings)
        case .slowIrl:
            media.setAdaptiveBitrateSettings(settings: adaptiveBitrateSlowSettings)
        case .customIrl:
            let customSettings = stream.srt.adaptiveBitrate!.customSettings
            media.setAdaptiveBitrateSettings(settings: AdaptiveBitrateSettings(
                packetsInFlight: Int64(customSettings.packetsInFlight),
                rttDiffHighFactor: Double(customSettings.rttDiffHighDecreaseFactor),
                rttDiffHighAllowedSpike: Double(customSettings.rttDiffHighAllowedSpike),
                rttDiffHighMinDecrease: Int64(customSettings.rttDiffHighMinimumDecrease * 1000),
                pifDiffIncreaseFactor: Int64(customSettings.pifDiffIncreaseFactor * 1000),
                minimumBitrate: Int64(customSettings.minimumBitrate! * 1000)
            ))
        case .belabox:
            var settings = adaptiveBitrateBelaboxSettings
            settings
                .minimumBitrate = Int64(stream.srt.adaptiveBitrate!.belaboxSettings!.minimumBitrate * 1000)
            media.setAdaptiveBitrateSettings(settings: settings)
        }
    }

    func updateAdaptiveBitrateRtmpIfEnabled() {
        var settings = adaptiveBitrateFastSettings
        settings.rttDiffHighAllowedSpike = 500
        media.setAdaptiveBitrateSettings(settings: settings)
    }

    func updateAdaptiveBitrateRistIfEnabled() {
        let settings = adaptiveBitrateRistFastSettings
        media.setAdaptiveBitrateSettings(settings: settings)
    }

    func toggleVerboseStatuses() {
        verboseStatuses.toggle()
        database.verboseStatuses!.toggle()
    }

    private func isShowingPanelGlobalButton(type: SettingsButtonType) -> Bool {
        return [
            SettingsButtonType.widgets,
            SettingsButtonType.luts,
            SettingsButtonType.chat,
            SettingsButtonType.mic,
            SettingsButtonType.bitrate,
            SettingsButtonType.recordings,
            SettingsButtonType.stream,
            SettingsButtonType.obs,
        ].contains(type)
    }

    func toggleShowingPanel(type: SettingsButtonType?, panel: ShowingPanel) {
        if showingPanel == panel {
            showingPanel = .none
        } else {
            showingPanel = panel
        }
        for pair in buttonPairs {
            if isShowingPanelGlobalButton(type: pair.first.button.type) {
                setGlobalButtonState(type: pair.first.button.type, isOn: false)
            }
            if let state = pair.second {
                if isShowingPanelGlobalButton(type: state.button.type) {
                    setGlobalButtonState(type: state.button.type, isOn: false)
                }
            }
        }
        if let type {
            setGlobalButtonState(type: type, isOn: showingPanel == panel)
        }
        updateButtonStates()
    }

    func createStreamMarker() {
        TwitchApi(stream.twitchAccessToken!, urlSession)
            .createStreamMarker(userId: stream.twitchChannelId) { data in
                if data != nil {
                    self.makeToast(title: String(localized: "Stream marker created"))
                } else {
                    self.makeErrorToast(title: String(localized: "Failed to create stream marker"))
                }
            }
    }

    @MainActor
    private func getProductsFromAppStore() async {
        do {
            let products = try await Product.products(for: iconsProductIds)
            for product in products {
                self.products[product.id] = product
            }
            logger.debug("cosmetics: Got \(products.count) product(s) from App Store")
        } catch {
            logger.error("cosmetics: Failed to get products from App Store: \(error)")
        }
    }

    private func listenForAppStoreTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                guard let transaction = self.checkVerified(result: result) else {
                    logger.info("cosmetics: Updated transaction failed verification")
                    continue
                }
                await self.updateProductFromAppStore()
                await transaction.finish()
            }
        }
    }

    private func checkVerified(result: VerificationResult<StoreKit.Transaction>)
        -> StoreKit.Transaction?
    {
        switch result {
        case .unverified:
            return nil
        case let .verified(safe):
            return safe
        }
    }

    @MainActor
    func updateProductFromAppStore() async {
        logger.debug("cosmetics: Update my products from App Store")
        let myProductIds = await getMyProductIds()
        updateIcons(myProductIds: myProductIds)
    }

    private func getMyProductIds() async -> [String] {
        var myProductIds: [String] = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = checkVerified(result: result) else {
                logger.info("cosmetics: Verification failed for my product")
                continue
            }
            myProductIds.append(transaction.productID)
        }
        return myProductIds
    }

    private func updateIcons(myProductIds: [String]) {
        var myIcons = globalMyIcons
        var iconsInStore: [Icon] = []
        for productId in iconsProductIds {
            guard let product = products[productId] else {
                logger.info("cosmetics: Icon product \(productId) not found")
                continue
            }
            if myProductIds.contains(productId) {
                myIcons.append(Icon(
                    name: product.displayName,
                    id: product.id,
                    price: product.displayPrice
                ))
            } else {
                iconsInStore.append(Icon(
                    name: product.displayName,
                    id: product.id,
                    price: product.displayPrice
                ))
            }
        }
        self.myIcons = myIcons
        self.iconsInStore = iconsInStore
    }

    private func findProduct(id: String) -> Product? {
        return products[id]
    }

    func purchaseProduct(id: String) async throws {
        guard let product = findProduct(id: id) else {
            throw "Product not found"
        }
        let result = try await product.purchase()

        switch result {
        case let .success(result):
            logger.info("cosmetics: Purchase successful")
            guard let transaction = checkVerified(result: result) else {
                throw "Purchase failed verification"
            }
            await updateProductFromAppStore()
            await transaction.finish()
        case .userCancelled, .pending:
            logger.info("cosmetics: Purchase not done yet")
        default:
            logger.warning("cosmetics: What happend when buying? \(result)")
        }
    }

    func setAllowVideoRangePixelFormat() {
        allowVideoRangePixelFormat = database.debug.allowVideoRangePixelFormat!
    }

    func setBlurSceneSwitch() {
        ioVideoBlurSceneSwitch = database.debug.blurSceneSwitch!
    }

    func makeToast(title: String, subTitle: String? = nil) {
        toast = AlertToast(type: .regular, title: title, subTitle: subTitle)
        showingToast = true
        logger.debug("toast: Info: \(title): \(subTitle ?? "-")")
    }

    func makeWarningToast(title: String, subTitle: String? = nil, vibrate: Bool = false) {
        toast = AlertToast(type: .regular, title: formatWarning(title), subTitle: subTitle)
        showingToast = true
        logger.debug("toast: Warning: \(title): \(subTitle ?? "-")")
        if vibrate {
            UIDevice.vibrate()
        }
    }

    func makeErrorToast(title: String, font: Font? = nil, subTitle: String? = nil, vibrate: Bool = false) {
        toast = AlertToast(
            type: .regular,
            title: title,
            subTitle: subTitle,
            style: .style(titleColor: .red, titleFont: font)
        )
        showingToast = true
        logger.debug("toast: Error: \(title): \(subTitle ?? "-")")
        if vibrate {
            UIDevice.vibrate()
        }
    }

    func scrollQuickButtonsToBottom() {
        scrollQuickButtons += 1
    }

    func updateButtonStates() {
        let states = database.globalButtons!.filter { button in
            button.enabled!
        }.map { button in
            ButtonState(isOn: button.isOn, button: button)
        }
        var pairs: [ButtonPair] = []
        for index in stride(from: 0, to: states.count, by: 2) {
            if states.count - index > 1 {
                pairs.append(ButtonPair(
                    id: UUID(),
                    first: states[index],
                    second: states[index + 1]
                ))
            } else {
                pairs.append(ButtonPair(id: UUID(), first: states[index]))
            }
        }
        buttonPairs = pairs.reversed()
    }

    func takeSnapshot(isChatBot: Bool = false, message: String? = nil) {
        let age = isChatBot ? stream.estimatedViewerDelay! : 0.0
        media.takeSnapshot(age: age) { image in
            guard let imageJpeg = image.jpegData(compressionQuality: 0.9) else {
                return
            }
            DispatchQueue.main.async {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                self.makeToast(title: String(localized: "Snapshot saved to Photos"))
                self.tryUploadSnapshotToDiscord(imageJpeg, message, isChatBot)
            }
        }
    }

    private func getDiscordWebhookUrl(_ isChatBot: Bool) -> URL? {
        if isChatBot {
            return URL(string: stream.discordChatBotSnapshotWebhook!)
        } else {
            return URL(string: stream.discordSnapshotWebhook!)
        }
    }

    private func tryUploadSnapshotToDiscord(_ image: Data, _ message: String?, _ isChatBot: Bool) {
        guard !stream.discordSnapshotWebhookOnlyWhenLive! || isLive, let url = getDiscordWebhookUrl(isChatBot)
        else {
            return
        }
        logger.debug("Uploading snapshot to Discord of \(image).")
        uploadImage(
            url: url,
            paramName: "snapshot",
            fileName: "snapshot.jpg",
            image: image,
            message: message
        ) { ok in
            DispatchQueue.main.async {
                if ok {
                    self.makeToast(title: String(localized: "Snapshot uploaded to Discord"))
                } else {
                    self.makeErrorToast(title: String(localized: "Failed to upload snapshot to Discord"))
                }
            }
        }
    }

    private func debugLog(message: String) {
        DispatchQueue.main.async {
            if self.log.count > self.database.debug.maximumLogLines! {
                self.log.removeFirst()
            }
            self.log.append(LogEntry(id: self.logId, message: message))
            self.logId += 1
            self.remoteControlStreamer?.log(entry: message)
            if self.streamLog.count >= 100_000 {
                self.streamLog.removeFirst()
            }
            self.streamLog.append(message)
        }
    }

    func makeStreamShareLogUrl(logId: UUID) -> URL {
        return logsStorage.makePath(id: logId)
    }

    func clearLog() {
        log = []
    }

    func formatLog(log: Deque<LogEntry>) -> String {
        var data = "Version: \(appVersion())\n"
        data += "Debug: \(logger.debugEnabled)\n\n"
        data += log.map { e in e.message }.joined(separator: "\n")
        return data
    }

    func setAllowHapticsAndSystemSoundsDuringRecording() {
        do {
            try AVAudioSession.sharedInstance()
                .setAllowHapticsAndSystemSoundsDuringRecording(database.vibrate!)
        } catch {}
    }

    func isObsConnected() -> Bool {
        return obsWebSocket?.isConnected() ?? false
    }

    func obsConnectionErrorMessage() -> String {
        return obsWebSocket?.connectionErrorMessage ?? ""
    }

    func listObsScenes(updateAudioInputs: Bool = false) {
        obsWebSocket?.getSceneList(onSuccess: { list in
            self.obsCurrentScenePicker = list.current
            self.obsCurrentScene = list.current
            self.obsScenes = list.scenes
            if updateAudioInputs {
                self.updateObsAudioInputs(sceneName: list.current)
            }
        }, onError: { _ in
        })
    }

    func updateObsAudioInputs(sceneName: String) {
        obsWebSocket?.getInputList { inputs in
            self.obsWebSocket?.getSpecialInputs { specialInputs in
                self.obsWebSocket?.getSceneItemList(sceneName: sceneName, onSuccess: { sceneItems in
                    guard !sceneItems.isEmpty else {
                        self.obsSceneInputs = []
                        return
                    }
                    var obsSceneInputs: [ObsSceneInput] = []
                    for input in inputs {
                        if specialInputs.mics().contains(input) {
                            obsSceneInputs.append(ObsSceneInput(name: input))
                        } else if sceneItems.contains(where: { $0.sourceName == input }) {
                            if sceneItems.first(where: { $0.sourceName == input })?.sceneItemEnabled == true {
                                obsSceneInputs.append(ObsSceneInput(name: input))
                            }
                        }
                    }
                    self.obsWebSocket?.getInputMuteBatch(
                        inputNames: obsSceneInputs.map { $0.name },
                        onSuccess: { muteds in
                            guard muteds.count == obsSceneInputs.count else {
                                self.obsSceneInputs = []
                                return
                            }
                            for (i, muted) in muteds.enumerated() {
                                obsSceneInputs[i].muted = muted
                            }
                            self.obsSceneInputs = obsSceneInputs
                        }, onError: { _ in
                            self.obsSceneInputs = []
                        }
                    )
                }, onError: { _ in
                    self.obsSceneInputs = []
                })
            } onError: { _ in
                self.obsSceneInputs = []
            }
        } onError: { _ in
            self.obsSceneInputs = []
        }
    }

    func setObsScene(name: String) {
        obsWebSocket?.setCurrentProgramScene(name: name, onSuccess: {
            self.obsCurrentScene = name
            self.updateObsAudioInputs(sceneName: name)
        }, onError: { message in
            self.makeErrorToast(title: String(localized: "Failed to set OBS scene to \(name)"),
                                subTitle: message)
        })
    }

    private func updateObsStatus() {
        guard isObsConnected() else {
            obsAudioVolumeLatest = noValue
            return
        }
        obsWebSocket?.getStreamStatus(onSuccess: { state in
            self.obsWebsocketStreamStatusChanged(active: state.active, state: state.state)
        }, onError: { _ in
            self.obsWebsocketStreamStatusChanged(active: false, state: nil)
        })
        obsWebSocket?.getRecordStatus(onSuccess: { status in
            self.obsWebsocketRecordStatusChanged(active: status.active, state: nil)
        }, onError: { _ in
            self.obsWebsocketRecordStatusChanged(active: false, state: nil)
        })
        listObsScenes()
    }

    func reloadSpeechToText() {
        speechToText.stop()
        speechToText = SpeechToText()
        speechToText.delegate = self
        for textEffect in textEffects.values {
            textEffect.clearSubtitles()
        }
        if isSpeechToTextNeeded() {
            speechToText.start { message in
                self.makeErrorToast(title: message)
            }
        }
    }

    private func isSpeechToTextNeeded() -> Bool {
        for widget in database.widgets {
            guard widget.type == .text else {
                continue
            }
            guard widget.enabled! else {
                continue
            }
            guard widget.text.needsSubtitles! else {
                continue
            }
            return true
        }
        return false
    }

    func setup() {
        createUrlSession()
        AppDependencyManager.shared.add(dependency: self)
        faxReceiver.delegate = self
        fixAlertMedias()
        setMapPitch()
        setAllowVideoRangePixelFormat()
        setBlurSceneSwitch()
        audioUnitRemoveWindNoise = database.debug.removeWindNoise!
        showFirstTimeChatterMessage = database.chat.showFirstTimeChatterMessage!
        showNewFollowerMessage = database.chat.showNewFollowerMessage!
        verboseStatuses = database.verboseStatuses!
        supportsAppleLog = hasAppleLog()
        ioVideoUnitIgnoreFramesAfterAttachSeconds = Double(database.debug.cameraSwitchRemoveBlackish!)
        let webPCoder = SDImageWebPCoder.shared
        SDImageCodersManager.shared.addCoder(webPCoder)
        UIDevice.current.isBatteryMonitoringEnabled = true
        logger.handler = debugLog(message:)
        logger.debugEnabled = database.debug.logLevel == .debug
        updateCameraLists()
        updateBatteryLevel()
        media.onSrtConnected = handleSrtConnected
        media.onSrtDisconnected = handleSrtDisconnected
        media.onRtmpConnected = handleRtmpConnected
        media.onRtmpDisconnected = handleRtmpDisconnected
        media.onRistConnected = handleRistConnected
        media.onRistDisconnected = handleRistDisconnected
        media.onAudioMuteChange = updateAudioLevel
        media.onAudioBuffer = handleAudioBuffer
        media.onLowFpsImage = handleLowFpsImage
        media.onFindVideoFormatError = handleFindVideoFormatError
        media.onRecorderFinished = handleRecorderFinished
        media.onRecorderError = handleRecorderError
        media.onNoTorch = handleNoTorch
        setPixelFormat()
        setMetalPetalFilters()
        setHigherDataRateLimit()
        setupAudioSession()
        reloadSpeechToText()
        if let cameraDevice = preferredCamera(position: .back) {
            (cameraZoomXMinimum, cameraZoomXMaximum) = cameraDevice
                .getUIZoomRange(hasUltraWideCamera: hasUltraWideBackCamera())
            if let preset = backZoomPresets().first {
                backZoomPresetId = preset.id
                backZoomX = preset.x!
            } else {
                backZoomX = cameraZoomXMinimum
            }
            zoomX = backZoomX
        }
        frontZoomPresetId = database.zoom.front[0].id
        streamPreviewView.videoGravity = .resizeAspect
        updateDigitalClock(now: Date())
        twitchChat = TwitchChatMoblin(model: self)
        reloadStream()
        resetSelectedScene()
        setMic()
        setupPeriodicTimers()
        setupThermalState()
        updateButtonStates()
        scrollQuickButtonsToBottom()
        removeUnusedImages()
        removeUnusedAlertMedias()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(orientationDidChange),
                                               name: UIDevice.orientationDidChangeNotification,
                                               object: nil)
        iconImage = database.iconImage
        Task {
            appStoreUpdateListenerTask = listenForAppStoreTransactions()
            await getProductsFromAppStore()
            await updateProductFromAppStore()
            DispatchQueue.main.async {
                self.updateIconImageFromDatabase()
            }
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAudioRouteChange),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleDidEnterBackgroundNotification),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleWillEnterForegroundNotification),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleWillTerminate),
                                               name: UIApplication.willTerminateNotification,
                                               object: nil)
        updateOrientation()
        reloadRtmpServer()
        reloadSrtlaServer()
        ipMonitor.pathUpdateHandler = handleIpStatusUpdate
        ipMonitor.start()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleBatteryStateDidChangeNotification),
                                               name: UIDevice.batteryStateDidChangeNotification,
                                               object: nil)
        updateBatteryState()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleGameControllerDidConnect),
                                               name: NSNotification.Name.GCControllerDidConnect,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleGameControllerDidDisconnect),
                                               name: NSNotification.Name.GCControllerDidDisconnect,
                                               object: nil)
        GCController.startWirelessControllerDiscovery {}
        reloadLocation()
        currentStreamId = stream.id
        lutUpdated()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleCaptureDeviceWasConnected),
                                               name: NSNotification.Name.AVCaptureDeviceWasConnected,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleCaptureDeviceWasDisconnected),
                                               name: NSNotification.Name.AVCaptureDeviceWasDisconnected,
                                               object: nil)

        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        } else {
            logger.info("watch: Not supported")
        }
        chatTextToSpeech.setRate(rate: database.chat.textToSpeechRate!)
        chatTextToSpeech.setVolume(volume: database.chat.textToSpeechSayVolume!)
        chatTextToSpeech.setVoices(voices: database.chat.textToSpeechLanguageVoices!)
        chatTextToSpeech.setSayUsername(value: database.chat.textToSpeechSayUsername!)
        chatTextToSpeech
            .setDetectLanguagePerMessage(value: database.chat.textToSpeechDetectLanguagePerMessage!)
        chatTextToSpeech.setFilter(value: database.chat.textToSpeechFilter!)
        chatTextToSpeech.setFilterMentions(value: database.chat.textToSpeechFilterMentions!)
        setTextToSpeechStreamerMentions()
        AppDelegate.orientationLock = .landscape
        updateOrientationLock()
        updateFaceFilterSettings()
        setupSampleBufferReceiver()
        initMediaPlayers()
        removeUnusedLogs()
        autoStartDjiDevices()
        autoStartCatPrinters()
        startWeatherManager()
        startGeographyManager()
        twitchAuth.setOnAccessToken(onAccessToken: handleTwitchAccessToken)
        MoblinShortcuts.updateAppShortcutParameters()
        bondingStatisticsFormatter.setNetworkInterfaceNames(database.networkInterfaceNames!)
        reloadTeslaVehicle()
    }

    func reloadTeslaVehicle() {
        stopTeslaVehicle()
        let tesla = database.debug.tesla!
        if tesla.vin != "", tesla.privateKey != "" {
            teslaVehicle = TeslaVehicle(vin: tesla.vin, privateKeyPem: tesla.privateKey)
            teslaVehicle?.delegate = self
            teslaVehicle?.start()
        }
    }

    private func stopTeslaVehicle() {
        teslaVehicle?.delegate = nil
        teslaVehicle?.stop()
        teslaVehicle = nil
        teslaVehicleState = nil
    }

    func teslaFlashLights() {
        teslaVehicle?.flashLights()
    }

    func teslaHonk() {
        teslaVehicle?.honk()
    }

    private var teslaChargeState = CarServer_ChargeState()

    func teslaGetChargeState() {
        teslaVehicle?.getChargeState { state in
            self.teslaChargeState = state
        }
    }

    func teslaGetDriveState() {
        teslaVehicle?.getDriveState { _ in
        }
    }

    func teslaGetMediaState() {
        teslaVehicle?.getMediaState { _ in
        }
    }

    func teslaOpenTrunk() {
        teslaVehicle?.openTrunk()
    }

    func teslaCloseTrunk() {
        teslaVehicle?.closeTrunk()
    }

    private func updateTeslaVehicleState() {
        teslaGetChargeState()
    }

    func mediaNextTrack() {
        teslaVehicle?.mediaNextTrack()
    }

    func mediaTogglePlayback() {
        teslaVehicle?.mediaTogglePlayback()
    }

    func teslaPing() {
        teslaVehicle?.ping()
    }

    private func isWeatherNeeded() -> Bool {
        for widget in database.widgets {
            guard widget.type == .text else {
                continue
            }
            guard widget.enabled! else {
                continue
            }
            guard widget.text.needsWeather! else {
                continue
            }
            return true
        }
        return false
    }

    func startWeatherManager() {
        weatherManager.setEnabled(value: isWeatherNeeded())
        weatherManager.start()
    }

    private func isGeographyNeeded() -> Bool {
        for widget in database.widgets {
            guard widget.type == .text else {
                continue
            }
            guard widget.enabled! else {
                continue
            }
            guard widget.text.needsGeography! else {
                continue
            }
            return true
        }
        return false
    }

    func startGeographyManager() {
        geographyManager.setEnabled(value: isGeographyNeeded())
        geographyManager.start()
    }

    private func removeUnusedLogs() {
        for logId in logsStorage.ids()
            where !streamingHistory.database.streams.contains(where: { $0.logId == logId })
        {
            logsStorage.remove(id: logId)
        }
    }

    func setMetalPetalFilters() {
        ioVideoUnitMetalPetal = database.debug.metalPetalFilters!
    }

    func setHigherDataRateLimit() {
        videoCodecHigherDataRateLimit = database.debug.higherDataRateLimit!
    }

    func setMapPitch() {
        maxMapPitch = database.debug.maxMapPitch!
    }

    private func setupSampleBufferReceiver() {
        sampleBufferReceiver.delegate = self
        sampleBufferReceiver.start(appGroup: moblinAppGroup)
    }

    func updateFaceFilterSettings() {
        let settings = database.debug.beautyFilterSettings!
        faceEffect.safeSettings.mutate { $0 = FaceEffectSettings(
            showCrop: database.debug.beautyFilter!,
            showBlur: settings.showBlur,
            showBlurBackground: settings.showBlurBackground!,
            showMouth: settings.showMoblin,
            showBeauty: settings.showBeauty!,
            shapeRadius: settings.shapeRadius!,
            shapeAmount: settings.shapeScale!,
            shapeOffset: settings.shapeOffset!,
            smoothAmount: settings.smoothAmount!,
            smoothRadius: settings.smoothRadius!
        ) }
    }

    func setPixelFormat() {
        for (format, type) in zip(pixelFormats, pixelFormatTypes) where
            database.debug.pixelFormat == format
        {
            logger.info("Setting pixel format \(format)")
            pixelFormatType = type
        }
    }

    private func handleIpStatusUpdate(statuses: [IPMonitor.Status]) {
        ipStatuses = statuses
        for status in statuses where status.interfaceType == .wiredEthernet {
            for stream in database.streams
                where !stream.srt.connectionPriorities!.priorities.contains(where: { priority in
                    priority.name == status.name
                })
            {
                stream.srt.connectionPriorities!.priorities
                    .append(SettingsStreamSrtConnectionPriority(name: status.name))
            }
            if !database.networkInterfaceNames!.contains(where: { interface in
                interface.interfaceName == status.name
            }) {
                let interface = SettingsNetworkInterfaceName()
                interface.interfaceName = status.name
                interface.name = status.name
                database.networkInterfaceNames!.append(interface)
            }
        }
    }

    private func handleGameControllerButtonZoom(pressed: Bool, x: Float) {
        if pressed {
            if let x = setCameraZoomX(x: x, rate: database.zoom.speed!) {
                setZoomX(x: x)
            }
        } else {
            if let x = stopCameraZoom() {
                setZoomX(x: x)
            }
        }
    }

    private func handleGameControllerButton(
        _ gameController: GCController,
        _ button: GCControllerButtonInput,
        _: Float,
        _ pressed: Bool
    ) {
        guard let gameControllerIndex = gameControllers.firstIndex(of: gameController) else {
            return
        }
        guard gameControllerIndex < database.gameControllers!.count else {
            return
        }
        guard let name = button.sfSymbolsName else {
            return
        }
        let button = database.gameControllers![gameControllerIndex].buttons.first(where: { button in
            button.name == name
        })
        guard let button else {
            return
        }
        switch button.function {
        case .unused:
            break
        case .record:
            if !pressed {
                toggleRecording()
                updateButtonStates()
            }
        case .stream:
            if !pressed {
                toggleStream()
                updateButtonStates()
            }
        case .zoomIn:
            handleGameControllerButtonZoom(pressed: pressed, x: Float.infinity)
        case .zoomOut:
            handleGameControllerButtonZoom(pressed: pressed, x: 0)
        case .torch:
            if !pressed {
                toggleTorch()
                toggleGlobalButton(type: .torch)
                updateButtonStates()
            }
        case .mute:
            if !pressed {
                toggleMute()
                toggleGlobalButton(type: .mute)
                updateButtonStates()
            }
        case .blackScreen:
            if !pressed {
                toggleBlackScreen()
                updateButtonStates()
            }
        case .chat:
            break
        case .scene:
            if !pressed {
                selectScene(id: button.sceneId)
            }
        }
    }

    private func updateCameraLists() {
        if ProcessInfo().isiOSAppOnMac {
            externalCameras = []
            backCameras = listCameras(position: .back)
            frontCameras = listCameras(position: .front)
        } else {
            externalCameras = listExternalCameras()
            backCameras = listCameras(position: .back)
            frontCameras = listCameras(position: .front)
        }
    }

    @objc func handleCaptureDeviceWasConnected(_: Notification) {
        logger.info("Capture device connected")
        updateCameraLists()
    }

    @objc func handleCaptureDeviceWasDisconnected(_: Notification) {
        logger.info("Capture device disconnected")
        updateCameraLists()
    }

    private func numberOfGameControllers() -> Int {
        return gameControllers.filter { gameController in
            gameController != nil
        }.count
    }

    func isGameControllerConnected() -> Bool {
        return numberOfGameControllers() > 0
    }

    private func updateGameControllers() {
        gameControllersTotal = String(numberOfGameControllers())
    }

    private func gameControllerNumber(gameController: GCController) -> Int? {
        if let gameControllerIndex = gameControllers.firstIndex(of: gameController) {
            return gameControllerIndex + 1
        }
        return nil
    }

    @objc func handleGameControllerDidConnect(_ notification: Notification) {
        guard let gameController = notification.object as? GCController else {
            return
        }
        guard let gamepad = gameController.extendedGamepad else {
            return
        }
        gamepad.dpad.left.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.dpad.right.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.dpad.up.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.dpad.down.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.buttonA.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.buttonB.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.buttonX.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.buttonY.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.buttonMenu.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.leftShoulder.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.rightShoulder.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.leftTrigger.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.rightTrigger.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        if let index = gameControllers.firstIndex(of: nil) {
            gameControllers[index] = gameController
        } else {
            gameControllers.append(gameController)
        }
        if let number = gameControllerNumber(gameController: gameController) {
            makeToast(title: String(localized: "Game controller \(number) connected"))
        }
        updateGameControllers()
    }

    @objc func handleGameControllerDidDisconnect(notification: Notification) {
        guard let gameController = notification.object as? GCController else {
            return
        }
        if let number = gameControllerNumber(gameController: gameController) {
            makeToast(title: String(localized: "Game controller \(number) disconnected"))
        }
        if let index = gameControllers.firstIndex(of: gameController) {
            gameControllers[index] = nil
        }
        updateGameControllers()
    }

    @objc func handleDidEnterBackgroundNotification() {
        store()
        guard !ProcessInfo().isiOSAppOnMac else {
            return
        }
        if !shouldStreamInBackground() {
            if isRecording {
                suspendRecording()
            }
            stopRtmpServer()
            stopSrtlaServer()
            teardownAudioSession()
            chatTextToSpeech.reset(running: false)
            locationManager.stop()
            weatherManager.stop()
            geographyManager.stop()
            obsWebSocket?.stop()
            media.stopAllNetStreams()
            speechToText.stop()
            stopWorkout(showToast: false)
            stopTeslaVehicle()
        }
    }

    @objc func handleWillEnterForegroundNotification() {
        guard !ProcessInfo().isiOSAppOnMac else {
            return
        }
        if !shouldStreamInBackground() {
            reloadStream(continueRecording: isRecording)
            sceneUpdated()
            setupAudioSession()
            media.attachAudio(device: AVCaptureDevice.default(for: .audio))
            reloadRtmpServer()
            reloadDjiDevices()
            reloadSrtlaServer()
            chatTextToSpeech.reset(running: true)
            startWeatherManager()
            startGeographyManager()
            if isRecording {
                resumeRecording()
            }
            reloadSpeechToText()
            reloadTeslaVehicle()
        }
    }

    @objc func handleWillTerminate() {
        if isRecording {
            suspendRecording()
        }
        if !showLoadSettingsFailed {
            store()
        }
    }

    private func shouldStreamInBackground() -> Bool {
        return (isLive || isRecording) && stream.backgroundStreaming!
    }

    @objc func handleBatteryStateDidChangeNotification() {
        updateBatteryState()
    }

    private func stopRtmpServer() {
        rtmpServer?.stop()
        rtmpServer = nil
        stopAllRtmpStreams()
    }

    func reloadRtmpServer() {
        stopRtmpServer()
        if database.rtmpServer!.enabled {
            rtmpServer = RtmpServer(settings: database.rtmpServer!.clone())
            rtmpServer?.delegate = self
            rtmpServer!.start()
        }
    }

    private func stopSrtlaServer() {
        srtlaServer?.stop()
        srtlaServer = nil
    }

    func reloadSrtlaServer() {
        stopSrtlaServer()
        if database.srtlaServer!.enabled {
            srtlaServer = SrtlaServer(settings: database.srtlaServer!)
            srtlaServer!.delegate = self
            srtlaServer!.start()
        }
    }

    func srtlaServerEnabled() -> Bool {
        return srtlaServer != nil
    }

    private func srtlaCameras() -> [String] {
        return database.srtlaServer!.streams.map { stream in
            stream.camera()
        }
    }

    func getSrtlaStream(id: UUID) -> SettingsSrtlaServerStream? {
        return database.srtlaServer!.streams.first { stream in
            stream.id == id
        }
    }

    func getSrtlaStream(camera: String) -> SettingsSrtlaServerStream? {
        return database.srtlaServer!.streams.first { stream in
            camera == stream.camera()
        }
    }

    func getSrtlaStream(streamId: String) -> SettingsSrtlaServerStream? {
        return database.srtlaServer!.streams.first { stream in
            stream.streamId == streamId
        }
    }

    func isSrtlaStreamConnected(streamId: String) -> Bool {
        return srtlaServer?.isStreamConnected(streamId: streamId) ?? false
    }

    private func playerCameras() -> [String] {
        return database.mediaPlayers!.players.map { $0.camera() }
    }

    func getMediaPlayer(camera: String) -> SettingsMediaPlayer? {
        return database.mediaPlayers!.players.first {
            $0.camera() == camera
        }
    }

    func getMediaPlayer(id: UUID) -> SettingsMediaPlayer? {
        return database.mediaPlayers!.players.first {
            $0.id == id
        }
    }

    private func mediaPlayerCameras() -> [String] {
        return database.mediaPlayers!.players.map { $0.camera() }
    }

    func reloadRtmpStreams() {
        for rtmpCamera in rtmpCameras() {
            guard let stream = getRtmpStream(camera: rtmpCamera) else {
                continue
            }
            if isRtmpStreamConnected(streamKey: stream.streamKey) {
                let micId = "\(stream.id.uuidString) 0"
                let isLastMic = (currentMic.id == micId)
                handleRtmpServerPublishStop(streamKey: stream.streamKey)
                handleRtmpServerPublishStart(streamKey: stream.streamKey)
                if currentMic.id != micId, isLastMic {
                    selectMicById(id: micId)
                }
            }
        }
    }

    func handleRtmpServerPublishStart(streamKey: String) {
        DispatchQueue.main.async {
            let camera = self.getRtmpStream(streamKey: streamKey)?.camera() ?? rtmpCamera(name: "Unknown")
            self.makeToast(title: String(localized: "\(camera) connected"))
            guard let stream = self.getRtmpStream(streamKey: streamKey) else {
                return
            }
            let name = "RTMP \(camera)"
            let latency = Double(stream.latency!) / 1000.0
            self.media.addReplaceVideo(cameraId: stream.id, name: name, latency: latency)
            self.media.addReplaceAudio(cameraId: stream.id, name: name, latency: latency)
            if stream.autoSelectMic! {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.selectMicById(id: "\(stream.id) 0")
                }
            }
            self.markDjiIsStreamingIfNeeded(rtmpServerStreamId: stream.id)
        }
    }

    func handleRtmpServerPublishStop(streamKey: String) {
        DispatchQueue.main.async {
            guard let stream = self.getRtmpStream(streamKey: streamKey) else {
                return
            }
            self.stopRtmpServerStream(stream: stream, showToast: true)
        }
    }

    private func stopRtmpServerStream(stream: SettingsRtmpServerStream, showToast: Bool) {
        if showToast {
            makeToast(title: String(localized: "\(stream.camera()) disconnected"))
        }
        media.removeReplaceVideo(cameraId: stream.id)
        media.removeReplaceAudio(cameraId: stream.id)
        if currentMic.id == "\(stream.id) 0" {
            setMicFromSettings()
        }
        for device in database.djiDevices!.devices {
            guard device.rtmpUrlType == .server, device.serverRtmpStreamId! == stream.id else {
                continue
            }
            restartDjiLiveStreamIfNeededAfterDelay(device: device)
        }
    }

    func handleRtmpServerFrame(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        media.addReplaceVideoSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func handleRtmpServerAudioBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        media.addReplaceAudioSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    private func rtmpServerInfo() {
        guard let rtmpServer, logger.debugEnabled else {
            return
        }
        for stream in database.rtmpServer!.streams {
            guard let info = rtmpServer.streamInfo(streamKey: stream.streamKey) else {
                continue
            }
            let audioRate = formatTwoDecimals(info.audioSamplesPerSecond)
            let fps = formatTwoDecimals(info.videoFps)
            logger
                .debug(
                    "RTMP server stream \(stream.streamKey) has FPS \(fps) and \(audioRate) audio samples/second"
                )
        }
    }

    private func keepSpeakerAlive(now: ContinuousClock.Instant) {
        guard keepSpeakerAliveLatestPlayed.duration(to: now) > .seconds(5 * 60) else {
            return
        }
        keepSpeakerAliveLatestPlayed = now
        guard let soundUrl = Bundle.main.url(forResource: "Alerts.bundle/Silence", withExtension: "mp3")
        else {
            return
        }
        keepSpeakerAlivePlayer = try? AVAudioPlayer(contentsOf: soundUrl)
        keepSpeakerAlivePlayer?.play()
    }

    private func listCameras(position: AVCaptureDevice.Position) -> [Camera] {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualCamera,
            .builtInDualWideCamera,
            .builtInUltraWideCamera,
            .builtInWideAngleCamera,
            .builtInTelephotoCamera,
        ]
        if #available(iOS 17.0, *) {
            deviceTypes.append(.external)
        }
        let deviceDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position
        )
        return deviceDiscovery.devices.map { device in
            Camera(id: device.uniqueID, name: cameraName(device: device))
        }
    }

    func isSceneActive(scene: SettingsScene) -> Bool {
        switch scene.cameraPosition {
        case .rtmp:
            if let stream = getRtmpStream(id: scene.rtmpCameraId!) {
                return isRtmpStreamConnected(streamKey: stream.streamKey)
            } else {
                return false
            }
        case .srtla:
            if let stream = getSrtlaStream(id: scene.rtmpCameraId!) {
                return isSrtlaStreamConnected(streamId: stream.streamId)
            } else {
                return false
            }
        case .external:
            return isExternalCameraConnected(id: scene.externalCameraId!)
        default:
            return true
        }
    }

    private func isExternalCameraConnected(id: String) -> Bool {
        externalCameras.first { camera in
            camera.id == id
        } != nil
    }

    private func listExternalCameras() -> [Camera] {
        var deviceTypes: [AVCaptureDevice.DeviceType] = []
        if #available(iOS 17.0, *) {
            deviceTypes.append(.external)
        }
        let deviceDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )
        return deviceDiscovery.devices.map { device in
            Camera(id: device.uniqueID, name: cameraName(device: device))
        }
    }

    deinit {
        appStoreUpdateListenerTask?.cancel()
    }

    func updateOrientation() {
        if stream.portrait! || database.portrait! {
            streamPreviewView.videoOrientation = .landscapeRight
        } else {
            switch UIDevice.current.orientation {
            case .landscapeLeft:
                streamPreviewView.videoOrientation = .landscapeRight
            case .landscapeRight:
                streamPreviewView.videoOrientation = .landscapeLeft
            default:
                break
            }
        }
    }

    @objc private func orientationDidChange(animated _: Bool) {
        updateOrientation()
    }

    private func isInMyIcons(id: String) -> Bool {
        return myIcons.contains(where: { icon in
            icon.id == id
        })
    }

    func updateIconImageFromDatabase() {
        if !isInMyIcons(id: database.iconImage) {
            logger.warning("Database icon image \(database.iconImage) is not mine")
            database.iconImage = plainIcon.id
        }
        iconImage = database.iconImage
    }

    private func handleSettingsUrlsDefaultStreams(settings: MoblinSettingsUrl) {
        var newSelectedStream: SettingsStream?
        for stream in settings.streams ?? [] {
            let newStream = SettingsStream(name: stream.name)
            newStream.url = stream.url.trim()
            if stream.selected == true {
                newSelectedStream = newStream
            }
            if let video = stream.video {
                if let resolution = video.resolution {
                    newStream.resolution = resolution
                }
                if let fps = video.fps, fpss.contains(String(fps)) {
                    newStream.fps = fps
                }
                if let bitrate = video.bitrate, bitrate >= 50000, bitrate <= 50_000_000 {
                    newStream.bitrate = bitrate
                }
                if let codec = video.codec {
                    newStream.codec = codec
                }
                if let bFrames = video.bFrames {
                    newStream.bFrames = bFrames
                }
                if let maxKeyFrameInterval = video.maxKeyFrameInterval, maxKeyFrameInterval >= 0,
                   maxKeyFrameInterval <= 10
                {
                    newStream.maxKeyFrameInterval = maxKeyFrameInterval
                }
            }
            if let audio = stream.audio {
                if let bitrate = audio.bitrate, isValidAudioBitrate(bitrate: bitrate) {
                    newStream.audioBitrate = bitrate
                }
            }
            if let srt = stream.srt {
                if let latency = srt.latency {
                    newStream.srt.latency = latency
                }
                if let adaptiveBitrateEnabled = srt.adaptiveBitrateEnabled {
                    newStream.srt.adaptiveBitrateEnabled = adaptiveBitrateEnabled
                }
            }
            if let obs = stream.obs {
                newStream.obsWebSocketEnabled = true
                newStream.obsWebSocketUrl = obs.webSocketUrl.trim()
                newStream.obsWebSocketPassword = obs.webSocketPassword.trim()
            }
            if let twitch = stream.twitch {
                newStream.twitchChannelName = twitch.channelName.trim()
                newStream.twitchChannelId = twitch.channelId.trim()
            }
            if let kick = stream.kick {
                newStream.kickChannelName = kick.channelName.trim()
            }
            database.streams.append(newStream)
        }
        if let newSelectedStream, !isLive, !isRecording {
            setCurrentStream(stream: newSelectedStream)
        }
    }

    private func handleSettingsUrlsDefaultQuickButtons(settings: MoblinSettingsUrl) {
        if let quickButtons = settings.quickButtons {
            if let twoColumns = quickButtons.twoColumns {
                database.quickButtons!.twoColumns = twoColumns
            }
            if let showName = quickButtons.showName {
                database.quickButtons!.showName = showName
            }
            if let enableScroll = quickButtons.enableScroll {
                database.quickButtons!.enableScroll = enableScroll
            }
            if quickButtons.disableAllButtons == true {
                for globalButton in database.globalButtons! {
                    globalButton.enabled = false
                }
            }
            for button in quickButtons.buttons ?? [] {
                for globalButton in database.globalButtons! {
                    guard button.type == globalButton.type else {
                        continue
                    }
                    if let enabled = button.enabled {
                        globalButton.enabled = enabled
                    }
                }
            }
        }
    }

    private func handleSettingsUrlsDefaultWebBrowser(settings: MoblinSettingsUrl) {
        if let webBrowser = settings.webBrowser {
            if let home = webBrowser.home {
                database.webBrowser!.home = home
            }
        }
    }

    private func handleSettingsUrlsDefault(settings: MoblinSettingsUrl) {
        handleSettingsUrlsDefaultStreams(settings: settings)
        handleSettingsUrlsDefaultQuickButtons(settings: settings)
        handleSettingsUrlsDefaultWebBrowser(settings: settings)
        makeToast(title: String(localized: "URL import successful"))
        updateButtonStates()
    }

    func handleSettingsUrls(urls: Set<UIOpenURLContext>) {
        for url in urls {
            if let message = handleSettingsUrl(url: url.url) {
                makeErrorToast(
                    title: String(localized: "URL import failed"),
                    subTitle: message
                )
            }
        }
    }

    func handleSettingsUrl(url: URL) -> String? {
        guard url.path.isEmpty else {
            return "Custom URL path is not empty"
        }
        guard let query = url.query(percentEncoded: false) else {
            return "Custom URL query is missing"
        }
        let settings: MoblinSettingsUrl
        do {
            settings = try MoblinSettingsUrl.fromString(query: query)
        } catch {
            return error.localizedDescription
        }
        if isPresentingWizard || isPresentingSetupWizard {
            handleSettingsUrlsInWizard(settings: settings)
        } else {
            handleSettingsUrlsDefault(settings: settings)
        }
        return nil
    }

    private func setupPeriodicTimers() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            let now = Date()
            let monotonicNow = ContinuousClock.now
            self.updateUptime(now: monotonicNow)
            self.updateRecordingLength(now: now)
            self.updateDigitalClock(now: now)
            self.updateChatSpeed()
            self.media.updateSrtSpeed()
            self.updateSpeed(now: monotonicNow)
            self.updateServersSpeed()
            if !self.database.show.audioBar {
                self.updateAudioLevel()
            }
            self.updateBondingStatistics()
            self.removeOldChatMessages(now: monotonicNow)
            self.updateLocation()
            self.updateObsSourceScreenshot()
            self.updateObsAudioVolume()
            self.updateBrowserWidgetStatus()
            self.logStatus()
            self.updateFailedVideoEffects()
            self.updateAdaptiveBitrateDebug()
            self.updateTextEffects(now: now, timestamp: monotonicNow)
            self.updateMapEffects()
            self.updatePoll()
            self.updateObsSceneSwitcher(now: monotonicNow)
            self.weatherManager.setLocation(location: self.latestKnownLocation)
            self.geographyManager.setLocation(location: self.latestKnownLocation)
            self.updateBitrateStatus()
            self.updateAdsRemainingTimer(now: now)
            self.keepSpeakerAlive(now: monotonicNow)
        })
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true, block: { _ in
            self.updateBatteryLevel()
            self.media.logStatistics()
            self.updateObsStatus()
            self.updateRemoteControlStatus()
            if self.stream.enabled {
                self.media.updateVideoStreamBitrate(bitrate: self.stream.bitrate)
            }
            // self.media.logTiming()
            self.updateViewers()
            self.updateCurrentSsid()
            self.rtmpServerInfo()
            self.updateTeslaVehicleState()
        })
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: { _ in
            self.updateRemoteControlAssistantStatus()
            self.sendThermalStateToWatch(thermalState: self.thermalState)
        })
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { _ in
            let monotonicNow = ContinuousClock.now
            if self.database.show.audioBar {
                self.updateAudioLevel()
            }
            self.updateChat()
            if !self.isRemoteControlAssistantConnected() {
                self.trySendNextChatPostToWatch()
            }
            if let lastAttachCompletedTime = self.lastAttachCompletedTime,
               lastAttachCompletedTime.duration(to: monotonicNow) > .seconds(0.5)
            {
                self.updateTorch()
                self.lastAttachCompletedTime = nil
            }
            self.speechToText.tick(now: monotonicNow)
        })
        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true, block: { _ in
            self.updateAdaptiveBitrate()
        })
    }

    private func isStreamLikelyBroken(now: ContinuousClock.Instant) -> Bool {
        defer {
            previousSrtDroppedPacketsTotal = media.srtDroppedPacketsTotal
        }
        if streamState == .disconnected {
            return true
        }
        if media.srtDroppedPacketsTotal > previousSrtDroppedPacketsTotal {
            streamBecameBrokenTime = now
            return true
        }
        if let streamBecameBrokenTime {
            if streamBecameBrokenTime.duration(to: now) < .seconds(15) {
                return true
            } else if obsCurrentScene != stream.obsBrbScene! {
                return true
            }
        }
        if stream.obsBrbSceneVideoSourceBroken!, let scene = getSelectedScene() {
            switch scene.cameraPosition {
            case .srtla:
                if let srtlaStream = getSrtlaStream(id: scene.srtlaCameraId!) {
                    if srtlaServer?.isStreamConnected(streamId: srtlaStream.streamId) == false {
                        streamBecameBrokenTime = now
                        return true
                    }
                }
            case .rtmp:
                if let rtmpStream = getRtmpStream(id: scene.rtmpCameraId!) {
                    if rtmpServer?.isStreamConnected(streamKey: rtmpStream.streamKey) == false {
                        streamBecameBrokenTime = now
                        return true
                    }
                }
            default:
                break
            }
        }
        streamBecameBrokenTime = nil
        return false
    }

    private func updateObsSceneSwitcher(now: ContinuousClock.Instant) {
        guard isLive, !stream.obsBrbScene!.isEmpty, !obsCurrentScene.isEmpty, isObsConnected() else {
            return
        }
        if isStreamLikelyBroken(now: now) {
            if obsCurrentScene != stream.obsBrbScene! {
                if !stream.obsMainScene!.isEmpty {
                    obsSceneBeforeSwitchToBrbScene = stream.obsMainScene!
                } else {
                    obsSceneBeforeSwitchToBrbScene = obsCurrentScene
                }
                makeStreamLikelyBrokenToast(scene: stream.obsBrbScene!)
                setObsScene(name: stream.obsBrbScene!)
            }
        } else if let obsSceneBeforeSwitchToBrbScene {
            if obsCurrentScene == stream.obsBrbScene! {
                makeStreamLikelyWorkingToast(scene: obsSceneBeforeSwitchToBrbScene)
                setObsScene(name: obsSceneBeforeSwitchToBrbScene)
            } else if obsCurrentScene == obsSceneBeforeSwitchToBrbScene {
                self.obsSceneBeforeSwitchToBrbScene = nil
            }
        }
    }

    private func updateBitrateStatus() {
        defer {
            previousBitrateStatusColorSrtDroppedPacketsTotal = media.srtDroppedPacketsTotal
            previousBitrateStatusNumberOfFailedEncodings = numberOfFailedEncodings
        }
        let newBitrateStatusColor: Color
        if media.srtDroppedPacketsTotal > previousBitrateStatusColorSrtDroppedPacketsTotal {
            newBitrateStatusColor = .red
        } else if numberOfFailedEncodings > previousBitrateStatusNumberOfFailedEncodings {
            newBitrateStatusColor = .red
        } else {
            newBitrateStatusColor = .white
        }
        if newBitrateStatusColor != bitrateStatusColor {
            bitrateStatusColor = newBitrateStatusColor
        }
    }

    private func updateAdsRemainingTimer(now: Date) {
        guard let adsEndDate else {
            return
        }
        let secondsLeft = adsEndDate.timeIntervalSince(now)
        if secondsLeft < 0 {
            self.adsEndDate = nil
            adsRemainingTimerStatus = noValue
        } else {
            adsRemainingTimerStatus = String(Int(secondsLeft))
        }
    }

    private func updateCurrentSsid() {
        NEHotspotNetwork.fetchCurrent(completionHandler: { network in
            self.currentWiFiSsid = network?.ssid
        })
    }

    func colorSpaceUpdated() {
        setColorSpace()
    }

    func lutEnabledUpdated() {
        if database.color!.lutEnabled, database.color!.space == .appleLog {
            media.registerEffect(lutEffect)
        } else {
            media.unregisterEffect(lutEffect)
        }
    }

    func loadLutImage(lut: SettingsColorLut) -> UIImage? {
        var image: UIImage?
        switch lut.type {
        case .bundled:
            guard let path = Bundle.main.path(forResource: "LUTs.bundle/\(lut.name).png", ofType: nil) else {
                return nil
            }
            image = UIImage(contentsOfFile: path)
        case .disk:
            if let data = try? Data(contentsOf: imageStorage.makePath(id: lut.id)) {
                image = UIImage(data: data)
            }
        }
        guard let image else {
            let message = "Failed to load LUT image \(lut.name)"
            makeErrorToast(title: message)
            logger.info(message)
            return nil
        }
        return image
    }

    func lutUpdated() {
        guard let lut = getLogLutById(id: database.color!.lut) else {
            media.unregisterEffect(lutEffect)
            return
        }
        guard let image = loadLutImage(lut: lut) else {
            return
        }
        do {
            try lutEffect.setLut(image: image)
        } catch {
            let message = "\(error)"
            makeErrorToast(title: message)
            logger.info(message)
        }
    }

    func addLut(data: Data) {
        let lut = SettingsColorLut(type: .disk, name: "My LUT")
        lut.buttonId = .init()
        imageStorage.write(id: lut.id, data: data)
        database.color!.diskLuts!.append(lut)
        resetSelectedScene()
    }

    func removeLut(offsets: IndexSet) {
        for offset in offsets {
            let lut = database.color!.diskLuts![offset]
            imageStorage.remove(id: lut.id)
        }
        database.color!.diskLuts!.remove(atOffsets: offsets)
        resetSelectedScene()
    }

    func setLutName(lut: SettingsColorLut, name: String) {
        lut.name = name
    }

    func allLuts() -> [SettingsColorLut] {
        return database.color!.bundledLuts + database.color!.diskLuts!
    }

    func getLogLutById(id: UUID) -> SettingsColorLut? {
        return allLuts().first { $0.id == id }
    }

    private func updateAdaptiveBitrate() {
        if let (lines, actions) = media.updateAdaptiveBitrate(overlay: database.debug.srtOverlay) {
            latestDebugLines = lines
            latestDebugActions = actions
        }
    }

    private func updateAdaptiveBitrateDebug() {
        if database.debug.srtOverlay {
            debugLines = latestDebugLines + latestDebugActions
            debugLines.append("Audio/video capture delta: \(Int(1000 * media.getCaptureDelta())) ms")
            if logger.debugEnabled, isLive {
                logger.debug(latestDebugLines.joined(separator: ", "))
            }
        } else if !debugLines.isEmpty {
            debugLines = []
        }
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
            if database.color!.diskLuts!.contains(where: { lut in
                lut.id == id
            }) {
                used = true
            }
            if !used {
                logger.info("Removing unused image \(id)")
                imageStorage.remove(id: id)
            }
        }
    }

    private func updateViewers() {
        var newNumberOfViewers = 0
        var hasInfo = false
        if isTwitchViewersConfigured(), let twitchPubSub, twitchPubSub.isConnected(),
           let numberOfViewers = twitchPubSub.numberOfViewers
        {
            newNumberOfViewers += numberOfViewers
            hasInfo = true
        }
        if isKickViewersConfigured(), let numberOfViewers = kickViewers?.numberOfViewers {
            newNumberOfViewers += numberOfViewers
            hasInfo = true
        }
        var newValue: String
        if hasInfo {
            newValue = countFormatter.format(newNumberOfViewers)
        } else {
            newValue = noValue
        }
        if !isLive {
            newValue = noValue
        }
        if newValue != numberOfViewers {
            numberOfViewers = newValue
            sendViewerCountWatch()
        }
    }

    private func updateAudioLevel() {
        let newAudioLevel = media.getAudioLevel()
        let newNumberOfAudioChannels = media.getNumberOfAudioChannels()
        if newNumberOfAudioChannels != numberOfAudioChannels {
            numberOfAudioChannels = newNumberOfAudioChannels
        }
        if newAudioLevel == audioLevel {
            return
        }
        if abs(audioLevel - newAudioLevel) > 5 || newAudioLevel
            .isNaN || newAudioLevel == .infinity || audioLevel.isNaN || audioLevel == .infinity
        {
            audioLevel = newAudioLevel
            if !isRemoteControlAssistantConnected() {
                sendAudioLevelToWatch(audioLevel: audioLevel)
            }
        }
    }

    private func handleAudioBuffer(sampleBuffer: CMSampleBuffer) {
        DispatchQueue.main.async {
            self.speechToText.append(sampleBuffer: sampleBuffer)
        }
    }

    private func updateBondingStatistics() {
        if isStreamConnected() {
            if let connections = media.srtlaConnectionStatistics() {
                if let (message, percentages) = bondingStatisticsFormatter.format(connections) {
                    bondingStatistics = message
                    bondingPieChartPercentages = percentages
                }
                return
            }
            if let connections = media.ristBondingStatistics() {
                if let (message, percentages) = bondingStatisticsFormatter.format(connections) {
                    bondingStatistics = message
                    bondingPieChartPercentages = percentages
                }
                return
            }
        }
        if bondingStatistics != noValue {
            bondingStatistics = noValue
        }
    }

    func updateSrtlaPriorities() {
        media.setConnectionPriorities(connectionPriorities: stream.srt.connectionPriorities!)
    }

    func endOfInteractiveChatReachedWhenPaused() {
        var numberOfPostsAppended = 0
        while numberOfPostsAppended < 5, let post = pausedInteractiveChatPosts.popFirst() {
            if post.user == nil {
                if let lastPost = interactiveChatPosts.first, lastPost.user == nil {
                    continue
                }
                if pausedInteractiveChatPosts.isEmpty {
                    continue
                }
            }
            if interactiveChatPosts.count > maximumNumberOfInteractiveChatMessages - 1 {
                interactiveChatPosts.removeLast()
            }
            interactiveChatPosts.prepend(post)
            numberOfPostsAppended += 1
        }
        if numberOfPostsAppended == 0 {
            interactiveChatPaused = false
        }
    }

    func pauseInteractiveChat() {
        interactiveChatPaused = true
        pausedInteractiveChatPostsCount = 0
        appendChatMessage(
            platform: .unknown,
            user: nil,
            userId: nil,
            userColor: nil,
            userBadges: [],
            segments: [],
            timestamp: "",
            timestampTime: .now,
            isAction: false,
            isSubscriber: false,
            isModerator: false,
            bits: nil,
            highlight: nil
        )
    }

    func endOfInteractiveChatAlertsReachedWhenPaused() {
        var numberOfPostsAppended = 0
        while numberOfPostsAppended < 5, let post = pausedInteractiveChatAlertsPosts.popFirst() {
            if post.user == nil {
                if let lastPost = interactiveChatAlertsPosts.first, lastPost.user == nil {
                    continue
                }
                if pausedInteractiveChatAlertsPosts.isEmpty {
                    continue
                }
            }
            if interactiveChatAlertsPosts.count > maximumNumberOfInteractiveChatMessages - 1 {
                interactiveChatAlertsPosts.removeLast()
            }
            interactiveChatAlertsPosts.prepend(post)
            numberOfPostsAppended += 1
        }
        if numberOfPostsAppended == 0 {
            interactiveChatAlertsPaused = false
        }
    }

    func pauseInteractiveChatAlerts() {
        interactiveChatAlertsPaused = true
        pausedInteractiveChatAlertsPostsCount = 0
    }

    private func removeOldChatMessages(now: ContinuousClock.Instant) {
        if interactiveChatPaused {
            return
        }
        guard database.chat.maximumAgeEnabled! else {
            return
        }
        while let post = chatPosts.last {
            if now > post.timestampTime + .seconds(database.chat.maximumAge!) {
                chatPosts.removeLast()
            } else {
                break
            }
        }
    }

    private func updateChat() {
        while let post = newChatPosts.popFirst() {
            if chatPosts.count > maximumNumberOfChatMessages - 1 {
                chatPosts.removeLast()
            }
            chatPosts.prepend(post)
            if !isRemoteControlAssistantConnected() {
                sendChatMessageToWatch(post: post)
            }
            if isTextToSpeechEnabledForMessage(post: post), let user = post.user {
                let message = post.segments.filter { $0.text != nil }.map { $0.text! }.joined(separator: "")
                if !message.trimmingCharacters(in: .whitespaces).isEmpty {
                    chatTextToSpeech.say(user: user, message: message, isRedemption: post.isRedemption())
                }
            }
            if isAnyConnectedCatPrinterPrintingChat() {
                printChatMessage(post: post)
            }
            numberOfChatPostsPerTick += 1
            streamTotalChatMessages += 1
        }
        if interactiveChatPaused {
            // The red line is one post.
            pausedInteractiveChatPostsCount = max(pausedInteractiveChatPosts.count - 1, 0)
        } else {
            while let post = newInteractiveChatPosts.popFirst() {
                if interactiveChatPosts.count > maximumNumberOfInteractiveChatMessages - 1 {
                    interactiveChatPosts.removeLast()
                }
                interactiveChatPosts.prepend(post)
            }
        }
        if interactiveChatAlertsPaused {
            // The red line is one post.
            pausedInteractiveChatAlertsPostsCount = max(pausedInteractiveChatAlertsPosts.count - 1, 0)
        } else {
            while let post = newInteractiveChatAlertsPosts.popFirst() {
                if interactiveChatAlertsPosts.count > maximumNumberOfInteractiveChatMessages - 1 {
                    interactiveChatAlertsPosts.removeLast()
                }
                interactiveChatAlertsPosts.prepend(post)
            }
        }
    }

    private func printChatMessage(post: ChatPost) {
        // Delay 2 seconds to likely have emotes fetched.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            let message = HStack {
                WrappingHStack(
                    alignment: .leading,
                    horizontalSpacing: 0,
                    verticalSpacing: 0,
                    fitContentWidth: true
                ) {
                    Text(post.user!)
                        .lineLimit(1)
                        .padding([.trailing], 0)
                    if post.isRedemption() {
                        Text(" ")
                    } else {
                        Text(": ")
                    }
                    ForEach(post.segments) { segment in
                        if let text = segment.text {
                            Text(text)
                        }
                        if let url = segment.url {
                            CacheAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Image("AppIconNoBackground")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            }
                            .frame(height: 45)
                            Text(" ")
                        }
                    }
                }
                .foregroundColor(.black)
                .font(.system(size: CGFloat(30), weight: .bold, design: .default))
                Spacer()
            }
            .frame(width: 384)
            let renderer = ImageRenderer(content: message)
            guard let image = renderer.uiImage else {
                return
            }
            guard let ciImage = CIImage(image: image) else {
                return
            }
            for catPrinter in self.catPrinters.values
                where self.getCatPrinterSettings(catPrinter: catPrinter)?.printChat == true
            {
                catPrinter.print(image: ciImage, feedPaperDelay: 3)
            }
        }
    }

    private func isTextToSpeechEnabledForMessage(post: ChatPost) -> Bool {
        guard database.chat.textToSpeechEnabled! else {
            return false
        }
        if database.chat.textToSpeechSubscribersOnly! {
            guard post.isSubscriber else {
                return false
            }
        }
        if post.bits != nil {
            return false
        }
        if isAlertMessage(post: post) && isTextToSpeechEnabledForAnyAlertWidget() {
            return false
        }
        return true
    }

    private func isAlertMessage(post: ChatPost) -> Bool {
        switch post.highlight?.kind {
        case .redemption:
            return true
        case .newFollower:
            return true
        default:
            return false
        }
    }

    private func isTextToSpeechEnabledForAnyAlertWidget() -> Bool {
        for alertEffect in enabledAlertsEffects {
            let settings = alertEffect.getSettings()
            if settings.twitch!.follows.isTextToSpeechEnabled() {
                return true
            }
            if settings.twitch!.subscriptions.isTextToSpeechEnabled() {
                return true
            }
            if settings.twitch!.raids!.isTextToSpeechEnabled() {
                return true
            }
            if settings.twitch!.cheers!.isTextToSpeechEnabled() {
                return true
            }
        }
        return false
    }

    private func setTextToSpeechStreamerMentions() {
        var streamerMentions: [String] = []
        if isTwitchChatConfigured() {
            streamerMentions.append("@\(stream.twitchChannelName)")
        }
        if isKickPusherConfigured() {
            streamerMentions.append("@\(stream.kickChannelName!)")
        }
        if isAfreecaTvChatConfigured() {
            streamerMentions.append("@\(stream.afreecaTvChannelName!)")
        }
        chatTextToSpeech.setStreamerMentions(streamerMentions: streamerMentions)
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
                    height: widget.height,
                    settingName: realWidget.name
                )
            }
        }
    }

    private func handleFindFaceChanged(value: Bool) {
        DispatchQueue.main.async {
            self.findFace = value
            self.findFaceTimer?.invalidate()
            self.findFaceTimer = Timer
                .scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
                    self.findFace = false
                }
        }
    }

    private func unregisterGlobalVideoEffects() {
        media.unregisterEffect(faceEffect)
        media.unregisterEffect(movieEffect)
        media.unregisterEffect(grayScaleEffect)
        media.unregisterEffect(sepiaEffect)
        media.unregisterEffect(tripleEffect)
        media.unregisterEffect(pixellateEffect)
        media.unregisterEffect(pollEffect)
        faceEffect = FaceEffect(fps: Float(stream.fps), onFindFaceChanged: handleFindFaceChanged(value:))
        updateFaceFilterSettings()
        movieEffect = MovieEffect()
        grayScaleEffect = GrayScaleEffect()
        sepiaEffect = SepiaEffect()
        tripleEffect = TripleEffect()
        pixellateEffect = PixellateEffect()
        pollEffect = PollEffect()
    }

    private func isGlobalButtonOn(type: SettingsButtonType) -> Bool {
        return database.globalButtons?.first(where: { button in
            button.type == type
        })?.isOn ?? false
    }

    private func isFaceEnabled() -> Bool {
        let settings = database.debug.beautyFilterSettings!
        return database.debug.beautyFilter! || settings.showBlur || settings.showBlurBackground! || settings
            .showMoblin || settings
            .showBeauty!
    }

    private func registerGlobalVideoEffects() -> [VideoEffect] {
        var effects: [VideoEffect] = []
        if isFaceEnabled() {
            effects.append(faceEffect)
        }
        if isGlobalButtonOn(type: .movie) {
            effects.append(movieEffect)
        }
        if isGlobalButtonOn(type: .fourThree) {
            effects.append(fourThreeEffect)
        }
        if isGlobalButtonOn(type: .grayScale) {
            effects.append(grayScaleEffect)
        }
        if isGlobalButtonOn(type: .sepia) {
            effects.append(sepiaEffect)
        }
        if isGlobalButtonOn(type: .triple) {
            effects.append(tripleEffect)
        }
        if isGlobalButtonOn(type: .pixellate) {
            effects.append(pixellateEffect)
        }
        return effects
    }

    private func registerGlobalVideoEffectsOnTop() -> [VideoEffect] {
        var effects: [VideoEffect] = []
        if isGlobalButtonOn(type: .poll) {
            effects.append(pollEffect)
        }
        return effects
    }

    func getTextEffect(id: UUID) -> TextEffect? {
        for (textEffectId, textEffect) in textEffects where id == textEffectId {
            return textEffect
        }
        return nil
    }

    func getVideoSourceEffect(id: UUID) -> VideoSourceEffect? {
        for (videoSourceEffectId, videoSourceEffect) in videoSourceEffects where id == videoSourceEffectId {
            return videoSourceEffect
        }
        return nil
    }

    func getVideoSourceSettings(id: UUID) -> SettingsWidget? {
        return database.widgets.first(where: { $0.id == id })
    }

    private func fixAlert(alert: SettingsWidgetAlertsAlert) {
        if getAllAlertImages().first(where: { $0.id == alert.imageId }) == nil {
            alert.imageId = database.alertsMediaGallery!.bundledImages[0].id
        }
        if getAllAlertSounds().first(where: { $0.id == alert.soundId }) == nil {
            alert.soundId = database.alertsMediaGallery!.bundledSounds[0].id
        }
    }

    func fixAlertMedias() {
        for widget in database.widgets {
            fixAlert(alert: widget.alerts!.twitch!.follows)
            fixAlert(alert: widget.alerts!.twitch!.subscriptions)
            for command in widget.alerts!.chatBot!.commands {
                fixAlert(alert: command.alert)
            }
        }
        updateAlertsSettings()
    }

    private func removeUnusedAlertMedias() {
        for mediaId in alertMediaStorage.ids() {
            var found = false
            if database.alertsMediaGallery!.customImages.contains(where: { $0.id == mediaId }) {
                found = true
            }
            if database.alertsMediaGallery!.customSounds.contains(where: { $0.id == mediaId }) {
                found = true
            }
            if !found {
                alertMediaStorage.remove(id: mediaId)
            }
        }
    }

    func getAllAlertImages() -> [SettingsAlertsMediaGalleryItem] {
        return database.alertsMediaGallery!.bundledImages + database.alertsMediaGallery!.customImages
    }

    func getAllAlertSounds() -> [SettingsAlertsMediaGalleryItem] {
        return database.alertsMediaGallery!.bundledSounds + database.alertsMediaGallery!.customSounds
    }

    func getAlertsEffect(id: UUID) -> AlertsEffect? {
        for (alertsEffectId, alertsEffect) in alertsEffects where id == alertsEffectId {
            return alertsEffect
        }
        return nil
    }

    private func updateTextEffects(now: Date, timestamp: ContinuousClock.Instant) {
        guard !textEffects.isEmpty else {
            return
        }
        let location = locationManager.getLatestKnownLocation()
        if let latestKnownLocation {
            let distance = location?.distance(from: latestKnownLocation) ?? 0
            if distance > latestKnownLocation.horizontalAccuracy {
                self.distance += distance
                self.latestKnownLocation = location
            }
        } else {
            latestKnownLocation = location
        }
        let weather = weatherManager.getLatestWeather()
        let placemark = geographyManager.getLatestPlacemark()
        var teslaBatteryLevel = "-"
        if teslaChargeState.optionalBatteryLevel != nil {
            teslaBatteryLevel = "\(teslaChargeState.batteryLevel) %"
        }
        let stats = TextEffectStats(
            timestamp: timestamp,
            bitrateAndTotal: speedAndTotal,
            date: now,
            debugOverlayLines: debugLines,
            speed: format(speed: max(location?.speed ?? 0, 0)),
            altitude: format(altitude: location?.altitude ?? 0),
            distance: getDistance(),
            conditions: weather?.currentWeather.symbolName,
            temperature: weather?.currentWeather.temperature,
            country: placemark?.country ?? "",
            countryFlag: emojiFlag(country: placemark?.isoCountryCode ?? ""),
            city: placemark?.locality,
            muted: isMuteOn,
            heartRate: workoutHeartRate,
            activeEnergyBurned: workoutActiveEnergyBurned,
            workoutDistance: workoutDistance,
            power: workoutPower,
            stepCount: workoutStepCount,
            teslaBatteryLevel: teslaBatteryLevel
        )
        for textEffect in textEffects.values {
            textEffect.updateStats(stats: stats)
        }
    }

    private func forceUpdateTextEffects() {
        for textEffect in textEffects.values {
            textEffect.forceImageUpdate()
        }
    }

    private func updateMapEffects() {
        guard !mapEffects.isEmpty else {
            return
        }
        guard var location = locationManager.getLatestKnownLocation() else {
            return
        }
        if isLocationInPrivacyRegion(location: location) {
            location = .init()
        }
        for mapEffect in mapEffects.values {
            mapEffect.updateLocation(location: location)
        }
    }

    func getDistance() -> String {
        return format(distance: distance)
    }

    func togglePoll() {
        pollEnabled = !pollEnabled
        pollVotes = [0, 0, 0]
        pollEffect = PollEffect()
    }

    private func handlePollVote(vote: String?) {
        switch vote {
        case "1":
            pollVotes[0] += 1
        case "2":
            pollVotes[1] += 1
        case "3":
            pollVotes[2] += 1
        default:
            break
        }
    }

    private func updatePoll() {
        guard pollEnabled else {
            return
        }
        let totalVotes = Double(pollVotes.reduce(0, +))
        guard totalVotes > 0 else {
            return
        }
        var votes: [String] = []
        for index in 0 ..< pollVotes.count {
            let percentage = Int((Double(100 * pollVotes[index]) / totalVotes).rounded())
            votes.append("\(index + 1): \(percentage)%")
        }
        pollEffect.updateText(text: votes.joined(separator: ", "))
    }

    func removeDeadWidgetsFromScenes() {
        for scene in database.scenes {
            scene.widgets = scene.widgets.filter { findWidget(id: $0.widgetId) != nil }
        }
    }

    func resetSelectedScene(changeScene: Bool = true) {
        if !enabledScenes.isEmpty, changeScene {
            setSceneId(id: enabledScenes[0].id)
            sceneIndex = 0
        }
        unregisterGlobalVideoEffects()
        for textEffect in textEffects.values {
            media.unregisterEffect(textEffect)
        }
        textEffects.removeAll()
        for widget in database.widgets where widget.type == .text {
            textEffects[widget.id] = TextEffect(
                format: widget.text.formatString,
                backgroundColor: widget.text.backgroundColor!,
                foregroundColor: widget.text.foregroundColor!,
                fontSize: CGFloat(widget.text.fontSize!),
                fontDesign: widget.text.fontDesign!.toSystem(),
                fontWeight: widget.text.fontWeight!.toSystem(),
                settingName: widget.name,
                delay: widget.text.delay!,
                timersEndTime: widget.text.timers!.map {
                    .now.advanced(by: .seconds(utcTimeDeltaFromNow(to: $0.endTime)))
                },
                checkboxes: widget.text.checkboxes!.map { $0.checked },
                ratings: widget.text.ratings!.map { $0.rating }
            )
        }
        for browserEffect in browserEffects.values {
            media.unregisterEffect(browserEffect)
            browserEffect.stop()
        }
        browserEffects.removeAll()
        for widget in database.widgets where widget.type == .browser {
            let videoSize = media.getVideoSize()
            guard let url = URL(string: widget.browser.url) else {
                continue
            }
            browserEffects[widget.id] = BrowserEffect(
                url: url,
                styleSheet: widget.browser.styleSheet!,
                widget: widget.browser,
                videoSize: videoSize,
                settingName: widget.name
            )
        }
        for mapEffect in mapEffects.values {
            media.unregisterEffect(mapEffect)
        }
        mapEffects.removeAll()
        for widget in database.widgets where widget.type == .map {
            mapEffects[widget.id] = MapEffect(widget: widget.map!)
        }
        for qrCodeEffect in qrCodeEffects.values {
            media.unregisterEffect(qrCodeEffect)
        }
        qrCodeEffects.removeAll()
        for widget in database.widgets where widget.type == .qrCode {
            qrCodeEffects[widget.id] = QrCodeEffect(widget: widget.qrCode!)
        }
        for videoSourceEffect in videoSourceEffects.values {
            media.unregisterEffect(videoSourceEffect)
        }
        videoSourceEffects.removeAll()
        for widget in database.widgets where widget.type == .videoSource {
            videoSourceEffects[widget.id] = VideoSourceEffect()
        }
        for padelScoreboardEffect in padelScoreboardEffects.values {
            media.unregisterEffect(padelScoreboardEffect)
        }
        padelScoreboardEffects.removeAll()
        for widget in database.widgets where widget.type == .scoreboard {
            padelScoreboardEffects[widget.id] = PadelScoreboardEffect()
        }
        for alertsEffect in alertsEffects.values {
            media.unregisterEffect(alertsEffect)
        }
        alertsEffects.removeAll()
        for widget in database.widgets where widget.type == .alerts {
            alertsEffects[widget.id] = AlertsEffect(
                settings: widget.alerts!.clone(),
                fps: stream.fps,
                delegate: self,
                mediaStorage: alertMediaStorage,
                bundledImages: database.alertsMediaGallery!.bundledImages,
                bundledSounds: database.alertsMediaGallery!.bundledSounds
            )
        }
        browsers = browserEffects.map { _, browser in
            Browser(browserEffect: browser)
        }
        drawOnStreamEffect.updateOverlay(
            videoSize: media.getVideoSize(),
            size: drawOnStreamSize,
            lines: drawOnStreamLines,
            mirror: isFrontCameraSelected && !database.mirrorFrontCameraOnStream!
        )
        for lutEffect in lutEffects.values {
            media.unregisterEffect(lutEffect)
        }
        lutEffects.removeAll()
        for lut in allLuts() {
            guard let image = loadLutImage(lut: lut) else {
                continue
            }
            let lutEffect = LutEffect()
            do {
                try lutEffect.setLut(image: image)
            } catch {
                continue
            }
            lutEffects[lut.id] = lutEffect
        }
        sceneUpdated(imageEffectChanged: true)
    }

    func store() {
        settings.store()
    }

    func networkInterfaceNamesUpdated() {
        media.setNetworkInterfaceNames(networkInterfaceNames: database.networkInterfaceNames!)
        bondingStatisticsFormatter.setNetworkInterfaceNames(database.networkInterfaceNames!)
    }

    @MainActor
    private func playAlert(alert: AlertsEffectAlert) {
        for alertsEffect in enabledAlertsEffects {
            alertsEffect.play(alert: alert)
        }
    }

    @MainActor
    func testAlert(alert: AlertsEffectAlert) {
        playAlert(alert: alert)
    }

    func updateAlertsSettings() {
        for widget in database.widgets where widget.type == .alerts {
            getAlertsEffect(id: widget.id)?.setSettings(settings: widget.alerts!.clone())
        }
    }

    func updateOrientationLock() {
        if stream.portrait! {
            AppDelegate.orientationLock = .portrait
            streamPreviewView.isPortrait = true
        } else if database.portrait! {
            AppDelegate.orientationLock = .portrait
            streamPreviewView.isPortrait = false
        } else {
            AppDelegate.orientationLock = .landscape
            streamPreviewView.isPortrait = false
        }
        if #available(iOS 17.0, *) {
            if stream.portrait! {
                cameraPreviewView.previewLayer.connection?.videoRotationAngle = 90
            } else {
                cameraPreviewView.previewLayer.connection?.videoRotationAngle = 0
            }
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func reloadBrowserWidgets() {
        for browser in browsers {
            browser.browserEffect.reload()
        }
    }

    func startRecording() {
        setIsRecording(value: true)
        resumeRecording()
        var subTitle: String?
        if recordingsStorage.isFull() {
            subTitle = String(localized: "Too many recordings. Deleting oldest recording.")
        }
        makeToast(title: String(localized: "Recording started"), subTitle: subTitle)
    }

    func stopRecording(showToast: Bool = true) {
        guard isRecording else {
            return
        }
        setIsRecording(value: false)
        if showToast {
            makeToast(title: String(localized: "Recording stopped"))
        }
        suspendRecording()
    }

    func resumeRecording() {
        currentRecording = recordingsStorage.createRecording(settings: stream.clone())
        let bitrate = Int(stream.recording!.videoBitrate)
        let keyFrameInterval = Int(stream.recording!.maxKeyFrameInterval)
        let audioBitrate = Int(stream.recording!.audioBitrate!)
        media.startRecording(
            url: currentRecording!.url(),
            videoCodec: stream.recording!.videoCodec,
            videoBitrate: bitrate != 0 ? bitrate : nil,
            keyFrameInterval: keyFrameInterval != 0 ? keyFrameInterval : nil,
            audioBitrate: audioBitrate != 0 ? audioBitrate : nil
        )
    }

    private func suspendRecording() {
        media.stopRecording()
        if let currentRecording {
            recordingsStorage.append(recording: currentRecording)
            recordingsStorage.store()
        }
        updateRecordingLength(now: Date())
        currentRecording = nil
    }

    func startWorkout(type: WatchProtocolWorkoutType) {
        guard WCSession.default.isWatchAppInstalled else {
            makeToast(title: String(localized: "Install Moblin on your Apple Watch"))
            return
        }
        setIsWorkout(type: type)
        authorizeHealthKit {
            DispatchQueue.main.async {
                self.sendWorkoutToWatch()
            }
        }
        makeToast(
            title: String(localized: "Starting workout"),
            subTitle: String(localized: "Open Moblin in your Apple Watch to start it")
        )
    }

    func stopWorkout(showToast: Bool = true) {
        setIsWorkout(type: nil)
        sendWorkoutToWatch()
        if showToast {
            makeToast(title: String(localized: "Ending workout"),
                      subTitle: String(localized: "Open Moblin in your Apple Watch to end it"))
        }
    }

    func startAds(seconds: Int) {
        TwitchApi(stream.twitchAccessToken!, urlSession)
            .startCommercial(broadcasterId: stream.twitchChannelId, length: seconds) { data in
                if let data {
                    self.makeToast(title: data.message)
                } else {
                    self.makeErrorToast(title: String(localized: "Failed to start commercial"))
                }
            }
    }

    func setGlobalButtonState(type: SettingsButtonType, isOn: Bool) {
        for button in database.globalButtons! where button.type == type {
            button.isOn = isOn
        }
        for pair in buttonPairs {
            if pair.first.button.type == type {
                pair.first.isOn = isOn
            }
            if let state = pair.second {
                if state.button.type == type {
                    state.isOn = isOn
                }
            }
        }
    }

    func getGlobalButton(type: SettingsButtonType) -> SettingsButton? {
        return database.globalButtons!.first(where: { $0.type == type })
    }

    private func toggleGlobalButton(type: SettingsButtonType) {
        for button in database.globalButtons! where button.type == type {
            button.isOn.toggle()
        }
        for pair in buttonPairs {
            if pair.first.button.type == type {
                pair.first.isOn.toggle()
            }
            if let state = pair.second {
                if state.button.type == type {
                    state.isOn.toggle()
                }
            }
        }
    }

    private func toggleStream() {
        if isLive {
            stopStream()
        } else {
            startStream()
        }
    }

    func setIsLive(value: Bool) {
        isLive = value
        if !isRemoteControlAssistantConnected() {
            sendIsLiveToWatch(isLive: isLive)
        }
        remoteControlStreamer?.stateChanged(state: RemoteControlState(streaming: isLive))
    }

    func setIsRecording(value: Bool) {
        isRecording = value
        setGlobalButtonState(type: .record, isOn: value)
        updateButtonStates()
        if !isRemoteControlAssistantConnected() {
            sendIsRecordingToWatch(isRecording: isRecording)
        }
        remoteControlStreamer?.stateChanged(state: RemoteControlState(recording: isRecording))
    }

    func setIsWorkout(type: WatchProtocolWorkoutType?) {
        workoutType = type
        setGlobalButtonState(type: .workout, isOn: type != nil)
        updateButtonStates()
    }

    private func setIsMuted(value: Bool) {
        setMuteOn(value: value)
    }

    func startStream(delayed: Bool = false) {
        logger.info("stream: Start")
        guard !streaming else {
            return
        }
        if delayed, !isLive {
            return
        }
        guard stream.url != defaultStreamUrl else {
            makeErrorToast(
                title: String(
                    localized: "Please enter your stream URL in stream settings before going live."
                ),
                subTitle: String(
                    localized: "Configure it in Settings → Streams → \(stream.name) → URL."
                )
            )
            return
        }
        streamLog.removeAll()
        setIsLive(value: true)
        streaming = true
        streamTotalBytes = 0
        streamTotalChatMessages = 0
        updateScreenAutoOff()
        startNetStream()
        if stream.recording!.autoStartRecording! {
            startRecording()
        }
        if stream.obsAutoStartStream! {
            obsStartStream()
        }
        if stream.obsAutoStartRecording! {
            obsStartRecording()
        }
        streamingHistoryStream = StreamingHistoryStream(settings: stream.clone())
        streamingHistoryStream!.updateHighestThermalState(thermalState: ThermalState(from: thermalState))
        streamingHistoryStream!.updateLowestBatteryLevel(level: batteryLevel)
    }

    func stopStream(stopObsStreamIfEnabled: Bool = true, stopObsRecordingIfEnabled: Bool = true) {
        setIsLive(value: false)
        updateScreenAutoOff()
        realtimeIrl?.stop()
        if !streaming {
            return
        }
        logger.info("stream: Stop")
        streamTotalBytes += UInt64(media.streamTotal())
        streaming = false
        if stream.recording!.autoStopRecording! {
            stopRecording()
        }
        if stopObsStreamIfEnabled, stream.obsAutoStopStream! {
            obsStopStream()
        }
        if stopObsRecordingIfEnabled, stream.obsAutoStopRecording! {
            obsStopRecording()
        }
        stopNetStream()
        streamState = .disconnected
        if let streamingHistoryStream {
            if let logId = streamingHistoryStream.logId {
                logsStorage.write(id: logId, data: streamLog.joined(separator: "\n").utf8Data)
            }
            streamingHistoryStream.stopTime = Date()
            streamingHistoryStream.totalBytes = streamTotalBytes
            streamingHistoryStream.numberOfChatMessages = streamTotalChatMessages
            streamingHistory.append(stream: streamingHistoryStream)
            streamingHistory.store()
        }
    }

    func updateScreenAutoOff() {
        UIApplication.shared.isIdleTimerDisabled = (showingRemoteControl || isLive)
    }

    private func startNetStream(reconnect _: Bool = false) {
        streamState = .connecting
        latestLowBitrateTime = .now
        switch stream.getProtocol() {
        case .rtmp:
            media.rtmpStartStream(url: stream.url,
                                  targetBitrate: stream.bitrate,
                                  adaptiveBitrate: stream.rtmp!.adaptiveBitrateEnabled)
            updateAdaptiveBitrateRtmpIfEnabled()
        case .srt:
            payloadSize = stream.srt.mpegtsPacketsPerPacket * MpegTsPacket.size
            media.srtStartStream(
                isSrtla: stream.isSrtla(),
                url: stream.url,
                reconnectTime: 5,
                targetBitrate: stream.bitrate,
                adaptiveBitrateAlgorithm: stream.srt.adaptiveBitrateEnabled! ? stream.srt.adaptiveBitrate!
                    .algorithm : nil,
                latency: stream.srt.latency,
                overheadBandwidth: database.debug.srtOverheadBandwidth!,
                maximumBandwidthFollowInput: database.debug.maximumBandwidthFollowInput!,
                mpegtsPacketsPerPacket: stream.srt.mpegtsPacketsPerPacket,
                networkInterfaceNames: database.networkInterfaceNames!,
                connectionPriorities: stream.srt.connectionPriorities!
            )
            updateAdaptiveBitrateSrt(stream: stream)
        case .irltk:
            payloadSize = stream.srt.mpegtsPacketsPerPacket * MpegTsPacket.size
            media.irlToolkitStartStream(
                url: stream.url,
                reconnectTime: 5,
                targetBitrate: stream.bitrate,
                adaptiveBitrateAlgorithm: stream.srt.adaptiveBitrateEnabled! ? stream.srt.adaptiveBitrate!
                    .algorithm : nil,
                latency: stream.srt.latency,
                overheadBandwidth: database.debug.srtOverheadBandwidth!,
                maximumBandwidthFollowInput: database.debug.maximumBandwidthFollowInput!,
                mpegtsPacketsPerPacket: stream.srt.mpegtsPacketsPerPacket,
                networkInterfaceNames: database.networkInterfaceNames!,
                connectionPriorities: stream.srt.connectionPriorities!
            )
            updateAdaptiveBitrateSrt(stream: stream)
        case .rist:
            media.ristStartStream(url: stream.url,
                                  bonding: stream.rist!.bonding,
                                  targetBitrate: stream.bitrate,
                                  adaptiveBitrate: stream.rist!.adaptiveBitrateEnabled)
            updateAdaptiveBitrateRistIfEnabled()
        case .irl:
            media.irlStartStream()
        }
        updateSpeed(now: .now)
    }

    private func stopNetStream(reconnect: Bool = false) {
        reconnectTimer?.invalidate()
        media.rtmpStopStream()
        media.srtStopStream()
        media.ristStopStream()
        media.irlToolkitStopStream()
        streamStartTime = nil
        updateUptime(now: .now)
        updateSpeed(now: .now)
        updateAudioLevel()
        bondingStatistics = noValue
        if !reconnect {
            makeStreamEndedToast()
        }
    }

    func setCurrentStream(stream: SettingsStream) {
        stream.enabled = true
        for ostream in database.streams where ostream.id != stream.id {
            ostream.enabled = false
        }
        currentStreamId = stream.id
        updateOrientationLock()
    }

    func setCurrentStream(streamId: UUID) -> Bool {
        guard let stream = findStream(id: streamId) else {
            return false
        }
        setCurrentStream(stream: stream)
        return true
    }

    private func findStream(id: UUID) -> SettingsStream? {
        return database.streams.first { stream in
            stream.id == id
        }
    }

    func reloadStream(continueRecording: Bool = false) {
        cameraPosition = nil
        if !continueRecording {
            stopRecording()
        }
        stopStream()
        setNetStream()
        setStreamResolution()
        setStreamFPS()
        setColorSpace()
        setStreamCodec()
        setStreamAdaptiveResolution()
        setStreamKeyFrameInterval()
        setStreamBitrate(stream: stream)
        setAudioStreamBitrate(stream: stream)
        setAudioStreamFormat(format: .aac)
        setAudioChannelsMap(channelsMap: [
            0: database.audio!.audioOutputToInputChannelsMap!.channel1,
            1: database.audio!.audioOutputToInputChannelsMap!.channel2,
        ])
        reloadConnections()
        resetChat()
        reloadLocation()
        reloadRtmpStreams()
    }

    func reloadChats() {
        reloadTwitchChat()
        reloadKickPusher()
        reloadYouTubeLiveChat()
        reloadAfreecaTvChat()
        reloadOpenStreamingPlatformChat()
    }

    func reloadConnections() {
        reloadChats()
        reloadTwitchPubSub()
        reloadTwitchEventSub()
        reloadObsWebSocket()
        reloadRemoteControlStreamer()
        reloadRemoteControlAssistant()
        reloadRemoteControlRelay()
        reloadKickViewers()
    }

    func createUrlSession() {
        urlSession = URLSession.create(httpProxy: httpProxy())
    }

    func storeAndReloadStreamIfEnabled(stream: SettingsStream) {
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
        streamPreviewView.attachStream(media.getNetStream())
        setLowFpsImage()
    }

    private func showPreset(preset: SettingsZoomPreset) -> Bool {
        let x = preset.x!
        return x >= cameraZoomXMinimum && x <= cameraZoomXMaximum
    }

    func backZoomPresets() -> [SettingsZoomPreset] {
        return database.zoom.back.filter { showPreset(preset: $0) }
    }

    func frontZoomPresets() -> [SettingsZoomPreset] {
        return database.zoom.front.filter { showPreset(preset: $0) }
    }

    private func setStreamResolution() {
        switch stream.resolution {
        case .r3840x2160:
            media.setVideoSize(
                capture: .init(width: 3840, height: 2160),
                output: .init(width: 3840, height: 2160)
            )
        case .r2560x1440:
            // Use 4K camera and downscale to 1440p.
            media.setVideoSize(
                capture: .init(width: 3840, height: 2160),
                output: .init(width: 2560, height: 1440)
            )
        case .r1920x1080:
            media.setVideoSize(
                capture: .init(width: 1920, height: 1080),
                output: .init(width: 1920, height: 1080)
            )
        case .r1280x720:
            media.setVideoSize(
                capture: .init(width: 1280, height: 720),
                output: .init(width: 1280, height: 720)
            )
        case .r854x480:
            media.setVideoSize(
                capture: .init(width: 1280, height: 720),
                output: .init(width: 854, height: 480)
            )
        case .r640x360:
            media.setVideoSize(
                capture: .init(width: 1280, height: 720),
                output: .init(width: 640, height: 360)
            )
        case .r426x240:
            media.setVideoSize(
                capture: .init(width: 1280, height: 720),
                output: .init(width: 426, height: 240)
            )
        }
    }

    func setStreamFPS() {
        media.setStreamFPS(fps: stream.fps)
    }

    func setColorSpace() {
        var colorSpace: AVCaptureColorSpace
        switch database.color!.space {
        case .srgb:
            colorSpace = .sRGB
        case .p3D65:
            colorSpace = .P3_D65
        case .appleLog:
            if #available(iOS 17.0, *) {
                colorSpace = .appleLog
            } else {
                colorSpace = .sRGB
            }
        }
        media.setColorSpace(colorSpace: colorSpace, onComplete: {
            DispatchQueue.main.async {
                if let x = self.setCameraZoomX(x: self.zoomX) {
                    self.setZoomX(x: x)
                }
                self.lutEnabledUpdated()
            }
        })
    }

    func setStreamBitrate(stream: SettingsStream) {
        media.setVideoStreamBitrate(bitrate: stream.bitrate)
    }

    private func getBitratePresetByBitrate(bitrate: UInt32) -> SettingsBitratePreset? {
        return database.bitratePresets.first(where: { preset in
            preset.bitrate == bitrate
        })
    }

    func setBitrate(bitrate: UInt32) {
        stream.bitrate = bitrate
        guard let preset = getBitratePresetByBitrate(bitrate: bitrate) else {
            return
        }
        remoteControlStreamer?.stateChanged(state: RemoteControlState(bitrate: preset.id))
    }

    func setDebugLogging(on: Bool) {
        logger.debugEnabled = on
        if on {
            database.debug.logLevel = .debug
        } else {
            database.debug.logLevel = .error
        }
        remoteControlStreamer?.stateChanged(state: RemoteControlState(debugLogging: on))
    }

    func setAudioStreamBitrate(stream: SettingsStream) {
        media.setAudioStreamBitrate(bitrate: stream.audioBitrate!)
    }

    func setAudioStreamFormat(format: AudioCodecOutputSettings.Format) {
        media.setAudioStreamFormat(format: format)
    }

    func setAudioChannelsMap(channelsMap: [Int: Int]) {
        media.setAudioChannelsMap(channelsMap: channelsMap)
    }

    private func setStreamCodec() {
        switch stream.codec {
        case .h264avc:
            media.setVideoProfile(profile: kVTProfileLevel_H264_Main_AutoLevel)
        case .h265hevc:
            media.setVideoProfile(profile: kVTProfileLevel_HEVC_Main_AutoLevel)
        }
        media.setAllowFrameReordering(value: stream.bFrames!)
    }

    private func setStreamAdaptiveResolution() {
        media.setStreamAdaptiveResolution(value: stream.adaptiveEncoderResolution!)
    }

    private func setStreamKeyFrameInterval() {
        media.setStreamKeyFrameInterval(seconds: stream.maxKeyFrameInterval!)
    }

    func isStreamConfigured() -> Bool {
        return stream != fallbackStream
    }

    func isEventsConfigured() -> Bool {
        return isTwitchEventSubConfigured()
    }

    func isTwitchEventSubConfigured() -> Bool {
        return isTwitchAccessTokenConfigured()
    }

    func isEventsConnected() -> Bool {
        return isTwitchEventsConnected()
    }

    func isEventsRemoteControl() -> Bool {
        return twitchEventSub?.isRemoteControl() ?? false
    }

    func isTwitchEventsConnected() -> Bool {
        return twitchEventSub?.isConnected() ?? false
    }

    func isChatConfigured() -> Bool {
        return isTwitchChatConfigured() || isKickPusherConfigured() ||
            isYouTubeLiveChatConfigured() || isAfreecaTvChatConfigured() ||
            isOpenStreamingPlatformChatConfigured()
    }

    func isViewersConfigured() -> Bool {
        return isTwitchViewersConfigured() || isKickViewersConfigured()
    }

    func isTwitchViewersConfigured() -> Bool {
        return stream.twitchChannelId != ""
    }

    func isTwitchChatConfigured() -> Bool {
        return database.chat.enabled! && stream.twitchChannelName != ""
    }

    func isTwitchAccessTokenConfigured() -> Bool {
        return stream.twitchAccessToken != ""
    }

    func isTwitchChatConnected() -> Bool {
        return twitchChat?.isConnected() ?? false
    }

    func hasTwitchChatEmotes() -> Bool {
        return twitchChat?.hasEmotes() ?? false
    }

    func isTwitchPubSubConnected() -> Bool {
        return twitchPubSub?.isConnected() ?? false
    }

    func isKickPusherConfigured() -> Bool {
        return database.chat.enabled! && (stream.kickChatroomId != "" || stream.kickChannelName != "")
    }

    func isKickPusherConnected() -> Bool {
        return kickPusher?.isConnected() ?? false
    }

    func hasKickPusherEmotes() -> Bool {
        return kickPusher?.hasEmotes() ?? false
    }

    func isKickViewersConfigured() -> Bool {
        return stream.kickChannelName != ""
    }

    func isYouTubeLiveChatConfigured() -> Bool {
        return database.chat.enabled! && stream.youTubeVideoId! != ""
    }

    func isYouTubeLiveChatConnected() -> Bool {
        return youTubeLiveChat?.isConnected() ?? false
    }

    func hasYouTubeLiveChatEmotes() -> Bool {
        return youTubeLiveChat?.hasEmotes() ?? false
    }

    func isAfreecaTvChatConfigured() -> Bool {
        return database.chat.enabled! && stream.afreecaTvChannelName! != "" && stream.afreecaTvStreamId! != ""
    }

    func isAfreecaTvChatConnected() -> Bool {
        return afreecaTvChat?.isConnected() ?? false
    }

    func hasAfreecaTvChatEmotes() -> Bool {
        return afreecaTvChat?.hasEmotes() ?? false
    }

    func isOpenStreamingPlatformChatConfigured() -> Bool {
        return database.chat.enabled! && stream.openStreamingPlatformUrl! != "" && stream
            .openStreamingPlatformChannelId! != ""
    }

    func isOpenStreamingPlatformChatConnected() -> Bool {
        return openStreamingPlatformChat?.isConnected() ?? false
    }

    func hasOpenStreamingPlatformChatEmotes() -> Bool {
        return openStreamingPlatformChat?.hasEmotes() ?? false
    }

    func isChatConnected() -> Bool {
        if isTwitchChatConfigured() && !isTwitchChatConnected() {
            return false
        }
        if isKickPusherConfigured() && !isKickPusherConnected() {
            return false
        }
        if isYouTubeLiveChatConfigured() && !isYouTubeLiveChatConnected() {
            return false
        }
        if isAfreecaTvChatConfigured() && !isAfreecaTvChatConnected() {
            return false
        }
        if isOpenStreamingPlatformChatConfigured() && !isOpenStreamingPlatformChatConnected() {
            return false
        }
        return true
    }

    func hasChatEmotes() -> Bool {
        return hasTwitchChatEmotes() || hasKickPusherEmotes() ||
            hasYouTubeLiveChatEmotes() || hasAfreecaTvChatEmotes() || hasOpenStreamingPlatformChatEmotes()
    }

    func isStreamConnected() -> Bool {
        return streamState == .connected
    }

    func isStreaming() -> Bool {
        return streaming
    }

    private func resetChat() {
        chatPostsRate = "0.0/min"
        chatPostsTotal = 0
        chatSpeedTicks = 0
        chatPosts = []
        newChatPosts = []
        numberOfChatPostsPerTick = 0
        chatPostsRatePerSecond = 0
        chatPostsRatePerMinute = 0
        numberOfChatPostsPerMinute = 0
        interactiveChatPosts = []
        pausedInteractiveChatPosts = []
        newInteractiveChatPosts = []
        interactiveChatAlertsPosts = []
        pausedInteractiveChatAlertsPosts = []
        newInteractiveChatAlertsPosts = []
        chatTextToSpeech.reset(running: true)
    }

    private func reloadTwitchChat() {
        twitchChat.stop()
        setTextToSpeechStreamerMentions()
        if isTwitchChatConfigured() {
            twitchChat.start(
                channelName: stream.twitchChannelName,
                channelId: stream.twitchChannelId,
                settings: stream.chat!,
                accessToken: stream.twitchAccessToken!,
                httpProxy: httpProxy(),
                urlSession: urlSession
            )
        }
    }

    private func httpProxy() -> HttpProxy? {
        return settings.database.debug.httpProxy!.toHttpProxy()
    }

    private func reloadTwitchPubSub() {
        twitchPubSub?.stop()
        if isTwitchViewersConfigured() {
            twitchPubSub = TwitchPubSub(channelId: stream.twitchChannelId)
            twitchPubSub!.start()
        }
    }

    func reloadTwitchEventSub() {
        twitchEventSub?.stop()
        twitchEventSub = nil
        if isTwitchEventSubConfigured() {
            twitchEventSub = TwitchEventSub(
                remoteControl: isRemoteControlStreamerConnected(),
                userId: stream.twitchChannelId,
                accessToken: stream.twitchAccessToken!,
                httpProxy: httpProxy(),
                urlSession: urlSession,
                delegate: self
            )
            twitchEventSub!.start()
            updateRemoteControlStreamerTwitch()
        }
    }

    func fetchTwitchRewards() {
        TwitchApi(stream.twitchAccessToken!, urlSession)
            .getChannelPointsCustomRewards(broadcasterId: stream.twitchChannelId) { rewards in
                guard let rewards else {
                    logger.info("Failed to get Twitch rewards")
                    return
                }
                logger.info("Twitch rewards: \(rewards)")
                self.stream.twitchRewards = rewards.data.map {
                    let reward = SettingsStreamTwitchReward()
                    reward.rewardId = $0.id
                    reward.title = $0.title
                    return reward
                }
            }
    }

    private func makeNotLoggedInToTwitchToast() {
        makeErrorToast(
            title: String(localized: "Not logged in to Twitch"),
            subTitle: String(localized: "Please login again")
        )
    }

    func getTwitchChannelInformation(
        stream: SettingsStream,
        onComplete: @escaping (TwitchApiChannelInformationData) -> Void
    ) {
        guard stream.twitchLoggedIn! else {
            makeNotLoggedInToTwitchToast()
            return
        }
        TwitchApi(stream.twitchAccessToken!, urlSession)
            .getChannelInformation(broadcasterId: stream.twitchChannelId) { channelInformation in
                guard let channelInformation else {
                    return
                }
                onComplete(channelInformation)
            }
    }

    func setTwitchStreamTitle(stream: SettingsStream, title: String) {
        guard stream.twitchLoggedIn! else {
            makeNotLoggedInToTwitchToast()
            return
        }
        TwitchApi(stream.twitchAccessToken!, urlSession)
            .modifyChannelInformation(broadcasterId: stream.twitchChannelId, category: nil,
                                      title: title)
        { ok in
            if !ok {
                self.makeErrorToast(title: "Failed to set stream title")
            }
        }
    }

    func sendChatMessage(message: String) {
        guard isTwitchAccessTokenConfigured() else {
            makeNotLoggedInToTwitchToast()
            return
        }
        TwitchApi(stream.twitchAccessToken!, urlSession)
            .sendChatMessage(broadcasterId: stream.twitchChannelId, message: message) { ok in
                if !ok {
                    self.makeErrorToast(title: "Failed to send chat message")
                }
            }
    }

    private func reloadKickViewers() {
        kickViewers?.stop()
        if isKickViewersConfigured() {
            kickViewers = KickViewers()
            kickViewers!.start(channelName: stream.kickChannelName!)
        }
    }

    private func reloadKickPusher() {
        kickPusher?.stop()
        kickPusher = nil
        setTextToSpeechStreamerMentions()
        if isKickPusherConfigured() {
            kickPusher = KickPusher(model: self,
                                    channelId: stream.kickChatroomId,
                                    channelName: stream.kickChannelName!,
                                    settings: stream.chat!)
            kickPusher!.start()
        }
    }

    private func reloadYouTubeLiveChat() {
        youTubeLiveChat?.stop()
        youTubeLiveChat = nil
        if isYouTubeLiveChatConfigured() {
            youTubeLiveChat = YouTubeLiveChat(
                model: self,
                videoId: stream.youTubeVideoId!,
                settings: stream.chat!
            )
            youTubeLiveChat!.start()
        }
    }

    private func reloadAfreecaTvChat() {
        afreecaTvChat?.stop()
        afreecaTvChat = nil
        setTextToSpeechStreamerMentions()
        if isAfreecaTvChatConfigured() {
            afreecaTvChat = AfreecaTvChat(
                model: self,
                channelName: stream.afreecaTvChannelName!,
                streamId: stream.afreecaTvStreamId!
            )
            afreecaTvChat!.start()
        }
    }

    private func reloadOpenStreamingPlatformChat() {
        openStreamingPlatformChat?.stop()
        openStreamingPlatformChat = nil
        if isOpenStreamingPlatformChatConfigured() {
            openStreamingPlatformChat = OpenStreamingPlatformChat(
                model: self,
                url: stream.openStreamingPlatformUrl!,
                channelId: stream.openStreamingPlatformChannelId!
            )
            openStreamingPlatformChat!.start()
        }
    }

    private func reloadObsWebSocket() {
        obsWebSocket?.stop()
        obsWebSocket = nil
        guard isObsRemoteControlConfigured() else {
            return
        }
        guard let url = URL(string: stream.obsWebSocketUrl!) else {
            return
        }
        obsWebSocket = ObsWebSocket(
            url: url,
            password: stream.obsWebSocketPassword!,
            delegate: self
        )
        obsWebSocket!.start()
    }

    func twitchChannelNameUpdated() {
        reloadTwitchEventSub()
        reloadTwitchChat()
        resetChat()
    }

    func twitchChannelIdUpdated() {
        reloadTwitchEventSub()
        reloadTwitchPubSub()
        reloadTwitchChat()
        resetChat()
    }

    func kickChannelNameUpdated() {
        reloadKickPusher()
        reloadKickViewers()
        resetChat()
    }

    func youTubeVideoIdUpdated() {
        reloadYouTubeLiveChat()
        resetChat()
    }

    func afreecaTvChannelNameUpdated() {
        reloadAfreecaTvChat()
        resetChat()
    }

    func afreecaTvStreamIdUpdated() {
        reloadAfreecaTvChat()
        resetChat()
    }

    func openStreamingPlatformUrlUpdated() {
        reloadOpenStreamingPlatformChat()
        resetChat()
    }

    func openStreamingPlatformRoomUpdated() {
        reloadOpenStreamingPlatformChat()
        resetChat()
    }

    func obsWebSocketEnabledUpdated() {
        reloadObsWebSocket()
    }

    func obsWebSocketUrlUpdated() {
        reloadObsWebSocket()
    }

    func obsWebSocketPasswordUpdated() {
        reloadObsWebSocket()
    }

    func bttvEmotesEnabledUpdated() {
        reloadChats()
    }

    func ffzEmotesEnabledUpdated() {
        reloadChats()
    }

    func seventvEmotesEnabledUpdated() {
        reloadChats()
    }

    func obsStartStream() {
        obsWebSocket?.startStream(onSuccess: {}, onError: { message in
            DispatchQueue.main.async {
                self.makeErrorToast(title: String(localized: "Failed to start OBS stream"),
                                    subTitle: message)
            }
        })
    }

    func obsStopStream() {
        obsWebSocket?.stopStream(onSuccess: {}, onError: { message in
            DispatchQueue.main.async {
                self.makeErrorToast(title: String(localized: "Failed to stop OBS stream"),
                                    subTitle: message)
            }
        })
    }

    func obsStartRecording() {
        obsWebSocket?.startRecord(onSuccess: {}, onError: { message in
            DispatchQueue.main.async {
                self.makeErrorToast(title: String(localized: "Failed to start OBS recording"),
                                    subTitle: message)
            }
        })
    }

    func obsStopRecording() {
        obsWebSocket?.stopRecord(onSuccess: {}, onError: { message in
            DispatchQueue.main.async {
                self.makeErrorToast(title: String(localized: "Failed to stop OBS recording"),
                                    subTitle: message)
            }
        })
    }

    func obsFixStream() {
        guard let obsWebSocket else {
            return
        }
        obsFixOngoing = true
        obsWebSocket.setInputSettings(inputName: stream.obsSourceName!,
                                      onSuccess: {
                                          self.obsFixOngoing = false
                                      }, onError: { message in
                                          self.obsFixOngoing = false
                                          DispatchQueue.main.async {
                                              self.makeErrorToast(
                                                  title: String(localized: "Failed to fix OBS input"),
                                                  subTitle: message
                                              )
                                          }
                                      })
    }

    func obsMuteAudio(inputName: String, muted: Bool) {
        guard let obsWebSocket else {
            return
        }
        obsWebSocket.setInputMute(inputName: inputName,
                                  muted: muted,
                                  onSuccess: {}, onError: { _ in
                                  })
    }

    func startObsAudioVolume() {
        obsAudioVolumeLatest = noValue
        obsWebSocket?.startAudioVolume()
    }

    func stopObsAudioVolume() {
        obsWebSocket?.stopAudioVolume()
    }

    private func updateObsAudioVolume() {
        if obsAudioVolumeLatest != obsAudioVolume {
            obsAudioVolume = obsAudioVolumeLatest
        }
    }

    func updateBrowserWidgetStatus() {
        browserWidgetsStatusChanged = false
        var messages: [String] = []
        for browser in browsers {
            let progress = browser.browserEffect.progress
            if browser.browserEffect.isLoaded {
                messages.append("\(browser.browserEffect.host): \(progress)%")
                if progress != 100 || browser.browserEffect.startLoadingTime + .seconds(5) > .now {
                    browserWidgetsStatusChanged = true
                }
            }
        }
        var message: String
        if messages.isEmpty {
            message = noValue
        } else {
            message = messages.joined(separator: ", ")
        }
        if browserWidgetsStatus != message {
            browserWidgetsStatus = message
        }
    }

    private func logStatus() {
        if logger.debugEnabled, isLive {
            logger.debug("Status: Bitrate: \(speedAndTotal), Uptime: \(uptime)")
        }
    }

    private func updateFailedVideoEffects() {
        let newFailedVideoEffect = media.getFailedVideoEffect()
        if newFailedVideoEffect != failedVideoEffect {
            if let newFailedVideoEffect {
                makeErrorToast(title: String(localized: "Failed to render \(newFailedVideoEffect)"))
            }
            failedVideoEffect = newFailedVideoEffect
        }
    }

    func setLowFpsImage() {
        var fps: Float = 0.0
        if isWatchReachable() {
            fps = 1.0
        }
        if isRemoteControlStreamerConnected(), isRemoteControlAssistantRequestingPreview {
            fps = database.remoteControl!.server.previewFps!
        }
        media.setLowFpsImage(fps: fps)
        lowFpsImageFps = max(UInt64(fps), 1)
    }

    func toggleLocalOverlays() {
        showLocalOverlays.toggle()
    }

    func toggleBrowser() {
        showBrowser.toggle()
    }

    func startObsSourceScreenshot() {
        obsScreenshot = nil
        obsSourceFetchScreenshot = true
        obsSourceScreenshotIsFetching = false
    }

    func stopObsSourceScreenshot() {
        obsSourceFetchScreenshot = false
    }

    private func updateObsSourceScreenshot() {
        guard obsSourceFetchScreenshot else {
            return
        }
        guard !obsSourceScreenshotIsFetching else {
            return
        }
        guard !obsCurrentScene.isEmpty else {
            return
        }
        obsWebSocket?.getSourceScreenshot(name: obsCurrentScene, onSuccess: { data in
            let screenshot = UIImage(data: data)?.cgImage
            self.obsScreenshot = screenshot
            self.obsSourceScreenshotIsFetching = false
        }, onError: { message in
            logger.debug("Failed to update screenshot with error \(message)")
            self.obsScreenshot = nil
            self.obsSourceScreenshotIsFetching = false
        })
    }

    func setObsAudioDelay(offset: Int) {
        guard !stream.obsSourceName!.isEmpty else {
            return
        }
        obsWebSocket?.setInputAudioSyncOffset(name: stream.obsSourceName!, offsetInMs: offset, onSuccess: {
            DispatchQueue.main.async {
                self.updateObsAudioDelay()
            }
        }, onError: { _ in
        })
    }

    func updateObsAudioDelay() {
        guard !stream.obsSourceName!.isEmpty else {
            return
        }
        obsWebSocket?.getInputAudioSyncOffset(name: stream.obsSourceName!, onSuccess: { offset in
            DispatchQueue.main.async {
                self.obsAudioDelay = offset
            }
        }, onError: { _ in
        })
    }

    private func handleChatBotMessage(message: ChatBotMessage) {
        guard message.segments.count > 1 else {
            return
        }
        var command = ""
        for segment in message.segments.suffix(from: 1) {
            if let text = segment.text {
                command += text
            }
        }
        command = command.trim()
        switch command {
        case "tts on":
            handleChatBotMessageTtsOn(message: message)
        case "tts off":
            handleChatBotMessageTtsOff(message: message)
        case "obs fix":
            handleChatBotMessageObsFix(message: message)
        case "map zoom out":
            handleChatBotMessageMapZoomOut(message: message)
        case "snapshot":
            handleChatBotMessageSnapshot(message: message)
        default:
            if command.starts(with: "alert ") {
                handleChatBotMessageAlert(message: message, command: command)
            } else if command.starts(with: "fax ") {
                handleChatBotMessageFax(message: message, command: command)
            } else if command.starts(with: "filter ") {
                handleChatBotMessageFilter(message: message, command: command)
            } else if command.starts(with: "say ") {
                handleChatBotMessageTtsSay(message: message, command: command)
            } else if command.starts(with: "tesla ") {
                handleChatBotMessageTesla(message: message, command: command)
            }
        }
    }

    private func handleChatBotMessageTtsOn(message: ChatBotMessage) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions!.tts,
            message: message
        ) {
            self.makeToast(
                title: String(localized: "Chat bot"),
                subTitle: String(localized: "Turning on chat text to speech")
            )
            self.database.chat.textToSpeechEnabled = true
        }
    }

    private func handleChatBotMessageTtsOff(message: ChatBotMessage) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions!.tts,
            message: message
        ) {
            self.makeToast(
                title: String(localized: "Chat bot"),
                subTitle: String(localized: "Turning off chat text to speech")
            )
            self.database.chat.textToSpeechEnabled = false
            self.chatTextToSpeech.reset(running: true)
        }
    }

    private func handleChatBotMessageTtsSay(message: ChatBotMessage, command: String) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions!.tts,
            message: message
        ) {
            let parts = command.split(separator: " ")
            guard parts.count > 2 else {
                return
            }
            let user = message.user ?? "Unknown"
            let message = parts.suffix(from: 2).joined(separator: " ")
            self.chatTextToSpeech.say(user: user, message: message, isRedemption: false)
        }
    }

    private func handleChatBotMessageObsFix(message: ChatBotMessage) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions!.fix,
            message: message
        ) {
            if self.obsWebSocket != nil {
                self.makeToast(
                    title: String(localized: "Chat bot"),
                    subTitle: String(localized: "Fixing OBS input")
                )
                self.obsFixStream()
            } else {
                self.makeErrorToast(
                    title: String(localized: "Chat bot"),
                    subTitle: String(
                        localized: "Cannot fix OBS input. OBS remote control is not configured."
                    )
                )
            }
        }
    }

    private func handleChatBotMessageMapZoomOut(message: ChatBotMessage) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions!.map,
            message: message
        ) {
            self.makeToast(
                title: String(localized: "Chat bot"),
                subTitle: String(localized: "Zooming out map")
            )
            for mapEffect in self.mapEffects.values {
                mapEffect.zoomOutTemporarily()
            }
        }
    }

    private func handleChatBotMessageSnapshot(message: ChatBotMessage) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions!.snapshot!,
            message: message
        ) {
            if let user = message.user {
                self.takeSnapshot(isChatBot: true, message: String(localized: "Snapshot taken by \(user)."))
            } else {
                self.takeSnapshot(isChatBot: true)
            }
        }
    }

    private func handleChatBotMessageAlert(message: ChatBotMessage, command: String) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions!.alert!,
            message: message
        ) {
            let parts = command.split(separator: " ")
            guard parts.count >= 2 else {
                return
            }
            DispatchQueue.main.async {
                self.playAlert(alert: .chatBotCommand(parts[1].trim(), message.user ?? "Unknown"))
            }
        }
    }

    private func handleChatBotMessageFax(message: ChatBotMessage, command: String) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions!.fax!,
            message: message
        ) {
            let parts = command.split(separator: " ")
            guard parts.count >= 2 else {
                return
            }
            self.faxReceiver.add(url: parts[1].trim())
        }
    }

    private func handleChatBotMessageFilter(message: ChatBotMessage, command: String) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions!.filter!,
            message: message
        ) {
            let parts = command.split(separator: " ")
            guard parts.count == 3 else {
                return
            }
            var type: SettingsButtonType
            switch parts[1].trim() {
            case "movie":
                type = .movie
            case "grayscale":
                type = .grayScale
            case "sepia":
                type = .sepia
            case "triple":
                type = .triple
            case "pixellate":
                type = .pixellate
            case "4:3":
                type = .fourThree
            default:
                return
            }
            self.setGlobalButtonState(type: type, isOn: parts[2].trim() == "on")
            self.sceneUpdated()
            self.updateButtonStates()
        }
    }

    private func handleChatBotMessageTesla(message: ChatBotMessage, command: String) {
        executeIfUserAllowedToUseChatBot(
            permissions: database.chat.botCommandPermissions!.tesla!,
            message: message
        ) {
            let parts = command.split(separator: " ")
            guard parts.count >= 2 else {
                return
            }
            switch parts[1].trim() {
            case "trunk":
                self.handleChatBotMessageTeslaTrunk(message: message, command: command, parts: parts)
            default:
                break
            }
        }
    }

    private func handleChatBotMessageTeslaTrunk(message _: ChatBotMessage, command _: String, parts: [Substring]) {
        guard parts.count == 3 else {
            return
        }
        switch parts[2].trim() {
        case "open":
            teslaVehicle?.openTrunk()
        case "close":
            teslaVehicle?.closeTrunk()
        default: break
        }
    }

    private func executeIfUserAllowedToUseChatBot(
        permissions: SettingsChatBotPermissionsCommand,
        message: ChatBotMessage,
        onCompleted: @escaping () -> Void
    ) {
        if message.isModerator, permissions.moderatorsEnabled {
            onCompleted()
            return
        }
        if message.isSubscriber, permissions.subscribersEnabled! {
            if message.platform == .twitch {
                if permissions.minimumSubscriberTier! > 1 {
                    if let userId = message.userId {
                        TwitchApi(stream.twitchAccessToken!, urlSession).getBroadcasterSubscriptions(
                            broadcasterId: stream.twitchChannelId,
                            userId: userId
                        ) { data in
                            DispatchQueue.main.async {
                                if let tier = data?.tierAsNumber(),
                                   tier >= permissions.minimumSubscriberTier!
                                {
                                    onCompleted()
                                    return
                                }
                                self.executeIfUserAllowedToUseChatBotAfterSubscribeCheck(
                                    permissions: permissions,
                                    message: message,
                                    onCompleted: onCompleted
                                )
                            }
                        }
                        return
                    }
                } else {
                    onCompleted()
                    return
                }
            } else {
                onCompleted()
                return
            }
        }
        executeIfUserAllowedToUseChatBotAfterSubscribeCheck(
            permissions: permissions,
            message: message,
            onCompleted: onCompleted
        )
    }

    private func executeIfUserAllowedToUseChatBotAfterSubscribeCheck(
        permissions: SettingsChatBotPermissionsCommand,
        message: ChatBotMessage,
        onCompleted: @escaping () -> Void
    ) {
        guard let user = message.user else {
            return
        }
        switch message.platform {
        case .twitch:
            if isTwitchUserAllowedToUseChatBot(permissions: permissions, user: user) {
                onCompleted()
            }
        case .kick:
            if isKickUserAllowedToUseChatBot(permissions: permissions, user: user) {
                onCompleted()
            }
        default:
            break
        }
    }

    private func isTwitchUserAllowedToUseChatBot(permissions: SettingsChatBotPermissionsCommand,
                                                 user: String) -> Bool
    {
        if permissions.othersEnabled {
            return true
        }
        return user.lowercased() == stream.twitchChannelName.lowercased()
    }

    private func isKickUserAllowedToUseChatBot(permissions: SettingsChatBotPermissionsCommand,
                                               user: String) -> Bool
    {
        if permissions.othersEnabled {
            return true
        }
        return user.lowercased() == stream.kickChannelName?.lowercased()
    }

    func appendChatMessage(
        platform: Platform,
        user: String?,
        userId: String?,
        userColor: RgbColor?,
        userBadges: [URL],
        segments: [ChatPostSegment],
        timestamp: String,
        timestampTime: ContinuousClock.Instant,
        isAction: Bool,
        isSubscriber: Bool,
        isModerator: Bool,
        bits: String?,
        highlight: ChatHighlight?
    ) {
        if database.chat.usernamesToIgnore!.contains(where: { user == $0.value }) {
            return
        }
        if database.chat.botEnabled!, segments.first?.text?.trim().lowercased() == "!moblin" {
            handleChatBotMessage(message: ChatBotMessage(
                platform: platform,
                user: user,
                isModerator: isModerator,
                isSubscriber: isSubscriber,
                userId: userId,
                segments: segments
            ))
        }
        if pollEnabled {
            handlePollVote(vote: segments.first?.text?.trim())
        }
        let post = ChatPost(
            id: chatPostId,
            user: user,
            userColor: userColor?.makeReadableOnDarkBackground(),
            userBadges: userBadges,
            segments: segments,
            timestamp: timestamp,
            timestampTime: timestampTime,
            isAction: isAction,
            isSubscriber: isSubscriber,
            bits: bits,
            highlight: highlight
        )
        chatPostId += 1
        newChatPosts.append(post)
        if interactiveChatPaused {
            if pausedInteractiveChatPosts.count < 2 * maximumNumberOfInteractiveChatMessages {
                pausedInteractiveChatPosts.append(post)
            }
        } else {
            newInteractiveChatPosts.append(post)
        }
        if highlight != nil {
            if interactiveChatAlertsPaused {
                if pausedInteractiveChatAlertsPosts.count < 2 * maximumNumberOfInteractiveChatMessages {
                    pausedInteractiveChatAlertsPosts.append(post)
                }
            } else {
                newInteractiveChatAlertsPosts.append(post)
            }
        }
    }

    func reloadChatMessages() {
        chatPosts = newPostIds(posts: chatPosts)
        interactiveChatPosts = newPostIds(posts: interactiveChatPosts)
        interactiveChatAlertsPosts = newPostIds(posts: interactiveChatAlertsPosts)
    }

    private func newPostIds(posts: Deque<ChatPost>) -> Deque<ChatPost> {
        var newPosts: Deque<ChatPost> = []
        for post in posts {
            var newPost = post
            newPost.id = chatPostId
            chatPostId += 1
            newPosts.append(newPost)
        }
        return newPosts
    }

    func toggleBlackScreen() {
        blackScreen.toggle()
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

    func getSceneName(id: UUID) -> String {
        return database.scenes.first { scene in
            scene.id == id
        }?.name ?? "Unknown"
    }

    private func sceneUpdatedOff() {
        unregisterGlobalVideoEffects()
        for imageEffect in imageEffects.values {
            media.unregisterEffect(imageEffect)
        }
        for textEffect in textEffects.values {
            media.unregisterEffect(textEffect)
        }
        for browserEffect in browserEffects.values {
            media.unregisterEffect(browserEffect)
            browserEffect.stop()
        }
        for mapEffect in mapEffects.values {
            media.unregisterEffect(mapEffect)
        }
        media.unregisterEffect(drawOnStreamEffect)
        media.unregisterEffect(lutEffect)
        for lutEffect in lutEffects.values {
            media.unregisterEffect(lutEffect)
        }
        for padelScoreboardEffect in padelScoreboardEffects.values {
            media.unregisterEffect(padelScoreboardEffect)
        }
    }

    private func attachSingleLayout(scene: SettingsScene) {
        isFrontCameraSelected = false
        deactivateAllMediaPlayers()
        switch scene.cameraPosition! {
        case .back:
            attachCamera(position: .back)
        case .front:
            attachCamera(position: .front)
            isFrontCameraSelected = true
        case .rtmp:
            attachReplaceCamera(cameraId: scene.rtmpCameraId!)
        case .srtla:
            attachReplaceCamera(cameraId: scene.srtlaCameraId!)
        case .mediaPlayer:
            mediaPlayers[scene.mediaPlayerCameraId!]?.activate()
            attachReplaceCamera(cameraId: scene.mediaPlayerCameraId!)
        case .external:
            attachExternalCamera(cameraId: scene.externalCameraId!)
        case .screenCapture:
            attachReplaceCamera(cameraId: screenCaptureCameraId)
        }
    }

    private func getVideoSourceBuiltinCameraDevice() -> AVCaptureDevice? {
        for widgetId in videoSourceEffects.keys {
            guard let widget = getVideoSourceSettings(id: widgetId) else {
                continue
            }
            switch widget.videoSource!.cameraPosition! {
            case .back:
                return AVCaptureDevice(uniqueID: widget.videoSource!.backCameraId!)
            case .front:
                return AVCaptureDevice(uniqueID: widget.videoSource!.frontCameraId!)
            case .external:
                return AVCaptureDevice(uniqueID: widget.videoSource!.externalCameraId!)
            default:
                break
            }
        }
        return nil
    }

    func listCameraPositions(excludeBuiltin: Bool = false) -> [(String, String)] {
        var cameras: [(String, String)] = []
        if !excludeBuiltin {
            cameras += backCameras.map {
                ($0.id, "Back \($0.name)")
            }
            cameras += frontCameras.map {
                ($0.id, "Front \($0.name)")
            }
            cameras += externalCameras.map {
                ($0.id, $0.name)
            }
        }
        cameras += rtmpCameras().map {
            ($0, $0)
        }
        cameras += srtlaCameras().map {
            ($0, $0)
        }
        cameras += playerCameras().map {
            ($0, $0)
        }
        cameras.append((screenCaptureCamera, screenCaptureCamera))
        return cameras
    }

    func isBackCamera(cameraId: String) -> Bool {
        return backCameras.contains(where: { $0.id == cameraId })
    }

    func isFrontCamera(cameraId: String) -> Bool {
        return frontCameras.contains(where: { $0.id == cameraId })
    }

    func isScreenCaptureCamera(cameraId: String) -> Bool {
        return cameraId == screenCaptureCamera
    }

    func getCameraPositionId(scene: SettingsScene?) -> String {
        return getCameraPositionId(settingsCameraId: scene?.toCameraId())
    }

    func getCameraPositionId(videoSourceWidget: SettingsWidgetVideoSource?) -> String {
        return getCameraPositionId(settingsCameraId: videoSourceWidget?.toCameraId())
    }

    func cameraIdToSettingsCameraId(cameraId: String) -> SettingsCameraId {
        if isSrtlaCamera(camera: cameraId) {
            return .srtla(id: getSrtlaStream(camera: cameraId)?.id ?? .init())
        } else if isRtmpCamera(camera: cameraId) {
            return .rtmp(id: getRtmpStream(camera: cameraId)?.id ?? .init())
        } else if isMediaPlayerCamera(camera: cameraId) {
            return .mediaPlayer(id: getMediaPlayer(camera: cameraId)?.id ?? .init())
        } else if isBackCamera(cameraId: cameraId) {
            return .back(id: cameraId)
        } else if isFrontCamera(cameraId: cameraId) {
            return .front(id: cameraId)
        } else if isScreenCaptureCamera(cameraId: cameraId) {
            return .screenCapture
        } else {
            return .external(id: cameraId, name: getExternalCameraName(cameraId: cameraId))
        }
    }

    private func getCameraPositionId(settingsCameraId: SettingsCameraId?) -> String {
        guard let settingsCameraId else {
            return ""
        }
        switch settingsCameraId {
        case let .rtmp(id):
            return getRtmpStream(id: id)?.camera() ?? ""
        case let .srtla(id):
            return getSrtlaStream(id: id)?.camera() ?? ""
        case let .mediaPlayer(id):
            return getMediaPlayer(id: id)?.camera() ?? ""
        case let .external(id, _):
            return id
        case let .back(id):
            return id
        case let .front(id):
            return id
        case .screenCapture:
            return screenCaptureCamera
        }
    }

    func getCameraPositionName(scene: SettingsScene?) -> String {
        return getCameraPositionName(settingsCameraId: scene?.toCameraId())
    }

    func getCameraPositionName(videoSourceWidget: SettingsWidgetVideoSource?) -> String {
        return getCameraPositionName(settingsCameraId: videoSourceWidget?.toCameraId())
    }

    private func getCameraPositionName(settingsCameraId: SettingsCameraId?) -> String {
        guard let settingsCameraId else {
            return unknownSad
        }
        switch settingsCameraId {
        case let .rtmp(id):
            return getRtmpStream(id: id)?.camera() ?? unknownSad
        case let .srtla(id):
            return getSrtlaStream(id: id)?.camera() ?? unknownSad
        case let .mediaPlayer(id):
            return getMediaPlayer(id: id)?.camera() ?? unknownSad
        case let .external(_, name):
            if !name.isEmpty {
                return name
            } else {
                return unknownSad
            }
        case let .back(id):
            if let camera = backCameras.first(where: { $0.id == id }) {
                return "Back \(camera.name)"
            } else {
                return unknownSad
            }
        case let .front(id):
            if let camera = frontCameras.first(where: { $0.id == id }) {
                return "Front \(camera.name)"
            } else {
                return unknownSad
            }
        case .screenCapture:
            return screenCaptureCamera
        }
    }

    func getExternalCameraName(cameraId: String) -> String {
        if let camera = externalCameras.first(where: { camera in
            camera.id == cameraId
        }) {
            return camera.name
        } else {
            return unknownSad
        }
    }

    private func rtmpCameras() -> [String] {
        return database.rtmpServer!.streams.map { stream in
            stream.camera()
        }
    }

    func getRtmpStream(id: UUID) -> SettingsRtmpServerStream? {
        return database.rtmpServer!.streams.first { stream in
            stream.id == id
        }
    }

    func getRtmpStream(camera: String) -> SettingsRtmpServerStream? {
        return database.rtmpServer!.streams.first { stream in
            camera == stream.camera()
        }
    }

    func getRtmpStream(streamKey: String) -> SettingsRtmpServerStream? {
        return database.rtmpServer!.streams.first { stream in
            stream.streamKey == streamKey
        }
    }

    private func stopAllRtmpStreams() {
        for stream in database.rtmpServer!.streams {
            stopRtmpServerStream(stream: stream, showToast: false)
        }
    }

    func isRtmpStreamConnected(streamKey: String) -> Bool {
        return rtmpServer?.isStreamConnected(streamKey: streamKey) ?? false
    }

    private func findSceneWidget(scene: SettingsScene, widgetId: UUID) -> SettingsSceneWidget? {
        return scene.widgets.first(where: { $0.widgetId == widgetId })
    }

    private func sceneUpdatedOn(scene: SettingsScene) {
        var effects: [VideoEffect] = []
        if database.color!.lutEnabled, database.color!.space == .appleLog {
            effects.append(lutEffect)
        }
        for lut in allLuts() {
            guard lut.enabled! else {
                continue
            }
            guard let lutEffect = lutEffects[lut.id] else {
                continue
            }
            effects.append(lutEffect)
        }
        effects += registerGlobalVideoEffects()
        var usedBrowserEffects: [BrowserEffect] = []
        var usedMapEffects: [MapEffect] = []
        var usedPadelScoreboardEffects: [PadelScoreboardEffect] = []
        var addedScenes: [SettingsScene] = []
        var needsSpeechToText = false
        enabledAlertsEffects = []
        addSceneEffects(
            scene,
            &effects,
            &usedBrowserEffects,
            &usedMapEffects,
            &usedPadelScoreboardEffects,
            &addedScenes,
            &enabledAlertsEffects,
            &needsSpeechToText
        )
        if !drawOnStreamLines.isEmpty {
            effects.append(drawOnStreamEffect)
        }
        effects += registerGlobalVideoEffectsOnTop()
        media.setPendingAfterAttachEffects(effects: effects)
        for browserEffect in browserEffects.values where !usedBrowserEffects.contains(browserEffect) {
            browserEffect.setSceneWidget(sceneWidget: nil, crops: [])
        }
        for mapEffect in mapEffects.values where !usedMapEffects.contains(mapEffect) {
            mapEffect.setSceneWidget(sceneWidget: nil)
        }
        for (id, padelScoreboardEffect) in padelScoreboardEffects
            where !usedPadelScoreboardEffects.contains(padelScoreboardEffect)
        {
            sendRemovePadelScoreboardToWatch(id: id)
        }
        media.setSpeechToText(enabled: needsSpeechToText)
        attachSingleLayout(scene: scene)
        // To do: Should update on first frame in draw effect instead.
        if !drawOnStreamLines.isEmpty {
            drawOnStreamEffect.updateOverlay(
                videoSize: media.getVideoSize(),
                size: drawOnStreamSize,
                lines: drawOnStreamLines,
                mirror: isFrontCameraSelected && !database.mirrorFrontCameraOnStream!
            )
        }
    }

    private func authorizeHealthKit(completion: @escaping () -> Void) {
        let typesToShare: Set = [
            HKQuantityType.workoutType(),
        ]
        var types: Set<HKSampleType> = [
            .quantityType(forIdentifier: .heartRate)!,
            .quantityType(forIdentifier: .distanceCycling)!,
            .quantityType(forIdentifier: .distanceWalkingRunning)!,
            .quantityType(forIdentifier: .stepCount)!,
            .quantityType(forIdentifier: .activeEnergyBurned)!,
            .quantityType(forIdentifier: .runningPower)!,
        ]
        if #available(iOS 17.0, *) {
            types.insert(.quantityType(forIdentifier: .cyclingPower)!)
        }
        healthStore.requestAuthorization(toShare: typesToShare, read: types) { _, _ in
            completion()
        }
    }

    private func addSceneEffects(
        _ scene: SettingsScene,
        _ effects: inout [VideoEffect],
        _ usedBrowserEffects: inout [BrowserEffect],
        _ usedMapEffects: inout [MapEffect],
        _ usedPadelScoreboardEffects: inout [PadelScoreboardEffect],
        _ addedScenes: inout [SettingsScene],
        _ enabledAlertsEffects: inout [AlertsEffect],
        _ needsSpeechToText: inout Bool
    ) {
        guard !addedScenes.contains(scene) else {
            return
        }
        addedScenes.append(scene)
        for sceneWidget in scene.widgets {
            guard let widget = findWidget(id: sceneWidget.widgetId) else {
                continue
            }
            guard widget.enabled! else {
                continue
            }
            switch widget.type {
            case .image:
                if let imageEffect = imageEffects[sceneWidget.id] {
                    effects.append(imageEffect)
                }
            case .text:
                if let textEffect = textEffects[widget.id] {
                    textEffect.setPosition(x: sceneWidget.x, y: sceneWidget.y)
                    effects.append(textEffect)
                    if widget.text.needsSubtitles! {
                        needsSpeechToText = true
                    }
                }
            case .videoEffect:
                break
            case .browser:
                if let browserEffect = browserEffects[widget.id],
                   !usedBrowserEffects.contains(browserEffect)
                {
                    browserEffect.setSceneWidget(
                        sceneWidget: sceneWidget,
                        crops: findWidgetCrops(scene: scene, sourceWidgetId: widget.id)
                    )
                    if !browserEffect.audioOnly {
                        effects.append(browserEffect)
                    }
                    usedBrowserEffects.append(browserEffect)
                }
            case .crop:
                if let browserEffect = browserEffects[widget.crop!.sourceWidgetId],
                   !usedBrowserEffects.contains(browserEffect)
                {
                    browserEffect.setSceneWidget(
                        sceneWidget: findSceneWidget(scene: scene, widgetId: widget.crop!.sourceWidgetId),
                        crops: findWidgetCrops(scene: scene, sourceWidgetId: widget.crop!.sourceWidgetId)
                    )
                    if !browserEffect.audioOnly {
                        effects.append(browserEffect)
                    }
                    usedBrowserEffects.append(browserEffect)
                }
            case .map:
                if let mapEffect = mapEffects[widget.id], !usedMapEffects.contains(mapEffect) {
                    mapEffect.setSceneWidget(sceneWidget: sceneWidget.clone())
                    effects.append(mapEffect)
                    usedMapEffects.append(mapEffect)
                }
            case .scene:
                if let sceneWidgetScene = database.scenes.first(where: { $0.id == widget.scene!.sceneId }) {
                    addSceneEffects(
                        sceneWidgetScene,
                        &effects,
                        &usedBrowserEffects,
                        &usedMapEffects,
                        &usedPadelScoreboardEffects,
                        &addedScenes,
                        &enabledAlertsEffects,
                        &needsSpeechToText
                    )
                }
            case .qrCode:
                if let qrCodeEffect = qrCodeEffects[widget.id] {
                    qrCodeEffect.setSceneWidget(sceneWidget: sceneWidget.clone())
                    effects.append(qrCodeEffect)
                }
            case .alerts:
                if let alertsEffect = alertsEffects[widget.id] {
                    if alertsEffect.shoudRegisterEffect() {
                        effects.append(alertsEffect)
                    }
                    alertsEffect.setPosition(x: sceneWidget.x, y: sceneWidget.y)
                    enabledAlertsEffects.append(alertsEffect)
                }
            case .videoSource:
                if let videoSourceEffect = videoSourceEffects[widget.id] {
                    if let videoSourceId = getVideoSourceId(cameraId: widget.videoSource!.toCameraId()) {
                        videoSourceEffect.setVideoSourceId(videoSourceId: videoSourceId)
                    }
                    videoSourceEffect.setSceneWidget(sceneWidget: sceneWidget.clone())
                    videoSourceEffect.setSettings(settings: widget.videoSource!.toEffectSettings())
                    effects.append(videoSourceEffect)
                }
            case .scoreboard:
                if let padelScoreboardEffect = padelScoreboardEffects[widget.id] {
                    padelScoreboardEffect.setSceneWidget(sceneWidget: sceneWidget.clone())
                    let scoreboard = widget.scoreboard!
                    padelScoreboardEffect
                        .update(scoreboard: padelScoreboardSettingsToEffect(scoreboard.padel))
                    sendUpdatePadelScoreboardToWatch(id: widget.id, scoreboard: scoreboard)
                    effects.append(padelScoreboardEffect)
                    usedPadelScoreboardEffects.append(padelScoreboardEffect)
                }
            }
        }
    }

    private func padelScoreboardSettingsToEffect(_ scoreboard: SettingsWidgetPadelScoreboard)
        -> PadelScoreboard
    {
        var homePlayers = [createPadelPlayer(id: scoreboard.homePlayer1)]
        var awayPlayers = [createPadelPlayer(id: scoreboard.awayPlayer1)]
        if scoreboard.type == .doubles {
            homePlayers.append(createPadelPlayer(id: scoreboard.homePlayer2))
            awayPlayers.append(createPadelPlayer(id: scoreboard.awayPlayer2))
        }
        let home = PadelScoreboardTeam(players: homePlayers)
        let away = PadelScoreboardTeam(players: awayPlayers)
        let score = scoreboard.score.map { PadelScoreboardScore(home: $0.home, away: $0.away) }
        return PadelScoreboard(home: home, away: away, score: score)
    }

    private func createPadelPlayer(id: UUID) -> PadelScoreboardPlayer {
        return PadelScoreboardPlayer(name: findScoreboardPlayer(id: id))
    }

    func findScoreboardPlayer(id: UUID) -> String {
        return database.scoreboardPlayers!.first(where: { $0.id == id })?.name ?? "🇸🇪 Moblin"
    }

    private func getVideoSourceId(cameraId: SettingsCameraId) -> UUID? {
        switch cameraId {
        case let .rtmp(id: id):
            return id
        case let .srtla(id: id):
            return id
        case let .mediaPlayer(id: id):
            return id
        case .screenCapture:
            return screenCaptureCameraId
        default:
            return builtinCameraId
        }
    }

    private func findWidgetCrops(scene: SettingsScene, sourceWidgetId: UUID) -> [WidgetCrop] {
        var crops: [WidgetCrop] = []
        for sceneWidget in scene.widgets.filter({ $0.enabled }) {
            guard let widget = findWidget(id: sceneWidget.widgetId) else {
                logger.error("Widget not found")
                continue
            }
            guard widget.type == .crop else {
                continue
            }
            let crop = widget.crop!
            guard crop.sourceWidgetId == sourceWidgetId else {
                continue
            }
            crops.append(WidgetCrop(position: .init(x: sceneWidget.x, y: sceneWidget.y),
                                    crop: .init(
                                        x: crop.x,
                                        y: crop.y,
                                        width: crop.width,
                                        height: crop.height
                                    )))
        }
        return crops
    }

    func setSceneId(id: UUID) {
        selectedSceneId = id
        remoteControlStreamer?.stateChanged(state: RemoteControlState(scene: id))
        sendSceneToWatch()
        sendZoomPresetsToWatch()
        sendZoomPresetToWatch()
        showMediaPlayerControls = enabledScenes.first(where: { $0.id == id })?.cameraPosition == .mediaPlayer
    }

    private func getSelectedScene() -> SettingsScene? {
        return findEnabledScene(id: selectedSceneId)
    }

    private func selectScene(id: UUID) {
        if let index = enabledScenes.firstIndex(where: { scene in
            scene.id == id
        }) {
            sceneIndex = index
            setSceneId(id: id)
        }
    }

    func sceneUpdated(imageEffectChanged: Bool = false) {
        if imageEffectChanged {
            reloadImageEffects()
        }
        guard let scene = getSelectedScene() else {
            sceneUpdatedOff()
            return
        }
        sceneUpdatedOn(scene: scene)
        startWeatherManager()
        startGeographyManager()
    }

    private func updateUptime(now: ContinuousClock.Instant) {
        if let streamStartTime, isStreamConnected() {
            let elapsed = now - streamStartTime
            uptime = uptimeFormatter.string(from: Double(elapsed.components.seconds))!
        } else if uptime != noValue {
            uptime = noValue
        }
    }

    private func updateRecordingLength(now: Date) {
        if let currentRecording {
            let elapsed = uptimeFormatter.string(from: now.timeIntervalSince(currentRecording.startTime))!
            let size = currentRecording.url().fileSize.formatBytes()
            recordingLength = "\(elapsed) (\(size))"
            if !isRemoteControlAssistantConnected() {
                sendRecordingLengthToWatch(recordingLength: recordingLength)
            }
        } else if recordingLength != noValue {
            recordingLength = noValue
            if !isRemoteControlAssistantConnected() {
                sendRecordingLengthToWatch(recordingLength: recordingLength)
            }
        }
    }

    private func updateDigitalClock(now: Date) {
        let newDigitalClock = digitalClockFormatter.string(from: now)
        if digitalClock != newDigitalClock {
            digitalClock = newDigitalClock
        }
    }

    private func updateBatteryLevel() {
        batteryLevel = Double(UIDevice.current.batteryLevel)
        streamingHistoryStream?.updateLowestBatteryLevel(level: batteryLevel)
        if batteryLevel <= 0.07, !isBatteryCharging(), !ProcessInfo().isiOSAppOnMac {
            batteryLevelLowCounter += 1
            if (batteryLevelLowCounter % 3) == 0 {
                makeWarningToast(title: lowBatteryMessage, vibrate: true)
                if database.chat.botEnabled!, database.chat.botSendLowBatteryWarning! {
                    sendChatMessage(message: "Moblin bot: \(lowBatteryMessage)")
                }
            }
        } else {
            batteryLevelLowCounter = -1
        }
    }

    private func updateBatteryState() {
        batteryState = UIDevice.current.batteryState
    }

    func isBatteryCharging() -> Bool {
        return batteryState == .charging || batteryState == .full
    }

    private func updateChatSpeed() {
        if numberOfChatPostsPerTick != 0 {
            chatPostsTotal += numberOfChatPostsPerTick
        }
        chatPostsRatePerSecond = chatPostsRatePerSecond * 0.8 +
            Double(numberOfChatPostsPerTick) * 0.2
        numberOfChatPostsPerMinute += numberOfChatPostsPerTick
        if chatSpeedTicks % 60 == 0 {
            chatPostsRatePerMinute = chatPostsRatePerMinute * 0.5 +
                Double(numberOfChatPostsPerMinute) * 0.5
            numberOfChatPostsPerMinute = 0
        }
        let newChatPostsRate: String
        if chatPostsRatePerSecond > 0.5 ||
            (chatPostsRatePerSecond > 0.05 && chatPostsRate.hasSuffix(secondsSuffix))
        {
            newChatPostsRate = String(format: "%.1f", chatPostsRatePerSecond) + secondsSuffix
        } else {
            newChatPostsRate = String(format: String(localized: "%.1f/min"), chatPostsRatePerMinute)
        }
        if chatPostsRate != newChatPostsRate {
            chatPostsRate = newChatPostsRate
        }
        numberOfChatPostsPerTick = 0
        chatSpeedTicks += 1
    }

    private func checkLowBitrate(speed: Int64, now: ContinuousClock.Instant) {
        guard database.lowBitrateWarning! else {
            return
        }
        guard streamState == .connected else {
            return
        }
        if speed < 500_000, now > latestLowBitrateTime + .seconds(15) {
            makeWarningToast(title: lowBitrateMessage, vibrate: true)
            latestLowBitrateTime = now
        }
    }

    private func updateSpeed(now: ContinuousClock.Instant) {
        if isLive {
            let speed = Int64(media.getVideoStreamBitrate(bitrate: stream.bitrate))
            checkLowBitrate(speed: speed, now: now)
            streamingHistoryStream?.updateBitrate(bitrate: speed)
            speedMbpsOneDecimal = String(format: "%.1f", Double(speed) / 1_000_000)
            let speedString = formatBytesPerSecond(speed: speed)
            let total = sizeFormatter.string(fromByteCount: media.streamTotal())
            speedAndTotal = String(localized: "\(speedString) (\(total))")
            if !isRemoteControlAssistantConnected() {
                sendSpeedAndTotalToWatch(speedAndTotal: speedAndTotal)
            }
        } else if speedAndTotal != noValue {
            speedMbpsOneDecimal = noValue
            speedAndTotal = noValue
            if !isRemoteControlAssistantConnected() {
                sendSpeedAndTotalToWatch(speedAndTotal: speedAndTotal)
            }
        }
    }

    private var serversSpeed: Int64 = 0

    private func updateServersSpeed() {
        var anyServerEnabled = false
        var speed: UInt64 = 0
        var total: UInt64 = 0
        var numberOfClients = 0
        if let rtmpServer {
            let stats = rtmpServer.updateStats()
            numberOfClients += rtmpServer.numberOfClients()
            if rtmpServer.numberOfClients() > 0 {
                total += stats.total
                speed += stats.speed
            }
            anyServerEnabled = true
        }
        if let srtlaServer {
            let stats = srtlaServer.updateStats()
            numberOfClients += srtlaServer.getNumberOfClients()
            if srtlaServer.getNumberOfClients() > 0 {
                total += stats.total
                speed += stats.speed
            }
            anyServerEnabled = true
        }
        let message: String
        if anyServerEnabled {
            if numberOfClients > 0 {
                let total = total.formatBytes()
                serversSpeed = Int64(Double(serversSpeed) * 0.7 + Double(speed) * 0.3)
                let speed = formatBytesPerSecond(speed: 8 * serversSpeed)
                message = String(localized: "\(speed) (\(total)) \(numberOfClients)")
            } else {
                message = String(numberOfClients)
            }
        } else {
            message = noValue
        }
        if message != serversSpeedAndTotal {
            serversSpeedAndTotal = message
        }
    }

    func rtmpServerEnabled() -> Bool {
        return rtmpServer != nil
    }

    func checkPhotoLibraryAuthorization() {
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
        streamingHistoryStream?.updateHighestThermalState(thermalState: ThermalState(from: thermalState))
        if !isRemoteControlAssistantConnected() {
            sendThermalStateToWatch(thermalState: thermalState)
        }
        logger.info("Thermal state: \(thermalState.string())")
        if thermalState == .critical {
            makeFlameRedToast()
        }
    }

    func reattachCamera() {
        detachCamera()
        attachCamera()
    }

    func detachCamera() {
        media.attachCamera(device: nil, videoStabilizationMode: .off, videoMirrored: false)
    }

    func attachCamera() {
        lastAttachCompletedTime = nil
        let isMirrored = getVideoMirroredOnScreen()
        media.attachCamera(
            device: cameraDevice,
            videoStabilizationMode: getVideoStabilizationMode(),
            videoMirrored: getVideoMirroredOnStream()
        ) {
            self.streamPreviewView.isMirrored = isMirrored
            self.lastAttachCompletedTime = .now
        }
    }

    func setGlobalToneMapping(on: Bool) {
        guard let cameraDevice else {
            return
        }
        guard cameraDevice.activeFormat.isGlobalToneMappingSupported else {
            logger.info("Global tone mapping is not supported")
            return
        }
        do {
            try cameraDevice.lockForConfiguration()
            cameraDevice.isGlobalToneMappingEnabled = on
            cameraDevice.unlockForConfiguration()
        } catch {
            logger.info("Failed to set global tone mapping")
        }
    }

    func getGlobalToneMappingOn() -> Bool {
        return cameraDevice?.isGlobalToneMappingEnabled ?? false
    }

    private func getVideoMirroredOnStream() -> Bool {
        if cameraPosition == .front {
            if stream.portrait! {
                return true
            } else {
                return database.mirrorFrontCameraOnStream!
            }
        }
        return false
    }

    private func getVideoMirroredOnScreen() -> Bool {
        if cameraPosition == .front {
            if stream.portrait! {
                return false
            } else {
                return !database.mirrorFrontCameraOnStream!
            }
        }
        return false
    }

    private func hasCameraChanged(
        oldCameraDevice: AVCaptureDevice?,
        oldPosition: AVCaptureDevice.Position?,
        newPosition: AVCaptureDevice.Position?
    ) -> Bool {
        if oldPosition != newPosition {
            return true
        }
        if let newPosition {
            return oldCameraDevice != preferredCamera(position: newPosition)
        } else {
            return oldCameraDevice != nil
        }
    }

    private func attachCamera(position: AVCaptureDevice.Position) {
        guard hasCameraChanged(
            oldCameraDevice: cameraDevice,
            oldPosition: cameraPosition,
            newPosition: position
        ) else {
            media.usePendingAfterAttachEffects()
            return
        }
        cameraDevice = preferredCamera(position: position)
        setFocusAfterCameraAttach()
        cameraZoomLevelToXScale = cameraDevice?
            .getZoomFactorScale(hasUltraWideCamera: hasUltraWideBackCamera()) ?? 1.0
        (cameraZoomXMinimum, cameraZoomXMaximum) = cameraDevice?
            .getUIZoomRange(hasUltraWideCamera: hasUltraWideBackCamera()) ?? (
                1.0,
                1.0
            )
        cameraPosition = position
        switch position {
        case .back:
            if database.zoom.switchToBack.enabled {
                clearZoomId()
                backZoomX = database.zoom.switchToBack.x!
            }
            zoomX = backZoomX
        case .front:
            if database.zoom.switchToFront.enabled {
                clearZoomId()
                frontZoomX = database.zoom.switchToFront.x!
            }
            zoomX = frontZoomX
        default:
            break
        }
        lastAttachCompletedTime = nil
        let isMirrored = getVideoMirroredOnScreen()
        media.attachCamera(
            device: cameraDevice,
            videoStabilizationMode: getVideoStabilizationMode(),
            videoMirrored: getVideoMirroredOnStream(),
            onSuccess: {
                self.streamPreviewView.isMirrored = isMirrored
                if let x = self.setCameraZoomX(x: self.zoomX) {
                    self.setZoomX(x: x)
                }
                if let device = self.cameraDevice {
                    self.setIsoAfterCameraAttach(device: device)
                    self.setWhiteBalanceAfterCameraAttach(device: device)
                }
                self.lastAttachCompletedTime = .now
            }
        )
        zoomXPinch = zoomX
        hasZoom = true
    }

    private func attachReplaceCamera(cameraId: UUID) {
        cameraDevice = nil
        cameraPosition = nil
        streamPreviewView.isMirrored = false
        hasZoom = false
        media.attachReplaceCamera(device: getVideoSourceBuiltinCameraDevice(), cameraId: cameraId)
        media.usePendingAfterAttachEffects()
    }

    private func attachExternalCamera(cameraId _: String) {
        attachCamera(position: .unspecified)
    }

    private func setCameraZoomX(x: Float, rate: Float? = nil) -> Float? {
        let level = media.setCameraZoomLevel(level: x / cameraZoomLevelToXScale, rate: rate)
        if let level {
            return level * cameraZoomLevelToXScale
        }
        return level
    }

    private func stopCameraZoom() -> Float? {
        let level = media.stopCameraZoomLevel()
        if let level {
            return level * cameraZoomLevelToXScale
        }
        return level
    }

    func setExposureBias(bias: Float) {
        guard let position = cameraPosition else {
            return
        }
        guard let device = preferredCamera(position: position) else {
            return
        }
        if bias < device.minExposureTargetBias {
            return
        }
        if bias > device.maxExposureTargetBias {
            return
        }
        do {
            try device.lockForConfiguration()
            device.setExposureTargetBias(bias)
            device.unlockForConfiguration()
        } catch {}
    }

    private func getVideoStabilizationMode() -> AVCaptureVideoStabilizationMode {
        if #available(iOS 18.0, *) {
            switch database.videoStabilizationMode {
            case .off:
                return .off
            case .standard:
                return .standard
            case .cinematic:
                return .cinematic
            case .cinematicExtendedEnhanced:
                return .cinematicExtendedEnhanced
            }
        } else {
            switch database.videoStabilizationMode {
            case .off:
                return .off
            case .standard:
                return .standard
            case .cinematic:
                return .cinematic
            case .cinematicExtendedEnhanced:
                return .off
            }
        }
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

    func setMuted(value: Bool) {
        isMuteOn = value
        updateMute()
    }

    private func updateMute() {
        media.setMute(on: isMuteOn)
        if !isRemoteControlAssistantConnected() {
            sendIsMutedToWatch(isMuteOn: isMuteOn)
        }
        updateTextEffects(now: .now, timestamp: .now)
        forceUpdateTextEffects()
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
            if setCameraZoomX(x: preset.x!, rate: database.zoom.speed!) != nil {
                setZoomX(x: preset.x!)
            }
            sendZoomPresetToWatch()
        } else {
            clearZoomId()
        }
    }

    private func setZoomX(x: Float, setPinch: Bool = true) {
        switch cameraPosition {
        case .back:
            backZoomX = x
        case .front:
            frontZoomX = x
        default:
            break
        }
        zoomX = x
        remoteControlStreamer?.stateChanged(state: RemoteControlState(zoom: x))
        sendZoomToWatch(x: x)
        if setPinch {
            zoomXPinch = zoomX
        }
    }

    func changeZoomX(amount: Float, rate: Float? = nil) {
        guard hasZoom else {
            return
        }
        clearZoomId()
        if let x = setCameraZoomX(x: zoomXPinch * amount, rate: rate) {
            setZoomX(x: x, setPinch: false)
        }
    }

    func commitZoomX(amount: Float, rate: Float? = nil) {
        guard hasZoom else {
            return
        }
        clearZoomId()
        if let x = setCameraZoomX(x: zoomXPinch * amount, rate: rate) {
            setZoomX(x: x)
        }
    }

    private func clearZoomId() {
        switch cameraPosition {
        case .back:
            backZoomPresetId = noBackZoomPresetId
        case .front:
            frontZoomPresetId = noFrontZoomPresetId
        default:
            break
        }
        sendZoomPresetToWatch()
    }

    private func findZoomPreset(id: UUID) -> SettingsZoomPreset? {
        switch cameraPosition {
        case .back:
            return database.zoom.back.first { preset in
                preset.id == id
            }
        case .front:
            return database.zoom.front.first { preset in
                preset.id == id
            }
        default:
            return nil
        }
    }

    private func handleRtmpConnected() {
        onConnected()
    }

    private func handleRtmpDisconnected(message: String) {
        onDisconnected(reason: "RTMP disconnected with message \(message)")
    }

    private func handleRistConnected() {
        DispatchQueue.main.async {
            self.onConnected()
        }
    }

    private func handleRistDisconnected() {
        DispatchQueue.main.async {
            self.onDisconnected(reason: "RIST disconnected")
        }
    }

    private func handleLowFpsImage(image: Data?, frameNumber: UInt64) {
        guard let image else {
            return
        }
        DispatchQueue.main.async { [self] in
            if frameNumber % lowFpsImageFps == 0 {
                if !isRemoteControlAssistantConnected() {
                    sendPreviewToWatch(image: image)
                }
            }
            sendPreviewToRemoteControlAssistant(preview: image)
        }
    }

    private func handleFindVideoFormatError(findVideoFormatError: String, activeFormat: String) {
        DispatchQueue.main.async {
            self.makeErrorToast(title: findVideoFormatError, subTitle: activeFormat)
        }
    }

    private func handleRecorderFinished() {}

    private var latestRecordingErrorRestart: ContinuousClock.Instant = .now

    private func handleRecorderError() {
        DispatchQueue.main.async { [self] in
            guard isRecording else {
                return
            }
            if self.latestRecordingErrorRestart.duration(to: .now) > .seconds(60) {
                makeErrorToast(
                    title: String(localized: "Recording error"),
                    subTitle: String(localized: "Starting a new recording")
                )
                suspendRecording()
                startRecording()
            } else {
                stopRecording(showToast: false)
                makeErrorToast(
                    title: String(localized: "Recording error"),
                    subTitle: String(localized: "Recording stopped")
                )
            }
            self.latestRecordingErrorRestart = .now
        }
    }

    private func handleNoTorch() {
        DispatchQueue.main.async { [self] in
            if !isFrontCameraSelected {
                makeErrorToast(
                    title: String(localized: "Torch unavailable in this scene."),
                    subTitle: String(localized: "Normally only available for built-in cameras.")
                )
            }
        }
    }

    private func onConnected() {
        makeYouAreLiveToast()
        streamStartTime = .now
        streamState = .connected
        updateUptime(now: .now)
    }

    private func onDisconnected(reason: String) {
        guard streaming else {
            return
        }
        logger.info("stream: Disconnected with reason \(reason)")
        let subTitle = String(localized: "Attempting again in 5 seconds.")
        if streamState == .connected {
            streamTotalBytes += UInt64(media.streamTotal())
            streamingHistoryStream?.numberOfFffffs! += 1
            makeFffffToast(subTitle: subTitle)
        } else if streamState == .connecting {
            makeConnectFailureToast(subTitle: subTitle)
        }
        streamState = .disconnected
        stopNetStream(reconnect: true)
        reconnectTimer = Timer
            .scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
                logger.info("stream: Reconnecting")
                self.startNetStream(reconnect: true)
            }
    }

    private func handleSrtConnected() {
        onConnected()
    }

    private func handleSrtDisconnected(reason: String) {
        onDisconnected(reason: reason)
    }

    func backZoomUpdated() {
        if !database.zoom.back.contains(where: { level in
            level.id == backZoomPresetId
        }) {
            backZoomPresetId = database.zoom.back[0].id
        }
        sceneUpdated()
    }

    func frontZoomUpdated() {
        if !database.zoom.front.contains(where: { level in
            level.id == frontZoomPresetId
        }) {
            frontZoomPresetId = database.zoom.front[0].id
        }
        sceneUpdated()
    }

    private func makeConnectFailureToast(subTitle: String) {
        makeErrorToast(title: failedToConnectMessage(stream.name),
                       subTitle: subTitle,
                       vibrate: true)
    }

    private func makeYouAreLiveToast() {
        makeToast(title: String(localized: "🎉 You are LIVE at \(stream.name) 🎉"))
    }

    private func makeStreamEndedToast() {
        makeToast(title: String(localized: "🤟 Stream ended 🤟"))
    }

    private func makeFffffToast(subTitle: String) {
        makeErrorToast(
            title: fffffMessage,
            font: .system(size: 64).bold(),
            subTitle: subTitle,
            vibrate: true
        )
    }

    private func makeStreamLikelyBrokenToast(scene: String) {
        makeErrorToast(
            title: String(localized: "😠 Stream likely broken 😠"),
            subTitle: String(localized: "Trying to switch OBS scene to \(scene)")
        )
    }

    private func makeStreamLikelyWorkingToast(scene: String) {
        makeToast(
            title: String(localized: "🥳 Stream likely working 🥳"),
            subTitle: String(localized: "Trying to switch OBS scene to \(scene)")
        )
    }

    private func makeFlameRedToast() {
        makeWarningToast(title: flameRedMessage, vibrate: true)
    }

    private func startMotionDetection() {
        motionManager.stopDeviceMotionUpdates()
        manualFocusMotionAttitude = nil
        motionManager.deviceMotionUpdateInterval = 0.2
        motionManager.startDeviceMotionUpdates(to: OperationQueue.main) { data, _ in
            guard let data else {
                return
            }
            let attitude = data.attitude
            if self.manualFocusMotionAttitude == nil {
                self.manualFocusMotionAttitude = attitude
            }
            if diffAngles(attitude.pitch, self.manualFocusMotionAttitude!.pitch) > 10 {
                self.setAutoFocus()
            } else if diffAngles(attitude.roll, self.manualFocusMotionAttitude!.roll) > 10 {
                self.setAutoFocus()
            } else if diffAngles(attitude.yaw, self.manualFocusMotionAttitude!.yaw) > 10 {
                self.setAutoFocus()
            }
        }
    }

    private func stopMotionDetection() {
        motionManager.stopDeviceMotionUpdates()
    }

    func preferredCamera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if let scene = findEnabledScene(id: selectedSceneId) {
            if position == .back {
                return AVCaptureDevice(uniqueID: scene.backCameraId!)
            } else if position == .front {
                return AVCaptureDevice(uniqueID: scene.frontCameraId!)
            } else {
                return AVCaptureDevice(uniqueID: scene.externalCameraId!)
            }
        } else {
            return nil
        }
    }

    private func factorToX(position: AVCaptureDevice.Position, factor: Float) -> Float {
        if position == .back && hasUltraWideBackCamera() {
            return factor / 2
        }
        return factor
    }

    func getMinMaxZoomX(position: AVCaptureDevice.Position) -> (Float, Float) {
        var minX: Float
        var maxX: Float
        if let device = preferredCamera(position: position) {
            minX = factorToX(
                position: position,
                factor: Float(device.minAvailableVideoZoomFactor)
            )
            maxX = factorToX(
                position: position,
                factor: Float(device.maxAvailableVideoZoomFactor)
            )
        } else {
            minX = 1.0
            maxX = 1.0
        }
        return (minX, maxX)
    }

    func isShowingStatusStream() -> Bool {
        return database.show.stream && isStreamConfigured()
    }

    func isShowingStatusCamera() -> Bool {
        return database.show.cameras!
    }

    func isShowingStatusMic() -> Bool {
        return database.show.microphone
    }

    func isShowingStatusZoom() -> Bool {
        return database.show.zoom && hasZoom
    }

    func isShowingStatusObs() -> Bool {
        return database.show.obsStatus! && isObsRemoteControlConfigured()
    }

    func isShowingStatusEvents() -> Bool {
        return database.show.events! && isEventsConfigured()
    }

    func isShowingStatusChat() -> Bool {
        return database.show.chat && isChatConfigured()
    }

    func isShowingStatusViewers() -> Bool {
        return database.show.viewers && isViewersConfigured() && isLive
    }

    func statusStreamText() -> String {
        let proto = stream.protocolString()
        let resolution = stream.resolutionString()
        let codec = stream.codecString()
        let bitrate = stream.bitrateString()
        let audioCodec = stream.audioCodecString()
        let audioBitrate = stream.audioBitrateString()
        return """
        \(stream.name) (\(resolution), \(stream.fps), \(proto), \(codec) \(bitrate), \
        \(audioCodec) \(audioBitrate))
        """
    }

    func statusCameraText() -> String {
        return getCameraPositionName(scene: findEnabledScene(id: selectedSceneId))
    }

    func statusZoomText() -> String {
        return String(format: "%.1f", zoomX)
    }

    func statusObsText() -> String {
        if !isObsRemoteControlConfigured() {
            return String(localized: "Not configured")
        } else if isObsConnected() {
            if obsStreaming && obsRecording {
                return "\(obsCurrentScene) (Streaming, Recording)"
            } else if obsStreaming {
                return "\(obsCurrentScene) (Streaming)"
            } else if obsRecording {
                return "\(obsCurrentScene) (Recording)"
            } else {
                return obsCurrentScene
            }
        } else {
            return obsConnectionErrorMessage()
        }
    }

    func statusEventsText() -> String {
        if !isEventsConfigured() {
            return String(localized: "Not configured")
        } else if isEventsRemoteControl() {
            if isRemoteControlStreamerConnected() {
                return String(localized: "Connected (remote control)")
            } else {
                return String(localized: "Disconnected (remote control)")
            }
        } else {
            if isEventsConnected() {
                return String(localized: "Connected")
            } else {
                return String(localized: "Disconnected")
            }
        }
    }

    func statusChatText() -> String {
        if !isChatConfigured() {
            return String(localized: "Not configured")
        } else if isChatConnected() {
            return String(
                format: String(localized: "%@ (%@ total)"),
                chatPostsRate,
                countFormatter.format(chatPostsTotal)
            )
        } else {
            return String(localized: "Disconnected")
        }
    }

    func statusViewersText() -> String {
        if isViewersConfigured() {
            return numberOfViewers
        } else {
            return String(localized: "Not configured")
        }
    }

    func isShowingStatusAudioLevel() -> Bool {
        return database.show.audioLevel
    }

    func isShowingStatusHypeTrain() -> Bool {
        return hypeTrainStatus != noValue
    }

    func isShowingStatusAdsRemainingTimer() -> Bool {
        return adsRemainingTimerStatus != noValue
    }

    func isShowingStatusServers() -> Bool {
        return database.show.rtmpSpeed! && (rtmpServerEnabled() || srtlaServerEnabled())
    }

    func isShowingStatusRemoteControl() -> Bool {
        return database.show
            .remoteControl! && (isRemoteControlStreamerConfigured() || isRemoteControlAssistantConfigured())
    }

    func isShowingStatusGameController() -> Bool {
        return database.show.gameController! && isGameControllerConnected()
    }

    func isShowingStatusBitrate() -> Bool {
        return database.show.speed && isLive
    }

    func isShowingStatusUptime() -> Bool {
        return database.show.uptime && isLive
    }

    func isShowingStatusLocation() -> Bool {
        return database.show.location! && isLocationEnabled()
    }

    func isShowingStatusBonding() -> Bool {
        return database.show.bonding! && stream.isBonding() && isLive
    }

    func isShowingStatusRecording() -> Bool {
        return isRecording
    }

    func isShowingStatusBrowserWidgets() -> Bool {
        return database.show.browserWidgets! && !browserWidgetsStatus
            .isEmpty && browserWidgetsStatusChanged
    }
}

extension Model: RemoteControlStreamerDelegate {
    func remoteControlStreamerConnected() {
        makeToast(title: String(localized: "Remote control assistant connected"))
        isRemoteControlAssistantRequestingPreview = false
        setLowFpsImage()
        updateRemoteControlStatus()
        reloadTwitchEventSub()
        var state = RemoteControlState()
        if sceneIndex < enabledScenes.count {
            state.scene = enabledScenes[sceneIndex].id
        }
        state.mic = currentMic.id
        if let preset = getBitratePresetByBitrate(bitrate: stream.bitrate) {
            state.bitrate = preset.id
        }
        state.zoom = zoomX
        state.debugLogging = database.debug.logLevel == .debug
        remoteControlStreamer?.stateChanged(state: state)
    }

    func remoteControlStreamerDisconnected() {
        makeToast(title: String(localized: "Remote control assistant disconnected"))
        isRemoteControlAssistantRequestingPreview = false
        setLowFpsImage()
        updateRemoteControlStatus()
        updateRemoteControlStreamerTwitch()
    }

    func remoteControlStreamerGetStatus(onComplete: @escaping (
        RemoteControlStatusGeneral,
        RemoteControlStatusTopLeft,
        RemoteControlStatusTopRight
    ) -> Void) {
        var general = RemoteControlStatusGeneral()
        general.batteryCharging = isBatteryCharging()
        general.batteryLevel = Int(100 * batteryLevel)
        switch thermalState {
        case .nominal:
            general.flame = .white
        case .fair:
            general.flame = .white
        case .serious:
            general.flame = .yellow
        case .critical:
            general.flame = .red
        @unknown default:
            general.flame = .red
        }
        general.wiFiSsid = currentWiFiSsid
        general.isLive = isLive
        general.isRecording = isRecording
        general.isMuted = isMuteOn
        var topLeft = RemoteControlStatusTopLeft()
        if isShowingStatusStream() {
            topLeft.stream = RemoteControlStatusItem(message: statusStreamText())
        }
        if isShowingStatusCamera() {
            topLeft.camera = RemoteControlStatusItem(message: statusCameraText())
        }
        if isShowingStatusMic() {
            topLeft.mic = RemoteControlStatusItem(message: currentMic.name)
        }
        if isShowingStatusZoom() {
            topLeft.zoom = RemoteControlStatusItem(message: statusZoomText())
        }
        if isShowingStatusObs() {
            topLeft.obs = RemoteControlStatusItem(message: statusObsText())
        }
        if isShowingStatusEvents() {
            topLeft.events = RemoteControlStatusItem(message: statusEventsText())
        }
        if isShowingStatusChat() {
            topLeft.chat = RemoteControlStatusItem(message: statusChatText())
        }
        if isShowingStatusViewers() {
            topLeft.viewers = RemoteControlStatusItem(message: statusViewersText())
        }
        var topRight = RemoteControlStatusTopRight()
        if isShowingStatusAudioLevel() {
            let level = formatAudioLevel(level: audioLevel) +
                formatAudioLevelChannels(channels: numberOfAudioChannels)
            topRight.audioLevel = RemoteControlStatusItem(message: level)
            topRight.audioInfo = .init(
                audioLevel: .unknown,
                numberOfAudioChannels: numberOfAudioChannels
            )
            if audioLevel.isNaN {
                topRight.audioInfo!.audioLevel = .muted
            } else if audioLevel.isInfinite {
                topRight.audioInfo!.audioLevel = .unknown
            } else {
                topRight.audioInfo!.audioLevel = .value(audioLevel)
            }
        }
        if isShowingStatusServers() {
            topRight.rtmpServer = RemoteControlStatusItem(message: serversSpeedAndTotal)
        }
        if isShowingStatusRemoteControl() {
            topRight.remoteControl = RemoteControlStatusItem(message: remoteControlStatus)
        }
        if isShowingStatusGameController() {
            topRight.gameController = RemoteControlStatusItem(message: gameControllersTotal)
        }
        if isShowingStatusBitrate() {
            topRight.bitrate = RemoteControlStatusItem(message: speedAndTotal)
        }
        if isShowingStatusUptime() {
            topRight.uptime = RemoteControlStatusItem(message: uptime)
        }
        if isShowingStatusLocation() {
            topRight.location = RemoteControlStatusItem(message: location)
        }
        if isShowingStatusBonding() {
            topRight.srtla = RemoteControlStatusItem(message: bondingStatistics)
        }
        if isShowingStatusRecording() {
            topRight.recording = RemoteControlStatusItem(message: recordingLength)
        }
        if isShowingStatusBrowserWidgets() {
            topRight.browserWidgets = RemoteControlStatusItem(message: browserWidgetsStatus)
        }
        onComplete(general, topLeft, topRight)
    }

    func remoteControlStreamerGetSettings(onComplete: @escaping (RemoteControlSettings) -> Void) {
        let scenes = enabledScenes.map { scene in
            RemoteControlSettingsScene(id: scene.id, name: scene.name)
        }
        let mics = listMics().map { mic in
            RemoteControlSettingsMic(id: mic.id, name: mic.name)
        }
        let bitratePresets = database.bitratePresets.map { preset in
            RemoteControlSettingsBitratePreset(id: preset.id, bitrate: preset.bitrate)
        }
        let connectionPriorities = stream.srt.connectionPriorities!.priorities
            .map { priority in
                RemoteControlSettingsSrtConnectionPriority(
                    id: priority.id,
                    name: priority.name,
                    priority: priority.priority,
                    enabled: priority.enabled!
                )
            }
        let connectionPrioritiesEnabled = stream.srt.connectionPriorities!.enabled
        onComplete(RemoteControlSettings(
            scenes: scenes,
            bitratePresets: bitratePresets,
            mics: mics,
            srt: RemoteControlSettingsSrt(
                connectionPrioritiesEnabled: connectionPrioritiesEnabled,
                connectionPriorities: connectionPriorities
            )
        ))
    }

    func remoteControlStreamerSetScene(id: UUID, onComplete: @escaping () -> Void) {
        selectScene(id: id)
        onComplete()
    }

    func remoteControlStreamerSetMic(id: String, onComplete: @escaping () -> Void) {
        selectMicById(id: id)
        onComplete()
    }

    func remoteControlStreamerSetBitratePreset(id: UUID, onComplete: @escaping () -> Void) {
        guard let preset = database.bitratePresets.first(where: { preset in
            preset.id == id
        }) else {
            return
        }
        setBitrate(bitrate: preset.bitrate)
        if stream.enabled {
            setStreamBitrate(stream: stream)
        }
        onComplete()
    }

    func remoteControlStreamerSetRecord(on: Bool, onComplete: @escaping () -> Void) {
        if on {
            startRecording()
        } else {
            stopRecording()
        }
        updateButtonStates()
        onComplete()
    }

    func remoteControlStreamerSetStream(on: Bool, onComplete: @escaping () -> Void) {
        if on {
            startStream()
        } else {
            stopStream()
        }
        updateButtonStates()
        onComplete()
    }

    func remoteControlStreamerSetDebugLogging(on: Bool, onComplete: @escaping () -> Void) {
        setDebugLogging(on: on)
        onComplete()
    }

    func remoteControlStreamerSetZoom(x: Float, onComplete: @escaping () -> Void) {
        if let x = setCameraZoomX(x: x, rate: database.zoom.speed!) {
            setZoomX(x: x)
        }
        onComplete()
    }

    private func setMuteOn(value: Bool) {
        if value {
            isMuteOn = true
        } else {
            isMuteOn = false
        }
        updateMute()
        setGlobalButtonState(type: .mute, isOn: value)
        updateButtonStates()
    }

    func remoteControlStreamerSetMute(on: Bool, onComplete: @escaping () -> Void) {
        setMuteOn(value: on)
        onComplete()
    }

    func remoteControlStreamerSetTorch(on: Bool, onComplete: @escaping () -> Void) {
        if on {
            isTorchOn = true
        } else {
            isTorchOn = false
        }
        updateTorch()
        toggleGlobalButton(type: .torch)
        updateButtonStates()
        onComplete()
    }

    func remoteControlStreamerReloadBrowserWidgets(onComplete: @escaping () -> Void) {
        reloadBrowserWidgets()
        onComplete()
    }

    func remoteControlStreamerSetSrtConnectionPrioritiesEnabled(
        enabled: Bool,
        onComplete: @escaping () -> Void
    ) {
        DispatchQueue.main.async {
            self.stream.srt.connectionPriorities!.enabled = enabled
            self.updateSrtlaPriorities()
            onComplete()
        }
    }

    func remoteControlStreamerSetSrtConnectionPriority(
        id: UUID,
        priority: Int,
        enabled: Bool,
        onComplete: @escaping () -> Void
    ) {
        DispatchQueue.main.async {
            if let entry = self.stream.srt.connectionPriorities!.priorities.first(where: { $0.id == id }) {
                entry.priority = clampConnectionPriority(value: priority)
                entry.enabled = enabled
                self.updateSrtlaPriorities()
            }
            onComplete()
        }
    }

    private func sendPreviewToRemoteControlAssistant(preview: Data) {
        guard isRemoteControlStreamerConnected() else {
            return
        }
        remoteControlStreamer?.sendPreview(preview: preview)
    }

    func remoteControlStreamerTwitchEventSubNotification(message: String) {
        twitchEventSub?.handleMessage(messageText: message)
    }

    func remoteControlStreamerStartPreview(onComplete _: @escaping () -> Void) {
        isRemoteControlAssistantRequestingPreview = true
        setLowFpsImage()
    }

    func remoteControlStreamerStopPreview(onComplete _: @escaping () -> Void) {
        isRemoteControlAssistantRequestingPreview = false
        setLowFpsImage()
    }
}

extension Model {
    func isObsRemoteControlConfigured() -> Bool {
        return stream.obsWebSocketEnabled! && stream.obsWebSocketUrl != "" && stream
            .obsWebSocketPassword != ""
    }

    func clearRemoteControlAssistantLog() {
        remoteControlAssistantLog = []
    }

    func reloadRemoteControlStreamer() {
        remoteControlStreamer?.stop()
        remoteControlStreamer = nil
        guard isRemoteControlStreamerConfigured() else {
            reloadTwitchEventSub()
            return
        }
        guard let url = URL(string: database.remoteControl!.server.url) else {
            reloadTwitchEventSub()
            return
        }
        remoteControlStreamer = RemoteControlStreamer(
            clientUrl: url,
            password: database.remoteControl!.password!,
            delegate: self
        )
        remoteControlStreamer!.start()
    }

    private func updateRemoteControlStreamerTwitch() {
        if stream.twitchLoggedIn! {
            remoteControlStreamer?.twitchStart(
                channelId: stream.twitchChannelId,
                accessToken: stream.twitchAccessToken!
            )
        } else {
            remoteControlStreamer?.twitchStop()
        }
    }

    private func updateRemoteControlStatus() {
        if isRemoteControlAssistantConnected(), isRemoteControlStreamerConnected() {
            remoteControlStatus = String(localized: "Assistant and streamer")
        } else if isRemoteControlAssistantConnected() {
            remoteControlStatus = String(localized: "Assistant")
        } else if isRemoteControlStreamerConnected() {
            remoteControlStatus = String(localized: "Streamer")
        } else {
            let assistantError = remoteControlAssistant?.connectionErrorMessage ?? ""
            let streamerError = remoteControlStreamer?.connectionErrorMessage ?? ""
            if isRemoteControlAssistantConfigured(), isRemoteControlStreamerConfigured() {
                remoteControlStatus = "\(assistantError), \(streamerError)"
            } else if isRemoteControlAssistantConfigured() {
                remoteControlStatus = assistantError
            } else if isRemoteControlStreamerConfigured() {
                remoteControlStatus = streamerError
            } else {
                remoteControlStatus = noValue
            }
        }
    }

    func isRemoteControlStreamerConfigured() -> Bool {
        let server = database.remoteControl!.server
        return server.enabled && !server.url.isEmpty && !database.remoteControl!.password!.isEmpty
    }

    func isRemoteControlStreamerConnected() -> Bool {
        return remoteControlStreamer?.isConnected() ?? false
    }

    func reloadRemoteControlAssistant() {
        remoteControlAssistant?.stop()
        remoteControlAssistant = nil
        guard isRemoteControlAssistantConfigured() else {
            return
        }
        remoteControlAssistant = RemoteControlAssistant(
            port: database.remoteControl!.client.port,
            password: database.remoteControl!.password!,
            delegate: self,
            httpProxy: httpProxy(),
            urlSession: urlSession
        )
        remoteControlAssistant!.start()
    }

    func isRemoteControlAssistantConnected() -> Bool {
        return remoteControlAssistant?.isConnected() ?? false
    }

    func updateRemoteControlAssistantStatus() {
        guard showingRemoteControl || isWatchReachable(), isRemoteControlAssistantConnected() else {
            return
        }
        remoteControlAssistant?.getStatus { general, topLeft, topRight in
            self.remoteControlGeneral = general
            self.remoteControlTopLeft = topLeft
            self.remoteControlTopRight = topRight
            if let general {
                if let thermalState = general.flame?.toThermalState() {
                    self.sendThermalStateToWatch(thermalState: thermalState)
                }
                if let isLive = general.isLive {
                    self.sendIsLiveToWatch(isLive: isLive)
                }
                if let isRecording = general.isRecording {
                    self.sendIsRecordingToWatch(isRecording: isRecording)
                }
                if let isMuted = general.isMuted {
                    self.sendIsMutedToWatch(isMuteOn: isMuted)
                }
            }
            if let recordingMessage = topRight.recording?.message {
                self.sendRecordingLengthToWatch(recordingLength: recordingMessage)
            }
            if let bitrateMessage = topRight.bitrate?.message {
                self.sendSpeedAndTotalToWatch(speedAndTotal: bitrateMessage)
            }
            if let audioInfo = topRight.audioInfo {
                self.sendAudioLevelToWatch(audioLevel: audioInfo.audioLevel.toFloat())
            }
        }
        remoteControlAssistant?.getSettings { settings in
            self.remoteControlSettings = settings
        }
    }

    func isRemoteControlAssistantConfigured() -> Bool {
        let client = database.remoteControl!.client
        return client.enabled && client.port > 0 && !database.remoteControl!.password!.isEmpty
    }

    func remoteControlAssistantSetStream(on: Bool, onSuccess: @escaping () -> Void) {
        remoteControlAssistant?.setStream(on: on) {
            onSuccess()
        }
    }

    func remoteControlAssistantSetRecord(on: Bool, onSuccess: @escaping () -> Void) {
        remoteControlAssistant?.setRecord(on: on) {
            onSuccess()
        }
    }

    func remoteControlAssistantSetMute(on: Bool, onSuccess: @escaping () -> Void) {
        remoteControlAssistant?.setMute(on: on) {
            onSuccess()
        }
    }

    func remoteControlAssistantSetScene(id: UUID) {
        remoteControlAssistant?.setScene(id: id) {}
    }

    func remoteControlAssistantSetMic(id: String) {
        remoteControlAssistant?.setMic(id: id) {}
    }

    func remoteControlAssistantSetZoom(x: Float) {
        remoteControlAssistant?.setZoom(x: x) {}
    }

    func remoteControlAssistantSetBitratePreset(id: UUID) {
        remoteControlAssistant?.setBitratePreset(id: id) {}
    }

    func remoteControlAssistantSetDebugLogging(on: Bool) {
        remoteControlAssistant?.setDebugLogging(on: on) {}
    }

    func remoteControlAssistantReloadBrowserWidgets() {
        remoteControlAssistant?.reloadBrowserWidgets {
            DispatchQueue.main.async {
                self.makeToast(title: String(localized: "Browser widgets reloaded"))
            }
        }
    }

    func remoteControlAssistantSetSrtConnectionPriorityEnabled(enabled: Bool) {
        remoteControlAssistant?.setSrtConnectionPrioritiesEnabled(
            enabled: enabled
        ) {}
    }

    func remoteControlAssistantSetSrtConnectionPriority(priority: RemoteControlSettingsSrtConnectionPriority) {
        remoteControlAssistant?.setSrtConnectionPriority(
            id: priority.id,
            priority: priority.priority,
            enabled: priority.enabled
        ) {}
    }

    func remoteControlAssistantStartPreview() {
        remoteControlAssistant?.startPreview()
    }

    func remoteControlAssistantStopPreview() {
        remoteControlAssistant?.stopPreview()
    }

    func reloadRemoteControlRelay() {
        remoteControlRelay?.stop()
        remoteControlRelay = nil
        guard isRemoteControlRelayConfigured() else {
            return
        }
        guard let assistantUrl = URL(string: "ws://localhost:\(database.remoteControl!.client.port)") else {
            return
        }
        remoteControlRelay = RemoteControlRelay(
            baseUrl: database.remoteControl!.client.relay!.baseUrl,
            bridgeId: database.remoteControl!.client.relay!.bridgeId,
            assistantUrl: assistantUrl
        )
        remoteControlRelay?.start()
    }

    func isRemoteControlRelayConfigured() -> Bool {
        let relay = database.remoteControl!.client.relay!
        return relay.enabled && !relay.baseUrl.isEmpty
    }
}

extension Model: RemoteControlAssistantDelegate {
    func remoteControlAssistantConnected() {
        makeToast(title: String(localized: "Remote control streamer connected"))
        updateRemoteControlStatus()
        updateRemoteControlAssistantStatus()
    }

    func remoteControlAssistantDisconnected() {
        makeToast(title: String(localized: "Remote control streamer disconnected"))
        remoteControlTopLeft = nil
        remoteControlTopRight = nil
        updateRemoteControlStatus()
    }

    func remoteControlAssistantStateChanged(state: RemoteControlState) {
        if let scene = state.scene {
            remoteControlState.scene = scene
            remoteControlScene = scene
        }
        if let mic = state.mic {
            remoteControlState.mic = mic
            remoteControlMic = mic
        }
        if let bitrate = state.bitrate {
            remoteControlState.bitrate = bitrate
            remoteControlBitrate = bitrate
        }
        if let zoom = state.zoom {
            remoteControlState.zoom = zoom
            remoteControlZoom = String(zoom)
        }
        if let debugLogging = state.debugLogging {
            remoteControlState.debugLogging = debugLogging
            remoteControlDebugLogging = debugLogging
        }
        if let streaming = state.streaming {
            remoteControlState.streaming = streaming
        }
        if let recording = state.recording {
            remoteControlState.recording = recording
        }
    }

    func remoteControlAssistantPreview(preview: Data) {
        remoteControlPreview = UIImage(data: preview)
        sendPreviewToWatch(image: preview)
    }

    func remoteControlAssistantLog(entry: String) {
        if remoteControlAssistantLog.count > 100_000 {
            remoteControlAssistantLog.removeFirst()
        }
        logId += 1
        remoteControlAssistantLog.append(LogEntry(id: logId, message: entry))
    }
}

extension Model {
    private func isWatchReachable() -> Bool {
        return WCSession.default.activationState == .activated && WCSession.default.isReachable
    }

    private func sendMessageToWatch(
        type: WatchMessageToWatch,
        data: Any,
        replyHandler: (([String: Any]) -> Void)? = nil,
        errorHandler: ((Error) -> Void)? = nil
    ) {
        WCSession.default.sendMessage(
            WatchMessageToWatch.pack(type: type, data: data),
            replyHandler: replyHandler,
            errorHandler: errorHandler
        )
    }

    private func sendSpeedAndTotalToWatch(speedAndTotal: String) {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .speedAndTotal, data: speedAndTotal)
    }

    private func sendRecordingLengthToWatch(recordingLength: String) {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .recordingLength, data: recordingLength)
    }

    private func sendAudioLevelToWatch(audioLevel: Float) {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .audioLevel, data: audioLevel)
    }

    private func sendThermalStateToWatch(thermalState: ProcessInfo.ThermalState) {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .thermalState, data: thermalState.rawValue)
    }

    private func sendStartWorkoutToWatch(type: WatchProtocolWorkoutType) {
        guard isWatchReachable() else {
            return
        }
        var data: Data
        do {
            let message = WatchProtocolStartWorkout(type: type)
            data = try JSONEncoder().encode(message)
        } catch {
            return
        }
        sendMessageToWatch(type: .startWorkout, data: data)
    }

    private func sendStopWorkoutToWatch() {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .stopWorkout, data: true)
    }

    private func sendWorkoutToWatch() {
        if let workoutType {
            sendStartWorkoutToWatch(type: workoutType)
        } else {
            sendStopWorkoutToWatch()
        }
    }

    private func sendViewerCountWatch() {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .viewerCount, data: numberOfViewers)
    }

    private func sendUpdatePadelScoreboardToWatch(id: UUID, scoreboard: SettingsWidgetScoreboard) {
        guard isWatchReachable() else {
            return
        }
        var data: Data
        do {
            var home = [scoreboard.padel.homePlayer1]
            var away = [scoreboard.padel.awayPlayer1]
            if scoreboard.padel.type == .doubles {
                home.append(scoreboard.padel.homePlayer2)
                away.append(scoreboard.padel.awayPlayer2)
            }
            let score = scoreboard.padel.score.map { WatchProtocolPadelScoreboardScore(
                home: $0.home,
                away: $0.away
            ) }
            let message = WatchProtocolPadelScoreboard(id: id, home: home, away: away, score: score)
            data = try JSONEncoder().encode(message)
        } catch {
            return
        }
        sendMessageToWatch(type: .padelScoreboard, data: data)
    }

    private func sendRemovePadelScoreboardToWatch(id: UUID) {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .removePadelScoreboard, data: id.uuidString)
    }

    func sendScoreboardPlayersToWatch() {
        guard isWatchReachable() else {
            return
        }
        var data: Data
        do {
            let message = database.scoreboardPlayers!.map { WatchProtocolScoreboardPlayer(
                id: $0.id,
                name: $0.name
            ) }
            data = try JSONEncoder().encode(message)
        } catch {
            return
        }
        sendMessageToWatch(type: .scoreboardPlayers, data: data)
    }

    private func resetWorkoutStats() {
        workoutHeartRate = nil
        workoutActiveEnergyBurned = nil
        workoutDistance = nil
        workoutPower = nil
        workoutStepCount = nil
    }

    private func enqueueWatchChatPost(post: ChatPost) {
        guard WCSession.default.isWatchAppInstalled else {
            return
        }
        guard let user = post.user else {
            return
        }
        let userColor: WatchProtocolColor
        if let color = post.userColor {
            userColor = WatchProtocolColor(red: color.red, green: color.green, blue: color.blue)
        } else {
            let color = database.chat.usernameColor
            userColor = WatchProtocolColor(red: color.red, green: color.green, blue: color.blue)
        }
        let post = WatchProtocolChatMessage(
            id: nextWatchChatPostId,
            timestamp: post.timestamp,
            user: user,
            userColor: userColor,
            userBadges: post.userBadges,
            segments: post.segments
                .map { WatchProtocolChatSegment(text: $0.text, url: $0.url?.absoluteString) },
            highlight: post.highlight?.toWatchProtocol()
        )
        nextWatchChatPostId += 1
        watchChatPosts.append(post)
        if watchChatPosts.count > maximumNumberOfWatchChatMessages {
            _ = watchChatPosts.popFirst()
        }
    }

    private func trySendNextChatPostToWatch() {
        guard isWatchReachable(), let post = watchChatPosts.popFirst() else {
            return
        }
        var data: Data
        do {
            data = try JSONEncoder().encode(post)
        } catch {
            logger.info("watch: Chat message send failed")
            return
        }
        sendMessageToWatch(type: .chatMessage, data: data)
    }

    private func sendChatMessageToWatch(post: ChatPost) {
        enqueueWatchChatPost(post: post)
    }

    private func sendPreviewToWatch(image: Data) {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .preview, data: image)
    }

    private func sendZoomToWatch(x: Float) {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .zoom, data: x)
    }

    private func sendZoomPresetsToWatch() {
        guard isWatchReachable() else {
            return
        }
        let zoomPresets: [WatchProtocolZoomPreset]
        if cameraPosition == .front {
            zoomPresets = frontZoomPresets().map { .init(id: $0.id, name: $0.name) }
        } else {
            zoomPresets = backZoomPresets().map { .init(id: $0.id, name: $0.name) }
        }
        do {
            let zoomPresets = try JSONEncoder().encode(zoomPresets)
            sendMessageToWatch(type: .zoomPresets, data: zoomPresets)
        } catch {}
    }

    private func sendZoomPresetToWatch() {
        guard isWatchReachable() else {
            return
        }
        let zoomPreset: UUID
        if cameraPosition == .front {
            zoomPreset = frontZoomPresetId
        } else {
            zoomPreset = backZoomPresetId
        }
        sendMessageToWatch(type: .zoomPreset, data: zoomPreset.uuidString)
    }

    private func sendScenesToWatch() {
        guard isWatchReachable() else {
            return
        }
        let scenes = enabledScenes.map { WatchProtocolScene(id: $0.id, name: $0.name) }
        do {
            try sendMessageToWatch(type: .scenes, data: JSONEncoder().encode(scenes))
        } catch {}
    }

    private func sendSceneToWatch() {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .scene, data: selectedSceneId.uuidString)
    }

    func sendSettingsToWatch() {
        guard isWatchReachable() else {
            return
        }
        do {
            let settings = try JSONEncoder().encode(database.watch)
            sendMessageToWatch(type: .settings, data: settings)
        } catch {}
    }

    private func sendIsLiveToWatch(isLive: Any) {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .isLive, data: isLive)
    }

    private func sendIsRecordingToWatch(isRecording: Any) {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .isRecording, data: isRecording)
    }

    private func sendIsMutedToWatch(isMuteOn: Any) {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .isMuted, data: isMuteOn)
    }
}

extension Model: WCSessionDelegate {
    func session(
        _: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error _: Error?
    ) {
        logger.debug("watch: \(activationState)")
        switch activationState {
        case .activated:
            DispatchQueue.main.async {
                self.setLowFpsImage()
                self.sendWorkoutToWatch()
            }
        default:
            break
        }
    }

    func sessionDidBecomeInactive(_: WCSession) {
        logger.debug("watch: Session inactive")
    }

    func sessionDidDeactivate(_: WCSession) {
        logger.debug("watch: Session deactive")
    }

    func sessionReachabilityDidChange(_: WCSession) {
        logger.debug("watch: Reachability changed to \(isWatchReachable())")
        DispatchQueue.main.async {
            self.setLowFpsImage()
            self.sendSettingsToWatch()
            self.sendZoomToWatch(x: self.zoomX)
            self.sendZoomPresetsToWatch()
            self.sendZoomPresetToWatch()
            self.sendScenesToWatch()
            self.sendSceneToWatch()
            self.sendWorkoutToWatch()
            self.resetWorkoutStats()
            if self.isRemoteControlAssistantConnected() {
                if let general = self.remoteControlGeneral {
                    if let thermalState = general.flame?.toThermalState() {
                        self.sendThermalStateToWatch(thermalState: thermalState)
                    }
                    if let isLive = general.isLive {
                        self.sendIsLiveToWatch(isLive: isLive)
                    }
                    if let isRecording = general.isRecording {
                        self.sendIsRecordingToWatch(isRecording: isRecording)
                    }
                    if let isMuted = general.isMuted {
                        self.sendIsMutedToWatch(isMuteOn: isMuted)
                    }
                }
                if let topRight = self.remoteControlTopRight {
                    if let audioInfo = topRight.audioInfo {
                        self.sendAudioLevelToWatch(audioLevel: audioInfo.audioLevel.toFloat())
                    }
                }
            } else {
                self.trySendNextChatPostToWatch()
                self.sendAudioLevelToWatch(audioLevel: self.audioLevel)
                self.sendThermalStateToWatch(thermalState: self.thermalState)
                self.sendIsLiveToWatch(isLive: self.isLive)
                self.sendIsRecordingToWatch(isRecording: self.isRecording)
                self.sendIsMutedToWatch(isMuteOn: self.isMuteOn)
                self.sendViewerCountWatch()
                self.sendScoreboardPlayersToWatch()
                let sceneWidgets = self.getSelectedScene()?.widgets ?? []
                for id in self.padelScoreboardEffects.keys {
                    if let sceneWidget = sceneWidgets.first(where: { $0.widgetId == id }),
                       sceneWidget.enabled,
                       let scoreboard = self.findWidget(id: id)?.scoreboard
                    {
                        self.sendUpdatePadelScoreboardToWatch(id: id, scoreboard: scoreboard)
                    } else {
                        self.sendRemovePadelScoreboardToWatch(id: id)
                    }
                }
            }
        }
    }

    private func makePng(_ uiImage: UIImage) -> Data {
        for height in [35.0, 25.0, 15.0] {
            guard let pngData = uiImage.resize(height: height).pngData() else {
                return Data()
            }
            if pngData.count < 15000 {
                return pngData
            }
        }
        return Data()
    }

    private func handleGetImage(_ data: Any, _ replyHandler: @escaping ([String: Any]) -> Void) {
        guard let urlString = data as? String else {
            replyHandler(["data": Data()])
            return
        }
        guard let url = URL(string: urlString) else {
            replyHandler(["data": Data()])
            return
        }
        URLSession.shared.dataTask(with: URLRequest(url: url)) { data, response, _ in
            guard let response = response?.http else {
                replyHandler(["data": Data()])
                return
            }
            guard response.isSuccessful, let data else {
                replyHandler(["data": Data()])
                return
            }
            guard let uiImage = UIImage(data: data) else {
                replyHandler(["data": Data()])
                return
            }
            replyHandler(["data": self.makePng(uiImage)])
        }
        .resume()
    }

    private func handleSetIsLive(_ data: Any) {
        guard let value = data as? Bool else {
            return
        }
        DispatchQueue.main.async {
            if self.isRemoteControlAssistantConnected() {
                self.remoteControlAssistantSetStream(on: value) {
                    DispatchQueue.main.async {
                        self.updateRemoteControlAssistantStatus()
                    }
                }
            } else {
                if value {
                    self.startStream()
                } else {
                    self.stopStream()
                }
            }
        }
    }

    private func handleSetIsRecording(_ data: Any) {
        guard let value = data as? Bool else {
            return
        }
        DispatchQueue.main.async {
            if self.isRemoteControlAssistantConnected() {
                self.remoteControlAssistantSetRecord(on: value) {
                    DispatchQueue.main.async {
                        self.updateRemoteControlAssistantStatus()
                    }
                }
            } else {
                if value {
                    self.startRecording()
                } else {
                    self.stopRecording()
                }
            }
        }
    }

    private func handleSetIsMuted(_ data: Any) {
        guard let value = data as? Bool else {
            return
        }
        DispatchQueue.main.async {
            if self.isRemoteControlAssistantConnected() {
                self.remoteControlAssistantSetMute(on: value) {
                    DispatchQueue.main.async {
                        self.updateRemoteControlAssistantStatus()
                    }
                }
            } else {
                self.setIsMuted(value: value)
            }
        }
    }

    private func handleSkipCurrentChatTextToSpeechMessage(_: Any) {
        DispatchQueue.main.async {
            self.chatTextToSpeech.skipCurrentMessage()
        }
    }

    private func handleSetZoomMessage(_ data: Any) {
        guard let x = data as? Float else {
            return
        }
        DispatchQueue.main.async {
            self.clearZoomId()
            if let x = self.setCameraZoomX(x: x, rate: self.database.zoom.speed!) {
                self.setZoomX(x: x)
            }
        }
    }

    private func handleSetZoomPresetMessage(_ data: Any) {
        guard let data = data as? String else {
            return
        }
        guard let zoomPresetId = UUID(uuidString: data) else {
            return
        }
        DispatchQueue.main.async {
            self.setCameraZoomPreset(id: zoomPresetId)
        }
    }

    private func handleSetSceneMessage(_ data: Any) {
        guard let data = data as? String else {
            return
        }
        guard let sceneId = UUID(uuidString: data) else {
            return
        }
        DispatchQueue.main.async {
            self.selectScene(id: sceneId)
        }
    }

    private func handleUpdateWorkoutStats(_ data: Any) {
        guard let data = data as? Data else {
            return
        }
        guard let stats = try? JSONDecoder().decode(WatchProtocolWorkoutStats.self, from: data) else {
            return
        }
        DispatchQueue.main.async {
            if let heartRate = stats.heartRate {
                self.workoutHeartRate = heartRate
            }
            if let activeEnergyBurned = stats.activeEnergyBurned {
                self.workoutActiveEnergyBurned = activeEnergyBurned
            }
            if let distance = stats.distance {
                self.workoutDistance = distance
            }
            if let stepCount = stats.stepCount {
                self.workoutStepCount = stepCount
            }
            if let power = stats.power {
                self.workoutPower = power
            }
        }
    }

    private func handleUpdatePadelScoreboard(_ data: Any) {
        guard let data = data as? Data else {
            return
        }
        guard let scoreboard = try? JSONDecoder().decode(WatchProtocolPadelScoreboard.self, from: data) else {
            return
        }
        DispatchQueue.main.async {
            guard let widget = self.findWidget(id: scoreboard.id) else {
                return
            }
            widget.scoreboard!.padel.score = scoreboard.score.map {
                let score = SettingsWidgetScoreboardScore()
                score.home = $0.home
                score.away = $0.away
                return score
            }
            widget.scoreboard!.padel.homePlayer1 = scoreboard.home[0]
            if scoreboard.home.count > 1 {
                widget.scoreboard!.padel.homePlayer2 = scoreboard.home[1]
            }
            widget.scoreboard!.padel.awayPlayer1 = scoreboard.away[0]
            if scoreboard.away.count > 1 {
                widget.scoreboard!.padel.awayPlayer2 = scoreboard.away[1]
            }
            guard let padelScoreboardEffect = self.padelScoreboardEffects[scoreboard.id] else {
                return
            }
            padelScoreboardEffect
                .update(scoreboard: self.padelScoreboardSettingsToEffect(widget.scoreboard!.padel))
        }
    }

    private func handleCreateStreamMarker() {
        createStreamMarker()
    }

    func session(
        _: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let (type, data) = WatchMessageFromWatch.unpack(message) else {
            logger.info("watch: Invalid message")
            replyHandler([:])
            return
        }
        switch type {
        case .getImage:
            handleGetImage(data, replyHandler)
        default:
            replyHandler([:])
        }
    }

    func session(_: WCSession, didReceiveMessage message: [String: Any]) {
        guard let (type, data) = WatchMessageFromWatch.unpack(message) else {
            logger.info("watch: Invalid message")
            return
        }
        switch type {
        case .setIsLive:
            handleSetIsLive(data)
        case .setIsRecording:
            handleSetIsRecording(data)
        case .setIsMuted:
            handleSetIsMuted(data)
        case .keepAlive:
            break
        case .skipCurrentChatTextToSpeechMessage:
            handleSkipCurrentChatTextToSpeechMessage(data)
        case .setZoom:
            handleSetZoomMessage(data)
        case .setZoomPreset:
            handleSetZoomPresetMessage(data)
        case .setScene:
            handleSetSceneMessage(data)
        case .updateWorkoutStats:
            handleUpdateWorkoutStats(data)
        case .updatePadelScoreboard:
            handleUpdatePadelScoreboard(data)
        case .createStreamMarker:
            handleCreateStreamMarker()
        default:
            break
        }
    }
}

extension Model {
    private func cleanWizardUrl(url: String) -> String {
        var cleanedUrl = cleanUrl(url: url)
        if isValidUrl(url: cleanedUrl) != nil {
            cleanedUrl = defaultStreamUrl
            makeErrorToast(
                title: String(localized: "Malformed stream URL"),
                subTitle: String(localized: "Using default")
            )
        }
        return cleanedUrl
    }

    private func createStreamFromWizardCustomUrl() -> String? {
        switch wizardCustomProtocol {
        case .none:
            break
        case .srt:
            if var urlComponents = URLComponents(string: wizardCustomSrtUrl.trim()) {
                urlComponents.queryItems = [
                    URLQueryItem(name: "streamid", value: wizardCustomSrtStreamId.trim()),
                ]
                if let fullUrl = urlComponents.url {
                    return fullUrl.absoluteString
                }
            }
        case .rtmp:
            let rtmpUrl = wizardCustomRtmpUrl
                .trim()
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return "\(rtmpUrl)/\(wizardCustomRtmpStreamKey.trim())"
        case .rist:
            return wizardCustomRistUrl.trim()
        }
        return nil
    }

    private func createStreamFromWizardUrl() -> String {
        var url = defaultStreamUrl
        if wizardPlatform == .custom {
            if let customUrl = createStreamFromWizardCustomUrl() {
                url = customUrl
            }
        } else {
            switch wizardNetworkSetup {
            case .none:
                break
            case .obs:
                url = "srt://\(wizardObsAddress):\(wizardObsPort)"
            case .belaboxCloudObs:
                url = wizardBelaboxUrl
            case .irlToolkit:
                let ingestUrl = wizardDirectIngest.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if let directUrl = URL(string: "\(ingestUrl)/\(wizardDirectStreamKey)") {
                    url = "irltk:///?url=\(directUrl)"
                }
            case .direct:
                let ingestUrl = wizardDirectIngest.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                url = "\(ingestUrl)/\(wizardDirectStreamKey)"
            case .myServers:
                if let customUrl = createStreamFromWizardCustomUrl() {
                    url = customUrl
                }
            }
        }
        return cleanWizardUrl(url: url)
    }

    func createStreamFromWizard() {
        let stream = SettingsStream(name: wizardName.trim())
        if wizardPlatform != .custom {
            if wizardNetworkSetup != .direct {
                if wizardObsRemoteControlEnabled {
                    let url = cleanUrl(url: wizardObsRemoteControlUrl.trim())
                    if isValidWebSocketUrl(url: url) == nil {
                        stream.obsWebSocketEnabled = true
                        stream.obsWebSocketUrl = url
                        stream.obsWebSocketPassword = wizardObsRemoteControlPassword.trim()
                        stream.obsSourceName = wizardObsRemoteControlSourceName.trim()
                        stream.obsBrbScene = wizardObsRemoteControlBrbScene.trim()
                    }
                }
            }
        }
        switch wizardPlatform {
        case .twitch:
            stream.twitchChannelName = wizardTwitchChannelName.trim()
            stream.twitchChannelId = wizardTwitchChannelId.trim()
            stream.twitchAccessToken = wizardTwitchAccessToken
            stream.twitchLoggedIn = wizardTwitchLoggedIn
        case .kick:
            stream.kickChannelName = wizardKickChannelName.trim()
        case .youTube:
            if !wizardYouTubeVideoId.isEmpty {
                stream.youTubeVideoId = wizardYouTubeVideoId.trim()
            }
        case .afreecaTv:
            if !wizardAfreecaTvChannelName.isEmpty, !wizardAfreecsTvCStreamId.isEmpty {
                stream.afreecaTvChannelName = wizardAfreecaTvChannelName.trim()
                stream.afreecaTvStreamId = wizardAfreecsTvCStreamId.trim()
            }
        case .custom:
            break
        }
        stream.chat!.bttvEmotes = wizardChatBttv
        stream.chat!.ffzEmotes = wizardChatFfz
        stream.chat!.seventvEmotes = wizardChatSeventv
        stream.url = createStreamFromWizardUrl()
        switch wizardNetworkSetup {
        case .none:
            stream.codec = wizardCustomProtocol.toDefaultCodec()
        case .obs:
            stream.codec = .h265hevc
        case .belaboxCloudObs:
            stream.codec = .h265hevc
        case .irlToolkit:
            stream.codec = .h265hevc
        case .direct:
            stream.codec = .h264avc
        case .myServers:
            stream.codec = wizardCustomProtocol.toDefaultCodec()
        }
        stream.audioBitrate = 128_000
        database.streams.append(stream)
        setCurrentStream(stream: stream)
        reloadStream()
        sceneUpdated()
    }

    func resetWizard() {
        wizardPlatform = .custom
        wizardNetworkSetup = .none
        wizardName = ""
        wizardTwitchChannelName = ""
        wizardTwitchChannelId = ""
        wizardTwitchAccessToken = ""
        wizardKickChannelName = ""
        wizardYouTubeVideoId = ""
        wizardAfreecaTvChannelName = ""
        wizardAfreecsTvCStreamId = ""
        wizardObsAddress = ""
        wizardObsPort = ""
        wizardObsRemoteControlEnabled = false
        wizardObsRemoteControlUrl = ""
        wizardObsRemoteControlPassword = ""
        wizardDirectIngest = ""
        wizardDirectStreamKey = ""
        wizardChatBttv = true
        wizardChatFfz = true
        wizardChatSeventv = true
        wizardBelaboxUrl = ""
    }

    private func handleSettingsUrlsInWizard(settings: MoblinSettingsUrl) {
        switch wizardNetworkSetup {
        case .none:
            break
        case .obs:
            break
        case .belaboxCloudObs:
            for stream in settings.streams ?? [] {
                wizardName = stream.name
                wizardBelaboxUrl = stream.url
            }
        case .irlToolkit:
            break
        case .direct:
            break
        case .myServers:
            break
        }
    }
}

extension Model {
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            let bluetoothOption: AVAudioSession.CategoryOptions
            if database.debug.bluetoothOutputOnly! {
                bluetoothOption = .allowBluetoothA2DP
            } else {
                bluetoothOption = .allowBluetooth
            }
            try session.setCategory(
                .playAndRecord,
                options: [.mixWithOthers, bluetoothOption, .defaultToSpeaker]
            )
            try session.setActive(true)
        } catch {
            logger.error("app: Session error \(error)")
        }
        setAllowHapticsAndSystemSoundsDuringRecording()
    }

    private func teardownAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            logger.info("Failed to stop audio session with error: \(error)")
        }
    }

    @objc func handleAudioRouteChange(notification _: Notification) {
        guard let inputPort = AVAudioSession.sharedInstance().currentRoute.inputs.first
        else {
            return
        }
        var newMic: Mic
        if let dataSource = inputPort.preferredDataSource {
            var name: String
            var builtInMicOrientation: SettingsMic?
            if inputPort.portType == .builtInMic {
                name = dataSource.dataSourceName
                builtInMicOrientation = getBuiltInMicOrientation(orientation: dataSource.orientation)
            } else {
                name = "\(inputPort.portName): \(dataSource.dataSourceName)"
            }
            newMic = Mic(
                name: name,
                inputUid: inputPort.uid,
                dataSourceID: dataSource.dataSourceID,
                builtInOrientation: builtInMicOrientation
            )
        } else if inputPort.portType != .builtInMic {
            newMic = Mic(name: inputPort.portName, inputUid: inputPort.uid)
        } else {
            return
        }
        if newMic == micChange {
            return
        }
        if micChange != noMic {
            makeToast(title: newMic.name)
        }
        logger.info("Mic: \(newMic.name)")
        currentMic = newMic
        micChange = newMic
    }

    private func getBuiltInMicOrientation(orientation: AVAudioSession.Orientation?) -> SettingsMic? {
        guard let orientation else {
            return nil
        }
        switch orientation {
        case .bottom:
            return .bottom
        case .front:
            return .front
        case .back:
            return .back
        default:
            return nil
        }
    }

    func listMics() -> [Mic] {
        var mics: [Mic] = []
        let session = AVAudioSession.sharedInstance()
        for inputPort in session.availableInputs ?? [] {
            if let dataSources = inputPort.dataSources, !dataSources.isEmpty {
                for dataSource in dataSources {
                    var name: String
                    var builtInOrientation: SettingsMic?
                    if inputPort.portType == .builtInMic {
                        name = dataSource.dataSourceName
                        builtInOrientation = getBuiltInMicOrientation(orientation: dataSource.orientation)
                    } else {
                        name = "\(inputPort.portName): \(dataSource.dataSourceName)"
                    }
                    mics.append(Mic(
                        name: name,
                        inputUid: inputPort.uid,
                        dataSourceID: dataSource.dataSourceID,
                        builtInOrientation: builtInOrientation
                    ))
                }
            } else {
                mics.append(Mic(name: inputPort.portName, inputUid: inputPort.uid))
            }
        }
        for rtmpCamera in rtmpCameras() {
            guard let stream = getRtmpStream(camera: rtmpCamera) else {
                continue
            }
            if isRtmpStreamConnected(streamKey: stream.streamKey) {
                mics.append(Mic(
                    name: rtmpCamera,
                    inputUid: stream.id.uuidString,
                    builtInOrientation: nil
                ))
            }
        }
        for srtlaCamera in srtlaCameras() {
            guard let stream = getSrtlaStream(camera: srtlaCamera) else {
                continue
            }
            if isSrtlaStreamConnected(streamId: stream.streamId) {
                mics.append(Mic(
                    name: srtlaCamera,
                    inputUid: stream.id.uuidString,
                    builtInOrientation: nil
                ))
            }
        }
        for mediaPlayerCamera in mediaPlayerCameras() {
            guard let mediaPlayer = getMediaPlayer(camera: mediaPlayerCamera) else {
                continue
            }
            mics.append(Mic(
                name: mediaPlayerCamera,
                inputUid: mediaPlayer.id.uuidString,
                builtInOrientation: nil
            ))
        }
        return mics
    }

    private func setMic() {
        var wantedOrientation: AVAudioSession.Orientation
        switch database.mic {
        case .bottom:
            wantedOrientation = .bottom
        case .front:
            wantedOrientation = .front
        case .back:
            wantedOrientation = .back
        case .top:
            wantedOrientation = .top
        }
        let session = AVAudioSession.sharedInstance()
        for inputPort in session.availableInputs ?? [] {
            if inputPort.portType != .builtInMic {
                continue
            }
            if let dataSources = inputPort.dataSources, !dataSources.isEmpty {
                for dataSource in dataSources where dataSource.orientation == wantedOrientation {
                    do {
                        try setBuiltInMicAudioMode(dataSource: dataSource)
                        try inputPort.setPreferredDataSource(dataSource)
                    } catch {
                        logger.error("Failed to set mic as preferred with error \(error)")
                    }
                }
            }
        }
    }

    func setMicFromSettings() {
        let mics = listMics()
        if let mic = mics.first(where: { mic in mic.builtInOrientation == database.mic }) {
            selectMic(mic: mic)
        } else if let mic = mics.first {
            selectMic(mic: mic)
        } else {
            logger.error("No mic to select from settings.")
        }
    }

    func selectMicById(id: String) {
        guard let mic = listMics().first(where: { mic in mic.id == id }) else {
            logger.info("Mic with id \(id) not found")
            makeErrorToast(
                title: String(localized: "Mic not found"),
                subTitle: String(localized: "Mic id \(id)")
            )
            return
        }
        selectMic(mic: mic)
    }

    private func selectMic(mic: Mic) {
        if isRtmpMic(mic: mic) {
            selectMicRtmp(mic: mic)
        } else if isSrtlaMic(mic: mic) {
            selectMicSrtla(mic: mic)
        } else if isMediaPlayerMic(mic: mic) {
            selectMicMediaPlayer(mic: mic)
        } else {
            selectMicDefault(mic: mic)
        }
    }

    private func isRtmpMic(mic: Mic) -> Bool {
        guard let id = UUID(uuidString: mic.inputUid) else {
            return false
        }
        return getRtmpStream(id: id) != nil
    }

    private func isSrtlaMic(mic: Mic) -> Bool {
        guard let id = UUID(uuidString: mic.inputUid) else {
            return false
        }
        return getSrtlaStream(id: id) != nil
    }

    private func isMediaPlayerMic(mic: Mic) -> Bool {
        guard let id = UUID(uuidString: mic.inputUid) else {
            return false
        }
        return getMediaPlayer(id: id) != nil
    }

    private func selectMicRtmp(mic: Mic) {
        currentMic = mic
        let cameraId = getRtmpStream(camera: mic.name)?.id ?? .init()
        media.attachReplaceAudio(cameraId: cameraId)
        remoteControlStreamer?.stateChanged(state: RemoteControlState(mic: mic.id))
    }

    private func selectMicSrtla(mic: Mic) {
        currentMic = mic
        let cameraId = getSrtlaStream(camera: mic.name)?.id ?? .init()
        media.attachReplaceAudio(cameraId: cameraId)
        remoteControlStreamer?.stateChanged(state: RemoteControlState(mic: mic.id))
    }

    private func selectMicMediaPlayer(mic: Mic) {
        currentMic = mic
        let cameraId = getMediaPlayer(camera: mic.name)?.id ?? .init()
        media.attachReplaceAudio(cameraId: cameraId)
        remoteControlStreamer?.stateChanged(state: RemoteControlState(mic: mic.id))
    }

    private func selectMicDefault(mic: Mic) {
        media.attachReplaceAudio(cameraId: nil)
        let session = AVAudioSession.sharedInstance()
        do {
            for inputPort in session.availableInputs ?? [] {
                if mic.inputUid != inputPort.uid {
                    continue
                }
                try session.setPreferredInput(inputPort)
                if let dataSourceID = mic.dataSourceID {
                    for dataSource in inputPort.dataSources ?? [] {
                        if dataSourceID != dataSource.dataSourceID {
                            continue
                        }
                        try setBuiltInMicAudioMode(dataSource: dataSource)
                        try session.setInputDataSource(dataSource)
                    }
                }
            }
            currentMic = mic
            saveSelectedMic(mic: mic)
            remoteControlStreamer?.stateChanged(state: RemoteControlState(mic: mic.id))
        } catch {
            logger.error("Failed to select mic: \(error)")
            makeErrorToast(
                title: String(localized: "Failed to select mic"),
                subTitle: error.localizedDescription
            )
        }
    }

    private func saveSelectedMic(mic: Mic) {
        guard let orientation = mic.builtInOrientation, database.mic != orientation else {
            return
        }
        database.mic = orientation
    }

    private func setBuiltInMicAudioMode(dataSource: AVAudioSessionDataSourceDescription) throws {
        if database.debug.preferStereoMic! {
            if dataSource.supportedPolarPatterns?.contains(.stereo) == true {
                try dataSource.setPreferredPolarPattern(.stereo)
            } else {
                try dataSource.setPreferredPolarPattern(.none)
            }
            setupAudioSession()
            media.attachAudio(device: AVCaptureDevice.default(for: .audio))
        } else {
            try dataSource.setPreferredPolarPattern(.none)
        }
    }
}

extension Model {
    private func updateLocation() {
        var newLocation = locationManager.status()
        if let realtimeIrl {
            newLocation += realtimeIrl.status()
        }
        if location != newLocation {
            location = newLocation
        }
    }

    func reloadLocation() {
        locationManager.stop()
        if isLocationEnabled() {
            locationManager.start(onUpdate: handleLocationUpdate)
        }
        reloadRealtimeIrl()
    }

    func resetDistance() {
        distance = 0.0
        latestKnownLocation = nil
    }

    func isLocationEnabled() -> Bool {
        return database.location!.enabled
    }

    private func handleLocationUpdate(location: CLLocation) {
        guard isLive else {
            return
        }
        guard !isLocationInPrivacyRegion(location: location) else {
            return
        }
        realtimeIrl?.update(location: location)
    }

    private func isLocationInPrivacyRegion(location: CLLocation) -> Bool {
        for region in database.location!.privacyRegions
            where region.contains(coordinate: location.coordinate)
        {
            return true
        }
        return false
    }

    func getLatestKnownLocation() -> (Double, Double)? {
        if let location = locationManager.getLatestKnownLocation() {
            return (location.coordinate.latitude, location.coordinate.longitude)
        } else {
            return nil
        }
    }

    func isRealtimeIrlConfigured() -> Bool {
        return stream.realtimeIrlEnabled! && !stream.realtimeIrlPushKey!.isEmpty
    }

    func reloadRealtimeIrl() {
        realtimeIrl?.stop()
        realtimeIrl = nil
        if isRealtimeIrlConfigured() {
            realtimeIrl = RealtimeIrl(pushKey: stream.realtimeIrlPushKey!)
        }
    }
}

extension Model {
    func toggleDrawOnStream() {
        showDrawOnStream.toggle()
    }

    func drawOnStreamLineComplete() {
        drawOnStreamEffect.updateOverlay(
            videoSize: media.getVideoSize(),
            size: drawOnStreamSize,
            lines: drawOnStreamLines,
            mirror: isFrontCameraSelected && !database.mirrorFrontCameraOnStream!
        )
        media.registerEffect(drawOnStreamEffect)
    }

    func drawOnStreamWipe() {
        drawOnStreamLines = []
        drawOnStreamEffect.updateOverlay(
            videoSize: media.getVideoSize(),
            size: drawOnStreamSize,
            lines: drawOnStreamLines,
            mirror: isFrontCameraSelected && !database.mirrorFrontCameraOnStream!
        )
        media.unregisterEffect(drawOnStreamEffect)
    }

    func drawOnStreamUndo() {
        guard !drawOnStreamLines.isEmpty else {
            return
        }
        drawOnStreamLines.removeLast()
        drawOnStreamEffect.updateOverlay(
            videoSize: media.getVideoSize(),
            size: drawOnStreamSize,
            lines: drawOnStreamLines,
            mirror: isFrontCameraSelected && !database.mirrorFrontCameraOnStream!
        )
        if drawOnStreamLines.isEmpty {
            media.unregisterEffect(drawOnStreamEffect)
        }
    }
}

extension Model {
    private func getWebBrowserUrl() -> URL? {
        if let url = URL(string: webBrowserUrl), let scehme = url.scheme, !scehme.isEmpty {
            return url
        }
        if webBrowserUrl.contains("."), let url = URL(string: "https://\(webBrowserUrl)") {
            return url
        }
        return URL(string: "https://www.google.com/search?q=\(webBrowserUrl)")
    }

    func loadWebBrowserUrl() {
        guard let url = getWebBrowserUrl() else {
            return
        }
        webBrowser?.load(URLRequest(url: url))
    }

    func loadWebBrowserHome() {
        webBrowserUrl = database.webBrowser!.home
        loadWebBrowserUrl()
    }

    func getWebBrowser() -> WKWebView {
        if webBrowser == nil {
            webBrowser = WKWebView()
            webBrowser?.navigationDelegate = self
            DispatchQueue.main.async {
                self.loadWebBrowserHome()
            }
        }
        return webBrowser!
    }
}

extension Model: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        webBrowserUrl = webView.url?.absoluteString ?? ""
    }
}

extension Model {
    func setFocusPointOfInterest(focusPoint: CGPoint) {
        guard
            let device = cameraDevice, device.isFocusPointOfInterestSupported
        else {
            logger.warning("Tap to focus not supported for this camera")
            makeErrorToast(title: String(localized: "Tap to focus not supported for this camera"))
            return
        }
        var focusPointOfInterest = focusPoint
        if stream.portrait! {
            focusPointOfInterest.x = focusPoint.y
            focusPointOfInterest.y = 1 - focusPoint.x
        } else if getOrientation() == .landscapeRight {
            focusPointOfInterest.x = 1 - focusPoint.x
            focusPointOfInterest.y = 1 - focusPoint.y
        }
        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = focusPointOfInterest
            device.focusMode = .autoFocus
            device.exposurePointOfInterest = focusPointOfInterest
            device.exposureMode = .autoExpose
            device.unlockForConfiguration()
            manualFocusPoint = focusPoint
            startMotionDetection()
        } catch let error as NSError {
            logger.error("while locking device for focusPointOfInterest: \(error)")
        }
        manualFocusesEnabled[device] = false
        manualFocusEnabled = false
    }

    func setAutoFocus() {
        stopMotionDetection()
        guard let device = cameraDevice, device.isFocusPointOfInterestSupported else {
            return
        }
        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            device.focusMode = .continuousAutoFocus
            device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
            device.exposureMode = .continuousAutoExposure
            device.unlockForConfiguration()
            manualFocusPoint = nil
        } catch let error as NSError {
            logger.error("while locking device for focusPointOfInterest: \(error)")
        }
        manualFocusesEnabled[device] = false
        manualFocusEnabled = false
    }

    func setManualFocus(lensPosition: Float) {
        guard
            let device = cameraDevice, device.isLockingFocusWithCustomLensPositionSupported
        else {
            makeErrorToast(title: String(localized: "Manual focus not supported for this camera"))
            return
        }
        stopMotionDetection()
        do {
            try device.lockForConfiguration()
            device.setFocusModeLocked(lensPosition: lensPosition)
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.error("while locking device for manual focus: \(error)")
        }
        manualFocusPoint = nil
        manualFocusesEnabled[device] = true
        manualFocusEnabled = true
        manualFocuses[device] = lensPosition
    }

    private func setFocusAfterCameraAttach() {
        guard let device = cameraDevice else {
            return
        }
        manualFocus = manualFocuses[device] ?? device.lensPosition
        manualFocusEnabled = manualFocusesEnabled[device] ?? false
        if !manualFocusEnabled {
            setAutoFocus()
        }
        if focusObservation != nil {
            stopObservingFocus()
            startObservingFocus()
        }
    }

    func isCameraSupportingManualFocus() -> Bool {
        if let device = cameraDevice, device.isLockingFocusWithCustomLensPositionSupported {
            return true
        } else {
            return false
        }
    }

    func startObservingFocus() {
        guard let device = cameraDevice else {
            return
        }
        manualFocus = device.lensPosition
        focusObservation = device.observe(\.lensPosition) { [weak self] _, _ in
            guard let self else {
                return
            }
            DispatchQueue.main.async {
                guard !self.editingManualFocus else {
                    return
                }
                self.manualFocuses[device] = device.lensPosition
                self.manualFocus = device.lensPosition
            }
        }
    }

    func stopObservingFocus() {
        focusObservation = nil
    }
}

extension Model {
    func setAutoIso() {
        guard
            let device = cameraDevice, device.isExposureModeSupported(.continuousAutoExposure)
        else {
            makeErrorToast(title: String(localized: "Continuous auto exposure not supported for this camera"))
            return
        }
        do {
            try device.lockForConfiguration()
            device.exposureMode = .continuousAutoExposure
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.error("while locking device for continuous auto exposure: \(error)")
        }
        manualIsosEnabled[device] = false
        manualIsoEnabled = false
    }

    func setManualIso(factor: Float) {
        guard
            let device = cameraDevice, device.isExposureModeSupported(.custom)
        else {
            makeErrorToast(title: String(localized: "Manual exposure not supported for this camera"))
            return
        }
        let iso = factorToIso(device: device, factor: factor)
        do {
            try device.lockForConfiguration()
            device.setExposureModeCustom(duration: AVCaptureDevice.currentExposureDuration, iso: iso) { _ in
            }
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.error("while locking device for manual exposure: \(error)")
        }
        manualIsosEnabled[device] = true
        manualIsoEnabled = true
        manualIsos[device] = iso
    }

    private func setIsoAfterCameraAttach(device: AVCaptureDevice) {
        manualIso = manualIsos[device] ?? factorFromIso(device: device, iso: device.iso)
        manualIsoEnabled = manualIsosEnabled[device] ?? false
        if manualIsoEnabled {
            setManualIso(factor: manualIso)
        }
        if isoObservation != nil {
            stopObservingIso()
            startObservingIso()
        }
    }

    func isCameraSupportingManualIso() -> Bool {
        if let device = cameraDevice, device.isExposureModeSupported(.custom) {
            return true
        } else {
            return false
        }
    }

    func startObservingIso() {
        guard let device = cameraDevice else {
            return
        }
        manualIso = factorFromIso(device: device, iso: device.iso)
        isoObservation = device.observe(\.iso) { [weak self] _, _ in
            guard let self else {
                return
            }
            DispatchQueue.main.async {
                guard !self.editingManualIso else {
                    return
                }
                let iso = factorFromIso(device: device, iso: device.iso)
                self.manualIsos[device] = iso
                self.manualIso = iso
            }
        }
    }

    func stopObservingIso() {
        isoObservation = nil
    }
}

extension Model {
    func setAutoWhiteBalance() {
        guard
            let device = cameraDevice, device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance)
        else {
            makeErrorToast(
                title: String(localized: "Continuous auto white balance not supported for this camera")
            )
            return
        }
        do {
            try device.lockForConfiguration()
            device.whiteBalanceMode = .continuousAutoWhiteBalance
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.error("while locking device for continuous auto white balance: \(error)")
        }
        manualWhiteBalancesEnabled[device] = false
        manualWhiteBalanceEnabled = false
    }

    func setManualWhiteBalance(factor: Float) {
        guard
            let device = cameraDevice, device.isLockingWhiteBalanceWithCustomDeviceGainsSupported
        else {
            makeErrorToast(title: String(localized: "Manual white balance not supported for this camera"))
            return
        }
        do {
            try device.lockForConfiguration()
            device.setWhiteBalanceModeLocked(with: factorToWhiteBalance(device: device, factor: factor))
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.error("while locking device for manual white balance: \(error)")
        }
        manualWhiteBalancesEnabled[device] = true
        manualWhiteBalanceEnabled = true
        manualWhiteBalances[device] = factor
    }

    private func setWhiteBalanceAfterCameraAttach(device: AVCaptureDevice) {
        manualWhiteBalance = manualWhiteBalances[device] ?? 0.5
        manualWhiteBalanceEnabled = manualWhiteBalancesEnabled[device] ?? false
        if manualWhiteBalanceEnabled {
            setManualWhiteBalance(factor: manualWhiteBalance)
        }
        if whiteBalanceObservation != nil {
            stopObservingWhiteBalance()
            startObservingWhiteBalance()
        }
    }

    func isCameraSupportingManualWhiteBalance() -> Bool {
        if let device = cameraDevice, device.isLockingWhiteBalanceWithCustomDeviceGainsSupported {
            return true
        } else {
            return false
        }
    }

    func startObservingWhiteBalance() {
        guard let device = cameraDevice else {
            return
        }
        manualWhiteBalance = factorFromWhiteBalance(
            device: device,
            gains: device.deviceWhiteBalanceGains.clamped(maxGain: device.maxWhiteBalanceGain)
        )
        whiteBalanceObservation = device.observe(\.deviceWhiteBalanceGains) { [weak self] _, _ in
            guard let self else {
                return
            }
            DispatchQueue.main.async {
                guard !self.editingManualWhiteBalance else {
                    return
                }
                let factor = factorFromWhiteBalance(
                    device: device,
                    gains: device.deviceWhiteBalanceGains.clamped(maxGain: device.maxWhiteBalanceGain)
                )
                self.manualWhiteBalances[device] = factor
                self.manualWhiteBalance = factor
            }
        }
    }

    func stopObservingWhiteBalance() {
        whiteBalanceObservation = nil
    }
}

extension Model: SampleBufferReceiverDelegate {
    func senderConnected() {
        DispatchQueue.main.async {
            self.handleSampleBufferSenderConnected()
        }
    }

    func senderDisconnected() {
        DispatchQueue.main.async {
            self.handleSampleBufferSenderDisconnected()
        }
    }

    func handleSampleBuffer(type: RPSampleBufferType, sampleBuffer: CMSampleBuffer) {
        handleSampleBufferSenderBuffer(type, sampleBuffer)
    }
}

extension Model {
    private func handleSampleBufferSenderConnected() {
        makeToast(title: String(localized: "Screen capture started"))
        media.addReplaceVideo(
            cameraId: screenCaptureCameraId,
            name: "Screen capture",
            latency: screenRecordingLatency
        )
    }

    private func handleSampleBufferSenderDisconnected() {
        makeToast(title: String(localized: "Screen capture stopped"))
        media.removeReplaceVideo(cameraId: screenCaptureCameraId)
    }

    private func handleSampleBufferSenderBuffer(_ type: RPSampleBufferType, _ sampleBuffer: CMSampleBuffer) {
        switch type {
        case .video:
            media.addReplaceVideoSampleBuffer(cameraId: screenCaptureCameraId, sampleBuffer: sampleBuffer)
        default:
            break
        }
    }
}

extension Model: RtmpServerDelegate {
    func rtmpServerOnPublishStart(streamKey: String) {
        handleRtmpServerPublishStart(streamKey: streamKey)
    }

    func rtmpServerOnPublishStop(streamKey: String) {
        handleRtmpServerPublishStop(streamKey: streamKey)
    }

    func rtmpServerOnVideoBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        handleRtmpServerFrame(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func rtmpServerOnAudioBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        handleRtmpServerAudioBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func rtmpServerSetTargetLatencies(
        cameraId: UUID,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    ) {
        media.setReplaceVideoTargetLatency(cameraId: cameraId, latency: videoTargetLatency)
        media.setReplaceAudioTargetLatency(cameraId: cameraId, latency: audioTargetLatency)
    }
}

extension Model: SrtlaServerDelegate {
    func srtlaServerOnClientStart(streamId: String, latency _: Double) {
        DispatchQueue.main.async {
            let camera = self.getSrtlaStream(streamId: streamId)?.camera() ?? srtlaCamera(name: "Unknown")
            self.makeToast(title: String(localized: "\(camera) connected"))
            guard let stream = self.getSrtlaStream(streamId: streamId) else {
                return
            }
            let name = "SRTLA \(camera)"
            let latency = srtServerClientLatency
            self.media.addReplaceVideo(cameraId: stream.id, name: name, latency: latency)
            self.media.addReplaceAudio(cameraId: stream.id, name: name, latency: latency)
            if stream.autoSelectMic! {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self.selectMicById(id: "\(stream.id) 0")
                }
            }
        }
    }

    func srtlaServerOnClientStop(streamId: String) {
        DispatchQueue.main.async {
            let camera = self.getSrtlaStream(streamId: streamId)?.camera() ?? srtlaCamera(name: "Unknown")
            self.makeToast(title: String(localized: "\(camera) disconnected"))
            guard let stream = self.getSrtlaStream(streamId: streamId) else {
                return
            }
            self.media.removeReplaceVideo(cameraId: stream.id)
            self.media.removeReplaceAudio(cameraId: stream.id)
            if self.currentMic.id == "\(stream.id) 0" {
                self.setMicFromSettings()
            }
        }
    }

    func srtlaServerOnAudioBuffer(streamId: String, sampleBuffer: CMSampleBuffer) {
        guard let cameraId = getSrtlaStream(streamId: streamId)?.id else {
            return
        }
        media.addReplaceAudioSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func srtlaServerOnVideoBuffer(streamId: String, sampleBuffer: CMSampleBuffer) {
        guard let cameraId = getSrtlaStream(streamId: streamId)?.id else {
            return
        }
        media.addReplaceVideoSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
    }

    func srtlaServerSetTargetLatencies(
        streamId: String,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    ) {
        guard let cameraId = getSrtlaStream(streamId: streamId)?.id else {
            return
        }
        media.setReplaceVideoTargetLatency(cameraId: cameraId, latency: videoTargetLatency)
        media.setReplaceAudioTargetLatency(cameraId: cameraId, latency: audioTargetLatency)
    }
}

extension Model {
    private func initMediaPlayers() {
        for settings in database.mediaPlayers!.players {
            addMediaPlayer(settings: settings)
        }
        removeUnusedMediaPlayerFiles()
    }

    private func removeUnusedMediaPlayerFiles() {
        for mediaId in mediaStorage.ids() {
            var found = false
            for player in database.mediaPlayers!.players
                where player.playlist.contains(where: { $0.id == mediaId })
            {
                found = true
            }
            if !found {
                mediaStorage.remove(id: mediaId)
            }
        }
    }

    func addMediaPlayer(settings: SettingsMediaPlayer) {
        let mediaPlayer = MediaPlayer(settings: settings, mediaStorage: mediaStorage)
        mediaPlayer.delegate = self
        mediaPlayers[settings.id] = mediaPlayer
    }

    func deleteMediaPlayer(playerId: UUID) {
        mediaPlayers.removeValue(forKey: playerId)
    }

    func updateMediaPlayerSettings(playerId: UUID, settings: SettingsMediaPlayer) {
        mediaPlayers[playerId]?.updateSettings(settings: settings)
    }

    func mediaPlayerTogglePlaying() {
        guard let mediaPlayer = getCurrentMediaPlayer() else {
            return
        }
        if mediaPlayerPlaying {
            mediaPlayer.pause()
        } else {
            mediaPlayer.play()
        }
        mediaPlayerPlaying = !mediaPlayerPlaying
    }

    func mediaPlayerNext() {
        getCurrentMediaPlayer()?.next()
    }

    func mediaPlayerPrevious() {
        getCurrentMediaPlayer()?.previous()
    }

    func mediaPlayerSeek(position: Double) {
        getCurrentMediaPlayer()?.seek(position: position)
    }

    func mediaPlayerSetSeeking(on: Bool) {
        getCurrentMediaPlayer()?.setSeeking(on: on)
    }

    func getCurrentMediaPlayer() -> MediaPlayer? {
        guard let scene = getSelectedScene() else {
            return nil
        }
        guard scene.cameraPosition == .mediaPlayer else {
            return nil
        }
        guard let mediaPlayerSettings = getMediaPlayer(id: scene.mediaPlayerCameraId!) else {
            return nil
        }
        return mediaPlayers[mediaPlayerSettings.id]
    }

    private func deactivateAllMediaPlayers() {
        for mediaPlayer in mediaPlayers.values {
            mediaPlayer.deactivate()
        }
    }
}

extension Model: MediaPlayerDelegate {
    func mediaPlayerFileLoaded(playerId: UUID, name: String) {
        let name = "Media player file \(name)"
        let latency = mediaPlayerLatency
        media.addReplaceVideo(cameraId: playerId, name: name, latency: latency)
        media.addReplaceAudio(cameraId: playerId, name: name, latency: latency)
        // DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        //     self.selectMicById(id: "\(playerId) 0")
        // }
    }

    func mediaPlayerFileUnloaded(playerId: UUID) {
        media.removeReplaceVideo(cameraId: playerId)
        media.removeReplaceAudio(cameraId: playerId)
    }

    func mediaPlayerStateUpdate(
        playerId _: UUID,
        name: String,
        playing: Bool,
        position: Double,
        time: String
    ) {
        DispatchQueue.main.async {
            self.mediaPlayerPlaying = playing
            self.mediaPlayerFileName = name
            if !self.mediaPlayerSeeking {
                self.mediaPlayerPosition = Float(position)
            }
            self.mediaPlayerTime = time
        }
    }

    func mediaPlayerVideoBuffer(playerId: UUID, sampleBuffer: CMSampleBuffer) {
        media.addReplaceVideoSampleBuffer(cameraId: playerId, sampleBuffer: sampleBuffer)
    }

    func mediaPlayerAudioBuffer(playerId: UUID, sampleBuffer: CMSampleBuffer) {
        media.addReplaceAudioSampleBuffer(cameraId: playerId, sampleBuffer: sampleBuffer)
    }
}

extension Model: DjiDeviceDelegate {
    func djiDeviceStreamingState(_ device: DjiDevice, state: DjiDeviceState) {
        guard let device = getDjiDeviceSettings(djiDevice: device) else {
            return
        }
        guard let djiDeviceWrapper = djiDeviceWrappers[device.id] else {
            return
        }
        if device === currentDjiDeviceSettings {
            djiDeviceStreamingState = state
        }
        switch state {
        case .connecting:
            startDjiDeviceTimer(djiDeviceWrapper: djiDeviceWrapper, device: device)
            makeToast(title: String(localized: "Connecting to DJI device \(device.name)"))
        case .streaming:
            if device.rtmpUrlType == .custom {
                stopDjiDeviceTimer(djiDeviceWrapper: djiDeviceWrapper)
                makeToast(title: String(localized: "DJI device \(device.name) streaming to custom URL"))
            }
        case .wifiSetupFailed:
            makeErrorToast(title: String(localized: "WiFi setup failed for DJI device \(device.name)"),
                           subTitle: String(localized: "Please check the WiFi settings"))
        default:
            break
        }
    }
}

extension Model: TeslaVehicleDelegate {
    func teslaVehicleState(_: TeslaVehicle, state: TeslaVehicleState) {
        switch state {
        case .idle:
            reloadTeslaVehicle()
        case .discovering:
            makeToast(title: String(localized: "Searching for your Tesla"))
        case .connected:
            makeToast(title: String(localized: "Connected to your Tesla"))
        default:
            break
        }
        teslaVehicleState = state
    }
}

extension Model {
    func isDjiDeviceStarted(device: SettingsDjiDevice) -> Bool {
        return device.isStarted!
    }

    func startDjiDeviceLiveStream(device: SettingsDjiDevice) {
        if !djiDeviceWrappers.keys.contains(device.id) {
            let djiDevice = DjiDevice()
            djiDevice.delegate = self
            djiDeviceWrappers[device.id] = DjiDeviceWrapper(device: djiDevice)
        }
        guard let djiDeviceWrapper = djiDeviceWrappers[device.id] else {
            return
        }
        device.isStarted = true
        startDjiDeviceLiveStreamInternal(djiDeviceWrapper: djiDeviceWrapper, device: device)
    }

    private func startDjiDeviceLiveStreamInternal(
        djiDeviceWrapper: DjiDeviceWrapper,
        device: SettingsDjiDevice
    ) {
        var rtmpUrl: String?
        switch device.rtmpUrlType! {
        case .server:
            rtmpUrl = device.serverRtmpUrl
        case .custom:
            rtmpUrl = device.customRtmpUrl!
        }
        guard let rtmpUrl else {
            return
        }
        guard let deviceId = device.bluetoothPeripheralId else {
            return
        }
        djiDeviceWrapper.device.startLiveStream(
            wifiSsid: device.wifiSsid,
            wifiPassword: device.wifiPassword,
            rtmpUrl: rtmpUrl,
            resolution: device.resolution!,
            fps: device.fps!,
            bitrate: device.bitrate!,
            imageStabilization: device.imageStabilization!,
            deviceId: deviceId,
            model: device.model!
        )
        startDjiDeviceTimer(djiDeviceWrapper: djiDeviceWrapper, device: device)
    }

    private func startDjiDeviceTimer(djiDeviceWrapper: DjiDeviceWrapper, device: SettingsDjiDevice) {
        djiDeviceWrapper.autoRestartStreamTimer = DispatchSource
            .makeTimerSource(queue: DispatchQueue.main)
        djiDeviceWrapper.autoRestartStreamTimer!.schedule(deadline: .now() + 45)
        djiDeviceWrapper.autoRestartStreamTimer!.setEventHandler { [weak self] in
            self?
                .makeErrorToast(
                    title: String(localized: "Failed to start live stream from DJI device \(device.name)")
                )
            self?.restartDjiLiveStreamIfNeeded(device: device)
        }
        djiDeviceWrapper.autoRestartStreamTimer!.activate()
    }

    private func stopDjiDeviceTimer(djiDeviceWrapper: DjiDeviceWrapper) {
        djiDeviceWrapper.autoRestartStreamTimer?.cancel()
        djiDeviceWrapper.autoRestartStreamTimer = nil
    }

    func stopDjiDeviceLiveStream(device: SettingsDjiDevice) {
        device.isStarted = false
        guard let djiDeviceWrapper = djiDeviceWrappers[device.id] else {
            return
        }
        djiDeviceWrapper.device.stopLiveStream()
        stopDjiDeviceTimer(djiDeviceWrapper: djiDeviceWrapper)
    }

    private func restartDjiLiveStreamIfNeededAfterDelay(device: SettingsDjiDevice) {
        guard let djiDeviceWrapper = djiDeviceWrappers[device.id] else {
            return
        }
        djiDeviceWrapper.autoRestartStreamTimer = DispatchSource
            .makeTimerSource(queue: DispatchQueue.main)
        djiDeviceWrapper.autoRestartStreamTimer!.schedule(deadline: .now() + 5)
        djiDeviceWrapper.autoRestartStreamTimer!.setEventHandler { [weak self] in
            self?.restartDjiLiveStreamIfNeeded(device: device)
        }
        djiDeviceWrapper.autoRestartStreamTimer!.activate()
    }

    private func restartDjiLiveStreamIfNeeded(device: SettingsDjiDevice) {
        switch device.rtmpUrlType! {
        case .server:
            guard device.autoRestartStream! else {
                stopDjiDeviceLiveStream(device: device)
                return
            }
        case .custom:
            return
        }
        guard let djiDeviceWrapper = djiDeviceWrappers[device.id] else {
            return
        }
        guard device.isStarted! else {
            return
        }
        startDjiDeviceLiveStreamInternal(djiDeviceWrapper: djiDeviceWrapper, device: device)
    }

    private func markDjiIsStreamingIfNeeded(rtmpServerStreamId: UUID) {
        for device in database.djiDevices!.devices {
            guard device.rtmpUrlType == .server, device.serverRtmpStreamId! == rtmpServerStreamId else {
                continue
            }
            guard let djiDeviceWrapper = djiDeviceWrappers[device.id] else {
                continue
            }
            djiDeviceWrapper.autoRestartStreamTimer?.cancel()
            djiDeviceWrapper.autoRestartStreamTimer = nil
        }
    }

    private func getDjiDeviceSettings(djiDevice: DjiDevice) -> SettingsDjiDevice? {
        return database.djiDevices!.devices.first(where: { djiDeviceWrappers[$0.id]?.device === djiDevice })
    }

    func setCurrentDjiDevice(device: SettingsDjiDevice) {
        currentDjiDeviceSettings = device
        djiDeviceStreamingState = getDjiDeviceState(device: device)
    }

    func reloadDjiDevices() {
        for deviceId in djiDeviceWrappers.keys {
            guard let device = database.djiDevices!.devices.first(where: { $0.id == deviceId }) else {
                continue
            }
            guard device.isStarted! else {
                continue
            }
            guard let djiDeviceWrapper = djiDeviceWrappers[device.id] else {
                return
            }
            guard djiDeviceWrapper.device.getState() != .streaming else {
                return
            }
            startDjiDeviceLiveStream(device: device)
        }
    }

    func autoStartDjiDevices() {
        for device in database.djiDevices!.devices where device.isStarted! {
            startDjiDeviceLiveStream(device: device)
        }
    }

    func getDjiDeviceState(device: SettingsDjiDevice) -> DjiDeviceState? {
        return djiDeviceWrappers[device.id]?.device.getState()
    }

    func removeDjiDevices(offsets: IndexSet) {
        for offset in offsets {
            let device = database.djiDevices!.devices[offset]
            stopDjiDeviceLiveStream(device: device)
            djiDeviceWrappers.removeValue(forKey: device.id)
        }
        database.djiDevices!.devices.remove(atOffsets: offsets)
    }
}

extension Model {
    func twitchLogin(stream: SettingsStream, onComplete: (() -> Void)? = nil) {
        twitchAuthOnComplete = { accessToken in
            storeTwitchAccessTokenInKeychain(streamId: stream.id, accessToken: accessToken)
            stream.twitchLoggedIn = true
            stream.twitchAccessToken = accessToken
            self.showTwitchAuth = false
            self.wizardShowTwitchAuth = false
            TwitchApi(accessToken, self.urlSession).getUserInfo { info in
                guard let info else {
                    return
                }
                stream.twitchChannelName = info.login
                stream.twitchChannelId = info.id
                if stream.enabled {
                    self.twitchChannelIdUpdated()
                }
                onComplete?()
            }
        }
    }

    func twitchLogout(stream: SettingsStream) {
        stream.twitchLoggedIn = false
        stream.twitchAccessToken = ""
        removeTwitchAccessTokenInKeychain(streamId: stream.id)
        if stream.enabled {
            reloadTwitchEventSub()
        }
    }

    private func handleTwitchAccessToken(accessToken: String) {
        twitchAuthOnComplete?(accessToken)
    }
}

extension Model: TwitchEventSubDelegate {
    func twitchEventSubMakeErrorToast(title: String) {
        makeErrorToast(
            title: title,
            subTitle: String(localized: "Re-login to Twitch probably fixes this error")
        )
    }

    func twitchEventSubChannelFollow(event: TwitchEventSubNotificationChannelFollowEvent) {
        DispatchQueue.main.async {
            let text = String(localized: "just followed!")
            self.makeToast(title: "\(event.user_name) \(text)")
            self.playAlert(alert: .twitchFollow(event))
            self.appendTwitchChatAlertMessage(
                user: event.user_name,
                text: text,
                title: String(localized: "New follower"),
                color: .pink,
                kind: .newFollower
            )
        }
    }

    func twitchEventSubChannelSubscribe(event: TwitchEventSubNotificationChannelSubscribeEvent) {
        guard !event.is_gift else {
            return
        }
        DispatchQueue.main.async {
            let text = String(localized: "just subscribed tier \(event.tierAsNumber())!")
            self.makeToast(title: "\(event.user_name) \(text)")
            self.playAlert(alert: .twitchSubscribe(event))
            self.appendTwitchChatAlertMessage(
                user: event.user_name,
                text: text,
                title: String(localized: "New subscriber"),
                color: .cyan,
                image: "party.popper"
            )
        }
    }

    func twitchEventSubChannelSubscriptionGift(event: TwitchEventSubNotificationChannelSubscriptionGiftEvent) {
        DispatchQueue.main.async {
            let user = event.user_name ?? String(localized: "Anonymous")
            let text =
                String(localized: "just gifted \(event.total) tier \(event.tierAsNumber()) subsciptions!")
            self.makeToast(title: "\(user) \(text)")
            self.playAlert(alert: .twitchSubscrptionGift(event))
            self.appendTwitchChatAlertMessage(
                user: user,
                text: text,
                title: String(localized: "Gift subsciptions"),
                color: .cyan,
                image: "gift"
            )
        }
    }

    func twitchEventSubChannelSubscriptionMessage(
        event: TwitchEventSubNotificationChannelSubscriptionMessageEvent
    ) {
        DispatchQueue.main.async {
            let text = String(localized: """
            just resubscribed tier \(event.tierAsNumber()) for \(event.cumulative_months) \
            months! \(event.message.text)
            """)
            self.makeToast(title: "\(event.user_name) \(text)")
            self.playAlert(alert: .twitchResubscribe(event))
            self.appendTwitchChatAlertMessage(
                user: event.user_name,
                text: text,
                title: String(localized: "New resubscribe"),
                color: .cyan,
                image: "party.popper"
            )
        }
    }

    func twitchEventSubChannelPointsCustomRewardRedemptionAdd(
        event: TwitchEventSubNotificationChannelPointsCustomRewardRedemptionAddEvent
    ) {
        let text = String(localized: "redeemed \(event.reward.title)!")
        makeToast(title: "\(event.user_name) \(text)")
        appendTwitchChatAlertMessage(
            user: event.user_name,
            text: text,
            title: String(localized: "Reward redemption"),
            color: .blue,
            image: "medal.star"
        )
    }

    func twitchEventSubChannelRaid(event: TwitchEventSubChannelRaidEvent) {
        DispatchQueue.main.async {
            let text = String(localized: "raided with a party of \(event.viewers)!")
            self.makeToast(title: "\(event.from_broadcaster_user_name) \(text)")
            self.playAlert(alert: .twitchRaid(event))
            self.appendTwitchChatAlertMessage(
                user: event.from_broadcaster_user_name,
                text: text,
                title: String(localized: "Raid"),
                color: .pink,
                image: "person.3"
            )
        }
    }

    func twitchEventSubChannelCheer(event: TwitchEventSubChannelCheerEvent) {
        DispatchQueue.main.async {
            let user = event.user_name ?? String(localized: "Anonymous")
            let bits = countFormatter.format(event.bits)
            let text = String(localized: "cheered \(bits) bits!")
            self.makeToast(title: "\(user) \(text)", subTitle: event.message)
            self.playAlert(alert: .twitchCheer(event))
            self.appendTwitchChatAlertMessage(
                user: user,
                text: "\(text) \(event.message)",
                title: String(localized: "Cheer"),
                color: .green,
                image: "suit.diamond",
                bits: ""
            )
        }
    }

    private func updateHypeTrainStatus(level: Int, progress: Int, goal: Int) {
        let percentage = Int(100 * Float(progress) / Float(goal))
        hypeTrainStatus = "LVL \(level), \(percentage)%"
    }

    private func startHypeTrainTimer(timeout: Double) {
        hypeTrainTimer.startSingleShot(timeout: timeout) { [weak self] in
            self?.removeHypeTrain()
        }
    }

    private func stopHypeTrainTimer() {
        hypeTrainTimer.stop()
    }

    func twitchEventSubChannelHypeTrainBegin(event: TwitchEventSubChannelHypeTrainBeginEvent) {
        hypeTrainLevel = event.level
        hypeTrainProgress = event.progress
        hypeTrainGoal = event.goal
        updateHypeTrainStatus(level: event.level, progress: event.progress, goal: event.goal)
        startHypeTrainTimer(timeout: 600)
    }

    func twitchEventSubChannelHypeTrainProgress(event: TwitchEventSubChannelHypeTrainProgressEvent) {
        hypeTrainLevel = event.level
        hypeTrainProgress = event.progress
        hypeTrainGoal = event.goal
        updateHypeTrainStatus(level: event.level, progress: event.progress, goal: event.goal)
        startHypeTrainTimer(timeout: 600)
    }

    func twitchEventSubChannelHypeTrainEnd(event: TwitchEventSubChannelHypeTrainEndEvent) {
        hypeTrainLevel = event.level
        hypeTrainProgress = 1
        hypeTrainGoal = 1
        updateHypeTrainStatus(level: event.level, progress: 1, goal: 1)
        startHypeTrainTimer(timeout: 60)
    }

    func twitchEventSubChannelAdBreakBegin(event: TwitchEventSubChannelAdBreakBeginEvent) {
        adsEndDate = Date().advanced(by: Double(event.duration_seconds))
        let duration = formatCommercialStartedDuration(seconds: event.duration_seconds)
        let kind = event.is_automatic ? String(localized: "automatic") : String(localized: "manual")
        makeToast(title: String(localized: "\(duration) \(kind) commercial starting"))
    }

    func removeHypeTrain() {
        hypeTrainLevel = nil
        hypeTrainProgress = nil
        hypeTrainGoal = nil
        hypeTrainStatus = noValue
        stopHypeTrainTimer()
    }

    private func appendTwitchChatAlertMessage(
        user: String,
        text: String,
        title: String,
        color: Color,
        image: String? = nil,
        kind: ChatHighlightKind? = nil,
        bits: String? = nil
    ) {
        appendChatMessage(platform: .twitch,
                          user: user,
                          userId: nil,
                          userColor: nil,
                          userBadges: [],
                          segments: twitchChat.createSegmentsNoTwitchEmotes(text: text, bits: bits),
                          timestamp: digitalClock,
                          timestampTime: .now,
                          isAction: false,
                          isSubscriber: false,
                          isModerator: false,
                          bits: nil,
                          highlight: .init(
                              kind: kind ?? .redemption,
                              color: color,
                              image: image ?? "medal",
                              title: title
                          ))
    }

    func twitchEventSubUnauthorized() {
        twitchApiUnauthorized()
    }

    func twitchEventSubNotification(message _: String) {}
}

extension Model: AlertsEffectDelegate {
    func alertsPlayerRegisterVideoEffect(effect: VideoEffect) {
        media.registerEffect(effect)
    }
}

extension Model: UIDocumentPickerDelegate {
    func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            return
        }
        DispatchQueue.main.async {
            self.onDocumentPickerUrl?(url)
        }
    }
}

extension Model: ObsWebsocketDelegate {
    func obsWebsocketConnected() {
        updateObsStatus()
    }

    func obsWebsocketSceneChanged(sceneName: String) {
        obsCurrentScenePicker = sceneName
        obsCurrentScene = sceneName
        updateObsAudioInputs(sceneName: sceneName)
    }

    func obsWebsocketInputMuteStateChangedEvent(inputName: String, muted: Bool) {
        obsSceneInputs = obsSceneInputs.map { input in
            var input = input
            if input.name == inputName {
                input.muted = muted
            }
            return input
        }
    }

    func obsWebsocketStreamStatusChanged(active: Bool, state: ObsOutputState?) {
        obsStreaming = active
        if let state {
            obsStreamingState = state
        } else if active {
            obsStreamingState = .started
        } else {
            obsStreamingState = .stopped
        }
    }

    func obsWebsocketRecordStatusChanged(active: Bool, state: ObsOutputState?) {
        obsRecording = active
        if let state {
            obsRecordingState = state
        } else if active {
            obsRecordingState = .started
        } else {
            obsRecordingState = .stopped
        }
    }

    func obsWebsocketAudioVolume(volumes: [ObsAudioInputVolume]) {
        guard let volume = volumes.first(where: { volume in
            volume.name == self.stream.obsSourceName!
        }) else {
            obsAudioVolumeLatest =
                String(localized: "Source \(stream.obsSourceName!) not found")
            return
        }
        var values: [String] = []
        for volume in volume.volumes {
            if volume.isInfinite {
                values.append(String(localized: "Muted"))
            } else {
                values.append(String(localized: "\(formatOneDecimal(volume)) dB"))
            }
        }
        obsAudioVolumeLatest = values.joined(separator: ", ")
    }
}

extension Model: TwitchApiDelegate {
    func twitchApiUnauthorized() {
        stream.twitchLoggedIn = false
        makeNotLoggedInToTwitchToast()
    }
}

extension Model: SpeechToTextDelegate {
    func speechToTextPartialResult(position: Int, text: String) {
        for textEffect in textEffects.values {
            textEffect.updateSubtitles(position: position, text: text)
        }
    }

    func speechToTextClear() {
        for textEffect in textEffects.values {
            textEffect.clearSubtitles()
        }
    }
}

extension Model {
    func isCatPrinterEnabled(device: SettingsCatPrinter) -> Bool {
        return device.enabled
    }

    func enableCatPrinter(device: SettingsCatPrinter) {
        if !catPrinters.keys.contains(device.id) {
            let catPrinter = CatPrinter()
            catPrinter.delegate = self
            catPrinters[device.id] = catPrinter
        }
        catPrinters[device.id]?.start(
            deviceId: device.bluetoothPeripheralId,
            meowSoundEnabled: device.faxMeowSound!
        )
    }

    func catPrinterSetFaxMeowSound(device: SettingsCatPrinter) {
        catPrinters[device.id]?.setMeowSoundEnabled(meowSoundEnabled: device.faxMeowSound!)
    }

    func disableCatPrinter(device: SettingsCatPrinter) {
        catPrinters[device.id]?.stop()
    }

    func catPrinterPrintTestImage(device: SettingsCatPrinter) {
        catPrinters[device.id]?.print(image: CIImage.black.cropped(to: .init(
            origin: .zero,
            size: .init(width: 100, height: 10)
        )))
    }

    private func getCatPrinterSettings(catPrinter: CatPrinter) -> SettingsCatPrinter? {
        return database.catPrinters!.devices.first(where: { catPrinters[$0.id] === catPrinter })
    }

    func setCurrentCatPrinter(device: SettingsCatPrinter) {
        currentCatPrinterSettings = device
        catPrinterState = getCatPrinterState(device: device)
    }

    func getCatPrinterState(device: SettingsCatPrinter) -> CatPrinterState {
        return catPrinters[device.id]?.getState() ?? .disconnected
    }

    private func autoStartCatPrinters() {
        for device in database.catPrinters!.devices where device.enabled {
            enableCatPrinter(device: device)
        }
    }

    private func isAnyConnectedCatPrinterPrintingChat() -> Bool {
        return catPrinters.values.contains(where: {
            $0.getState() == .connected && getCatPrinterSettings(catPrinter: $0)?.printChat == true
        })
    }
}

extension Model: CatPrinterDelegate {
    func catPrinterState(_ catPrinter: CatPrinter, state: CatPrinterState) {
        DispatchQueue.main.async {
            guard let device = self.getCatPrinterSettings(catPrinter: catPrinter) else {
                return
            }
            if device === self.currentCatPrinterSettings {
                self.catPrinterState = state
            }
        }
    }
}

extension Model: FaxReceiverDelegate {
    func faxReceiverPrint(image: CIImage) {
        DispatchQueue.main.async {
            for catPrinter in self.catPrinters.values {
                catPrinter.print(image: image, feedPaperDelay: nil)
            }
        }
    }
}
