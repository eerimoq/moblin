import AlertToast
import Collections
import Combine
import CoreBluetooth
import CoreMotion
import GameController
import HealthKit
import MediaPlayer
import NetworkExtension
import PhotosUI
import SDWebImageSwiftUI
import SDWebImageWebPCoder
import StoreKit
import SwiftUI
import TrueTime
import WatchConnectivity
import WebKit

private enum BackgroundRunLevel {
    // Streaming and recording
    case full
    // Moblink and cat printer
    case service(keepChatRunning: Bool)
    case off
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
    case streamingButtonSettings

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

let fallbackStream = SettingsStream(name: "Fallback")
let flameRedMessage = String(localized: "🔥 Flame is red 🔥")
let unknownSad = String(localized: "Unknown 😢")

func formatWarning(_ message: String) -> String {
    return "⚠️ \(message) ⚠️"
}

let noMic = SettingsMicsMic()

class ButtonState {
    var isOn: Bool
    var button: SettingsQuickButton

    init(isOn: Bool, button: SettingsQuickButton) {
        self.isOn = isOn
        self.button = button
    }
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

class DebugOverlayProvider: ObservableObject {
    var cpuUsage: Float = 0.0
    @Published var debugLines: [String] = []
}

class StreamUptimeProvider: ObservableObject {
    @Published var uptime = noValue
}

class HypeTrain: ObservableObject {
    @Published var status = noValue
    @Published var level: Int?
    @Published var progress: Int?
    @Published var goal: Int?
    var timer = SimpleTimer(queue: .main)
}

class Ingests: ObservableObject {
    var rtmp: RtmpServer?
    var srtla: SrtlaServer?
    var rist: RistServer?
    var rtsp: [RtspClient] = []
    @Published var speedAndTotal = noValue
}

class Bitrate: ObservableObject {
    @Published var speedAndTotal = noValue
    @Published var speedMbpsOneDecimal = noValue
    @Published var statusColor: Color = .white
    @Published var statusIconColor: Color?
}

class Bonding: ObservableObject {
    @Published var statistics = noValue
    @Published var rtts = noValue
    @Published var pieChartPercentages: [BondingPercentage] = []
    var statisticsFormatter = BondingStatisticsFormatter()
}

class Show: ObservableObject {
    @Published var cameraPreview = false
    @Published var cameraBias = false
    @Published var cameraWhiteBalance = false
    @Published var cameraIso = false
    @Published var cameraFocus = false
    @Published var faceBeauty = false
    @Published var faceBeautyShape = false
    @Published var faceBeautySmooth = false
}

class Battery: ObservableObject {
    var levelLowCounter = -1
    @Published var level = Double(UIDevice.current.batteryLevel)
    @Published var state: UIDevice.BatteryState = .full
}

class StatusOther: ObservableObject {
    @Published var ipStatuses: [IPMonitor.Status] = []
    @Published var thermalState = ProcessInfo.processInfo.thermalState
    @Published var digitalClock = noValue
}

class StatusTopLeft: ObservableObject {
    @Published var numberOfViewers = noValue
    @Published var statusEventsText = noValue
    @Published var statusChatText = noValue
    @Published var streamText = noValue
    @Published var statusCameraText = noValue
    @Published var statusObsText = noValue
}

class StatusTopRight: ObservableObject {
    @Published var browserWidgetsStatusChanged = false
    @Published var remoteControlStatus = noValue
    @Published var djiDevicesStatus = noValue
    @Published var browserWidgetsStatus = noValue
    @Published var catPrinterStatus = noValue
    @Published var cyclingPowerDeviceStatus = noValue
    @Published var heartRateDeviceStatus = noValue
    @Published var fixedHorizonStatus = noValue
    @Published var adsRemainingTimerStatus = noValue
    @Published var phoneCoolerPhoneTemp: Int?
    @Published var phoneCoolerExhaustTemp: Int?
    @Published var phoneCoolerDeviceState: PhoneCoolerDeviceState?
    @Published var gameControllersTotal = noValue
    @Published var djiDeviceStreamingState: DjiDeviceState?
    @Published var catPrinterState: CatPrinterState?
    @Published var cyclingPowerDeviceState: CyclingPowerDeviceState?
    @Published var heartRateDeviceState: HeartRateDeviceState?
    @Published var location = noValue
    @Published var isLowPowerMode = false
}

class Toast: ObservableObject {
    @Published var showingToast = false
    @Published var toast = AlertToast(type: .regular, title: "") {
        didSet {
            showingToast.toggle()
        }
    }

    var onTapped: (() -> Void)?
}

class SceneSelector: ObservableObject {
    @Published var sceneIndex = 0
    var selectedSceneId = UUID()
}

class StreamOverlay: ObservableObject {
    @Published var showMediaPlayerControls = false
    @Published var isFrontCameraSelected = false
    @Published var showingCamera = false
    @Published var showingPinch = false
    @Published var showingReplay = false
    @Published var showingPixellate = false
    @Published var showingWhirlpool = false
    @Published var isTorchOn = false
}

class Cosmetics: ObservableObject {
    @Published var myIcons: [Icon] = []
    @Published var iconsInStore: [Icon] = []
    @Published var iconImage: String = plainIcon.id
    var hasBoughtSomething: Bool = true
}

class DrawOnStream: ObservableObject {
    @Published var lines: [DrawOnStreamLine] = []
    @Published var selectedColor: Color = .pink
    @Published var selectedWidth: CGFloat = 4
}

class StealthMode: ObservableObject {
    var hideButtonsTimer = SimpleTimer(queue: .main)
    @Published var showChat = false
    @Published var showButtons = true
    @Published var image: UIImage?
}

class QuickButtonChat: ObservableObject {
    @Published var showAllChatMessages = true
    @Published var showFirstTimeChatterMessage = true
    @Published var showNewFollowerMessage = true
    @Published var chatAlertsPosts: Deque<ChatPost> = []
    @Published var pausedChatAlertsPostsCount: Int = 0
    @Published var chatAlertsPaused = false
}

class ExternalDisplay: ObservableObject {
    @Published var chatEnabled = false
}

class GoProState: ObservableObject {
    @Published var launchLiveStreamSelection: UUID?
    @Published var wifiCredentialsSelection: UUID?
    @Published var rtmpUrlSelection: UUID?
}

class QuickButtons: ObservableObject {
    @Published var pairs: [[QuickButtonPair]] = Array(repeating: [], count: controlBarPages)
}

class Snapshot: ObservableObject {
    @Published var countdown = 0
    @Published var currentJob: SnapshotJob?
}

final class Model: NSObject, ObservableObject, @unchecked Sendable {
    @Published var isPresentingWidgetWizard = false
    @Published var showingPanel: ShowingPanel = .none
    @Published var panelHidden = false
    @Published var showStealthMode = false
    @Published var lockScreen = false
    @Published var findFace = false
    @Published var isLive = false
    @Published var isRecording = false
    @Published var browsers: [Browser] = []
    @Published var showingGrid = false
    @Published var showingRemoteControl = false
    @Published var portraitVideoOffsetFromTop = 0.0
    @Published var currentStreamId = UUID()
    @Published var showTwitchAuth = false
    @Published var showDrawOnStream = false
    @Published var showFace = false
    @Published var showLocalOverlays = true
    @Published var showBrowser = false
    @Published var webBrowserUrl: String = ""
    @Published var quickButtonSettingsButton: SettingsQuickButton?
    @Published var bluetoothAllowed = false
    @Published var sceneSettingsPanelSceneId = 1
    @Published var showLoadSettingsFailed = false
    @Published var cameraControlEnabled = false
    @Published var stream: SettingsStream = fallbackStream
    var activeBufferedVideoIds: Set<UUID> = []

