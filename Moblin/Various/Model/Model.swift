import AlertToast
import AppIntents
import AppleGPUInfo
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
import TrueTime
import TwitchChat
import VideoToolbox
import WatchConnectivity
import WebKit
import WrappingHStack

private let noBackZoomPresetId = UUID()
private let noFrontZoomPresetId = UUID()

enum RemoteControlAssistantPreviewUser {
    case panel
    case watch
}

struct SnapshotJob {
    let isChatBot: Bool
    let message: String
    let user: String?
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
    case djiDevices
    case sceneSettings
    case goPro
    case connectionPriorities
    case autoSceneSwitcher
    case quickButtonSettings

    func buttonsBackgroundColor() -> Color {
        if self == .chat {
            return .black
        } else {
            return Color(UIColor.secondarySystemBackground)
        }
    }
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

let screenCaptureCameraId = UUID(uuidString: "00000000-cafe-babe-beef-000000000000")!
let builtinBackCameraId = UUID(uuidString: "00000000-cafe-dead-beef-000000000000")!
let builtinFrontCameraId = UUID(uuidString: "00000000-cafe-dead-beef-000000000001")!
let externalCameraId = UUID(uuidString: "00000000-cafe-dead-beef-000000000002")!
let screenCaptureCamera = "Screen capture"
private let backTripleLowEnergyCamera = "Back Triple (low energy)"
private let backDualLowEnergyCamera = "Back Dual (low energy)"
private let backWideDualLowEnergyCamera = "Back Wide dual (low energy)"

let plainIcon = Icon(name: "Plain", id: "AppIcon", price: "")
let noMic = Mic(name: "", inputUid: "")

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

struct ChatPostSegment: Identifiable, Codable {
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

enum ChatHighlightKind: Codable {
    case redemption
    case other
    case firstMessage
    case newFollower
    case reply
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
        case .reply:
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
    var userColor: RgbColor
    var userBadges: [URL]
    var segments: [ChatPostSegment]
    var timestamp: String
    var timestampTime: ContinuousClock.Instant
    var isAction: Bool
    var isSubscriber: Bool
    var bits: String?
    var highlight: ChatHighlight?
    var live: Bool
}

class ButtonState {
    var isOn: Bool
    var button: SettingsQuickButton

    init(isOn: Bool, button: SettingsQuickButton) {
        self.isOn = isOn
        self.button = button
    }
}

enum StreamState {
    case connecting
    case connected
    case disconnected
}

struct QuickButtonPair: Identifiable, Equatable {
    static func == (lhs: QuickButtonPair, rhs: QuickButtonPair) -> Bool {
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
    case obs
}

enum WizardNetworkSetup {
    case none
    case obs
    case belaboxCloudObs
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

class AudioProvider: ObservableObject {
    @Published var showing = false
    @Published var level: Float = defaultAudioLevel
    @Published var numberOfChannels: Int = 0
}

class ChatProvider: ObservableObject {
    var newPosts: Deque<ChatPost> = []
    var pausedPosts: Deque<ChatPost> = []
    @Published var posts: Deque<ChatPost> = []
    @Published var pausedPostsCount: Int = 0
    @Published var paused = false
    private let maximumNumberOfMessages: Int

    init(maximumNumberOfMessages: Int) {
        self.maximumNumberOfMessages = maximumNumberOfMessages
    }

    func reset() {
        posts = []
        pausedPosts = []
        newPosts = []
    }

    func appendMessage(post: ChatPost) {
        if paused {
            if pausedPosts.count < 2 * maximumNumberOfMessages {
                pausedPosts.append(post)
            }
        } else {
            newPosts.append(post)
        }
    }

    func update() {
        if paused {
            pausedPostsCount = max(pausedPosts.count - 1, 0)
        } else {
            while let post = newPosts.popFirst() {
                if posts.count > maximumNumberOfMessages - 1 {
                    posts.removeLast()
                }
                posts.prepend(post)
            }
        }
    }
}

class StreamUptimeProvider: ObservableObject {
    @Published var uptime = noValue
}

class RecordingProvider: ObservableObject {
    @Published var length = noValue
}

class ReplayProvider: ObservableObject {
    @Published var selectedId: UUID?
    @Published var isSaving = false
    @Published var previewImage: UIImage?
    @Published var isPlaying = false
    @Published var startFromEnd = 10.0
    @Published var speed: SettingsReplaySpeed? = .one
    @Published var instantReplayCountdown = 0
    @Published var timeLeft = 0
}

final class Model: NSObject, ObservableObject, @unchecked Sendable {
    let media = Media()
    var streamState = StreamState.disconnected {
        didSet {
            logger.info("stream: State \(oldValue) -> \(streamState)")
        }
    }

    @Published var goProLaunchLiveStreamSelection: UUID?
    @Published var goProWifiCredentialsSelection: UUID?
    @Published var goProRtmpUrlSelection: UUID?

    @Published var bias: Float = 0.0

    private var selectedFps: Int?
    private var autoFps = false

    var manualFocusesEnabled: [AVCaptureDevice: Bool] = [:]
    var manualFocuses: [AVCaptureDevice: Float] = [:]
    @Published var manualFocus: Float = 1.0
    @Published var manualFocusEnabled = false
    var editingManualFocus = false
    var focusObservation: NSKeyValueObservation?
    @Published var manualFocusPoint: CGPoint?

    var manualIsosEnabled: [AVCaptureDevice: Bool] = [:]
    var manualIsos: [AVCaptureDevice: Float] = [:]
    @Published var manualIso: Float = 1.0
    @Published var manualIsoEnabled = false
    var editingManualIso = false
    var isoObservation: NSKeyValueObservation?

    var manualWhiteBalancesEnabled: [AVCaptureDevice: Bool] = [:]
    var manualWhiteBalances: [AVCaptureDevice: Float] = [:]
    @Published var manualWhiteBalance: Float = 0
    @Published var manualWhiteBalanceEnabled = false
    var editingManualWhiteBalance = false
    var whiteBalanceObservation: NSKeyValueObservation?

    private var manualFocusMotionAttitude: CMAttitude?

    @Published var showingPanel: ShowingPanel = .none
    @Published var panelHidden = false
    @Published var blackScreen = false
    @Published var lockScreen = false
    @Published var findFace = false
    private var findFaceTimer: Timer?
    private var streaming = false
    @Published var currentMic = noMic
    var micChange = noMic
    private var streamStartTime: ContinuousClock.Instant?
    @Published var isLive = false
    @Published var isRecording = false
    var workoutType: WatchProtocolWorkoutType?
    private var currentRecording: Recording?
    let recording = RecordingProvider()
    @Published var browserWidgetsStatus = noValue
    @Published var catPrinterStatus = noValue
    @Published var cyclingPowerDeviceStatus = noValue
    @Published var heartRateDeviceStatus = noValue
    private var browserWidgetsStatusChanged = false
    private var subscriptions = Set<AnyCancellable>()
    var streamUptime = StreamUptimeProvider()
    @Published var bondingStatistics = noValue
    @Published var bondingRtts = noValue
    private var bondingStatisticsFormatter = BondingStatisticsFormatter()
    let audio = AudioProvider()
    var settings = Settings()
    @Published var digitalClock = noValue
    @Published var statusEventsText = noValue
    @Published var statusChatText = noValue
    var selectedSceneId = UUID()
    var twitchChat: TwitchChatMoblin!
    var twitchEventSub: TwitchEventSub?
    private var kickPusher: KickPusher?
    private var kickViewers: KickViewers?
    private var youTubeLiveChat: YouTubeLiveChat?
    private var afreecaTvChat: AfreecaTvChat?
    private var openStreamingPlatformChat: OpenStreamingPlatformChat!
    var obsWebSocket: ObsWebSocket?
    private var chatPostId = 0
    @Published var interactiveChat = false
    var chat = ChatProvider(maximumNumberOfMessages: maximumNumberOfChatMessages)
    var quickButtonChat = ChatProvider(maximumNumberOfMessages: maximumNumberOfInteractiveChatMessages)
    var externalDisplayChat = ChatProvider(maximumNumberOfMessages: 50)
    @Published var externalDisplayChatEnabled = false
    private var externalDisplayWindow: UIWindow?
    var chatBotMessages: Deque<ChatBotMessage> = []
    @Published var showAllQuickButtonChatMessage = true
    @Published var showFirstTimeChatterMessage = true
    @Published var showNewFollowerMessage = true
    @Published var quickButtonChatAlertsPosts: Deque<ChatPost> = []
    private var newQuickButtonChatAlertsPosts: Deque<ChatPost> = []
    private var pausedQuickButtonChatAlertsPosts: Deque<ChatPost> = []
    @Published var pausedQuickButtonChatAlertsPostsCount: Int = 0
    @Published var quickButtonChatAlertsPaused = false
    var watchChatPosts: Deque<WatchProtocolChatMessage> = []
    var nextWatchChatPostId = 1
    @Published var numberOfViewers = noValue
    @Published var batteryLevel = Double(UIDevice.current.batteryLevel)
    private var batteryLevelLowCounter = -1
    @Published var batteryState: UIDevice.BatteryState = .full
    @Published var speedAndTotal = noValue
    @Published var speedMbpsOneDecimal = noValue
    @Published var bitrateStatusColor: Color = .white
    @Published var bitrateStatusIconColor: Color?
    private var previousBitrateStatusColorSrtDroppedPacketsTotal: Int32 = 0
    private var previousBitrateStatusNumberOfFailedEncodings = 0
    @Published var thermalState = ProcessInfo.processInfo.thermalState
    let streamPreviewView = PreviewView()
    let externalDisplayStreamPreviewView = PreviewView()
    let cameraPreviewView = CameraPreviewUiView()
    var cameraPreviewLayer: AVCaptureVideoPreviewLayer?
    @Published var remoteControlPreview: UIImage?
    @Published var showCameraPreview = false
    var textEffects: [UUID: TextEffect] = [:]
    private var imageEffects: [UUID: ImageEffect] = [:]
    private var browserEffects: [UUID: BrowserEffect] = [:]
    private var lutEffects: [UUID: LutEffect] = [:]
    var mapEffects: [UUID: MapEffect] = [:]
    private var qrCodeEffects: [UUID: QrCodeEffect] = [:]
    private var alertsEffects: [UUID: AlertsEffect] = [:]
    private var videoSourceEffects: [UUID: VideoSourceEffect] = [:]
    var enabledAlertsEffects: [AlertsEffect] = []
    private var drawOnStreamEffect = DrawOnStreamEffect()
    private var lutEffect = LutEffect()
    var padelScoreboardEffects: [UUID: PadelScoreboardEffect] = [:]
    var speechToTextAlertMatchOffset = 0
    @Published var browsers: [Browser] = []
    @Published var sceneIndex = 0
    @Published var isTorchOn = false
    @Published var isFrontCameraSelected = false
    var isMuteOn = false
    var log: Deque<LogEntry> = []
    var remoteControlAssistantLog: Deque<LogEntry> = []
    var imageStorage = ImageStorage()
    var logsStorage = LogsStorage()
    var mediaStorage = MediaPlayerStorage()
    var alertMediaStorage = AlertMediaStorage()
    @Published var buttonPairs: [[QuickButtonPair]] = Array(repeating: [], count: controlBarPages)
    var controlBarPage = 1
    private var reconnectTimer: Timer?
    var logId = 1
    @Published var showingToast = false
    @Published var toast = AlertToast(type: .regular, title: "") {
        didSet {
            showingToast.toggle()
        }
    }

    private var serversSpeed: Int64 = 0

    @Published var hypeTrainLevel: Int?
    @Published var hypeTrainProgress: Int?
    @Published var hypeTrainGoal: Int?
    @Published var hypeTrainStatus = noValue
    @Published var adsRemainingTimerStatus = noValue
    var adsEndDate: Date?
    var hypeTrainTimer = SimpleTimer(queue: .main)
    var urlSession = URLSession.shared

    var heartRates: [String: Int?] = [:]
    var workoutActiveEnergyBurned: Int?
    var workoutDistance: Int?
    var workoutPower: Int?
    var workoutStepCount: Int?
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
    @Published var showingReplay = false
    @Published var showingCameraBias = false
    @Published var showingCameraWhiteBalance = false
    @Published var showingCameraIso = false
    @Published var showingCameraFocus = false
    @Published var showingPixellate = false
    @Published var showingGrid = false
    @Published var showingRemoteControl = false
    @Published var obsScenes: [String] = []
    @Published var obsSceneInputs: [ObsSceneInput] = []
    @Published var obsAudioVolume: String = noValue
    @Published var obsAudioDelay: Int = 0
    @Published var portraitVideoOffsetFromTop = 0.0
    var obsAudioVolumeLatest: String = ""
    @Published var obsCurrentScenePicker: String = ""
    @Published var obsCurrentScene: String = ""
    var obsSceneBeforeSwitchToBrbScene: String?
    var previousSrtDroppedPacketsTotal: Int32 = 0
    var streamBecameBrokenTime: ContinuousClock.Instant?
    @Published var currentStreamId = UUID()
    @Published var obsStreaming = false
    @Published var obsStreamingState: ObsOutputState = .stopped
    @Published var obsRecordingState: ObsOutputState = .stopped
    @Published var obsFixOngoing = false
    @Published var obsScreenshot: CGImage?
    var obsSourceFetchScreenshot = false
    var obsSourceScreenshotIsFetching = false
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
    private var gForceManager: GForceManager?
    var database: Database {
        settings.database
    }

    var speechToText = SpeechToText()
    var keepSpeakerAlivePlayer: AVAudioPlayer?
    var keepSpeakerAliveLatestPlayed: ContinuousClock.Instant = .now

    @Published var showTwitchAuth = false
    let twitchAuth = TwitchAuth()
    var twitchAuthOnComplete: ((_ accessToken: String) -> Void)?

    var numberOfTwitchViewers: Int?

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
    let webBrowserController = WebBrowserController()
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
    @Published var wizardChatBttv = false
    @Published var wizardChatFfz = false
    @Published var wizardChatSeventv = false
    @Published var wizardBelaboxUrl = ""
    @Published var wizardCustomSrtUrl = ""
    @Published var wizardCustomSrtStreamId = ""
    @Published var wizardCustomRtmpUrl = ""
    @Published var wizardCustomRtmpStreamKey = ""
    @Published var wizardCustomRistUrl = ""

    let chatTextToSpeech = ChatTextToSpeech()

    var teslaVehicle: TeslaVehicle?
    var teslaChargeState = CarServer_ChargeState()
    var teslaDriveState = CarServer_DriveState()
    var teslaMediaState = CarServer_MediaState()
    @Published var teslaVehicleState: TeslaVehicleState?
    @Published var teslaVehicleVehicleSecurityConnected = false
    @Published var teslaVehicleInfotainmentConnected = false

    private var lastAttachCompletedTime: ContinuousClock.Instant?
    private var relaxedBitrateStartTime: ContinuousClock.Instant?
    private var relaxedBitrate = false

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

    @Published var quickButtonSettingsButton: SettingsQuickButton?

    var remoteControlStreamer: RemoteControlStreamer?
    var remoteControlAssistant: RemoteControlAssistant?
    var remoteControlRelay: RemoteControlRelay?
    @Published var remoteControlAssistantShowPreview = true
    @Published var remoteControlAssistantShowPreviewFullScreen = false
    var isRemoteControlAssistantRequestingPreview = false
    var remoteControlAssistantPreviewUsers: Set<RemoteControlAssistantPreviewUser> = .init()
    var remoteControlStreamerLatestReceivedChatMessageId = -1
    var useRemoteControlForChatAndEvents = false

    var currentWiFiSsid: String?
    @Published var djiDeviceStreamingState: DjiDeviceState?
    var currentDjiDeviceSettings: SettingsDjiDevice?
    var djiDeviceWrappers: [UUID: DjiDeviceWrapper] = [:]

    @Published var djiGimbalDeviceStreamingState: DjiGimbalDeviceState?
    var currentDjiGimbalDeviceSettings: SettingsDjiGimbalDevice?
    var djiGimbalDevices: [UUID: DjiGimbalDevice] = [:]

    let autoSceneSwitcher = AutoSceneSwitcherProvider()

    @Published var catPrinterState: CatPrinterState?
    var currentCatPrinterSettings: SettingsCatPrinter?
    var catPrinters: [UUID: CatPrinter] = [:]

    @Published var cyclingPowerDeviceState: CyclingPowerDeviceState?
    var currentCyclingPowerDeviceSettings: SettingsCyclingPowerDevice?
    var cyclingPowerDevices: [UUID: CyclingPowerDevice] = [:]
    var cyclingPower = 0
    var cyclingCadence = 0