    var streamState = StreamState.disconnected {
        didSet {
            logger.info("stream: State \(oldValue) -> \(streamState)")
        }
    }

    var defaultMic = noMic {
        didSet {
            database.mics.defaultMic = defaultMic.id
        }
    }

    let snapshot = Snapshot()
    let quickButtons = QuickButtons()
    let mic = Mic()
    let goPro = GoProState()
    let obsQuickButton = QuickButtonObs()
    let streamingHistory = StreamingHistory()
    let quickButtonChatState = QuickButtonChat()
    let externalDisplay = ExternalDisplay()
    let tesla = Tesla()
    let debugOverlay = DebugOverlayProvider()
    let stealthMode = StealthMode()
    let drawOnStream = DrawOnStream()
    let cosmetics = Cosmetics()
    let show = Show()
    let streamOverlay = StreamOverlay()
    let sceneSelector = SceneSelector()
    let toast = Toast()
    let statusOther = StatusOther()
    let statusTopLeft = StatusTopLeft()
    let statusTopRight = StatusTopRight()
    let battery = Battery()
    let remoteControl = RemoteControl()
    let createStreamWizard = CreateStreamWizard()
    let zoom = Zoom()
    let camera = CameraState()
    let mediaPlayerPlayer = MediaPlayerPlayer()
    let media = Media()
    let hypeTrain = HypeTrain()
    let moblink = Moblink()
    let ingests = Ingests()
    let bitrate = Bitrate()
    let bonding = Bonding()
    var selectedFps: Int?
    var autoFps = false
    var showBackgroudStreamingDisabledToast = false
    private var manualFocusMotionAttitude: CMAttitude?
    private var findFaceTimer: Timer?
    var streaming = false
    var micChange = noMic
    var streamStartTime: ContinuousClock.Instant?
    var isRecorderRecording = false
    var workoutType: WatchProtocolWorkoutType?
    var currentRecording: Recording?
    let recording = RecordingProvider()
    private var subscriptions = Set<AnyCancellable>()
    var streamUptime = StreamUptimeProvider()
    let audio = AudioProvider()
    var settings = Settings()
    var twitchChat: TwitchChat?
    var twitchEventSub: TwitchEventSub?
    var kickPusher: KickPusher?
    var kickViewers: KickViewers?
    private var youTubeLiveChat: YouTubeLiveChat?
    private var afreecaTvChat: AfreecaTvChat?
    private var openStreamingPlatformChat: OpenStreamingPlatformChat!
    var youTubeFetchVideoIdStartTime: ContinuousClock.Instant?
    var obsWebSocket: ObsWebSocket?
    var chatPostId = 0
    var chat = ChatProvider(maximumNumberOfMessages: maximumNumberOfChatMessages)
    var quickButtonChat = ChatProvider(maximumNumberOfMessages: maximumNumberOfInteractiveChatMessages)
    var externalDisplayChat = ChatProvider(maximumNumberOfMessages: 50)
    private var externalDisplayWindow: UIWindow?
    var chatBotMessages: Deque<ChatBotMessage> = []
    var newQuickButtonChatAlertsPosts: Deque<ChatPost> = []
    var pausedQuickButtonChatAlertsPosts: Deque<ChatPost> = []
    var watchChatPosts: Deque<WatchProtocolChatMessage> = []
    var nextWatchChatPostId = 1
    var previousBitrateStatusColorSrtDroppedPacketsTotal: Int32 = 0
    var previousBitrateStatusNumberOfFailedEncodings = 0
    let streamPreviewView = PreviewView()
    let externalDisplayStreamPreviewView = PreviewView()
    let cameraPreviewView = CameraPreviewUiView()
    var cameraPreviewLayer: AVCaptureVideoPreviewLayer?
    var textEffects: [UUID: TextEffect] = [:]
    var imageEffects: [UUID: ImageEffect] = [:]
    var browserEffects: [UUID: BrowserEffect] = [:]
    var lutEffects: [UUID: LutEffect] = [:]
    var mapEffects: [UUID: MapEffect] = [:]
    var qrCodeEffects: [UUID: QrCodeEffect] = [:]
    var alertsEffects: [UUID: AlertsEffect] = [:]
    var videoSourceEffects: [UUID: VideoSourceEffect] = [:]
    var enabledAlertsEffects: [AlertsEffect] = []
    var drawOnStreamEffect = DrawOnStreamEffect()
    var lutEffect = LutEffect()
    var padelScoreboardEffects: [UUID: PadelScoreboardEffect] = [:]
    var vTuberEffects: [UUID: VTuberEffect] = [:]
    var pngTuberEffects: [UUID: PngTuberEffect] = [:]
    var snapshotEffects: [UUID: SnapshotEffect] = [:]
    var enabledSnapshotEffects: [SnapshotEffect] = []
    var speechToTextAlertMatchOffset = 0
    var isMuteOn = false
    var log: Deque<LogEntry> = []
    var remoteControlAssistantLog: Deque<LogEntry> = []
    var imageStorage = ImageStorage()
    var logsStorage = LogsStorage()
    var mediaStorage = MediaPlayerStorage()
    var alertMediaStorage = AlertMediaStorage()
    var vTuberStorage = VTuberStorage()
    var pngTuberStorage = PngTuberStorage()
    var controlBarPage = 1
    var reconnectTimer = SimpleTimer(queue: .main)
    var logId = 1
    private var serversSpeed: Int64 = 0
    var adsEndDate: Date?
    var urlSession = URLSession.shared
    var heartRates: [String: Int?] = [:]
    var workoutActiveEnergyBurned: Int?
    var workoutDistance: Int?
    var workoutPower: Int?
    var workoutStepCount: Int?
    private var pollVotes: [Int] = [0, 0, 0]
    var pollEnabled = false
    var mediaPlayers: [UUID: MediaPlayer] = [:]
    var previousSrtDroppedPacketsTotal: Int32 = 0
    var streamBecameBrokenTime: ContinuousClock.Instant?
    var cameraPosition: AVCaptureDevice.Position?
    private let motionManager = CMMotionManager()
    var gForceManager: GForceManager?
    var database: Database {
        settings.database
    }