    private let periodicTimer20ms = SimpleTimer(queue: .main)
    private let periodicTimer200ms = SimpleTimer(queue: .main)
    private let periodicTimer1s = SimpleTimer(queue: .main)
    private let periodicTimer3s = SimpleTimer(queue: .main)
    private let periodicTimer5s = SimpleTimer(queue: .main)
    private let periodicTimer10s = SimpleTimer(queue: .main)

    @Published var heartRateDeviceState: HeartRateDeviceState?
    var currentHeartRateDeviceSettings: SettingsHeartRateDevice?
    var heartRateDevices: [UUID: HeartRateDevice] = [:]

    var cameraDevice: AVCaptureDevice?
    var cameraZoomLevelToXScale: Float = 1.0
    var cameraZoomXMinimum: Float = 1.0
    var cameraZoomXMaximum: Float = 1.0
    @Published var debugLines: [String] = []
    @Published var cpuUsage: Float = 0.0
    var cpuUsageNeeded = false
    private var latestDebugLines: [String] = []
    private var latestDebugActions: [String] = []
    @Published var streamingHistory = StreamingHistory()
    private var streamingHistoryStream: StreamingHistoryStream?

    var backCameras: [Camera] = []
    var frontCameras: [Camera] = []
    var externalCameras: [Camera] = []

    var recordingsStorage = RecordingsStorage()
    private var latestLowBitrateTime = ContinuousClock.now

    var rtmpServer: RtmpServer?
    @Published var serversSpeedAndTotal = noValue
    var moblinkRelayState: MoblinkRelayState = .waitingForStreamers
    @Published var moblinkStreamerOk = true
    @Published var moblinkStatus = noValue
    @Published var djiDevicesStatus = noValue
    @Published var moblinkScannerDiscoveredStreamers: [MoblinkScannerStreamer] = []

    var sceneSettingsPanelScene = SettingsScene(name: "")
    @Published var sceneSettingsPanelSceneId = 1

    @Published var snapshotCountdown = 0
    @Published var currentSnapshotJob: SnapshotJob?
    private var snapshotJobs: Deque<SnapshotJob> = []

    var srtlaServer: SrtlaServer?

    var gameControllers: [GCController?] = []
    @Published var gameControllersTotal = noValue

    @Published var location = noValue
    @Published var showLoadSettingsFailed = false

    var latestKnownLocation: CLLocation?
    var slopePercent = 0.0
    var previousSlopeAltitude: Double? = 0.0
    var previousSlopeDistance = 0.0
    var averageSpeed = 0.0
    var averageSpeedStartTime: ContinuousClock.Instant = .now
    var averageSpeedStartDistance = 0.0

    let replaysStorage = ReplaysStorage()
    var replaySettings: ReplaySettings?
    var replayFrameExtractor: ReplayFrameExtractor?
    var replayVideo: ReplayBufferFile?
    var replayBuffer = ReplayBuffer()
    let replay = ReplayProvider()

    @Published var remoteControlStatus = noValue

    private let sampleBufferReceiver = SampleBufferReceiver()

    let faxReceiver = FaxReceiver()

    var moblinkStreamer: MoblinkStreamer?
    var moblinkRelays: [MoblinkRelay] = []
    var moblinkScanner: MoblinkScanner?

    @Published var cameraControlEnabled = false
    var twitchStreamUpdateTime = ContinuousClock.now

    var externalDisplayPreview = false

    var remoteSceneScenes: [SettingsScene] = []
    var remoteSceneWidgets: [SettingsWidget] = []
    var remoteSceneData = RemoteControlRemoteSceneData(textStats: nil, location: nil)
    private var remoteSceneSettingsUpdateRequested = false
    private var remoteSceneSettingsUpdating = false