    var speechToText = SpeechToText()
    var keepSpeakerAlivePlayer: AVAudioPlayer?
    var keepSpeakerAliveLatestPlayed: ContinuousClock.Instant = .now
    let twitchAuth = TwitchAuth()
    var twitchAuthOnComplete: ((_ accessToken: String) -> Void)?
    var numberOfTwitchViewers: Int?
    var drawOnStreamSize: CGSize = .zero
    var webBrowser: WKWebView?
    let webBrowserController = WebBrowserController()
    var lowFpsImageFps: UInt64 = 1
    let chatTextToSpeech = ChatTextToSpeech()
    private var lastAttachCompletedTime: ContinuousClock.Instant?
    private var relaxedBitrateStartTime: ContinuousClock.Instant?
    var relaxedBitrate = false
    var remoteControlState = RemoteControlState()
    var remoteControlStreamer: RemoteControlStreamer?
    var remoteControlAssistant: RemoteControlAssistant?
    var remoteControlRelay: RemoteControlRelay?
    var isRemoteControlAssistantRequestingPreview = false
    var isRemoteControlAssistantRequestingStatus = false
    var remoteControlAssistantRequestingStatusFilter: RemoteControlStartStatusFilter?
    var remoteControlAssistantPreviewUsers: Set<RemoteControlAssistantPreviewUser> = .init()
    var remoteControlAssistantStatusRequested: Bool = false
    var remoteControlStreamerLatestReceivedChatMessageId = -1
    var useRemoteControlForChatAndEvents = false
    var currentWiFiSsid: String?
    var currentDjiDeviceSettings: SettingsDjiDevice?
    var djiDeviceWrappers: [UUID: DjiDeviceWrapper] = [:]
    let autoSceneSwitcher = AutoSceneSwitcherProvider()
    var currentCatPrinterSettings: SettingsCatPrinter?
    var catPrinters: [UUID: CatPrinter] = [:]
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
    var currentHeartRateDeviceSettings: SettingsHeartRateDevice?
    var heartRateDevices: [UUID: HeartRateDevice] = [:]
    var currentPhoneCoolerDeviceSettings: SettingsPhoneCoolerDevice?
    var phoneCoolerDevices: [UUID: PhoneCoolerDevice] = [:]
    var cameraDevice: AVCaptureDevice?
    var cameraZoomLevelToXScale: Float = 1.0
    var cameraZoomXMinimum: Float = 1.0
    var cameraZoomXMaximum: Float = 1.0
    var latestDebugLines: [String] = []
    var latestDebugActions: [String] = []
    var streamingHistoryStream: StreamingHistoryStream?
    var backCameras: [Camera] = []
    var frontCameras: [Camera] = []
    var externalCameras: [Camera] = []
    var recordingsStorage = RecordingsStorage()
    var latestLowBitrateTime = ContinuousClock.now
    var bluetoothCentralManger: CBCentralManager?
    var sceneSettingsPanelScene = SettingsScene(name: "")
    var snapshotJobs: Deque<SnapshotJob> = []
    var gameControllers: [GCController?] = []
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
    private let sampleBufferReceiver = SampleBufferReceiver()
    let faxReceiver = FaxReceiver()
    var twitchStreamUpdateTime = ContinuousClock.now
    var externalDisplayPreview = false
    var remoteSceneScenes: [SettingsScene] = []
    var remoteSceneWidgets: [SettingsWidget] = []
    var remoteSceneData = RemoteControlRemoteSceneData(textStats: nil, location: nil)
    var remoteSceneSettingsUpdateRequested = false
    var remoteSceneSettingsUpdating = false
    var builtinCameraIds: [String: UUID] = [:]
    var isAppActive = true
    var initialVolume: Float?
    var latestVolumeChangeSequenceNumber: Int?
    let volumeView = MPVolumeView(frame: .zero)
    var latestSetVolumeTime = ContinuousClock.now
    private var appStoreUpdateListenerTask: Task<Void, Error>?
    var products: [String: Product] = [:]
    var streamTotalBytes: UInt64 = 0
    var streamTotalChatMessages: Int = 0
    var streamLog: Deque<String> = []
    private var ipMonitor = IPMonitor()
    var faceEffect = FaceEffect(fps: 30)
    var movieEffect = MovieEffect()
    var whirlpoolEffect = WhirlpoolEffect(angle: .pi / 2)
    var pinchEffect = PinchEffect(scale: 0.5)
    var fourThreeEffect = FourThreeEffect()
    var grayScaleEffect = GrayScaleEffect()
    var sepiaEffect = SepiaEffect()
    var tripleEffect = TripleEffect()
    var twinEffect = TwinEffect()
    var pixellateEffect = PixellateEffect(strength: 0.0)
    var pollEffect = PollEffect()
    var fixedHorizonEffect = FixedHorizonEffect()
    var replayEffect: ReplayEffect?
    var locationManager = Location()
    var realtimeIrl: RealtimeIrl?
    private var failedVideoEffect: String?
    var supportsAppleLog: Bool = false
    let weatherManager = WeatherManager()
    let geographyManager = GeographyManager()
    var onDocumentPickerUrl: ((URL) -> Void)?
    private var healthStore = HKHealthStore()

    weak var processor: Processor? {
        didSet {
            oldValue?.setDrawable(drawable: nil)
        }
    }

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

    var enabledScenes: [SettingsScene] {
        database.scenes.filter { scene in scene.enabled }
    }

    func isPortrait() -> Bool {
        return stream.portrait || database.portrait
    }

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
        for pageButtonPairs in quickButtons.pairs {
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

    func setAllowVideoRangePixelFormat() {
        allowVideoRangePixelFormat = database.debug.allowVideoRangePixelFormat
    }

    func makeToast(title: String, subTitle: String? = nil, onTapped: (() -> Void)? = nil) {
        toast.toast = AlertToast(type: .regular,
                                 title: title,
                                 subTitle: subTitle,
                                 style: .style(subTitleFont: .body))
        toast.onTapped = onTapped
        showToast()
        logger.debug("toast: Info: \(title): \(subTitle ?? "-")")
    }

    func makeWarningToast(title: String, subTitle: String? = nil, vibrate: Bool = false) {
        toast.toast = AlertToast(type: .regular,
                                 title: formatWarning(title),
                                 subTitle: subTitle,
                                 style: .style(subTitleFont: .body))
        showToast()
        logger.debug("toast: Warning: \(title): \(subTitle ?? "-")")
        if vibrate {
            UIDevice.vibrate()
        }
    }

    func makeErrorToast(title: String, font: Font? = nil, subTitle: String? = nil, vibrate: Bool = false) {
        toast.toast = AlertToast(
            type: .regular,
            title: title,
            subTitle: subTitle,
            style: .style(titleColor: .red, titleFont: font, subTitleFont: .body)
        )
        showToast()
        logger.debug("toast: Error: \(title): \(subTitle ?? "-")")
        if vibrate {
            UIDevice.vibrate()
        }
    }

    func makeErrorToastMain(title: String, font: Font? = nil, subTitle: String? = nil, vibrate: Bool = false) {
        DispatchQueue.main.async {
            self.makeErrorToast(title: title, font: font, subTitle: subTitle, vibrate: vibrate)
        }
    }

    private func showToast() {
        toast.showingToast = false
        DispatchQueue.main.async {
            self.toast.showingToast = true
        }
    }

    private func makeBuyIconsToastIfNeeded() {
        guard !cosmetics.hasBoughtSomething else {
            return
        }
        makeToast(title: String(localized: "💰 Buy Moblin icons to show some love ❤️"),
                  subTitle: String(localized: "Tap this toast to open the shop."))
        {
            self.toggleShowingPanel(type: nil, panel: .none)
            self.toggleShowingPanel(type: nil, panel: .cosmetics)
        }
    }

    func makePortErrorToast(port: String) {
        makeErrorToast(title: String(localized: "Invalid port \(port.trim())"))
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
            quickButtons.pairs[page] = pairs
        }
    }