    override init() {
        super.init()
        showLoadSettingsFailed = !settings.load()
        streamingHistory.load()
        recordingsStorage.load()
        replaysStorage.load()
        if isPortrait() {
            AppDelegate.orientationLock = .portrait
        } else {
            AppDelegate.orientationLock = .landscape
        }
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

    func widgetsInCurrentScene(onlyEnabled: Bool) -> [SettingsWidget] {
        guard let scene = getSelectedScene() else {
            return []
        }
        var found: [UUID] = []
        return getSceneWidgets(scene: scene, onlyEnabled: onlyEnabled).filter {
            if found.contains($0.id) {
                return false
            } else {
                found.append($0.id)
                return true
            }
        }
    }

    func isPortrait() -> Bool {
        return stream.portrait! || database.portrait
    }

    private func getSceneWidgets(scene: SettingsScene, onlyEnabled: Bool) -> [SettingsWidget] {
        var widgets: [SettingsWidget] = []
        for sceneWidget in scene.widgets {
            guard let widget = findWidget(id: sceneWidget.widgetId) else {
                continue
            }
            guard !onlyEnabled || widget.enabled else {
                continue
            }
            widgets.append(widget)
            guard widget.type == .scene else {
                continue
            }
            if let scene = database.scenes.first(where: { $0.id == widget.scene.sceneId }) {
                widgets += getSceneWidgets(scene: scene, onlyEnabled: onlyEnabled)
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
    private var ipMonitor = IPMonitor()
    @Published var ipStatuses: [IPMonitor.Status] = []
    private var faceEffect = FaceEffect(fps: 30)
    private var movieEffect = MovieEffect()
    private var whirlpoolEffect = WhirlpoolEffect()
    private var pinchEffect = PinchEffect()
    private var fourThreeEffect = FourThreeEffect()
    private var grayScaleEffect = GrayScaleEffect()
    private var sepiaEffect = SepiaEffect()
    private var tripleEffect = TripleEffect()
    private var twinEffect = TwinEffect()
    private var pixellateEffect = PixellateEffect(strength: 0.0)
    private var pollEffect = PollEffect()
    var replayEffect: ReplayEffect?
    var locationManager = Location()
    var realtimeIrl: RealtimeIrl?
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
        database.verboseStatuses.toggle()
    }

    private func isShowingPanelGlobalButton(type: SettingsQuickButtonType) -> Bool {
        return [
            SettingsQuickButtonType.widgets,
            SettingsQuickButtonType.luts,
            SettingsQuickButtonType.chat,
            SettingsQuickButtonType.mic,
            SettingsQuickButtonType.bitrate,
            SettingsQuickButtonType.recordings,
            SettingsQuickButtonType.stream,
            SettingsQuickButtonType.obs,
            SettingsQuickButtonType.djiDevices,
            SettingsQuickButtonType.goPro,
            SettingsQuickButtonType.connectionPriorities,
            SettingsQuickButtonType.autoSceneSwitcher,
        ].contains(type)
    }

    func toggleShowingPanel(type: SettingsQuickButtonType?, panel: ShowingPanel) {
        if showingPanel == panel {
            showingPanel = .none
        } else {
            showingPanel = panel
        }
        panelHidden = false
        for pageButtonPairs in buttonPairs {
            for pair in pageButtonPairs {
                if isShowingPanelGlobalButton(type: pair.first.button.type) {
                    setGlobalButtonState(type: pair.first.button.type, isOn: false)
                }
                if let state = pair.second {
                    if isShowingPanelGlobalButton(type: state.button.type) {
                        setGlobalButtonState(type: state.button.type, isOn: false)
                    }
                }
            }
        }
        if let type {
            setGlobalButtonState(type: type, isOn: showingPanel == panel)
        }
        updateQuickButtonStates()
    }

    func isSceneVideoSourceActive(sceneId: UUID) -> Bool {
        guard let scene = enabledScenes.first(where: { $0.id == sceneId }) else {
            return false
        }
        return isSceneVideoSourceActive(scene: scene)
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
        allowVideoRangePixelFormat = database.debug.allowVideoRangePixelFormat
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

    private func makeErrorToastMain(title: String, font: Font? = nil, subTitle: String? = nil, vibrate: Bool = false) {
        DispatchQueue.main.async {
            self.makeErrorToast(title: title, font: font, subTitle: subTitle, vibrate: vibrate)
        }
    }

    func updateQuickButtonStates() {
        for page in 0 ..< controlBarPages {
            let states = database.quickButtons.filter { button in
                button.enabled && button.page == page + 1
            }.map { button in
                ButtonState(isOn: button.isOn, button: button)
            }
            var pairs: [QuickButtonPair] = []
            for index in stride(from: 0, to: states.count, by: 2) {
                if states.count - index > 1 {
                    pairs.append(QuickButtonPair(
                        id: UUID(),
                        first: states[index + 1],
                        second: states[index]
                    ))
                } else {
                    pairs.append(QuickButtonPair(id: UUID(), first: states[index]))
                }
            }
            buttonPairs[page] = pairs
        }
    }

    func getQuickButtonPairs(page: Int) -> [QuickButtonPair] {
        return buttonPairs[page]
    }

    func updateShowCameraPreview() -> Bool {
        showCameraPreview = shouldShowCameraPreview()
        return showCameraPreview
    }

    func takeSnapshot(isChatBot: Bool = false, message: String? = nil, noDelay: Bool = false) {
        let age = (isChatBot && !noDelay) ? stream.estimatedViewerDelay! : 0.0
        media.takeSnapshot(age: age) { image, portraitImage in
            guard let imageJpeg = image.jpegData(compressionQuality: 0.9) else {
                return
            }
            DispatchQueue.main.async {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                self.makeToast(title: String(localized: "Snapshot saved to Photos"))
                self.tryUploadSnapshotToDiscord(imageJpeg, message, isChatBot)
                self.printSnapshotCatPrinters(image: portraitImage)
            }
        }
    }

    private func tryTakeNextSnapshot() {
        guard currentSnapshotJob == nil else {
            return
        }
        currentSnapshotJob = snapshotJobs.popFirst()
        guard currentSnapshotJob != nil else {
            return
        }
        snapshotCountdown = 5
        snapshotCountdownTick()
    }

    func formatSnapshotTakenBy(user: String) -> String {
        return String(localized: "Snapshot taken by \(user).")
    }

    func formatSnapshotTakenSuccessfully(user: String) -> String {
        return String(localized: "\(user), thanks for bringing our photo album to life. 🎉")
    }

    func formatSnapshotTakenNotAllowed(user: String) -> String {
        return String(localized: " \(user), you are not allowed to take snapshots, sorry. 😢")
    }

    private func snapshotCountdownTick() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.snapshotCountdown -= 1
            guard self.snapshotCountdown == 0 else {
                self.snapshotCountdownTick()
                return
            }
            guard let snapshotJob = self.currentSnapshotJob else {
                return
            }
            var message = snapshotJob.message
            if let user = snapshotJob.user {
                message += "\n"
                message += self.formatSnapshotTakenBy(user: user)
            }
            self.takeSnapshot(isChatBot: snapshotJob.isChatBot, message: message, noDelay: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                self.currentSnapshotJob = nil
                self.tryTakeNextSnapshot()
            }
        }
    }

    func takeSnapshotWithCountdown(isChatBot: Bool, message: String, user: String?) {
        snapshotJobs.append(SnapshotJob(isChatBot: isChatBot, message: message, user: user))
        tryTakeNextSnapshot()
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
            if self.log.count > self.database.debug.maximumLogLines {
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

    func formatLog(log: Deque<LogEntry>) -> URL {
        var data = "Version: \(appVersion())\n"
        data += "Debug: \(logger.debugEnabled)\n\n"
        data += log.map { e in e.message }.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Moblin-log-\(Date())")
            .appendingPathExtension("txt")
        try? data.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func setAllowHapticsAndSystemSoundsDuringRecording() {
        do {
            try AVAudioSession.sharedInstance()
                .setAllowHapticsAndSystemSoundsDuringRecording(database.vibrate)
        } catch {}
    }

    func setup() {
        deleteTrash()
        cameraPreviewLayer = cameraPreviewView.previewLayer
        media.delegate = self
        createUrlSession()
        AppDependencyManager.shared.add(dependency: self)
        faxReceiver.delegate = self
        fixAlertMedias()
        setAllowVideoRangePixelFormat()
        setSrtlaBatchSend()
        setExternalDisplayContent()
        portraitVideoOffsetFromTop = database.portraitVideoOffsetFromTop
        audioUnitRemoveWindNoise = database.debug.removeWindNoise
        showFirstTimeChatterMessage = database.chat.showFirstTimeChatterMessage
        showNewFollowerMessage = database.chat.showNewFollowerMessage
        verboseStatuses = database.verboseStatuses
        autoSceneSwitcher.currentSwitcherId = database.autoSceneSwitchers!.switcherId
        supportsAppleLog = hasAppleLog()
        interactiveChat = getGlobalButton(type: .interactiveChat)?.isOn ?? false
        _ = updateShowCameraPreview()
        setDisplayPortrait(portrait: database.portrait)
        setBitrateDropFix()
        let webPCoder = SDImageWebPCoder.shared
        SDImageCodersManager.shared.addCoder(webPCoder)
        UIDevice.current.isBatteryMonitoringEnabled = true
        logger.handler = debugLog(message:)
        logger.debugEnabled = database.debug.logLevel == .debug
        updateCameraLists()
        updateBatteryLevel()
        setPixelFormat()
        setMetalPetalFilters()
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
        externalDisplayStreamPreviewView.videoGravity = .resizeAspect
        updateDigitalClock(now: Date())
        twitchChat = TwitchChatMoblin(delegate: self)
        setMic()
        reloadStream()
        resetSelectedScene()
        setupPeriodicTimers()
        setupThermalState()
        updateQuickButtonStates()
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
        chatTextToSpeech.setRate(rate: database.chat.textToSpeechRate)
        chatTextToSpeech.setVolume(volume: database.chat.textToSpeechSayVolume)
        chatTextToSpeech.setVoices(voices: database.chat.textToSpeechLanguageVoices)
        chatTextToSpeech.setSayUsername(value: database.chat.textToSpeechSayUsername)
        chatTextToSpeech
            .setDetectLanguagePerMessage(value: database.chat.textToSpeechDetectLanguagePerMessage)
        chatTextToSpeech.setFilter(value: database.chat.textToSpeechFilter)
        chatTextToSpeech.setFilterMentions(value: database.chat.textToSpeechFilterMentions)
        chatTextToSpeech.setPauseBetweenMessages(value: database.chat.textToSpeechPauseBetweenMessages)
        setTextToSpeechStreamerMentions()
        updateOrientationLock()
        updateFaceFilterSettings()
        setupSampleBufferReceiver()
        initMediaPlayers()
        removeUnusedLogs()
        autoStartDjiDevices()
        autoStartDjiGimbalDevices()
        autoStartCatPrinters()
        autoStartCyclingPowerDevices()
        autoStartHeartRateDevices()
        startWeatherManager()
        startGeographyManager()
        twitchAuth.setOnAccessToken(onAccessToken: handleTwitchAccessToken)
        MoblinShortcuts.updateAppShortcutParameters()
        bondingStatisticsFormatter.setNetworkInterfaceNames(database.networkInterfaceNames)
        reloadTeslaVehicle()
        updateFaceFilterButtonState()
        updateLutsButtonState()
        updateAutoSceneSwitcherButtonState()
        reloadNtpClient()
        reloadMoblinkRelay()
        reloadMoblinkStreamer()
        setCameraControlsEnabled()
        resetAverageSpeed()
        resetSlope()
        goProLaunchLiveStreamSelection = database.goPro.selectedLaunchLiveStream
        goProWifiCredentialsSelection = database.goPro.selectedWifiCredentials
        goProRtmpUrlSelection = database.goPro.selectedRtmpUrl
        replay.speed = database.replay.speed
        gForceManager = GForceManager(motionManager: motionManager)
        startGForceManager()
    }

    func startGForceManager() {
        if isGForceManagerNeeded() {
            gForceManager?.start()
        } else {
            gForceManager?.stop()
        }
    }

    private func isGForceManagerNeeded() -> Bool {
        for widget in widgetsInCurrentScene(onlyEnabled: true) {
            guard widget.type == .text else {
                continue
            }
            guard widget.text.needsGForce! else {
                continue
            }
            return true
        }
        return false
    }

    func setBitrateDropFix() {
        if database.debug.bitrateDropFix {
            videoEncoderDataRateLimitFactor = Double(database.debug.dataRateLimitFactor)
        } else {
            videoEncoderDataRateLimitFactor = 1.2
        }
    }

    private func shouldShowCameraPreview() -> Bool {
        if !(getGlobalButton(type: .cameraPreview)?.isOn ?? false) {
            return false
        }
        return cameraDevice != nil
    }

    func formatDeviceStatus(name: String, batteryPercentage: Int?) -> (String, Bool) {
        var ok = true
        var status: String
        if let batteryPercentage {
            if batteryPercentage <= 10 {
                status = "\(name)🪫\(batteryPercentage)%"
                ok = false
            } else {
                status = "\(name)🔋\(batteryPercentage)%"
            }
        } else {
            status = name
        }
        return (status, ok)
    }

    func reloadNtpClient() {
        stopNtpClient()
        if isTimecodesEnabled() {
            logger.info("Starting NTP client for pool \(stream.ntpPoolAddress!)")
            TrueTimeClient.sharedInstance.start(pool: [stream.ntpPoolAddress!])
        }
    }

    func stopNtpClient() {
        logger.info("Stopping NTP client")
        TrueTimeClient.sharedInstance.pause()
    }

    private func isWeatherNeeded() -> Bool {
        for widget in widgetsInCurrentScene(onlyEnabled: true) {
            guard widget.type == .text else {
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
        for widget in widgetsInCurrentScene(onlyEnabled: true) {
            guard widget.type == .text else {
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
        ioVideoUnitMetalPetal = database.debug.metalPetalFilters
    }

    func setSrtlaBatchSend() {
        srtlaBatchSend = database.debug.srtlaBatchSendEnabled
    }

    func setExternalDisplayContent() {
        switch database.externalDisplayContent {
        case .stream:
            externalDisplayChatEnabled = false
        case .cleanStream:
            externalDisplayChatEnabled = false
        case .chat:
            externalDisplayChatEnabled = true
        case .mirror:
            externalDisplayChatEnabled = false
        }
        setCleanExternalDisplay()
        updateExternalMonitorWindow()
    }

    func setCameraControlsEnabled() {
        cameraControlEnabled = database.cameraControlsEnabled
        media.setCameraControls(enabled: database.cameraControlsEnabled)
    }

    private func setupSampleBufferReceiver() {
        sampleBufferReceiver.delegate = self
        sampleBufferReceiver.start(appGroup: moblinAppGroup)
    }

    func updateFaceFilterSettings() {
        let settings = database.debug.beautyFilterSettings
        faceEffect.safeSettings.mutate { $0 = FaceEffectSettings(
            showCrop: database.debug.beautyFilter,
            showBlur: settings.showBlur,
            showBlurBackground: settings.showBlurBackground,
            showMouth: settings.showMoblin,
            showBeauty: settings.showBeauty,
            shapeRadius: settings.shapeRadius,
            shapeAmount: settings.shapeScale,
            shapeOffset: settings.shapeOffset,
            smoothAmount: settings.smoothAmount,
            smoothRadius: settings.smoothRadius
        ) }
    }

    func updateFaceFilterButtonState() {
        var isOn = false
        if showFace, !showDrawOnStream {
            isOn = true
        }
        if database.debug.beautyFilter {
            isOn = true
        }
        if database.debug.beautyFilterSettings.showBeauty {
            isOn = true
        }
        if database.debug.beautyFilterSettings.showBlur {
            isOn = true
        }
        if database.debug.beautyFilterSettings.showBlurBackground {
            isOn = true
        }
        if database.debug.beautyFilterSettings.showMoblin {
            isOn = true
        }
        setGlobalButtonState(type: .face, isOn: isOn)
        updateQuickButtonStates()
    }

    func updateImageButtonState() {
        var isOn = showingCamera
        if bias != 0.0 {
            isOn = true
        }
        if manualWhiteBalanceEnabled {
            isOn = true
        }
        if manualIsoEnabled {
            isOn = true
        }
        if manualFocusEnabled {
            isOn = true
        }
        setGlobalButtonState(type: .image, isOn: isOn)
        updateQuickButtonStates()
    }

    func updateLutsButtonState() {
        var isOn = showingPanel == .luts
        for lut in allLuts() where lut.enabled! {
            isOn = true
        }
        setGlobalButtonState(type: .luts, isOn: isOn)
        updateQuickButtonStates()
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
            if !database.networkInterfaceNames.contains(where: { interface in
                interface.interfaceName == status.name
            }) {
                let interface = SettingsNetworkInterfaceName()
                interface.interfaceName = status.name
                interface.name = status.name
                database.networkInterfaceNames.append(interface)
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

    @objc func handleDidEnterBackgroundNotification() {
        store()
        replaysStorage.store()
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
            gForceManager?.stop()
            obsWebSocket?.stop()
            media.stopAllNetStreams()
            speechToText.stop()
            stopWorkout(showToast: false)
            stopTeslaVehicle()
            stopNtpClient()
            stopMoblinkRelay()
            stopMoblinkStreamer()
            stopCatPrinters()
            stopCyclingPowerDevices()
            stopHeartRateDevices()
            stopRemoteControlAssistant()
            stopDjiGimbalDevices()
        }
    }

    @objc func handleWillEnterForegroundNotification() {
        guard !ProcessInfo().isiOSAppOnMac else {
            return
        }
        if !shouldStreamInBackground() {
            clearRemoteSceneSettingsAndData()
            reloadStream()
            sceneUpdated(attachCamera: true, updateRemoteScene: false)
            setupAudioSession()
            media.attachDefaultAudioDevice(builtinDelay: database.debug.builtinAudioAndVideoDelay)
            reloadRtmpServer()
            reloadDjiDevices()
            reloadSrtlaServer()
            chatTextToSpeech.reset(running: true)
            startWeatherManager()
            startGeographyManager()
            startGForceManager()
            if isRecording {
                resumeRecording()
            }
            reloadSpeechToText()
            reloadTeslaVehicle()
            reloadMoblinkRelay()
            reloadMoblinkStreamer()
            updateOrientation()
            autoStartCatPrinters()
            autoStartCyclingPowerDevices()
            autoStartHeartRateDevices()
            autoStartDjiGimbalDevices()
        }
    }

    @objc func handleWillTerminate() {
        if isRecording {
            suspendRecording()
        }
        if !showLoadSettingsFailed {
            store()
            replaysStorage.store()
        }
    }

    func externalMonitorConnected(windowScene: UIWindowScene) {
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: ExternalScreenContentView())
        externalDisplayWindow = window
        updateExternalMonitorWindow()
        externalDisplayPreview = true
        reattachCamera()
    }

    func externalMonitorDisconnected() {
        externalDisplayWindow = nil
        externalDisplayPreview = false
        reattachCamera()
    }

    private func updateExternalMonitorWindow() {
        guard let externalDisplayWindow else {
            return
        }
        switch database.externalDisplayContent {
        case .stream:
            externalDisplayWindow.makeKeyAndVisible()
        case .cleanStream:
            externalDisplayWindow.makeKeyAndVisible()
        case .chat:
            externalDisplayWindow.makeKeyAndVisible()
        case .mirror:
            externalDisplayWindow.resignKey()
            externalDisplayWindow.isHidden = true
        }
    }

    private func shouldStreamInBackground() -> Bool {
        if (isLive || isRecording) && stream.backgroundStreaming! {
            return true
        }
        if isLive || isRecording {
            return false
        }
        return database.moblink.client.enabled || database.catPrinters.backgroundPrinting!
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
        if database.rtmpServer.enabled {
            rtmpServer = RtmpServer(settings: database.rtmpServer.clone())
            rtmpServer?.delegate = self
            rtmpServer!.start()
        }
    }

    private func playerCameras() -> [String] {
        return database.mediaPlayers.players.map { $0.camera() }
    }

    func getMediaPlayer(camera: String) -> SettingsMediaPlayer? {
        return database.mediaPlayers.players.first {
            $0.camera() == camera
        }
    }

    func getMediaPlayer(id: UUID) -> SettingsMediaPlayer? {
        return database.mediaPlayers.players.first {
            $0.id == id
        }
    }

    func mediaPlayerCameras() -> [String] {
        return database.mediaPlayers.players.map { $0.camera() }
    }

    func isSceneVideoSourceActive(scene: SettingsScene) -> Bool {
        switch scene.cameraPosition {
        case .rtmp:
            if let stream = getRtmpStream(id: scene.rtmpCameraId!) {
                return isRtmpStreamConnected(streamKey: stream.streamKey)
            } else {
                return false
            }
        case .srtla:
            if let stream = getSrtlaStream(id: scene.srtlaCameraId!) {
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
        if stream.portrait! {
            media.setVideoOrientation(value: .portrait)
        } else {
            switch UIDevice.current.orientation {
            case .landscapeLeft:
                media.setVideoOrientation(value: .landscapeRight)
            case .landscapeRight:
                media.setVideoOrientation(value: .landscapeLeft)
            default:
                break
            }
        }
        updateCameraPreviewRotation()
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
                if let dnsLookupStrategy = srt.dnsLookupStrategy {
                    newStream.srt.dnsLookupStrategy = dnsLookupStrategy
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
                database.quickButtonsGeneral.twoColumns = twoColumns
            }
            if let showName = quickButtons.showName {
                database.quickButtonsGeneral.showName = showName
            }
            if let enableScroll = quickButtons.enableScroll {
                database.quickButtonsGeneral.enableScroll = enableScroll
            }
            if quickButtons.disableAllButtons == true {
                for globalButton in database.quickButtons {
                    globalButton.enabled = false
                }
            }
            for button in quickButtons.buttons ?? [] {
                for globalButton in database.quickButtons {
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
                database.webBrowser.home = home
            }
        }
    }

    private func handleSettingsUrlsDefault(settings: MoblinSettingsUrl) {
        handleSettingsUrlsDefaultStreams(settings: settings)
        handleSettingsUrlsDefaultQuickButtons(settings: settings)
        handleSettingsUrlsDefaultWebBrowser(settings: settings)
        makeToast(title: String(localized: "URL import successful"))
        updateQuickButtonStates()
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
        periodicTimer20ms.startPeriodic(interval: 0.02) {
            self.updateAdaptiveBitrate()
        }
        periodicTimer200ms.startPeriodic(interval: 0.2) {
            let monotonicNow = ContinuousClock.now
            self.updateAudioLevel()
            self.updateChat()
            self.executeChatBotMessage()
            if self.isWatchLocal() {
                self.trySendNextChatPostToWatch()
            }
            if let lastAttachCompletedTime = self.lastAttachCompletedTime,
               lastAttachCompletedTime.duration(to: monotonicNow) > .seconds(0.5)
            {
                self.updateTorch()
                self.lastAttachCompletedTime = nil
            }
            if let relaxedBitrateStartTime = self.relaxedBitrateStartTime,
               relaxedBitrateStartTime.duration(to: monotonicNow) > .seconds(3)
            {
                self.relaxedBitrate = false
                self.relaxedBitrateStartTime = nil
            }
            self.speechToText.tick(now: monotonicNow)
        }
        periodicTimer1s.startPeriodic(interval: 1) {
            let now = Date()
            let monotonicNow = ContinuousClock.now
            self.updateStreamUptime(now: monotonicNow)
            self.updateRecordingLength(now: now)
            self.updateDigitalClock(now: now)
            self.media.updateSrtSpeed()
            self.updateSpeed(now: monotonicNow)
            self.updateServersSpeed()
            self.updateBondingStatistics()
            self.removeOldChatMessages(now: monotonicNow)
            self.updateLocation()
            self.updateObsSourceScreenshot()
            self.updateObsAudioVolume()
            self.updateBrowserWidgetStatus()
            self.logStatus()
            self.updateFailedVideoEffects()
            self.updateAdaptiveBitrateDebug()
            self.updateDistance()
            self.updateSlope()
            self.updateAverageSpeed(now: monotonicNow)
            self.updateTextEffects(now: now, timestamp: monotonicNow)
            self.updateMapEffects()
            self.updatePoll()
            self.updateObsSceneSwitcher(now: monotonicNow)
            self.weatherManager.setLocation(location: self.latestKnownLocation)
            self.geographyManager.setLocation(location: self.latestKnownLocation)
            self.updateBitrateStatus()
            self.updateAdsRemainingTimer(now: now)
            self.keepSpeakerAlive(now: monotonicNow)
            if self.cpuUsageNeeded {
                self.cpuUsage = getCpuUsage()
            }
            self.updateMoblinkStatus()
            self.updateStatusEventsText()
            self.updateStatusChatText()
            self.updateAutoSceneSwitcher(now: monotonicNow)
        }
        periodicTimer3s.startPeriodic(interval: 3) {
            self.teslaGetDriveState()
        }
        periodicTimer5s.startPeriodic(interval: 5) {
            self.updateRemoteControlAssistantStatus()
            if self.isWatchLocal() {
                self.sendThermalStateToWatch(thermalState: self.thermalState)
            }
            self.teslaGetMediaState()
        }
        periodicTimer10s.startPeriodic(interval: 10) {
            let monotonicNow = ContinuousClock.now
            self.updateBatteryLevel()
            self.media.logStatistics()
            self.updateObsStatus()
            self.updateRemoteControlStatus()
            if self.stream.enabled {
                self.media.updateVideoStreamBitrate(bitrate: self.stream.bitrate)
            }
            self.updateViewers()
            self.updateCurrentSsid()
            self.rtmpServerInfo()
            self.teslaGetChargeState()
            self.moblinkStreamer?.updateStatus()
            self.updateDjiDevicesStatus()
            self.updateTwitchStream(monotonicNow: monotonicNow)
            self.updateAvailableDiskSpace()
        }
    }

    private func updateAvailableDiskSpace() {
        guard isRecording, let available = getAvailableDiskSpace() else {
            return
        }
        if available < 1_000_000_000 {
            stopRecording(toastTitle: String(localized: "‼️ Low on disk. Stopping recording. ‼️"),
                          toastSubTitle: String(localized: "Please delete recordings and other big files"))
        } else if available < 2_000_000_000 {
            makeToast(
                title: String(localized: "⚠️ Low on disk ⚠️"),
                subTitle: String(localized: "Please delete recordings and other big files")
            )
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
        storeAndReloadStreamIfEnabled(stream: stream)
    }

    func lutEnabledUpdated() {
        if database.color.lutEnabled, database.color.space == .appleLog {
            media.registerEffect(lutEffect)
        } else {
            media.unregisterEffect(lutEffect)
        }
    }

    func lutUpdated() {
        guard let lut = getLogLutById(id: database.color.lut) else {
            media.unregisterEffect(lutEffect)
            return
        }
        lutEffect.setLut(lut: lut.clone(), imageStorage: imageStorage) { title, subTitle in
            self.makeErrorToastMain(title: title, subTitle: subTitle)
        }
    }

    func addLutCube(url: URL) {
        let lut = SettingsColorLut(type: .diskCube, name: "My LUT")
        imageStorage.write(id: lut.id, url: url)
        database.color.diskLutsCube!.append(lut)
        resetSelectedScene()
    }

    func removeLutCube(offsets: IndexSet) {
        for offset in offsets {
            let lut = database.color.diskLutsCube![offset]
            imageStorage.remove(id: lut.id)
        }
        database.color.diskLutsCube!.remove(atOffsets: offsets)
        resetSelectedScene()
    }

    func addLutPng(data: Data) {
        let lut = SettingsColorLut(type: .disk, name: "My LUT")
        imageStorage.write(id: lut.id, data: data)
        database.color.diskLutsPng!.append(lut)
        resetSelectedScene()
    }

    func removeLutPng(offsets: IndexSet) {
        for offset in offsets {
            let lut = database.color.diskLutsPng![offset]
            imageStorage.remove(id: lut.id)
        }
        database.color.diskLutsPng!.remove(atOffsets: offsets)
        resetSelectedScene()
    }

    func setLutName(lut: SettingsColorLut, name: String) {
        lut.name = name
    }

    func allLuts() -> [SettingsColorLut] {
        return database.color.bundledLuts + database.color.diskLutsCube! + database.color.diskLutsPng!
    }

    func getLogLutById(id: UUID) -> SettingsColorLut? {
        return allLuts().first { $0.id == id }
    }

    private func updateAdaptiveBitrate() {
        if let (lines, actions) = media.updateAdaptiveBitrate(
            overlay: database.debug.srtOverlay,
            relaxed: relaxedBitrate
        ) {
            latestDebugLines = lines
            latestDebugActions = actions
        }
    }

    private func updateAdaptiveBitrateDebug() {
        if database.debug.srtOverlay {
            debugLines = latestDebugLines + latestDebugActions
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
            if database.color.diskLutsPng!.contains(where: { lut in lut.id == id }) {
                used = true
            }
            if database.color.diskLutsCube!.contains(where: { lut in lut.id == id }) {
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
        if let numberOfTwitchViewers {
            newNumberOfViewers += numberOfTwitchViewers
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
        if database.show.audioLevel != audio.showing {
            audio.showing = database.show.audioLevel
        }
        let newAudioLevel = media.getAudioLevel()
        let newNumberOfAudioChannels = media.getNumberOfAudioChannels()
        if newNumberOfAudioChannels != audio.numberOfChannels {
            audio.numberOfChannels = newNumberOfAudioChannels
        }
        if newAudioLevel == audio.level {
            return
        }
        if abs(audio.level - newAudioLevel) > 5 || newAudioLevel
            .isNaN || newAudioLevel == .infinity || audio.level.isNaN || audio.level == .infinity
        {
            audio.level = newAudioLevel
            if isWatchLocal() {
                sendAudioLevelToWatch(audioLevel: audio.level)
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
                handleBondingStatistics(connections: connections)
                return
            }
            if let connections = media.ristBondingStatistics() {
                handleBondingStatistics(connections: connections)
                return
            }
        }
        if bondingStatistics != noValue {
            bondingStatistics = noValue
        }
    }

    private func handleBondingStatistics(connections: [BondingConnection]) {
        if let (message, rtts, percentages) = bondingStatisticsFormatter.format(connections) {
            bondingStatistics = message
            bondingRtts = rtts
            bondingPieChartPercentages = percentages
        }
    }

    func updateSrtlaPriorities() {
        media.setConnectionPriorities(connectionPriorities: stream.srt.connectionPriorities!.clone())
    }

    func pauseChat() {
        chat.paused = true
        chat.pausedPostsCount = 0
        chat.pausedPosts = [createRedLineChatPost()]
    }

    func disableInteractiveChat() {
        _ = appendPausedChatPosts(maximumNumberOfPostsToAppend: Int.max)
        chat.paused = false
    }

    private func createRedLineChatPost() -> ChatPost {
        defer {
            chatPostId += 1
        }
        return ChatPost(
            id: chatPostId,
            user: nil,
            userColor: .init(red: 0, green: 0, blue: 0),
            userBadges: [],
            segments: [],
            timestamp: "",
            timestampTime: .now,
            isAction: false,
            isSubscriber: false,
            bits: nil,
            highlight: nil,
            live: true
        )
    }

    func pauseQuickButtonChat() {
        quickButtonChat.paused = true
        quickButtonChat.pausedPostsCount = 0
        quickButtonChat.pausedPosts = [createRedLineChatPost()]
    }

    func endOfQuickButtonChatReachedWhenPaused() {
        var numberOfPostsAppended = 0
        while numberOfPostsAppended < 5, let post = quickButtonChat.pausedPosts.popFirst() {
            if post.user == nil {
                if let lastPost = quickButtonChat.posts.first, lastPost.user == nil {
                    continue
                }
                if quickButtonChat.pausedPosts.isEmpty {
                    continue
                }
            }
            if quickButtonChat.posts.count > maximumNumberOfInteractiveChatMessages - 1 {
                quickButtonChat.posts.removeLast()
            }
            quickButtonChat.posts.prepend(post)
            numberOfPostsAppended += 1
        }
        if numberOfPostsAppended == 0 {
            quickButtonChat.paused = false
        }
    }

    func endOfChatReachedWhenPaused() {
        if appendPausedChatPosts(maximumNumberOfPostsToAppend: 5) == 0 {
            chat.paused = false
        }
    }

    private func appendPausedChatPosts(maximumNumberOfPostsToAppend: Int) -> Int {
        var numberOfPostsAppended = 0
        while numberOfPostsAppended < maximumNumberOfPostsToAppend, let post = chat.pausedPosts.popFirst() {
            if post.user == nil {
                if let lastPost = chat.posts.first, lastPost.user == nil {
                    continue
                }
                if chat.pausedPosts.isEmpty {
                    continue
                }
            }
            if chat.posts.count > maximumNumberOfChatMessages - 1 {
                chat.posts.removeLast()
            }
            chat.posts.prepend(post)
            numberOfPostsAppended += 1
        }
        return numberOfPostsAppended
    }

    func pauseQuickButtonChatAlerts() {
        quickButtonChatAlertsPaused = true
        pausedQuickButtonChatAlertsPostsCount = 0
    }

    func endOfQuickButtonChatAlertsReachedWhenPaused() {
        var numberOfPostsAppended = 0
        while numberOfPostsAppended < 5, let post = pausedQuickButtonChatAlertsPosts.popFirst() {
            if post.user == nil {
                if let lastPost = quickButtonChatAlertsPosts.first, lastPost.user == nil {
                    continue
                }
                if pausedQuickButtonChatAlertsPosts.isEmpty {
                    continue
                }
            }
            if quickButtonChatAlertsPosts.count > maximumNumberOfInteractiveChatMessages - 1 {
                quickButtonChatAlertsPosts.removeLast()
            }
            quickButtonChatAlertsPosts.prepend(post)
            numberOfPostsAppended += 1
        }
        if numberOfPostsAppended == 0 {
            quickButtonChatAlertsPaused = false
        }
    }

    private func removeOldChatMessages(now: ContinuousClock.Instant) {
        if quickButtonChat.paused {
            return
        }
        guard database.chat.maximumAgeEnabled else {
            return
        }
        while let post = chat.posts.last {
            if now > post.timestampTime + .seconds(database.chat.maximumAge) {
                chat.posts.removeLast()
            } else {
                break
            }
        }
    }

    private func updateChat() {
        while let post = chat.newPosts.popFirst() {
            if chat.posts.count > maximumNumberOfChatMessages - 1 {
                chat.posts.removeLast()
            }
            chat.posts.prepend(post)
            if isWatchLocal() {
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
            streamTotalChatMessages += 1
        }
        chat.update()
        quickButtonChat.update()
        if externalDisplayChatEnabled {
            externalDisplayChat.update()
        }
        if quickButtonChatAlertsPaused {
            // The red line is one post.
            pausedQuickButtonChatAlertsPostsCount = max(pausedQuickButtonChatAlertsPosts.count - 1, 0)
        } else {
            while let post = newQuickButtonChatAlertsPosts.popFirst() {
                if quickButtonChatAlertsPosts.count > maximumNumberOfInteractiveChatMessages - 1 {
                    quickButtonChatAlertsPosts.removeLast()
                }
                quickButtonChatAlertsPosts.prepend(post)
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

    func isAlertMessage(post: ChatPost) -> Bool {
        switch post.highlight?.kind {
        case .redemption:
            return true
        case .newFollower:
            return true
        default:
            return false
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
        media.unregisterEffect(twinEffect)
        media.unregisterEffect(pixellateEffect)
        media.unregisterEffect(pollEffect)
        media.unregisterEffect(whirlpoolEffect)
        media.unregisterEffect(pinchEffect)
        faceEffect = FaceEffect(fps: Float(stream.fps), onFindFaceChanged: handleFindFaceChanged(value:))
        updateFaceFilterSettings()
        movieEffect = MovieEffect()
        grayScaleEffect = GrayScaleEffect()
        sepiaEffect = SepiaEffect()
        tripleEffect = TripleEffect()
        twinEffect = TwinEffect()
        pixellateEffect = PixellateEffect(strength: database.pixellateStrength)
        pollEffect = PollEffect()
        whirlpoolEffect = WhirlpoolEffect()
        pinchEffect = PinchEffect()
    }

    private func isGlobalButtonOn(type: SettingsQuickButtonType) -> Bool {
        return database.quickButtons.first(where: { button in
            button.type == type
        })?.isOn ?? false
    }

    private func isFaceEnabled() -> Bool {
        let settings = database.debug.beautyFilterSettings
        return database.debug.beautyFilter || settings.showBlur || settings.showBlurBackground || settings
            .showMoblin || settings.showBeauty
    }

    private func registerGlobalVideoEffects() -> [VideoEffect] {
        var effects: [VideoEffect] = []
        if isFaceEnabled() {
            effects.append(faceEffect)
        }
        if isGlobalButtonOn(type: .whirlpool) {
            effects.append(whirlpoolEffect)
        }
        if isGlobalButtonOn(type: .pinch) {
            effects.append(pinchEffect)
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
        if isGlobalButtonOn(type: .twin) {
            effects.append(twinEffect)
        }
        if isGlobalButtonOn(type: .pixellate) {
            pixellateEffect.strength.mutate { $0 = database.pixellateStrength }
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
            alert.imageId = database.alertsMediaGallery.bundledImages[0].id
        }
        if getAllAlertSounds().first(where: { $0.id == alert.soundId }) == nil {
            alert.soundId = database.alertsMediaGallery.bundledSounds[0].id
        }
    }

    func fixAlertMedias() {
        for widget in database.widgets {
            fixAlert(alert: widget.alerts.twitch!.follows)
            fixAlert(alert: widget.alerts.twitch!.subscriptions)
            for command in widget.alerts.chatBot!.commands {
                fixAlert(alert: command.alert)
            }
        }
        updateAlertsSettings()
    }

    private func removeUnusedAlertMedias() {
        for mediaId in alertMediaStorage.ids() {
            var found = false
            if database.alertsMediaGallery.customImages.contains(where: { $0.id == mediaId }) {
                found = true
            }
            if database.alertsMediaGallery.customSounds.contains(where: { $0.id == mediaId }) {
                found = true
            }
            for widget in database.widgets where widget.type == .alerts {
                for command in widget.alerts.chatBot!.commands where command.imagePlaygroundImageId! == mediaId {
                    found = true
                    break
                }
            }
            if !found {
                alertMediaStorage.remove(id: mediaId)
            }
        }
    }

    func getAllAlertImages() -> [SettingsAlertsMediaGalleryItem] {
        return database.alertsMediaGallery.bundledImages + database.alertsMediaGallery.customImages
    }

    func getAllAlertSounds() -> [SettingsAlertsMediaGalleryItem] {
        return database.alertsMediaGallery.bundledSounds + database.alertsMediaGallery.customSounds
    }

    func getAlertsEffect(id: UUID) -> AlertsEffect? {
        for (alertsEffectId, alertsEffect) in alertsEffects where id == alertsEffectId {
            return alertsEffect
        }
        return nil
    }

    private func updateTextWidgetsLapTimes(now: Date) {
        for widget in database.widgets where widget.type == .text {
            guard !widget.text.lapTimes!.isEmpty else {
                continue
            }
            let now = now.timeIntervalSince1970
            for lapTimes in widget.text.lapTimes! {
                let lastIndex = lapTimes.lapTimes.endIndex - 1
                guard lastIndex >= 0, let currentLapStartTime = lapTimes.currentLapStartTime else {
                    continue
                }
                lapTimes.lapTimes[lastIndex] = now - currentLapStartTime
            }
            getTextEffect(id: widget.id)?.setLapTimes(lapTimes: widget.text.lapTimes!.map { $0.lapTimes })
        }
    }

    private func updateTextEffects(now: Date, timestamp: ContinuousClock.Instant) {
        guard !textEffects.isEmpty else {
            return
        }
        var stats: TextEffectStats
        if let textStats = remoteSceneData.textStats {
            stats = textStats.toStats()
        } else {
            updateTextWidgetsLapTimes(now: now)
            let location = locationManager.getLatestKnownLocation()
            let weather = weatherManager.getLatestWeather()
            let placemark = geographyManager.getLatestPlacemark()
            stats = TextEffectStats(
                timestamp: timestamp,
                bitrateAndTotal: speedAndTotal,
                date: now,
                debugOverlayLines: debugLines,
                speed: format(speed: location?.speed ?? 0),
                averageSpeed: format(speed: averageSpeed),
                altitude: format(altitude: location?.altitude ?? 0),
                distance: getDistance(),
                slope: "\(Int(slopePercent)) %",
                conditions: weather?.currentWeather.symbolName,
                temperature: weather?.currentWeather.temperature,
                country: placemark?.country ?? "",
                countryFlag: emojiFlag(country: placemark?.isoCountryCode ?? ""),
                city: placemark?.locality,
                muted: isMuteOn,
                heartRates: heartRates,
                activeEnergyBurned: workoutActiveEnergyBurned,
                workoutDistance: workoutDistance,
                power: workoutPower,
                stepCount: workoutStepCount,
                teslaBatteryLevel: textEffectTeslaBatteryLevel(),
                teslaDrive: textEffectTeslaDrive(),
                teslaMedia: textEffectTeslaMedia(),
                cyclingPower: "\(cyclingPower) W",
                cyclingCadence: "\(cyclingCadence)",
                browserTitle: getBrowserTitle(),
                gForce: gForceManager?.getLatest()
            )
            remoteControlAssistantSetRemoteSceneDataTextStats(stats: stats)
        }
        for textEffect in textEffects.values {
            textEffect.updateStats(stats: stats)
        }
    }

    private func getBrowserTitle() -> String {
        if showBrowser {
            return getWebBrowser().title ?? ""
        } else {
            return ""
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
        let location: CLLocation
        if let remoteSceneLocation = remoteSceneData.location {
            location = remoteSceneLocation.toLocation()
        } else {
            guard var latestKnownLocation = locationManager.getLatestKnownLocation() else {
                return
            }
            if isLocationInPrivacyRegion(location: latestKnownLocation) {
                latestKnownLocation = .init()
            }
            remoteControlAssistantSetRemoteSceneDataLocation(location: latestKnownLocation)
            location = latestKnownLocation
        }
        for mapEffect in mapEffects.values {
            mapEffect.updateLocation(location: location)
        }
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

    private func resetVideoEffects(widgets: [SettingsWidget]) {
        unregisterGlobalVideoEffects()
        for textEffect in textEffects.values {
            media.unregisterEffect(textEffect)
        }
        textEffects.removeAll()
        for widget in widgets where widget.type == .text {
            textEffects[widget.id] = TextEffect(
                format: widget.text.formatString,
                backgroundColor: widget.text.backgroundColor!,
                foregroundColor: widget.text.foregroundColor!,
                fontSize: CGFloat(widget.text.fontSize!),
                fontDesign: widget.text.fontDesign!.toSystem(),
                fontWeight: widget.text.fontWeight!.toSystem(),
                fontMonospacedDigits: widget.text.fontMonospacedDigits!,
                horizontalAlignment: widget.text.horizontalAlignment!.toSystem(),
                verticalAlignment: widget.text.verticalAlignment!.toSystem(),
                settingName: widget.name,
                delay: widget.text.delay!,
                timersEndTime: widget.text.timers!.map {
                    .now.advanced(by: .seconds(utcTimeDeltaFromNow(to: $0.endTime)))
                },
                checkboxes: widget.text.checkboxes!.map { $0.checked },
                ratings: widget.text.ratings!.map { $0.rating },
                lapTimes: widget.text.lapTimes!.map { $0.lapTimes }
            )
        }
        for browserEffect in browserEffects.values {
            media.unregisterEffect(browserEffect)
            browserEffect.stop()
        }
        browserEffects.removeAll()
        for widget in widgets where widget.type == .browser {
            let videoSize = media.getVideoSize()
            guard let url = URL(string: widget.browser.url) else {
                continue
            }
            browserEffects[widget.id] = BrowserEffect(
                url: url,
                styleSheet: widget.browser.styleSheet!,
                widget: widget.browser,
                videoSize: videoSize,
                settingName: widget.name,
                moblinAccess: widget.browser.moblinAccess!
            )
        }
        for mapEffect in mapEffects.values {
            media.unregisterEffect(mapEffect)
        }
        mapEffects.removeAll()
        for widget in widgets where widget.type == .map {
            mapEffects[widget.id] = MapEffect(widget: widget.map)
        }
        for qrCodeEffect in qrCodeEffects.values {
            media.unregisterEffect(qrCodeEffect)
        }
        qrCodeEffects.removeAll()
        for widget in widgets where widget.type == .qrCode {
            qrCodeEffects[widget.id] = QrCodeEffect(widget: widget.qrCode)
        }
        for videoSourceEffect in videoSourceEffects.values {
            media.unregisterEffect(videoSourceEffect)
        }
        videoSourceEffects.removeAll()
        for widget in widgets where widget.type == .videoSource {
            videoSourceEffects[widget.id] = VideoSourceEffect()
        }
        for padelScoreboardEffect in padelScoreboardEffects.values {
            media.unregisterEffect(padelScoreboardEffect)
        }
        padelScoreboardEffects.removeAll()
        for widget in widgets where widget.type == .scoreboard {
            padelScoreboardEffects[widget.id] = PadelScoreboardEffect()
        }
        for alertsEffect in alertsEffects.values {
            media.unregisterEffect(alertsEffect)
        }
        alertsEffects.removeAll()
        for widget in widgets where widget.type == .alerts {
            alertsEffects[widget.id] = AlertsEffect(
                settings: widget.alerts.clone(),
                delegate: self,
                mediaStorage: alertMediaStorage,
                bundledImages: database.alertsMediaGallery.bundledImages,
                bundledSounds: database.alertsMediaGallery.bundledSounds
            )
        }
        browsers = browserEffects.map { _, browser in
            Browser(browserEffect: browser)
        }
    }

    func remoteSceneSettingsUpdated() {
        remoteSceneSettingsUpdateRequested = true
        updateRemoteSceneSettings()
    }

    private func updateRemoteSceneSettings() {
        guard !remoteSceneSettingsUpdating else {
            return
        }
        remoteSceneSettingsUpdating = true
        remoteControlAssistantSetRemoteSceneSettings()
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            self.remoteSceneSettingsUpdating = false
            if self.remoteSceneSettingsUpdateRequested {
                self.remoteSceneSettingsUpdateRequested = false
                self.updateRemoteSceneSettings()
            }
        }
    }

    private func getLocalAndRemoteScenes() -> [SettingsScene] {
        return database.scenes + remoteSceneScenes
    }

    private func getLocalAndRemoteWidgets() -> [SettingsWidget] {
        return database.widgets + remoteSceneWidgets
    }

    func resetSelectedScene(changeScene: Bool = true) {
        if !enabledScenes.isEmpty, changeScene {
            setSceneId(id: enabledScenes[0].id)
            sceneIndex = 0
        }
        resetVideoEffects(widgets: getLocalAndRemoteWidgets())
        drawOnStreamEffect.updateOverlay(
            videoSize: media.getVideoSize(),
            size: drawOnStreamSize,
            lines: drawOnStreamLines,
            mirror: isFrontCameraSelected && !database.mirrorFrontCameraOnStream
        )
        for lutEffect in lutEffects.values {
            media.unregisterEffect(lutEffect)
        }
        lutEffects.removeAll()
        for lut in allLuts() {
            let lutEffect = LutEffect()
            lutEffect.setLut(lut: lut.clone(), imageStorage: imageStorage) { title, subTitle in
                self.makeErrorToastMain(title: title, subTitle: subTitle)
            }
            lutEffects[lut.id] = lutEffect
        }
        sceneUpdated(imageEffectChanged: true, attachCamera: true)
    }

    func store() {
        settings.store()
    }

    func networkInterfaceNamesUpdated() {
        media.setNetworkInterfaceNames(networkInterfaceNames: database.networkInterfaceNames)
        bondingStatisticsFormatter.setNetworkInterfaceNames(database.networkInterfaceNames)
    }

    @MainActor
    func playAlert(alert: AlertsEffectAlert) {
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
            widget.alerts.needsSubtitles = !widget.alerts.speechToText!.strings.filter { $0.alert.enabled }.isEmpty
            getAlertsEffect(id: widget.id)?.setSettings(settings: widget.alerts.clone())
        }
        if isSpeechToTextNeeded() {
            reloadSpeechToText()
        }
        sceneUpdated()
    }

    func updateOrientationLock() {
        if stream.portrait! {
            AppDelegate.orientationLock = .portrait
            streamPreviewView.isPortrait = true
            externalDisplayStreamPreviewView.isPortrait = true
        } else if database.portrait {
            AppDelegate.orientationLock = .portrait
            streamPreviewView.isPortrait = false
            externalDisplayStreamPreviewView.isPortrait = false
        } else {
            AppDelegate.orientationLock = .landscape
            streamPreviewView.isPortrait = false
            externalDisplayStreamPreviewView.isPortrait = false
        }
        updateCameraPreviewRotation()
    }

    func toggleRecording() {
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
        var subTitle: String?
        if recordingsStorage.isFull() {
            subTitle = String(localized: "Too many recordings. Deleting oldest recording.")
        }
        makeToast(title: String(localized: "Recording started"), subTitle: subTitle)
        resumeRecording()
    }

    func stopRecording(showToast: Bool = true, toastTitle: String? = nil, toastSubTitle: String? = nil) {
        guard isRecording else {
            return
        }
        setIsRecording(value: false)
        if showToast {
            makeToast(title: toastTitle ?? String(localized: "Recording stopped"), subTitle: toastSubTitle)
        }
        media.setRecordUrl(url: nil)
        suspendRecording()
    }

    func resumeRecording() {
        currentRecording = recordingsStorage.createRecording(settings: stream.clone())
        media.setRecordUrl(url: currentRecording?.url())
        startRecorderIfNeeded()
    }

    private func suspendRecording() {
        stopRecorderIfNeeded()
        if let currentRecording {
            recordingsStorage.append(recording: currentRecording)
            recordingsStorage.store()
        }
        updateRecordingLength(now: Date())
        currentRecording = nil
    }

    func startRecorderIfNeeded() {
        guard !isRecorderRecording else {
            return
        }
        guard isRecording || stream.replay!.enabled else {
            return
        }
        isRecorderRecording = true
        let bitrate = Int(stream.recording!.videoBitrate)
        let keyFrameInterval = Int(stream.recording!.maxKeyFrameInterval)
        let audioBitrate = Int(stream.recording!.audioBitrate!)
        media.startRecording(
            url: isRecording ? currentRecording?.url() : nil,
            replay: stream.replay!.enabled,
            videoCodec: stream.recording!.videoCodec,
            videoBitrate: bitrate != 0 ? bitrate : nil,
            keyFrameInterval: keyFrameInterval != 0 ? keyFrameInterval : nil,
            audioBitrate: audioBitrate != 0 ? audioBitrate : nil
        )
    }

    func stopRecorderIfNeeded(forceStop: Bool = false) {
        guard isRecorderRecording else {
            return
        }
        if forceStop || (!isRecording && !stream.replay!.enabled) {
            media.stopRecording()
            isRecorderRecording = false
        }
    }

    private var isRecorderRecording = false

    func startWorkout(type: WatchProtocolWorkoutType) {
        guard WCSession.default.isWatchAppInstalled else {
            makeToast(title: String(localized: "Install Moblin on your Apple Watch"))
            return
        }
        setIsWorkout(type: type)
        authorizeHealthKit {
            DispatchQueue.main.async {
                if self.isWatchLocal() {
                    self.sendWorkoutToWatch()
                }
            }
        }
        makeToast(
            title: String(localized: "Starting workout"),
            subTitle: String(localized: "Open Moblin in your Apple Watch to start it")
        )
    }

    func stopWorkout(showToast: Bool = true) {
        setIsWorkout(type: nil)
        if isWatchLocal() {
            sendWorkoutToWatch()
        }
        if showToast {
            makeToast(title: String(localized: "Ending workout"),
                      subTitle: String(localized: "Open Moblin in your Apple Watch to end it"))
        }
    }

    func setGlobalButtonState(type: SettingsQuickButtonType, isOn: Bool) {
        for button in database.quickButtons where button.type == type {
            button.isOn = isOn
        }
        for pageButtonPairs in buttonPairs {
            for pair in pageButtonPairs {
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
    }

    func getGlobalButton(type: SettingsQuickButtonType) -> SettingsQuickButton? {
        return database.quickButtons.first(where: { $0.type == type })
    }

    func showQuickButtonSettings(type: SettingsQuickButtonType) {
        quickButtonSettingsButton = getGlobalButton(type: type)
        toggleShowingPanel(type: nil, panel: .none)
        toggleShowingPanel(type: nil, panel: .quickButtonSettings)
    }

    func toggleGlobalButton(type: SettingsQuickButtonType) {
        for button in database.quickButtons where button.type == type {
            button.isOn.toggle()
        }
        for pageButtonPairs in buttonPairs {
            for pair in pageButtonPairs {
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
    }

    func setDisplayPortrait(portrait: Bool) {
        database.portrait = portrait
        setGlobalButtonState(type: .portrait, isOn: portrait)
        updateQuickButtonStates()
        updateOrientationLock()
    }

    func toggleStream() {
        if isLive {
            stopStream()
        } else {
            startStream()
        }
    }

    func setIsLive(value: Bool) {
        isLive = value
        if isWatchLocal() {
            sendIsLiveToWatch(isLive: isLive)
        }
        remoteControlStreamer?.stateChanged(state: RemoteControlState(streaming: isLive))
    }

    func setIsRecording(value: Bool) {
        isRecording = value
        setGlobalButtonState(type: .record, isOn: value)
        updateQuickButtonStates()
        if isWatchLocal() {
            sendIsRecordingToWatch(isRecording: isRecording)
        }
        remoteControlStreamer?.stateChanged(state: RemoteControlState(recording: isRecording))
    }

    func setIsWorkout(type: WatchProtocolWorkoutType?) {
        workoutType = type
        setGlobalButtonState(type: .workout, isOn: type != nil)
        updateQuickButtonStates()
    }

    func setMuteOn(value: Bool) {
        if value {
            isMuteOn = true
        } else {
            isMuteOn = false
        }
        updateMute()
        setGlobalButtonState(type: .mute, isOn: value)
        updateQuickButtonStates()
    }

    func setIsMuted(value: Bool) {
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
        if database.location.resetWhenGoingLive! {
            resetLocationData()
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

    private func startNetStream() {
        streamState = .connecting
        latestLowBitrateTime = .now
        moblinkStreamer?.stopTunnels()
        if stream.twitchMultiTrackEnabled! {
            startNetStreamMultiTrack()
        } else {
            startNetStreamSingleTrack()
        }
    }

    private func startNetStreamMultiTrack() {
        twitchMultiTrackGetClientConfiguration(
            url: stream.url,
            dimensions: stream.dimensions(),
            fps: stream.fps
        ) { response in
            DispatchQueue.main.async {
                self.startNetStreamMultiTrackCompletion(response: response)
            }
        }
    }

    private func startNetStreamMultiTrackCompletion(response: TwitchMultiTrackGetClientConfigurationResponse?) {
        guard let response else {
            return
        }
        guard let ingestEndpoint = response.ingest_endpoints.first(where: { $0.proto == "RTMP" }) else {
            return
        }
        let url = ingestEndpoint.url_template.replacingOccurrences(
            of: "{stream_key}",
            with: ingestEndpoint.authentication
        )
        guard let videoEncoderSettings = createMultiTrackVideoCodecSettings(encoderConfigurations: response
            .encoder_configurations)
        else {
            return
        }
        media.rtmpMultiTrackStartStream(url, videoEncoderSettings)
        updateSpeed(now: .now)
    }

    private func createMultiTrackVideoCodecSettings(
        encoderConfigurations: [TwitchMultiTrackGetClientConfigurationEncoderContiguration]
    )
        -> [VideoEncoderSettings]?
    {
        var videoEncoderSettings: [VideoEncoderSettings] = []
        for encoderConfiguration in encoderConfigurations {
            var settings = VideoEncoderSettings()
            let bitrate = encoderConfiguration.settings.bitrate
            guard bitrate >= 100, bitrate <= 50000 else {
                return nil
            }
            settings.bitRate = bitrate * 1000
            let width = encoderConfiguration.width
            let height = encoderConfiguration.height
            guard width >= 1, width <= 5000 else {
                return nil
            }
            guard height >= 1, height <= 5000 else {
                return nil
            }
            settings.videoSize = CMVideoDimensions(width: width, height: height)
            settings.maxKeyFrameIntervalDuration = encoderConfiguration.settings.keyint_sec
            settings.allowFrameReordering = encoderConfiguration.settings.bframes
            let codec = encoderConfiguration.type
            let profile = encoderConfiguration.settings.profile
            if codec.hasSuffix("avc"), profile == "main" {
                settings.profileLevel = kVTProfileLevel_H264_Main_AutoLevel as String
            } else if codec.hasSuffix("avc"), profile == "high" {
                settings.profileLevel = kVTProfileLevel_H264_High_AutoLevel as String
            } else if codec.hasSuffix("hevc"), profile == "main" {
                settings.profileLevel = kVTProfileLevel_HEVC_Main_AutoLevel as String
            } else {
                logger.error("Unsupported multi track codec and profile combination: \(codec) \(profile)")
                return nil
            }
            videoEncoderSettings.append(settings)
        }
        return videoEncoderSettings
    }

    private func startNetStreamSingleTrack() {
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
                overheadBandwidth: database.debug.srtOverheadBandwidth,
                maximumBandwidthFollowInput: database.debug.maximumBandwidthFollowInput,
                mpegtsPacketsPerPacket: stream.srt.mpegtsPacketsPerPacket,
                networkInterfaceNames: database.networkInterfaceNames,
                connectionPriorities: stream.srt.connectionPriorities!,
                dnsLookupStrategy: stream.srt.dnsLookupStrategy!
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
        moblinkStreamer?.stopTunnels()
        reconnectTimer?.invalidate()
        media.rtmpStopStream()
        media.srtStopStream()
        media.ristStopStream()
        streamStartTime = nil
        updateStreamUptime(now: .now)
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

    func findStream(id: UUID) -> SettingsStream? {
        return database.streams.first { stream in
            stream.id == id
        }
    }

    func reloadStream() {
        cameraPosition = nil
        stopRecorderIfNeeded(forceStop: true)
        stopStream()
        setNetStream()
        setStreamResolution()
        setStreamFps()
        setStreamPreferAutoFps()
        setColorSpace()
        setStreamCodec()
        setStreamAdaptiveResolution()
        setStreamKeyFrameInterval()
        setStreamBitrate(stream: stream)
        setAudioStreamBitrate(stream: stream)
        setAudioStreamFormat(format: .aac)
        setAudioChannelsMap(channelsMap: [
            0: database.audio.audioOutputToInputChannelsMap!.channel1,
            1: database.audio.audioOutputToInputChannelsMap!.channel2,
        ])
        startRecorderIfNeeded()
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
        useRemoteControlForChatAndEvents = false
        reloadChats()
        reloadTwitchEventSub()
        reloadObsWebSocket()
        reloadRemoteControlStreamer()
        reloadRemoteControlAssistant()
        reloadRemoteControlRelay()
        reloadKickViewers()
        reloadNtpClient()
    }

    func createUrlSession() {
        urlSession = URLSession.create(httpProxy: httpProxy())
    }

    func storeAndReloadStreamIfEnabled(stream: SettingsStream) {
        store()
        if stream.enabled {
            reloadStream()
            sceneUpdated(attachCamera: true, updateRemoteScene: false)
        }
    }

    private func setNetStream() {
        cameraPreviewLayer?.session = nil
        media.setNetStream(
            proto: stream.getProtocol(),
            portrait: stream.portrait!,
            timecodesEnabled: isTimecodesEnabled(),
            builtinAudioDelay: database.debug.builtinAudioAndVideoDelay
        )
        updateTorch()
        updateMute()
        attachStream()
        setLowFpsImage()
        setSceneSwitchTransition()
        setCleanSnapshots()
        setCleanRecordings()
        setCleanExternalDisplay()
        updateCameraControls()
    }

    private weak var currentStream: NetStream? {
        didSet {
            oldValue?.mixer.video.drawable = nil
        }
    }

    private func attachStream() {
        guard let stream = media.getNetStream() else {
            currentStream = nil
            return
        }
        netStreamLockQueue.async {
            stream.mixer.video.drawable = self.streamPreviewView
            stream.mixer.video.externalDisplayDrawable = self.externalDisplayStreamPreviewView
            self.currentStream = stream
            stream.mixer.startRunning()
        }
    }

    func isTimecodesEnabled() -> Bool {
        return database.debug.timecodesEnabled && stream.timecodesEnabled! && !stream.ntpPoolAddress!.isEmpty
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
        var captureSize: CGSize
        var outputSize: CGSize
        switch stream.resolution {
        case .r3840x2160:
            captureSize = .init(width: 3840, height: 2160)
            outputSize = .init(width: 3840, height: 2160)
        case .r2560x1440:
            // Use 4K camera and downscale to 1440p.
            captureSize = .init(width: 3840, height: 2160)
            outputSize = .init(width: 2560, height: 1440)
        case .r1920x1080:
            captureSize = .init(width: 1920, height: 1080)
            outputSize = .init(width: 1920, height: 1080)
        case .r1280x720:
            captureSize = .init(width: 1280, height: 720)
            outputSize = .init(width: 1280, height: 720)
        case .r854x480:
            captureSize = .init(width: 1280, height: 720)
            outputSize = .init(width: 854, height: 480)
        case .r640x360:
            captureSize = .init(width: 1280, height: 720)
            outputSize = .init(width: 640, height: 360)
        case .r426x240:
            captureSize = .init(width: 1280, height: 720)
            outputSize = .init(width: 426, height: 240)
        }
        if stream.portrait! {
            outputSize = .init(width: outputSize.height, height: outputSize.width)
        }
        media.setVideoSize(capture: captureSize, output: outputSize)
    }

    func setPixellateStrength(strength: Float) {
        pixellateEffect.strength.mutate { $0 = strength }
    }

    func setStreamFps() {
        media.setStreamFps(fps: stream.fps)
    }

    func setStreamPreferAutoFps() {
        media.setStreamPreferAutoFps(value: stream.autoFps!)
    }

    func setColorSpace() {
        var colorSpace: AVCaptureColorSpace
        switch database.color.space {
        case .srgb:
            colorSpace = .sRGB
        case .p3D65:
            colorSpace = .P3_D65
        case .hlgBt2020:
            colorSpace = .HLG_BT2020
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
                    self.setZoomXWhenInRange(x: x)
                }
                self.lutEnabledUpdated()
            }
        })
    }

    func setStreamBitrate(stream: SettingsStream) {
        media.setVideoStreamBitrate(bitrate: stream.bitrate)
    }

    func getBitratePresetByBitrate(bitrate: UInt32) -> SettingsBitratePreset? {
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

    func setAudioStreamFormat(format: AudioEncoderSettings.Format) {
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
            if database.color.space == .hlgBt2020 {
                media.setVideoProfile(profile: kVTProfileLevel_HEVC_Main10_AutoLevel)
            } else {
                media.setVideoProfile(profile: kVTProfileLevel_HEVC_Main_AutoLevel)
            }
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

    func isEventsConnected() -> Bool {
        return isTwitchEventsConnected()
    }

    func isEventsRemoteControl() -> Bool {
        return useRemoteControlForChatAndEvents
    }

    func isChatConfigured() -> Bool {
        return isTwitchChatConfigured() || isKickPusherConfigured() ||
            isYouTubeLiveChatConfigured() || isAfreecaTvChatConfigured() ||
            isOpenStreamingPlatformChatConfigured()
    }

    func isChatRemoteControl() -> Bool {
        return useRemoteControlForChatAndEvents && database.debug.reliableChat
    }

    func isViewersConfigured() -> Bool {
        return isTwitchViewersConfigured() || isKickViewersConfigured()
    }

    func isKickPusherConfigured() -> Bool {
        return database.chat.enabled && (stream.kickChatroomId != "" || stream.kickChannelName != "")
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
        return database.chat.enabled && stream.youTubeVideoId! != ""
    }

    func isYouTubeLiveChatConnected() -> Bool {
        return youTubeLiveChat?.isConnected() ?? false
    }

    func hasYouTubeLiveChatEmotes() -> Bool {
        return youTubeLiveChat?.hasEmotes() ?? false
    }

    func isAfreecaTvChatConfigured() -> Bool {
        return database.chat.enabled && stream.afreecaTvChannelName! != "" && stream.afreecaTvStreamId! != ""
    }

    func isAfreecaTvChatConnected() -> Bool {
        return afreecaTvChat?.isConnected() ?? false
    }

    func hasAfreecaTvChatEmotes() -> Bool {
        return afreecaTvChat?.hasEmotes() ?? false
    }

    func isOpenStreamingPlatformChatConfigured() -> Bool {
        return database.chat.enabled && stream.openStreamingPlatformUrl! != "" && stream
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

    func resetChat() {
        chat.reset()
        quickButtonChat.reset()
        externalDisplayChat.reset()
        quickButtonChatAlertsPosts = []
        pausedQuickButtonChatAlertsPosts = []
        newQuickButtonChatAlertsPosts = []
        chatBotMessages = []
        chatTextToSpeech.reset(running: true)
        remoteControlStreamerLatestReceivedChatMessageId = -1
    }

    func httpProxy() -> HttpProxy? {
        return settings.database.debug.httpProxy.toHttpProxy()
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
        if isKickPusherConfigured(), !isChatRemoteControl() {
            kickPusher = KickPusher(delegate: self,
                                    channelId: stream.kickChatroomId,
                                    channelName: stream.kickChannelName!,
                                    settings: stream.chat!)
            kickPusher!.start()
        }
    }

    private func reloadYouTubeLiveChat() {
        youTubeLiveChat?.stop()
        youTubeLiveChat = nil
        if isYouTubeLiveChatConfigured(), !isChatRemoteControl() {
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
        if isAfreecaTvChatConfigured(), !isChatRemoteControl() {
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
        if isOpenStreamingPlatformChatConfigured(), !isChatRemoteControl() {
            openStreamingPlatformChat = OpenStreamingPlatformChat(
                model: self,
                url: stream.openStreamingPlatformUrl!,
                channelId: stream.openStreamingPlatformChannelId!
            )
            openStreamingPlatformChat!.start()
        }
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

    func bttvEmotesEnabledUpdated() {
        reloadChats()
    }

    func ffzEmotesEnabledUpdated() {
        reloadChats()
    }

    func seventvEmotesEnabledUpdated() {
        reloadChats()
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
            logger.debug("Status: Bitrate: \(speedAndTotal), Uptime: \(streamUptime.uptime)")
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
        if isWatchReachable(), isWatchLocal() {
            fps = 1.0
        }
        if isRemoteControlStreamerConnected(), isRemoteControlAssistantRequestingPreview {
            fps = database.remoteControl.server.previewFps!
        }
        media.setLowFpsImage(fps: fps)
        lowFpsImageFps = max(UInt64(fps), 1)
    }

    func setSceneSwitchTransition() {
        media.setSceneSwitchTransition(sceneSwitchTransition: database.sceneSwitchTransition.toVideoUnit())
    }

    func setCleanRecordings() {
        media.setCleanRecordings(enabled: stream.recording!.cleanRecordings!)
    }

    func setCleanSnapshots() {
        media.setCleanSnapshots(enabled: stream.recording!.cleanSnapshots!)
    }

    func setCleanExternalDisplay() {
        media.setCleanExternalDisplay(enabled: database.externalDisplayContent == .cleanStream)
    }

    func toggleLocalOverlays() {
        showLocalOverlays.toggle()
    }

    func toggleBrowser() {
        showBrowser.toggle()
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
        highlight: ChatHighlight?,
        live: Bool
    ) {
        if database.chat.usernamesToIgnore.contains(where: { user == $0.value }) {
            return
        }
        if database.chat.botEnabled, live, segments.first?.text?.trim().lowercased() == "!moblin" {
            if chatBotMessages.count < 25 || isModerator {
                chatBotMessages.append(ChatBotMessage(
                    platform: platform,
                    user: user,
                    isModerator: isModerator,
                    isSubscriber: isSubscriber,
                    userId: userId,
                    segments: segments
                ))
            }
        }
        if pollEnabled, live {
            handlePollVote(vote: segments.first?.text?.trim())
        }
        let post = ChatPost(
            id: chatPostId,
            user: user,
            userColor: userColor?.makeReadableOnDarkBackground() ?? database.chat.usernameColor,
            userBadges: userBadges,
            segments: segments,
            timestamp: timestamp,
            timestampTime: timestampTime,
            isAction: isAction,
            isSubscriber: isSubscriber,
            bits: bits,
            highlight: highlight,
            live: live
        )
        chatPostId += 1
        chat.appendMessage(post: post)
        quickButtonChat.appendMessage(post: post)
        for browserEffect in browserEffects.values {
            browserEffect.sendChatMessage(post: post)
        }
        if externalDisplayChatEnabled {
            externalDisplayChat.appendMessage(post: post)
        }
        if highlight != nil {
            if quickButtonChatAlertsPaused {
                if pausedQuickButtonChatAlertsPosts.count < 2 * maximumNumberOfInteractiveChatMessages {
                    pausedQuickButtonChatAlertsPosts.append(post)
                }
            } else {
                newQuickButtonChatAlertsPosts.append(post)
            }
        }
    }

    func reloadChatMessages() {
        chat.posts = newPostIds(posts: chat.posts)
        quickButtonChat.posts = newPostIds(posts: quickButtonChat.posts)
        externalDisplayChat.posts = newPostIds(posts: externalDisplayChat.posts)
        quickButtonChatAlertsPosts = newPostIds(posts: quickButtonChatAlertsPosts)
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

    func toggleLockScreen() {
        lockScreen.toggle()
        setGlobalButtonState(type: .lockScreen, isOn: lockScreen)
        updateQuickButtonStates()
        if lockScreen {
            makeToast(
                title: String(localized: "Screen locked"),
                subTitle: String(localized: "Double tap to unlock")
            )
        } else {
            makeToast(title: String(localized: "Screen unlocked"))
        }
    }

    func findWidget(id: UUID) -> SettingsWidget? {
        for widget in getLocalAndRemoteWidgets() where widget.id == id {
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

    func isCaptureDeviceVideoSoureWidget(widget: SettingsWidget) -> Bool {
        guard widget.type == .videoSource else {
            return false
        }
        switch widget.videoSource.cameraPosition {
        case .back:
            return true
        case .backWideDualLowEnergy:
            return true
        case .backDualLowEnergy:
            return true
        case .backTripleLowEnergy:
            return true
        case .front:
            return true
        case .external:
            return true
        default:
            return false
        }
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
            attachCamera(scene: scene, position: .back)
        case .front:
            attachCamera(scene: scene, position: .front)
            isFrontCameraSelected = true
        case .rtmp:
            attachBufferedCamera(cameraId: scene.rtmpCameraId!, scene: scene)
        case .srtla:
            attachBufferedCamera(cameraId: scene.srtlaCameraId!, scene: scene)
        case .mediaPlayer:
            mediaPlayers[scene.mediaPlayerCameraId!]?.activate()
            attachBufferedCamera(cameraId: scene.mediaPlayerCameraId!, scene: scene)
        case .external:
            attachExternalCamera(scene: scene)
        case .screenCapture:
            attachBufferedCamera(cameraId: screenCaptureCameraId, scene: scene)
        case .backTripleLowEnergy:
            attachBackTripleLowEnergyCamera()
        case .backDualLowEnergy:
            attachBackDualLowEnergyCamera()
        case .backWideDualLowEnergy:
            attachBackWideDualLowEnergyCamera()
        }
    }

    private var builtinCameraIds: [String: UUID] = [:]

    private func getBuiltinCameraId(_ uniqueId: String) -> UUID {
        if let id = builtinCameraIds[uniqueId] {
            return id
        }
        let id = UUID()
        builtinCameraIds[uniqueId] = id
        return id
    }

    private func makeCaptureDevice(device: AVCaptureDevice) -> CaptureDevice {
        return CaptureDevice(device: device, id: getBuiltinCameraId(device.uniqueID))
    }

    func getBuiltinCameraDevices(scene: SettingsScene, sceneDevice: AVCaptureDevice?) -> CaptureDevices {
        var devices = CaptureDevices(hasSceneDevice: false, devices: [])
        if let sceneDevice {
            devices.hasSceneDevice = true
            devices.devices.append(makeCaptureDevice(device: sceneDevice))
        }
        getBuiltinCameraDevicesInScene(scene: scene, devices: &devices.devices)
        return devices
    }

    private func getBuiltinCameraDevicesInScene(scene: SettingsScene, devices: inout [CaptureDevice]) {
        for sceneWidget in scene.widgets {
            guard let widget = findWidget(id: sceneWidget.widgetId) else {
                continue
            }
            guard widget.enabled else {
                continue
            }
            switch widget.type {
            case .videoSource:
                let cameraId: String?
                switch widget.videoSource.cameraPosition! {
                case .back:
                    cameraId = widget.videoSource.backCameraId!
                case .front:
                    cameraId = widget.videoSource.frontCameraId!
                case .external:
                    cameraId = widget.videoSource.externalCameraId!
                default:
                    cameraId = nil
                }
                if let cameraId, let device = AVCaptureDevice(uniqueID: cameraId) {
                    if !devices.contains(where: { $0.device == device }) {
                        devices.append(makeCaptureDevice(device: device))
                    }
                }
            case .scene:
                if let scene = database.scenes.first(where: { $0.id == widget.scene.sceneId }) {
                    getBuiltinCameraDevicesInScene(scene: scene, devices: &devices)
                }
            default:
                break
            }
        }
    }

    func listCameraPositions(excludeBuiltin: Bool = false) -> [(String, String)] {
        var cameras: [(String, String)] = []
        if !excludeBuiltin {
            if hasTripleBackCamera() {
                cameras.append((backTripleLowEnergyCamera, backTripleLowEnergyCamera))
            }
            if hasDualBackCamera() {
                cameras.append((backDualLowEnergyCamera, backDualLowEnergyCamera))
            }
            if hasWideDualBackCamera() {
                cameras.append((backWideDualLowEnergyCamera, backWideDualLowEnergyCamera))
            }
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

    func isBackTripleLowEnergyAutoCamera(cameraId: String) -> Bool {
        return cameraId == backTripleLowEnergyCamera
    }

    func isBackDualLowEnergyAutoCamera(cameraId: String) -> Bool {
        return cameraId == backDualLowEnergyCamera
    }

    func isBackWideDualLowEnergyAutoCamera(cameraId: String) -> Bool {
        return cameraId == backWideDualLowEnergyCamera
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
        } else if isBackTripleLowEnergyAutoCamera(cameraId: cameraId) {
            return .backTripleLowEnergy
        } else if isBackDualLowEnergyAutoCamera(cameraId: cameraId) {
            return .backDualLowEnergy
        } else if isBackWideDualLowEnergyAutoCamera(cameraId: cameraId) {
            return .backWideDualLowEnergy
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
        case .backTripleLowEnergy:
            return backTripleLowEnergyCamera
        case .backDualLowEnergy:
            return backDualLowEnergyCamera
        case .backWideDualLowEnergy:
            return backWideDualLowEnergyCamera
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
        case .backTripleLowEnergy:
            return backTripleLowEnergyCamera
        case .backDualLowEnergy:
            return backDualLowEnergyCamera
        case .backWideDualLowEnergy:
            return backWideDualLowEnergyCamera
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

    private func findSceneWidget(scene: SettingsScene, widgetId: UUID) -> SettingsSceneWidget? {
        return scene.widgets.first(where: { $0.widgetId == widgetId })
    }

    private func sceneUpdatedOn(scene: SettingsScene, attachCamera: Bool) {
        var effects: [VideoEffect] = []
        if database.color.lutEnabled, database.color.space == .appleLog {
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
        var scene = scene
        if let remoteSceneWidget = remoteSceneWidgets.first {
            scene = scene.clone()
            scene.widgets.append(SettingsSceneWidget(widgetId: remoteSceneWidget.id))
        }
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
        media.setPendingAfterAttachEffects(effects: effects, rotation: scene.videoSourceRotation!)
        for browserEffect in browserEffects.values where !usedBrowserEffects.contains(browserEffect) {
            browserEffect.setSceneWidget(sceneWidget: nil, crops: [])
        }
        for mapEffect in mapEffects.values where !usedMapEffects.contains(mapEffect) {
            mapEffect.setSceneWidget(sceneWidget: nil)
        }
        for (id, padelScoreboardEffect) in padelScoreboardEffects
            where !usedPadelScoreboardEffects.contains(padelScoreboardEffect)
        {
            if isWatchLocal() {
                sendRemovePadelScoreboardToWatch(id: id)
            }
        }
        media.setSpeechToText(enabled: needsSpeechToText)
        if attachCamera {
            attachSingleLayout(scene: scene)
        } else {
            media.usePendingAfterAttachEffects()
        }
        // To do: Should update on first frame in draw effect instead.
        if !drawOnStreamLines.isEmpty {
            drawOnStreamEffect.updateOverlay(
                videoSize: media.getVideoSize(),
                size: drawOnStreamSize,
                lines: drawOnStreamLines,
                mirror: isFrontCameraSelected && !database.mirrorFrontCameraOnStream
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
            guard widget.enabled else {
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
                if let browserEffect = browserEffects[widget.id], !usedBrowserEffects.contains(browserEffect) {
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
                if let browserEffect = browserEffects[widget.crop.sourceWidgetId],
                   !usedBrowserEffects.contains(browserEffect)
                {
                    browserEffect.setSceneWidget(
                        sceneWidget: findSceneWidget(scene: scene, widgetId: widget.crop.sourceWidgetId),
                        crops: findWidgetCrops(scene: scene, sourceWidgetId: widget.crop.sourceWidgetId)
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
                if let sceneWidgetScene = getLocalAndRemoteScenes().first(where: { $0.id == widget.scene.sceneId }) {
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
                    if alertsEffect.shouldRegisterEffect() {
                        effects.append(alertsEffect)
                    }
                    alertsEffect.setPosition(x: sceneWidget.x, y: sceneWidget.y)
                    enabledAlertsEffects.append(alertsEffect)
                    if widget.alerts.needsSubtitles! {
                        needsSpeechToText = true
                    }
                }
            case .videoSource:
                if let videoSourceEffect = videoSourceEffects[widget.id] {
                    if let videoSourceId = getVideoSourceId(cameraId: widget.videoSource.toCameraId()) {
                        videoSourceEffect.setVideoSourceId(videoSourceId: videoSourceId)
                    }
                    videoSourceEffect.setSceneWidget(sceneWidget: sceneWidget.clone())
                    videoSourceEffect.setSettings(settings: widget.videoSource.toEffectSettings())
                    effects.append(videoSourceEffect)
                }
            case .scoreboard:
                if let padelScoreboardEffect = padelScoreboardEffects[widget.id] {
                    padelScoreboardEffect.setSceneWidget(sceneWidget: sceneWidget.clone())
                    let scoreboard = widget.scoreboard
                    padelScoreboardEffect
                        .update(scoreboard: padelScoreboardSettingsToEffect(scoreboard.padel))
                    if isWatchLocal() {
                        sendUpdatePadelScoreboardToWatch(id: widget.id, scoreboard: scoreboard)
                    }
                    effects.append(padelScoreboardEffect)
                    usedPadelScoreboardEffects.append(padelScoreboardEffect)
                }
            }
        }
    }

    func padelScoreboardSettingsToEffect(_ scoreboard: SettingsWidgetPadelScoreboard) -> PadelScoreboard {
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
        return database.scoreboardPlayers.first(where: { $0.id == id })?.name ?? "🇸🇪 Moblin"
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
        case let .back(id: id):
            return getBuiltinCameraId(id)
        case let .front(id: id):
            return getBuiltinCameraId(id)
        case let .external(id: id, name: _):
            return getBuiltinCameraId(id)
        case .backDualLowEnergy:
            return nil
        case .backTripleLowEnergy:
            return nil
        case .backWideDualLowEnergy:
            return nil
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
            let crop = widget.crop
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

    private func setSceneId(id: UUID) {
        selectedSceneId = id
        remoteControlStreamer?.stateChanged(state: RemoteControlState(scene: id))
        if isWatchLocal() {
            sendSceneToWatch(id: selectedSceneId)
            sendZoomPresetsToWatch()
            sendZoomPresetToWatch()
        }
        showMediaPlayerControls = enabledScenes.first(where: { $0.id == id })?.cameraPosition == .mediaPlayer
    }

    func getSelectedScene() -> SettingsScene? {
        return findEnabledScene(id: selectedSceneId)
    }

    func showSceneSettings(scene: SettingsScene) {
        sceneSettingsPanelScene = scene
        sceneSettingsPanelSceneId += 1
        toggleShowingPanel(type: nil, panel: .none)
        toggleShowingPanel(type: nil, panel: .sceneSettings)
    }

    func selectSceneByName(name: String) {
        if let scene = enabledScenes.first(where: { $0.name.lowercased() == name.lowercased() }) {
            selectScene(id: scene.id)
        }
    }

    func selectScene(id: UUID) {
        guard id != selectedSceneId else {
            return
        }
        if let index = enabledScenes.firstIndex(where: { scene in
            scene.id == id
        }) {
            sceneIndex = index
            setSceneId(id: id)
            sceneUpdated(attachCamera: true, updateRemoteScene: false)
        }
    }

    private func toggleWidgetOnOff(id: UUID) {
        guard let widget = findWidget(id: id) else {
            return
        }
        widget.enabled.toggle()
        reloadSpeechToText()
        sceneUpdated()
    }

    func sceneUpdated(imageEffectChanged: Bool = false, attachCamera: Bool = false, updateRemoteScene: Bool = true) {
        if imageEffectChanged {
            reloadImageEffects()
        }
        guard let scene = getSelectedScene() else {
            sceneUpdatedOff()
            return
        }
        for browserEffect in browserEffects.values {
            browserEffect.stop()
        }
        sceneUpdatedOn(scene: scene, attachCamera: attachCamera)
        startWeatherManager()
        startGeographyManager()
        startGForceManager()
        if updateRemoteScene {
            remoteSceneSettingsUpdated()
        }
    }

    private func updateStreamUptime(now: ContinuousClock.Instant) {
        if let streamStartTime, isStreamConnected() {
            let elapsed = now - streamStartTime
            streamUptime.uptime = uptimeFormatter.string(from: Double(elapsed.components.seconds))!
        } else if streamUptime.uptime != noValue {
            streamUptime.uptime = noValue
        }
    }

    private func updateRecordingLength(now: Date) {
        if let currentRecording {
            let elapsed = uptimeFormatter.string(from: now.timeIntervalSince(currentRecording.startTime))!
            let size = currentRecording.url().fileSize.formatBytes()
            recording.length = "\(elapsed) (\(size))"
            if isWatchLocal() {
                sendRecordingLengthToWatch(recordingLength: recording.length)
            }
        } else if recording.length != noValue {
            recording.length = noValue
            if isWatchLocal() {
                sendRecordingLengthToWatch(recordingLength: recording.length)
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
                if database.chat.botEnabled, database.chat.botSendLowBatteryWarning {
                    sendChatMessage(message: "Moblin bot: \(lowBatteryMessage)")
                }
            }
        } else {
            batteryLevelLowCounter = -1
        }
    }

    func isKeyboardActive() -> Bool {
        if showingPanel != .none {
            return false
        }
        if showBrowser {
            return false
        }
        if showTwitchAuth {
            return false
        }
        if isPresentingWizard {
            return false
        }
        if isPresentingSetupWizard {
            return false
        }
        if wizardShowTwitchAuth {
            return false
        }
        return true
    }

    @available(iOS 17.0, *)
    func handleKeyPress(press: KeyPress) -> KeyPress.Result {
        let charactersHex = press.characters.data(using: .utf8)?.hexString() ?? "???"
        logger.info("""
        keyboard: Press characters \"\(press.characters)\" (\(charactersHex)), \
        modifiers \(press.modifiers), key \(press.key), phase \(press.phase)
        """)
        guard isKeyboardActive() else {
            return .ignored
        }
        guard let key = database.keyboard.keys.first(where: {
            $0.key == press.characters
        }) else {
            return .ignored
        }
        switch key.function {
        case .unused:
            break
        case .record:
            toggleRecording()
        case .stream:
            toggleStream()
        case .torch:
            toggleTorch()
            toggleGlobalButton(type: .torch)
        case .mute:
            toggleMute()
            toggleGlobalButton(type: .mute)
        case .blackScreen:
            toggleBlackScreen()
        case .scene:
            selectScene(id: key.sceneId)
        case .widget:
            toggleWidgetOnOff(id: key.widgetId!)
        case .instantReplay:
            instantReplay()
        }
        updateQuickButtonStates()
        return .handled
    }

    private func updateBatteryState() {
        batteryState = UIDevice.current.batteryState
    }

    func isBatteryCharging() -> Bool {
        return batteryState == .charging || batteryState == .full
    }

    private func checkLowBitrate(speed: Int64, now: ContinuousClock.Instant) {
        guard database.lowBitrateWarning else {
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
            if speed < stream.bitrate / 5 {
                bitrateStatusIconColor = .red
            } else if speed < stream.bitrate / 2 {
                bitrateStatusIconColor = .orange
            } else {
                bitrateStatusIconColor = nil
            }
            if isWatchLocal() {
                sendSpeedAndTotalToWatch(speedAndTotal: speedAndTotal)
            }
        } else if speedAndTotal != noValue {
            speedMbpsOneDecimal = noValue
            speedAndTotal = noValue
            if isWatchLocal() {
                sendSpeedAndTotalToWatch(speedAndTotal: speedAndTotal)
            }
        }
    }

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
        if isWatchLocal() {
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
        let params = VideoUnitAttachParams(devices: CaptureDevices(hasSceneDevice: false, devices: []),
                                           builtinDelay: 0,
                                           cameraPreviewLayer: cameraPreviewLayer!,
                                           showCameraPreview: false,
                                           externalDisplayPreview: false,
                                           bufferedVideo: nil,
                                           preferredVideoStabilizationMode: .off,
                                           isVideoMirrored: false,
                                           ignoreFramesAfterAttachSeconds: 0.0,
                                           fillFrame: false)
        media.attachCamera(params: params)
    }

    func attachCamera() {
        guard let scene = getSelectedScene() else {
            return
        }
        attachSingleLayout(scene: scene)
    }

    private func updateCameraPreviewRotation() {
        if stream.portrait! {
            cameraPreviewLayer?.connection?.videoOrientation = .portrait
        } else {
            switch UIDevice.current.orientation {
            case .landscapeLeft:
                cameraPreviewLayer?.connection?.videoOrientation = .landscapeRight
            case .landscapeRight:
                cameraPreviewLayer?.connection?.videoOrientation = .landscapeLeft
            default:
                cameraPreviewLayer?.connection?.videoOrientation = .landscapeRight
            }
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
                return database.mirrorFrontCameraOnStream
            }
        }
        return false
    }

    private func getVideoMirroredOnScreen() -> Bool {
        if cameraPosition == .front {
            if stream.portrait! {
                return false
            } else {
                return !database.mirrorFrontCameraOnStream
            }
        }
        return false
    }

    private func lowEnergyCameraUpdateBackZoom(force: Bool) {
        if force {
            updateBackZoomSwitchTo()
        }
    }

    private func updateBackZoomPresetId() {
        for preset in database.zoom.back where preset.x == backZoomX {
            backZoomPresetId = preset.id
        }
    }

    private func updateFrontZoomPresetId() {
        for preset in database.zoom.front where preset.x == frontZoomX {
            frontZoomPresetId = preset.id
        }
    }

    private func updateBackZoomSwitchTo() {
        if database.zoom.switchToBack.enabled {
            clearZoomPresetId()
            backZoomX = database.zoom.switchToBack.x!
            updateBackZoomPresetId()
        }
    }

    private func updateFrontZoomSwitchTo() {
        if database.zoom.switchToFront.enabled {
            clearZoomPresetId()
            frontZoomX = database.zoom.switchToFront.x!
            updateFrontZoomPresetId()
        }
    }

    private func attachBackTripleLowEnergyCamera(force: Bool = true) {
        cameraPosition = .back
        lowEnergyCameraUpdateBackZoom(force: force)
        zoomX = backZoomX
        guard let bestDevice = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back),
              let lastZoomFactor = bestDevice.virtualDeviceSwitchOverVideoZoomFactors.last
        else {
            return
        }
        let scale = bestDevice.getZoomFactorScale(hasUltraWideCamera: hasUltraWideBackCamera())
        let x = (Float(truncating: lastZoomFactor) * scale).rounded()
        var device: AVCaptureDevice?
        if backZoomX < 1.0 {
            device = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
        } else if backZoomX < x {
            device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        } else {
            device = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
        }
        guard let device, let scene = getSelectedScene() else {
            return
        }
        if !force, device == cameraDevice {
            return
        }
        cameraDevice = device
        cameraZoomLevelToXScale = device.getZoomFactorScale(hasUltraWideCamera: hasUltraWideBackCamera())
        (cameraZoomXMinimum, cameraZoomXMaximum) = bestDevice
            .getUIZoomRange(hasUltraWideCamera: hasUltraWideBackCamera())
        attachCameraFinalize(scene: scene)
    }

    private func attachBackDualLowEnergyCamera(force: Bool = true) {
        cameraPosition = .back
        lowEnergyCameraUpdateBackZoom(force: force)
        zoomX = backZoomX
        guard let bestDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back),
              let lastZoomFactor = bestDevice.virtualDeviceSwitchOverVideoZoomFactors.last
        else {
            return
        }
        let scale = bestDevice.getZoomFactorScale(hasUltraWideCamera: hasUltraWideBackCamera())
        let x = (Float(truncating: lastZoomFactor) * scale).rounded()
        var device: AVCaptureDevice?
        if backZoomX < x {
            device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        } else {
            device = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
        }
        guard let device, let scene = getSelectedScene() else {
            return
        }
        if !force, device == cameraDevice {
            return
        }
        cameraDevice = device
        cameraZoomLevelToXScale = device.getZoomFactorScale(hasUltraWideCamera: hasUltraWideBackCamera())
        (cameraZoomXMinimum, cameraZoomXMaximum) = bestDevice
            .getUIZoomRange(hasUltraWideCamera: hasUltraWideBackCamera())
        attachCameraFinalize(scene: scene)
    }

    private func attachBackWideDualLowEnergyCamera(force: Bool = true) {
        cameraPosition = .back
        lowEnergyCameraUpdateBackZoom(force: force)
        zoomX = backZoomX
        guard let bestDevice = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back),
              let lastZoomFactor = bestDevice.virtualDeviceSwitchOverVideoZoomFactors.last
        else {
            return
        }
        let scale = bestDevice.getZoomFactorScale(hasUltraWideCamera: hasUltraWideBackCamera())
        let x = (Float(truncating: lastZoomFactor) * scale).rounded()
        var device: AVCaptureDevice?
        if backZoomX < x {
            device = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
        } else {
            device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        }
        guard let device, let scene = getSelectedScene() else {
            return
        }
        if !force, device == cameraDevice {
            return
        }
        cameraDevice = device
        cameraZoomLevelToXScale = device.getZoomFactorScale(hasUltraWideCamera: hasUltraWideBackCamera())
        (cameraZoomXMinimum, cameraZoomXMaximum) = bestDevice
            .getUIZoomRange(hasUltraWideCamera: hasUltraWideBackCamera())
        attachCameraFinalize(scene: scene)
    }

    private func attachCamera(scene: SettingsScene, position: AVCaptureDevice.Position) {
        cameraDevice = preferredCamera(position: position)
        setFocusAfterCameraAttach()
        cameraZoomLevelToXScale = cameraDevice?.getZoomFactorScale(hasUltraWideCamera: hasUltraWideBackCamera()) ?? 1.0
        (cameraZoomXMinimum, cameraZoomXMaximum) = cameraDevice?
            .getUIZoomRange(hasUltraWideCamera: hasUltraWideBackCamera()) ?? (1.0, 1.0)
        cameraPosition = position
        switch position {
        case .back:
            updateBackZoomSwitchTo()
            zoomX = backZoomX
        case .front:
            updateFrontZoomSwitchTo()
            zoomX = frontZoomX
        default:
            break
        }
        attachCameraFinalize(scene: scene)
    }

    private func attachCameraFinalize(scene: SettingsScene) {
        lastAttachCompletedTime = nil
        let isMirrored = getVideoMirroredOnScreen()
        let params = VideoUnitAttachParams(devices: getBuiltinCameraDevices(scene: scene, sceneDevice: cameraDevice),
                                           builtinDelay: database.debug.builtinAudioAndVideoDelay,
                                           cameraPreviewLayer: cameraPreviewLayer!,
                                           showCameraPreview: updateShowCameraPreview(),
                                           externalDisplayPreview: externalDisplayPreview,
                                           bufferedVideo: nil,
                                           preferredVideoStabilizationMode: getVideoStabilizationMode(scene: scene),
                                           isVideoMirrored: getVideoMirroredOnStream(),
                                           ignoreFramesAfterAttachSeconds: getIgnoreFramesAfterAttachSeconds(),
                                           fillFrame: getFillFrame(scene: scene))
        media.attachCamera(
            params: params,
            onSuccess: {
                self.streamPreviewView.isMirrored = isMirrored
                self.externalDisplayStreamPreviewView.isMirrored = isMirrored
                if let x = self.setCameraZoomX(x: self.zoomX) {
                    self.setZoomXWhenInRange(x: x)
                }
                if let device = self.cameraDevice {
                    self.setIsoAfterCameraAttach(device: device)
                    self.setWhiteBalanceAfterCameraAttach(device: device)
                    self.updateImageButtonState()
                }
                self.lastAttachCompletedTime = .now
                self.relaxedBitrateStartTime = self.lastAttachCompletedTime
                self.relaxedBitrate = self.database.debug.relaxedBitrate
                self.updateCameraPreviewRotation()
            }
        )
        zoomXPinch = zoomX
        hasZoom = true
    }

    private func getIgnoreFramesAfterAttachSeconds() -> Double {
        return Double(database.debug.cameraSwitchRemoveBlackish)
    }

    private func getFillFrame(scene: SettingsScene) -> Bool {
        return scene.fillFrame!
    }

    private func getIgnoreFramesAfterAttachSecondsReplaceCamera() -> Double {
        if database.forceSceneSwitchTransition {
            return Double(database.debug.cameraSwitchRemoveBlackish)
        } else {
            return 0.0
        }
    }

    private func attachBufferedCamera(cameraId: UUID, scene: SettingsScene) {
        cameraDevice = nil
        cameraPosition = nil
        streamPreviewView.isMirrored = false
        externalDisplayStreamPreviewView.isMirrored = false
        hasZoom = false
        media.attachBufferedCamera(
            devices: getBuiltinCameraDevices(scene: scene, sceneDevice: nil),
            builtinDelay: database.debug.builtinAudioAndVideoDelay,
            cameraPreviewLayer: cameraPreviewLayer!,
            externalDisplayPreview: externalDisplayPreview,
            cameraId: cameraId,
            ignoreFramesAfterAttachSeconds: getIgnoreFramesAfterAttachSecondsReplaceCamera(),
            fillFrame: getFillFrame(scene: scene)
        )
        media.usePendingAfterAttachEffects()
    }

    private func attachExternalCamera(scene: SettingsScene) {
        attachCamera(scene: scene, position: .unspecified)
    }

    func setCameraZoomX(x: Float, rate: Float? = nil) -> Float? {
        return cameraZoomLevelToX(media.setCameraZoomLevel(
            device: cameraDevice,
            level: x / cameraZoomLevelToXScale,
            rate: rate
        ))
    }

    func stopCameraZoom() -> Float? {
        return cameraZoomLevelToX(media.stopCameraZoomLevel(device: cameraDevice))
    }

    private func cameraZoomLevelToX(_ level: Float?) -> Float? {
        if let level {
            return level * cameraZoomLevelToXScale
        }
        return nil
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

    private func getVideoStabilizationMode(scene: SettingsScene) -> AVCaptureVideoStabilizationMode {
        if scene.overrideVideoStabilizationMode! {
            return getVideoStabilization(mode: scene.videoStabilizationMode!)
        } else {
            return getVideoStabilization(mode: database.videoStabilizationMode)
        }
    }

    private func getVideoStabilization(mode: SettingsVideoStabilizationMode) -> AVCaptureVideoStabilizationMode {
        if #available(iOS 18.0, *) {
            switch mode {
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
            switch mode {
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

    func updateTorch() {
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

    func updateMute() {
        media.setMute(on: isMuteOn)
        if isWatchLocal() {
            sendIsMutedToWatch(isMuteOn: isMuteOn)
        }
        updateTextEffects(now: .now, timestamp: .now)
        forceUpdateTextEffects()
    }

    private func updateCameraControls() {
        media.setCameraControls(enabled: database.cameraControlsEnabled)
    }

    func setZoomPreset(id: UUID) {
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
                setZoomXWhenInRange(x: preset.x!)
                switch getSelectedScene()?.cameraPosition {
                case .backTripleLowEnergy:
                    attachBackTripleLowEnergyCamera(force: false)
                case .backDualLowEnergy:
                    attachBackDualLowEnergyCamera(force: false)
                case .backWideDualLowEnergy:
                    attachBackWideDualLowEnergyCamera(force: false)
                default:
                    break
                }
            }
            if isWatchLocal() {
                sendZoomPresetToWatch()
            }
        } else {
            clearZoomPresetId()
        }
    }

    func setZoomX(x: Float, rate: Float? = nil, setPinch: Bool = true) {
        clearZoomPresetId()
        if let x = setCameraZoomX(x: x, rate: rate) {
            setZoomXWhenInRange(x: x, setPinch: setPinch)
        }
    }

    func setZoomXWhenInRange(x: Float, setPinch: Bool = true) {
        switch cameraPosition {
        case .back:
            backZoomX = x
            updateBackZoomPresetId()
        case .front:
            frontZoomX = x
            updateFrontZoomPresetId()
        default:
            break
        }
        zoomX = x
        remoteControlStreamer?.stateChanged(state: RemoteControlState(zoom: x))
        if isWatchLocal() {
            sendZoomToWatch(x: x)
        }
        if setPinch {
            zoomXPinch = zoomX
        }
    }

    func changeZoomX(amount: Float, rate: Float? = nil) {
        guard hasZoom else {
            return
        }
        setZoomX(x: zoomXPinch * amount, rate: rate, setPinch: false)
    }

    func commitZoomX(amount: Float, rate: Float? = nil) {
        guard hasZoom else {
            return
        }
        setZoomX(x: zoomXPinch * amount, rate: rate)
    }

    private func clearZoomPresetId() {
        switch cameraPosition {
        case .back:
            backZoomPresetId = noBackZoomPresetId
        case .front:
            frontZoomPresetId = noFrontZoomPresetId
        default:
            break
        }
        if isWatchLocal() {
            sendZoomPresetToWatch()
        }
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
                if isWatchLocal() {
                    sendPreviewToWatch(image: image)
                }
            }
            sendPreviewToRemoteControlAssistant(preview: image)
        }
    }

    private func handleFindVideoFormatError(findVideoFormatError: String, activeFormat: String) {
        makeErrorToastMain(title: findVideoFormatError, subTitle: activeFormat)
    }

    private func handleAttachCameraError() {
        makeErrorToastMain(
            title: String(localized: "Camera capture setup error"),
            subTitle: videoCaptureError()
        )
    }

    private func handleCaptureSessionError(message: String) {
        makeErrorToastMain(title: message, subTitle: videoCaptureError())
    }

    private func handleRecorderFinished() {}

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
        updateStreamUptime(now: .now)
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
                self.startNetStream()
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
        sceneUpdated(updateRemoteScene: false)
    }

    func frontZoomUpdated() {
        if !database.zoom.front.contains(where: { level in
            level.id == frontZoomPresetId
        }) {
            frontZoomPresetId = database.zoom.front[0].id
        }
        sceneUpdated(updateRemoteScene: false)
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

    private func makeFlameRedToast() {
        makeWarningToast(title: flameRedMessage, vibrate: true)
    }

    func startMotionDetection() {
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

    func stopMotionDetection() {
        motionManager.stopDeviceMotionUpdates()
    }

    private func preferredCamera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
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
        let fps: String
        if autoFps {
            fps = "\(selectedFps ?? stream.fps) LLB"
        } else {
            fps = String(selectedFps ?? stream.fps)
        }
        return """
        \(stream.name) (\(resolution), \(fps), \(proto), \(codec) \(bitrate), \
        \(audioCodec) \(audioBitrate))
        """
    }

    func statusCameraText() -> String {
        return getCameraPositionName(scene: findEnabledScene(id: selectedSceneId))
    }

    func statusZoomText() -> String {
        return String(format: "%.1f", zoomX)
    }

    private func updateStatusEventsText() {
        let status: String
        if !isEventsConfigured() {
            status = String(localized: "Not configured")
        } else if isEventsRemoteControl() {
            if isRemoteControlStreamerConnected() {
                status = String(localized: "Connected (remote control)")
            } else {
                status = String(localized: "Disconnected (remote control)")
            }
        } else {
            if isEventsConnected() {
                status = String(localized: "Connected")
            } else {
                status = String(localized: "Disconnected")
            }
        }
        if status != statusEventsText {
            statusEventsText = status
        }
    }

    private func updateStatusChatText() {
        let status: String
        if !isChatConfigured() {
            status = String(localized: "Not configured")
        } else if isChatRemoteControl() {
            if isRemoteControlStreamerConnected() {
                status = String(localized: "Connected (remote control)")
            } else {
                status = String(localized: "Disconnected (remote control)")
            }
        } else if isChatConnected() {
            status = String(localized: "Connected")
        } else {
            status = String(localized: "Disconnected")
        }
        if status != statusChatText {
            statusChatText = status
        }
    }

    func statusViewersText() -> String {
        if isViewersConfigured() {
            return numberOfViewers
        } else {
            return String(localized: "Not configured")
        }
    }

    func isShowingStatusHypeTrain() -> Bool {
        return hypeTrainStatus != noValue
    }

    func isShowingStatusAdsRemainingTimer() -> Bool {
        return adsRemainingTimerStatus != noValue
    }

    func isShowingStatusServers() -> Bool {
        return database.show.rtmpSpeed! && isServersConfigured()
    }

    func isServersConfigured() -> Bool {
        return rtmpServerEnabled() || srtlaServerEnabled()
    }

    func isShowingStatusMoblink() -> Bool {
        return database.show.moblink! && isAnyMoblinkConfigured()
    }

    func isAnyMoblinkConfigured() -> Bool {
        return isMoblinkRelayConfigured() || isMoblinkStreamerConfigured()
    }

    func isShowingStatusDjiDevices() -> Bool {
        return database.show.djiDevices! && djiDevicesStatus != noValue
    }

    func isShowingStatusBitrate() -> Bool {
        return database.show.speed && isLive
    }

    func isShowingStatusStreamUptime() -> Bool {
        return database.show.uptime && isLive
    }

    func isShowingStatusBonding() -> Bool {
        return database.show.bonding! && isStatusBondingActive()
    }

    func isStatusBondingActive() -> Bool {
        return stream.isBonding() && isLive
    }

    func isShowingStatusBondingRtts() -> Bool {
        return database.show.bondingRtts! && isStatusBondingRttsActive()
    }

    func isStatusBondingRttsActive() -> Bool {
        return stream.isBonding() && isLive
    }

    func isShowingStatusRecording() -> Bool {
        return isRecording
    }

    func isShowingStatusReplay() -> Bool {
        return stream.replay!.enabled
    }

    func isShowingStatusBrowserWidgets() -> Bool {
        return database.show.browserWidgets! && isStatusBrowserWidgetsActive()
    }

    func isShowingStatusCatPrinter() -> Bool {
        return database.show.catPrinter! && isAnyCatPrinterConfigured()
    }

    func isShowingStatusCyclingPowerDevice() -> Bool {
        return database.show.cyclingPowerDevice! && isAnyCyclingPowerDeviceConfigured()
    }

    func isShowingStatusHeartRateDevice() -> Bool {
        return database.show.heartRateDevice! && isAnyHeartRateDeviceConfigured()
    }

    func isStatusBrowserWidgetsActive() -> Bool {
        return !browserWidgetsStatus.isEmpty && browserWidgetsStatusChanged
    }
}

extension Model {
    func toggleDrawOnStream() {
        showDrawOnStream.toggle()
        drawOnStreamUpdateButtonState()
    }

    func drawOnStreamLineComplete() {
        drawOnStreamEffect.updateOverlay(
            videoSize: media.getVideoSize(),
            size: drawOnStreamSize,
            lines: drawOnStreamLines,
            mirror: isFrontCameraSelected && !database.mirrorFrontCameraOnStream
        )
        media.registerEffect(drawOnStreamEffect)
        drawOnStreamUpdateButtonState()
    }

    func drawOnStreamWipe() {
        drawOnStreamLines = []
        drawOnStreamEffect.updateOverlay(
            videoSize: media.getVideoSize(),
            size: drawOnStreamSize,
            lines: drawOnStreamLines,
            mirror: isFrontCameraSelected && !database.mirrorFrontCameraOnStream
        )
        media.unregisterEffect(drawOnStreamEffect)
        drawOnStreamUpdateButtonState()
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
            mirror: isFrontCameraSelected && !database.mirrorFrontCameraOnStream
        )
        if drawOnStreamLines.isEmpty {
            media.unregisterEffect(drawOnStreamEffect)
        }
        drawOnStreamUpdateButtonState()
    }

    func drawOnStreamUpdateButtonState() {
        setGlobalButtonState(type: .draw, isOn: showDrawOnStream || !drawOnStreamLines.isEmpty)
        updateQuickButtonStates()
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
        webBrowserUrl = database.webBrowser.home
        loadWebBrowserUrl()
    }

    func getWebBrowser() -> WKWebView {
        if webBrowser == nil {
            webBrowser = WKWebView()
            webBrowser?.navigationDelegate = self
            webBrowser?.uiDelegate = webBrowserController
            webBrowser?.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
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
    private func initMediaPlayers() {
        for settings in database.mediaPlayers.players {
            addMediaPlayer(settings: settings)
        }
        removeUnusedMediaPlayerFiles()
    }

    private func removeUnusedMediaPlayerFiles() {
        for mediaId in mediaStorage.ids() {
            var found = false
            for player in database.mediaPlayers.players
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
        media.addBufferedVideo(cameraId: playerId, name: name, latency: latency)
        media.addBufferedAudio(cameraId: playerId, name: name, latency: latency)
        // DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        //     self.selectMicById(id: "\(playerId) 0")
        // }
    }

    func mediaPlayerFileUnloaded(playerId: UUID) {
        media.removeBufferedVideo(cameraId: playerId)
        media.removeBufferedAudio(cameraId: playerId)
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
        media.appendBufferedVideoSampleBuffer(cameraId: playerId, sampleBuffer: sampleBuffer)
    }

    func mediaPlayerAudioBuffer(playerId: UUID, sampleBuffer: CMSampleBuffer) {
        media.appendBufferedAudioSampleBuffer(cameraId: playerId, sampleBuffer: sampleBuffer)
    }
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

extension Model: FaxReceiverDelegate {
    func faxReceiverPrint(image: CIImage) {
        DispatchQueue.main.async {
            self.printAllCatPrinters(image: image)
        }
    }
}

extension Model: MediaDelegate {
    func mediaOnSrtConnected() {
        handleSrtConnected()
    }

    func mediaOnSrtDisconnected(_ reason: String) {
        handleSrtDisconnected(reason: reason)
    }

    func mediaOnRtmpConnected() {
        handleRtmpConnected()
    }

    func mediaOnRtmpDisconnected(_ message: String) {
        handleRtmpDisconnected(message: message)
    }

    func mediaOnRistConnected() {
        handleRistConnected()
    }

    func mediaOnRistDisconnected() {
        handleRistDisconnected()
    }

    func mediaOnAudioMuteChange() {
        updateAudioLevel()
    }

    func mediaOnAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        handleAudioBuffer(sampleBuffer: sampleBuffer)
    }

    func mediaOnLowFpsImage(_ lowFpsImage: Data?, _ frameNumber: UInt64) {
        handleLowFpsImage(image: lowFpsImage, frameNumber: frameNumber)
    }

    func mediaOnFindVideoFormatError(_ findVideoFormatError: String, _ activeFormat: String) {
        handleFindVideoFormatError(findVideoFormatError: findVideoFormatError, activeFormat: activeFormat)
    }

    func mediaOnAttachCameraError() {
        handleAttachCameraError()
    }

    func mediaOnCaptureSessionError(_ message: String) {
        handleCaptureSessionError(message: message)
    }

    func mediaOnRecorderInitSegment(data: Data) {
        handleRecorderInitSegment(data: data)
    }

    func mediaOnRecorderDataSegment(segment: RecorderDataSegment) {
        handleRecorderDataSegment(segment: segment)
    }

    func mediaOnRecorderFinished() {
        handleRecorderFinished()
    }

    func mediaOnNoTorch() {
        handleNoTorch()
    }

    func mediaStrlaRelayDestinationAddress(address: String, port: UInt16) {
        moblinkStreamer?.startTunnels(address: address, port: port)
    }

    func mediaSetZoomX(x: Float) {
        setZoomX(x: x)
    }

    func mediaSetExposureBias(bias: Float) {
        setExposureBias(bias: bias)
    }

    func mediaSelectedFps(fps: Double, auto: Bool) {
        DispatchQueue.main.async {
            self.selectedFps = Int(fps)
            self.autoFps = auto
        }
    }

    func mediaError(error: Error) {
        makeErrorToastMain(title: error.localizedDescription, subTitle: tryGetToastSubTitle(error: error))
    }
}

extension Model: KickOusherDelegate {
    func kickPusherMakeErrorToast(title: String, subTitle: String?) {
        makeErrorToast(title: title, subTitle: subTitle)
    }

    func kickPusherAppendMessage(
        user: String,
        userColor: RgbColor?,
        segments: [ChatPostSegment],
        isSubscriber: Bool,
        isModerator: Bool,
        highlight: ChatHighlight?
    ) {
        appendChatMessage(platform: .kick,
                          user: user,
                          userId: nil,
                          userColor: userColor,
                          userBadges: [],
                          segments: segments,
                          timestamp: digitalClock,
                          timestampTime: .now,
                          isAction: false,
                          isSubscriber: isSubscriber,
                          isModerator: isModerator,
                          bits: nil,
                          highlight: highlight,
                          live: true)
    }
}

private func videoCaptureError() -> String {
    return [
        String(localized: "Try to use single or low-energy cameras."),
        String(localized: "Try to lower stream FPS and resolution."),
    ].joined(separator: "\n")
}