    func getQuickButtonPairs(page: Int) -> [QuickButtonPair] {
        return quickButtons.pairs[page]
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
        setCurrentStream()
        bluetoothCentralManger = CBCentralManager(delegate: self, queue: .main)
        deleteTrash()
        cameraPreviewLayer = cameraPreviewView.previewLayer
        media.delegate = self
        createUrlSession()
        setupAppIntents()
        faxReceiver.delegate = self
        fixAlertMedias()
        setAllowVideoRangePixelFormat()
        setExternalDisplayContent()
        portraitVideoOffsetFromTop = database.portraitVideoOffsetFromTop
        audioUnitRemoveWindNoise = database.debug.removeWindNoise
        quickButtonChatState.showFirstTimeChatterMessage = database.chat.showFirstTimeChatterMessage
        quickButtonChatState.showNewFollowerMessage = database.chat.showNewFollowerMessage
        autoSceneSwitcher.currentSwitcherId = database.autoSceneSwitchers.switcherId
        supportsAppleLog = hasAppleLog()
        chat.interactiveChat = getGlobalButton(type: .interactiveChat)?.isOn ?? false
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
                zoom.backPresetId = preset.id
                zoom.backX = preset.x
            } else {
                zoom.backX = cameraZoomXMinimum
            }
            zoom.x = zoom.backX
        }
        zoom.frontPresetId = database.zoom.front[0].id
        streamPreviewView.videoGravity = .resizeAspect
        externalDisplayStreamPreviewView.videoGravity = .resizeAspect
        updateDigitalClock(now: Date())
        twitchChat = TwitchChat(delegate: self)
        reloadStream()
        resetSelectedScene()
        setupAudio()
        startPeriodicTimers()
        setupThermalState()
        updateQuickButtonStates()
        removeUnusedImages()
        removeUnusedAlertMedias()
        removeUnusedVTubers()
        removeUnusedPngTubers()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(orientationDidChange),
                                               name: UIDevice.orientationDidChangeNotification,
                                               object: nil)
        cosmetics.iconImage = database.iconImage
        Task {
            appStoreUpdateListenerTask = listenForAppStoreTransactions()
            await getProductsFromAppStore()
            await updateProductFromAppStore()
            DispatchQueue.main.async {
                self.updateIconImageFromDatabase()
            }
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(systemVolumeDidChange),
                                               name: Notification.Name("SystemVolumeDidChange"),
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidChangeActive),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidChangeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
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
        reloadRistServer()
        reloadRtspClient()
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
                                               name: AVCaptureDevice.wasConnectedNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleCaptureDeviceWasDisconnected),
                                               name: AVCaptureDevice.wasDisconnectedNotification,
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
        autoStartCatPrinters()
        autoStartCyclingPowerDevices()
        autoStartHeartRateDevices()
        autoStartPhoneCoolerDevices()
        startWeatherManager()
        startGeographyManager()
        twitchAuth.setOnAccessToken(onAccessToken: handleTwitchAccessToken)
        MoblinShortcuts.updateAppShortcutParameters()
        bonding.statisticsFormatter.setNetworkInterfaceNames(database.networkInterfaceNames)
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
        goPro.launchLiveStreamSelection = database.goPro.selectedLaunchLiveStream
        goPro.wifiCredentialsSelection = database.goPro.selectedWifiCredentials
        goPro.rtmpUrlSelection = database.goPro.selectedRtmpUrl
        replay.speed = database.replay.speed
        gForceManager = GForceManager(motionManager: motionManager)
        startGForceManager()
        loadStealthModeImage()
    }

    @objc func applicationDidChangeActive(notification: NSNotification) {
        isAppActive = notification.name == UIApplication.didBecomeActiveNotification
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
            guard widget.widget.type == .text else {
                continue
            }
            guard widget.widget.text.needsGForce else {
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
            logger.info("Starting NTP client for pool \(stream.ntpPoolAddress)")
            TrueTimeClient.sharedInstance.start(pool: [stream.ntpPoolAddress])
        }
    }

    func stopNtpClient() {
        logger.info("Stopping NTP client")
        TrueTimeClient.sharedInstance.pause()
    }

    private func isWeatherNeeded() -> Bool {
        for widget in widgetsInCurrentScene(onlyEnabled: true) {
            guard widget.widget.type == .text else {
                continue
            }
            guard widget.widget.text.needsWeather else {
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
            guard widget.widget.type == .text else {
                continue
            }
            guard widget.widget.text.needsGeography else {
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

    func setExternalDisplayContent() {
        switch database.externalDisplayContent {
        case .stream:
            externalDisplay.chatEnabled = false
        case .cleanStream:
            externalDisplay.chatEnabled = false
        case .chat:
            externalDisplay.chatEnabled = true
        case .mirror:
            externalDisplay.chatEnabled = false
        }
        setCleanExternalDisplay()
        updateExternalMonitorWindow()
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
        var isOn = streamOverlay.showingCamera
        if camera.bias != 0.0 {
            isOn = true
        }
        if camera.manualWhiteBalanceEnabled {
            isOn = true
        }
        if camera.manualIsoEnabled {
            isOn = true
        }
        if camera.manualFocusEnabled {
            isOn = true
        }
        if isOn != getGlobalButton(type: .image)?.isOn {
            setGlobalButtonState(type: .image, isOn: isOn)
            updateQuickButtonStates()
        }
    }

    private func handleIpStatusUpdate(statuses: [IPMonitor.Status]) {
        statusOther.ipStatuses = statuses
        for status in statuses where status.interfaceType == .wiredEthernet {
            for stream in database.streams
                where !stream.srt.connectionPriorities!.priorities.contains(where: { $0.name == status.name })
            {
                stream.srt.connectionPriorities!.priorities
                    .append(SettingsStreamSrtConnectionPriority(name: status.name))
            }
            if !database.networkInterfaceNames.contains(where: { $0.interfaceName == status.name }) {
                let interface = SettingsNetworkInterfaceName()
                interface.interfaceName = status.name
                interface.name = status.name
                database.networkInterfaceNames.append(interface)
            }
        }
        moblinkIpStatusesUpdated()
    }

    @objc func handleCaptureDeviceWasConnected(_: Notification) {
        updateCameraLists()
    }

    @objc func handleCaptureDeviceWasDisconnected(_: Notification) {
        updateCameraLists()
    }

    @objc func handleDidEnterBackgroundNotification() {
        store()
        replaysStorage.store()
        guard !isMac() else {
            return
        }
        switch backgroundRunLevel() {
        case .full:
            disableScreenPreview()
        case let .service(keepChatRunning):
            disableScreenPreview()
            stopPeriodicTimers(keepChatRunning: keepChatRunning)
        case .off:
            stopAll()
        }
    }

    @objc func handleWillEnterForegroundNotification() {
        guard !isMac() else {
            return
        }
        switch backgroundRunLevel() {
        case .full:
            maybeEnableScreenPreview()
        case .service:
            maybeEnableScreenPreview()
            startPeriodicTimers()
        case .off:
            makeBuyIconsToastIfNeeded()
            clearRemoteSceneSettingsAndData()
            reloadStream()
            sceneUpdated(attachCamera: true, updateRemoteScene: false)
            setupAudioSession()
            media.attachDefaultAudioDevice(builtinDelay: database.debug.builtinAudioAndVideoDelay)
            reloadRtmpServer()
            reloadDjiDevices()
            reloadSrtlaServer()
            reloadRistServer()
            reloadRtspClient()
            chatTextToSpeech.reset(running: true)
            startWeatherManager()
            startGeographyManager()
            startGForceManager()
            if isRecording {
                _ = resumeRecording()
            }
            reloadSpeechToText()
            reloadTeslaVehicle()
            reloadMoblinkRelay()
            reloadMoblinkStreamer()
            updateOrientation()
            autoStartCatPrinters()
            autoStartCyclingPowerDevices()
            autoStartHeartRateDevices()
            autoStartPhoneCoolerDevices()
            if showBackgroudStreamingDisabledToast {
                makeStreamEndedToast(subTitle: String(localized: "Tap this toast to enable background streaming.")) {
                    self.stream.backgroundStreaming = true
                    self.makeToast(title: String(localized: "Background streaming enabled"))
                }
                showBackgroudStreamingDisabledToast = false
            }
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
        if isMac() {
            stopAll()
        }
    }

    private func stopAll() {
        if isRecording {
            suspendRecording()
        }
        showBackgroudStreamingDisabledToast = stopStream()
        stopRtmpServer()
        stopSrtlaServer()
        stopRtspClient()
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
        fixedHorizonEffect.stop()
    }

    func externalMonitorConnected(windowScene: UIWindowScene) {
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: ExternalScreenContentView())
        externalDisplayWindow = window
        updateExternalMonitorWindow()
        externalDisplayPreview = true
        reattachCamera()
    }

    func disableScreenPreview() {
        media.setScreenPreview(enabled: false)
    }

    func maybeEnableScreenPreview() {
        guard !showStealthMode else {
            return
        }
        media.setScreenPreview(enabled: true)
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

    private func backgroundRunLevel() -> BackgroundRunLevel {
        if (isLive || isRecording) && stream.backgroundStreaming {
            return .full
        }
        if isLive || isRecording {
            return .off
        }
        if database.catPrinters.backgroundPrinting {
            return .service(keepChatRunning: true)
        }
        if database.moblink.relay.enabled {
            return .service(keepChatRunning: false)
        }
        return .off
    }

    @objc func handleBatteryStateDidChangeNotification() {
        updateBatteryState()
    }

    deinit {
        appStoreUpdateListenerTask?.cancel()
    }

    func updateOrientation() {
        if stream.portrait {
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

    func startPeriodicTimers() {
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
            self.updateIngestsSpeed()
            self.updateBondingStatistics()
            self.removeOldChatMessages(now: monotonicNow)
            self.updateLocation()
            self.updateObsSourceScreenshot()
            self.updateObsAudioVolume()
            self.updateBrowserWidgetStatus()
            self.logStatus()
            self.updateFailedVideoEffects()
            self.updateDebugOverlay()
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
            if self.database.debug.debugOverlay {
                self.debugOverlay.cpuUsage = getCpuUsage()
            }
            self.updateMoblinkStatus()
            self.updateStatusEventsText()
            self.updateStatusChatText()
            self.updateAutoSceneSwitcher(now: monotonicNow)
            self.sendPeriodicRemoteControlStreamerStatus()
        }
        periodicTimer3s.startPeriodic(interval: 3) {
            self.teslaGetDriveState()
        }
        periodicTimer5s.startPeriodic(interval: 5) {
            self.updateRemoteControlAssistantStatus()
            if self.isWatchLocal() {
                self.sendThermalStateToWatch(thermalState: self.statusOther.thermalState)
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
            self.teslaGetChargeState()
            self.moblink.streamer?.updateStatus()
            self.updateDjiDevicesStatus()
            self.updateTwitchStream(monotonicNow: monotonicNow)
            self.updateAvailableDiskSpace()
            self.tryToFetchYouTubeVideoId()
        }
    }

    func stopPeriodicTimers(keepChatRunning: Bool) {
        periodicTimer20ms.stop()
        if !keepChatRunning {
            periodicTimer200ms.stop()
        }
        periodicTimer1s.stop()
        periodicTimer3s.stop()
        periodicTimer5s.stop()
        periodicTimer10s.stop()
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

    private func updateAdsRemainingTimer(now: Date) {
        guard let adsEndDate else {
            return
        }
        let secondsLeft = adsEndDate.timeIntervalSince(now)
        if secondsLeft < 0 {
            self.adsEndDate = nil
            statusTopRight.adsRemainingTimerStatus = noValue
        } else {
            statusTopRight.adsRemainingTimerStatus = String(Int(secondsLeft))
        }
    }

    private func updateCurrentSsid() {
        NEHotspotNetwork.fetchCurrent(completionHandler: { network in
            self.currentWiFiSsid = network?.ssid
        })
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
            if database.color.diskLutsPng.contains(where: { lut in lut.id == id }) {
                used = true
            }
            if database.color.diskLutsCube.contains(where: { lut in lut.id == id }) {
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
        if newValue != statusTopLeft.numberOfViewers {
            statusTopLeft.numberOfViewers = newValue
            sendViewerCountWatch()
        }
    }

    func handleFindFaceChanged(value: Bool) {
        DispatchQueue.main.async {
            self.findFace = value
            self.findFaceTimer?.invalidate()
            self.findFaceTimer = Timer
                .scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
                    self.findFace = false
                }
        }
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

    private func removeUnusedVTubers() {
        for vTuberId in vTuberStorage.ids() {
            var found = false
            for widget in database.widgets where widget.vTuber.id == vTuberId {
                found = true
                break
            }
            if !found {
                vTuberStorage.remove(id: vTuberId)
            }
        }
    }

    private func removeUnusedPngTubers() {
        for pngTuberId in pngTuberStorage.ids() {
            var found = false
            for widget in database.widgets where widget.pngTuber.id == pngTuberId {
                found = true
                break
            }
            if !found {
                pngTuberStorage.remove(id: pngTuberId)
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

    func togglePoll() {
        pollEnabled = !pollEnabled
        pollVotes = [0, 0, 0]
        pollEffect = PollEffect()
    }

    func handlePollVote(vote: String?) {
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

    func store() {
        settings.store()
    }

    func networkInterfaceNamesUpdated() {
        media.setNetworkInterfaceNames(networkInterfaceNames: database.networkInterfaceNames)
        bonding.statisticsFormatter.setNetworkInterfaceNames(database.networkInterfaceNames)
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
        if stream.portrait {
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

    func reloadBrowserWidgets() {
        for browser in browsers {
            browser.browserEffect.reload()
        }
    }

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
        for pageButtonPairs in quickButtons.pairs {
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
        for pageButtonPairs in quickButtons.pairs {
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

    func updateScreenAutoOff() {
        UIApplication.shared.isIdleTimerDisabled = (showingRemoteControl || isLive)
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

    func isTimecodesEnabled() -> Bool {
        return stream.timecodesEnabled && !stream.ntpPoolAddress.isEmpty
    }

    func setPixellateStrength(strength: Float) {
        pixellateEffect.setSettings(strength: strength)
    }

    func setWhirlpoolAngle(angle: Float) {
        whirlpoolEffect.setSettings(angle: angle)
    }

    func setPinchScale(scale: Float) {
        pinchEffect.setSettings(scale: scale)
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

    func isEventsConfigured() -> Bool {
        return isTwitchEventSubConfigured()
    }

    func isEventsConnected() -> Bool {
        return isTwitchEventsConnected()
    }

    func isEventsRemoteControl() -> Bool {
        return useRemoteControlForChatAndEvents
    }

    func isViewersConfigured() -> Bool {
        return isTwitchViewersConfigured() || isKickViewersConfigured()
    }

    func isYouTubeLiveChatConfigured() -> Bool {
        return database.chat.enabled && stream.youTubeVideoId != ""
    }

    func isYouTubeLiveChatConnected() -> Bool {
        return youTubeLiveChat?.isConnected() ?? false
    }

    func hasYouTubeLiveChatEmotes() -> Bool {
        return youTubeLiveChat?.hasEmotes() ?? false
    }

    func isAfreecaTvChatConfigured() -> Bool {
        return database.chat.enabled && stream.afreecaTvChannelName != "" && stream.afreecaTvStreamId != ""
    }

    func isAfreecaTvChatConnected() -> Bool {
        return afreecaTvChat?.isConnected() ?? false
    }

    func hasAfreecaTvChatEmotes() -> Bool {
        return afreecaTvChat?.hasEmotes() ?? false
    }

    func isOpenStreamingPlatformChatConfigured() -> Bool {
        return database.chat.enabled && stream.openStreamingPlatformUrl != "" && stream
            .openStreamingPlatformChannelId != ""
    }

    func isOpenStreamingPlatformChatConnected() -> Bool {
        return openStreamingPlatformChat?.isConnected() ?? false
    }

    func hasOpenStreamingPlatformChatEmotes() -> Bool {
        return openStreamingPlatformChat?.hasEmotes() ?? false
    }

    func httpProxy() -> HttpProxy? {
        return settings.database.debug.httpProxy.toHttpProxy()
    }

    func reloadYouTubeLiveChat() {
        youTubeLiveChat?.stop()
        youTubeLiveChat = nil
        if isYouTubeLiveChatConfigured(), !isChatRemoteControl() {
            youTubeLiveChat = YouTubeLiveChat(
                model: self,
                videoId: stream.youTubeVideoId,
                settings: stream.chat
            )
            youTubeLiveChat!.start()
        }
        updateChatMoreThanOneChatConfigured()
    }

    func reloadAfreecaTvChat() {
        afreecaTvChat?.stop()
        afreecaTvChat = nil
        setTextToSpeechStreamerMentions()
        if isAfreecaTvChatConfigured(), !isChatRemoteControl() {
            afreecaTvChat = AfreecaTvChat(
                model: self,
                channelName: stream.afreecaTvChannelName,
                streamId: stream.afreecaTvStreamId
            )
            afreecaTvChat!.start()
        }
        updateChatMoreThanOneChatConfigured()
    }

    func reloadOpenStreamingPlatformChat() {
        openStreamingPlatformChat?.stop()
        openStreamingPlatformChat = nil
        if isOpenStreamingPlatformChatConfigured(), !isChatRemoteControl() {
            openStreamingPlatformChat = OpenStreamingPlatformChat(
                model: self,
                url: stream.openStreamingPlatformUrl,
                channelId: stream.openStreamingPlatformChannelId
            )
            openStreamingPlatformChat!.start()
        }
        updateChatMoreThanOneChatConfigured()
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
        if statusTopRight.browserWidgetsStatusChanged {
            statusTopRight.browserWidgetsStatusChanged = false
        }
        var messages: [String] = []
        for browser in browsers {
            let progress = browser.browserEffect.progress
            if browser.browserEffect.isLoaded {
                messages.append("\(browser.browserEffect.host): \(progress)%")
                if progress != 100 || browser.browserEffect.startLoadingTime + .seconds(5) > .now {
                    if !statusTopRight.browserWidgetsStatusChanged {
                        statusTopRight.browserWidgetsStatusChanged = true
                    }
                }
            }
        }
        var message: String
        if messages.isEmpty {
            message = noValue
        } else {
            message = messages.joined(separator: ", ")
        }
        if statusTopRight.browserWidgetsStatus != message {
            statusTopRight.browserWidgetsStatus = message
        }
    }

    private func logStatus() {
        if logger.debugEnabled, isLive {
            logger.debug("Status: Bitrate: \(bitrate.speedAndTotal), Uptime: \(streamUptime.uptime)")
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
            fps = database.remoteControl.streamer.previewFps
        }
        media.setLowFpsImage(fps: fps)
        lowFpsImageFps = max(UInt64(fps), 1)
    }

    func setSceneSwitchTransition() {
        media.setSceneSwitchTransition(sceneSwitchTransition: database.sceneSwitchTransition.toVideoUnit())
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

    private func updateDigitalClock(now: Date) {
        let digitalClock = digitalClockFormatter.string(from: now)
        if statusOther.digitalClock != digitalClock {
            statusOther.digitalClock = digitalClock
        }
    }

    private func updateBatteryLevel() {
        let level = Double(UIDevice.current.batteryLevel)
        if level != battery.level {
            battery.level = level
        }
        streamingHistoryStream?.updateLowestBatteryLevel(level: battery.level)
        if battery.level <= 0.07, !isBatteryCharging(), !isMac() {
            battery.levelLowCounter += 1
            if (battery.levelLowCounter % 3) == 0 {
                makeWarningToast(title: lowBatteryMessage, vibrate: true)
                if database.chat.botEnabled, database.chat.botSendLowBatteryWarning {
                    sendChatMessage(message: "Moblin bot: \(lowBatteryMessage)")
                }
            }
        } else {
            battery.levelLowCounter = -1
        }
    }

    private func updateBatteryState() {
        let state = UIDevice.current.batteryState
        if state != battery.state {
            battery.state = state
            remoteControlStreamer?.stateChanged(state: .init(batteryCharging: isBatteryCharging()))
        }
    }

    func isBatteryCharging() -> Bool {
        return battery.state == .charging || battery.state == .full
    }

    private func updateIngestsSpeed() {
        var anyServerEnabled = false
        var speed: UInt64 = 0
        var total: UInt64 = 0
        var numberOfClients = 0
        updateRtmpIngestsSpeed(&anyServerEnabled, &speed, &total, &numberOfClients)
        updateSrtlaIngestsSpeed(&anyServerEnabled, &speed, &total, &numberOfClients)
        updateRistIngestsSpeed(&anyServerEnabled, &speed, &total, &numberOfClients)
        updateRtspIngestsSpeed(&anyServerEnabled, &speed, &total, &numberOfClients)
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
        if message != ingests.speedAndTotal {
            ingests.speedAndTotal = message
        }
    }

    private func updateRtmpIngestsSpeed(_ anyServerEnabled: inout Bool,
                                        _ speed: inout UInt64,
                                        _ total: inout UInt64,
                                        _ numberOfClients: inout Int)
    {
        guard let rtmpServer = ingests.rtmp else {
            return
        }
        let stats = rtmpServer.updateStats()
        let numberOfRtmpClients = rtmpServer.getNumberOfClients()
        numberOfClients += numberOfRtmpClients
        if numberOfRtmpClients > 0 {
            total += stats.total
            speed += stats.speed
        }
        anyServerEnabled = true
    }

    private func updateSrtlaIngestsSpeed(_ anyServerEnabled: inout Bool,
                                         _ speed: inout UInt64,
                                         _ total: inout UInt64,
                                         _ numberOfClients: inout Int)
    {
        guard let srtlaServer = ingests.srtla else {
            return
        }
        let stats = srtlaServer.updateStats()
        let numberOfSrtlaClients = srtlaServer.getNumberOfClients()
        numberOfClients += numberOfSrtlaClients
        if numberOfSrtlaClients > 0 {
            total += stats.total
            speed += stats.speed
        }
        anyServerEnabled = true
    }

    private func updateRistIngestsSpeed(_ anyServerEnabled: inout Bool,
                                        _ speed: inout UInt64,
                                        _ total: inout UInt64,
                                        _ numberOfClients: inout Int)
    {
        guard let ristServer = ingests.rist else {
            return
        }
        let stats = ristServer.updateStats()
        let numberOfRistClients = ristServer.getNumberOfClients()
        numberOfClients += numberOfRistClients
        if numberOfRistClients > 0 {
            total += stats.total
            speed += stats.speed
        }
        anyServerEnabled = true
    }

    private func updateRtspIngestsSpeed(_ anyServerEnabled: inout Bool,
                                        _ speed: inout UInt64,
                                        _ total: inout UInt64,
                                        _ numberOfClients: inout Int)
    {
        for client in ingests.rtsp {
            let stats = client.updateStats()
            total += stats.total
            speed += stats.speed
            numberOfClients += 1
            anyServerEnabled = true
        }
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
        let state = ProcessInfo.processInfo.thermalState
        if state != statusOther.thermalState {
            statusOther.thermalState = state
        }
        streamingHistoryStream?.updateHighestThermalState(thermalState: ThermalState(from: state))
        if isWatchLocal() {
            sendThermalStateToWatch(thermalState: state)
        }
        logger.info("Thermal state: \(state.string())")
        if statusOther.thermalState == .critical {
            makeFlameRedToast()
            startLowPowerMode()
        } else {
            stopLowPowerMode()
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
        if stream.portrait {
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

    private func getVideoMirroredOnStream() -> Bool {
        if cameraPosition == .front {
            if stream.portrait {
                return true
            } else {
                return database.mirrorFrontCameraOnStream
            }
        }
        return false
    }

    private func getVideoMirroredOnScreen() -> Bool {
        if cameraPosition == .front {
            if stream.portrait {
                return false
            } else {
                return !database.mirrorFrontCameraOnStream
            }
        }
        return false
    }

    func attachBackTripleLowEnergyCamera(force: Bool = true) {
        cameraPosition = .back
        lowEnergyCameraUpdateBackZoom(force: force)
        zoom.x = zoom.backX
        guard let bestDevice = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back),
              let lastZoomFactor = bestDevice.virtualDeviceSwitchOverVideoZoomFactors.last
        else {
            return
        }
        let scale = bestDevice.getZoomFactorScale(hasUltraWideCamera: hasUltraWideBackCamera())
        let x = (Float(truncating: lastZoomFactor) * scale).rounded()
        var device: AVCaptureDevice?
        if zoom.backX < 1.0 {
            device = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
        } else if zoom.backX < x {
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

    func attachBackDualLowEnergyCamera(force: Bool = true) {
        cameraPosition = .back
        lowEnergyCameraUpdateBackZoom(force: force)
        zoom.x = zoom.backX
        guard let bestDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back),
              let lastZoomFactor = bestDevice.virtualDeviceSwitchOverVideoZoomFactors.last
        else {
            return
        }
        let scale = bestDevice.getZoomFactorScale(hasUltraWideCamera: hasUltraWideBackCamera())
        let x = (Float(truncating: lastZoomFactor) * scale).rounded()
        var device: AVCaptureDevice?
        if zoom.backX < x {
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

    func attachBackWideDualLowEnergyCamera(force: Bool = true) {
        cameraPosition = .back
        lowEnergyCameraUpdateBackZoom(force: force)
        zoom.x = zoom.backX
        guard let bestDevice = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back),
              let lastZoomFactor = bestDevice.virtualDeviceSwitchOverVideoZoomFactors.last
        else {
            return
        }
        let scale = bestDevice.getZoomFactorScale(hasUltraWideCamera: hasUltraWideBackCamera())
        let x = (Float(truncating: lastZoomFactor) * scale).rounded()
        var device: AVCaptureDevice?
        if zoom.backX < x {
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

    func attachCamera(scene: SettingsScene, position: AVCaptureDevice.Position) {
        cameraDevice = preferredCamera(position: position)
        setFocusAfterCameraAttach()
        cameraZoomLevelToXScale = cameraDevice?.getZoomFactorScale(hasUltraWideCamera: hasUltraWideBackCamera()) ?? 1.0
        (cameraZoomXMinimum, cameraZoomXMaximum) = cameraDevice?
            .getUIZoomRange(hasUltraWideCamera: hasUltraWideBackCamera()) ?? (1.0, 1.0)
        cameraPosition = position
        switch position {
        case .back:
            updateBackZoomSwitchTo()
            zoom.x = zoom.backX
        case .front:
            updateFrontZoomSwitchTo()
            zoom.x = zoom.frontX
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
                if let x = self.setCameraZoomX(x: self.zoom.x) {
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
        zoom.xPinch = zoom.x
        zoom.hasZoom = true
    }

    private func getIgnoreFramesAfterAttachSeconds() -> Double {
        return Double(database.debug.cameraSwitchRemoveBlackish) + database.debug.builtinAudioAndVideoDelay
    }

    private func getIgnoreFramesAfterAttachSecondsReplaceCamera() -> Double {
        if database.forceSceneSwitchTransition {
            return Double(database.debug.cameraSwitchRemoveBlackish)
        } else {
            return 0.0
        }
    }

    func attachBufferedCamera(cameraId: UUID, scene: SettingsScene) {
        cameraDevice = nil
        cameraPosition = nil
        streamPreviewView.isMirrored = false
        externalDisplayStreamPreviewView.isMirrored = false
        zoom.hasZoom = false
        media.attachBufferedCamera(
            devices: getBuiltinCameraDevices(scene: scene, sceneDevice: nil),
            builtinDelay: database.debug.builtinAudioAndVideoDelay,
            cameraPreviewLayer: cameraPreviewLayer!,
            showCameraPreview: updateShowCameraPreview(),
            externalDisplayPreview: externalDisplayPreview,
            cameraId: cameraId,
            ignoreFramesAfterAttachSeconds: getIgnoreFramesAfterAttachSecondsReplaceCamera(),
            fillFrame: getFillFrame(scene: scene)
        )
        media.usePendingAfterAttachEffects()
    }

    func attachExternalCamera(scene: SettingsScene) {
        attachCamera(scene: scene, position: .unspecified)
    }

    private func getVideoStabilizationMode(scene: SettingsScene) -> AVCaptureVideoStabilizationMode {
        if scene.overrideVideoStabilizationMode {
            return getVideoStabilization(mode: scene.videoStabilizationMode)
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
        streamOverlay.isTorchOn.toggle()
        updateTorch()
    }

    func updateTorch() {
        media.setTorch(on: streamOverlay.isTorchOn)
        remoteControlStreamer?.stateChanged(state: .init(torchOn: streamOverlay.isTorchOn))
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

    func preferredCamera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if let scene = findEnabledScene(id: sceneSelector.selectedSceneId) {
            if position == .back {
                return AVCaptureDevice(uniqueID: scene.backCameraId)
            } else if position == .front {
                return AVCaptureDevice(uniqueID: scene.frontCameraId)
            } else {
                return AVCaptureDevice(uniqueID: scene.externalCameraId)
            }
        } else {
            return nil
        }
    }

    func isShowingStatusCamera() -> Bool {
        return database.show.cameras
    }

    func isShowingStatusMic() -> Bool {
        return database.show.microphone
    }

    func isShowingStatusEvents() -> Bool {
        return database.show.events && isEventsConfigured()
    }

    func isShowingStatusViewers() -> Bool {
        return database.show.viewers && isViewersConfigured() && isLive
    }

    private func statusStreamText() -> String {
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

    func updateStatusStreamText() {
        let status = statusStreamText()
        if status != statusTopLeft.streamText {
            statusTopLeft.streamText = status
        }
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
        if status != statusTopLeft.statusEventsText {
            statusTopLeft.statusEventsText = status
        }
    }

    func statusViewersText() -> String {
        if isViewersConfigured() {
            return statusTopLeft.numberOfViewers
        } else {
            return String(localized: "Not configured")
        }
    }

    func isShowingStatusHypeTrain() -> Bool {
        return hypeTrain.status != noValue
    }

    func isShowingStatusAdsRemainingTimer() -> Bool {
        return statusTopRight.adsRemainingTimerStatus != noValue
    }

    func isShowingStatusServers() -> Bool {
        return database.show.rtmpSpeed && isServersConfigured()
    }

    func isServersConfigured() -> Bool {
        return rtmpServerEnabled() || srtlaServerEnabled() || ristServerEnabled()
    }

    func isShowingStatusMoblink() -> Bool {
        return database.show.moblink && isAnyMoblinkConfigured()
    }

    func isAnyMoblinkConfigured() -> Bool {
        return isMoblinkRelayConfigured() || isMoblinkStreamerConfigured()
    }

    func isShowingStatusDjiDevices() -> Bool {
        return database.show.djiDevices && statusTopRight.djiDevicesStatus != noValue
    }

    func isShowingStatusBitrate() -> Bool {
        return database.show.speed && isLive
    }

    func isShowingStatusStreamUptime() -> Bool {
        return database.show.uptime && isLive
    }

    func isShowingStatusBonding() -> Bool {
        return database.show.bonding && isStatusBondingActive()
    }

    func isStatusBondingActive() -> Bool {
        return stream.isBonding() && isLive
    }

    func isShowingStatusBondingRtts() -> Bool {
        return database.show.bondingRtts && isStatusBondingRttsActive()
    }

    func isStatusBondingRttsActive() -> Bool {
        return stream.isBonding() && isLive
    }

    func isShowingStatusReplay() -> Bool {
        return stream.replay.enabled
    }

    func isShowingStatusBrowserWidgets() -> Bool {
        return database.show.browserWidgets && isStatusBrowserWidgetsActive()
    }

    func isShowingStatusCatPrinter() -> Bool {
        return database.show.catPrinter && isAnyCatPrinterConfigured()
    }

    func isShowingStatusCyclingPowerDevice() -> Bool {
        return database.show.cyclingPowerDevice && isAnyCyclingPowerDeviceConfigured()
    }

    func isShowingStatusHeartRateDevice() -> Bool {
        return database.show.heartRateDevice && isAnyHeartRateDeviceConfigured()
    }

    func isShowingStatusFixedHorizon() -> Bool {
        if let scene = getSelectedScene() {
            return isFixedHorizonEnabled(scene: scene)
        } else {
            return false
        }
    }

    func isStatusBrowserWidgetsActive() -> Bool {
        return !statusTopRight.browserWidgetsStatus.isEmpty && statusTopRight.browserWidgetsStatusChanged
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
            lines: drawOnStream.lines,
            mirror: streamOverlay.isFrontCameraSelected && !database.mirrorFrontCameraOnStream
        )
        media.registerEffect(drawOnStreamEffect)
        drawOnStreamUpdateButtonState()
    }

    func drawOnStreamWipe() {
        drawOnStream.lines = []
        drawOnStreamEffect.updateOverlay(
            videoSize: media.getVideoSize(),
            size: drawOnStreamSize,
            lines: drawOnStream.lines,
            mirror: streamOverlay.isFrontCameraSelected && !database.mirrorFrontCameraOnStream
        )
        media.unregisterEffect(drawOnStreamEffect)
        drawOnStreamUpdateButtonState()
    }

    func drawOnStreamUndo() {
        guard !drawOnStream.lines.isEmpty else {
            return
        }
        drawOnStream.lines.removeLast()
        drawOnStreamEffect.updateOverlay(
            videoSize: media.getVideoSize(),
            size: drawOnStreamSize,
            lines: drawOnStream.lines,
            mirror: streamOverlay.isFrontCameraSelected && !database.mirrorFrontCameraOnStream
        )
        if drawOnStream.lines.isEmpty {
            media.unregisterEffect(drawOnStreamEffect)
        }
        drawOnStreamUpdateButtonState()
    }

    func drawOnStreamUpdateButtonState() {
        setGlobalButtonState(type: .draw, isOn: showDrawOnStream || !drawOnStream.lines.isEmpty)
        updateQuickButtonStates()
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
