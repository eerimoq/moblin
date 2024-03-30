import AlertToast
import Collections
import Combine
import CoreMotion
import GameController
import HaishinKit
import Logboard
import MapKit
import NaturalLanguage
import Network
import PhotosUI
import SDWebImageSwiftUI
import SDWebImageWebPCoder
import StoreKit
import SwiftUI
import TwitchChat
import VideoToolbox
import WatchConnectivity
import WebKit

class Browser: Identifiable {
    var id: UUID = .init()
    var browserEffect: BrowserEffect

    init(browserEffect: BrowserEffect) {
        self.browserEffect = browserEffect
    }
}

private let textToSpeechQueue = DispatchQueue(label: "com.eerimoq.textToSpeech", qos: .utility)
private let maximumNumberOfChatMessages = 50
private let secondsSuffix = String(localized: "/sec")
private let fallbackStream = SettingsStream(name: "Fallback")
let fffffMessage = String(localized: "😢 FFFFF 😢")
let lowBitrateMessage = String(localized: "Low bitrate")
let lowBatteryMessage = String(localized: "Low battery")

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
]

private let iconsProductIds = [
    "AppIconKing",
    "AppIconQueen",
    "AppIconHeart",
    "AppIconLooking",
    "AppIconGoblin",
    "AppIconGoblina",
    "AppIconTetris",
    "AppIconTub",
    "AppIconMillionaire",
    "AppIconBillionaire",
    "AppIconTrillionaire",
    "AppIconIreland",
]

private let globalIconsNotYetInStore = [
    Icon(name: "Basque", id: "AppIconBasque", price: ""),
    Icon(name: "China", id: "AppIconChina", price: ""),
    Icon(name: "France", id: "AppIconFrance", price: ""),
    Icon(name: "Poland", id: "AppIconPoland", price: ""),
    Icon(name: "Spain", id: "AppIconSpain", price: ""),
    Icon(name: "Sweden", id: "AppIconSweden", price: ""),
    Icon(name: "South Korea", id: "AppIconSouthKorea", price: ""),
    Icon(name: "United Kingdom", id: "AppIconUnitedKingdom", price: ""),
    Icon(name: "United States", id: "AppIconUnitedStates", price: ""),
    Icon(name: "Eyebrows", id: "AppIconEyebrows", price: ""),
]

struct ChatMessageEmote: Identifiable {
    var id = UUID()
    var url: URL
    var range: ClosedRange<Int>
}

struct ChatPostSegment: Identifiable {
    var id = UUID()
    var text: String?
    var url: URL?
}

func makeChatPostTextSegments(text: String) -> [ChatPostSegment] {
    var segments: [ChatPostSegment] = []
    for word in text.split(separator: " ") {
        segments.append(ChatPostSegment(
            text: "\(word) "
        ))
    }
    return segments
}

struct ChatPost: Identifiable, Equatable {
    static func == (lhs: ChatPost, rhs: ChatPost) -> Bool {
        return lhs.id == rhs.id
    }

    var id: Int
    var user: String?
    var userColor: String?
    var segments: [ChatPostSegment]
    var timestamp: String
    var timestampDate: Date
    var isAction: Bool
    var isAnnouncement: Bool
    var isFirstMessage: Bool
    var isSubscriber: Bool
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
    case direct
}

enum WizardCustomProtocol {
    case none
    case srt
    case rtmp
}

final class Model: NSObject, ObservableObject {
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
    @Published var manualFocusPoint: CGPoint?
    @Published var manualFocus: Float = 1.0
    var editingManualFocus = false
    private var manualFocusMotionAttitude: CMAttitude?
    private var focusObservation: NSKeyValueObservation?
    @Published var showingSettings = false
    @Published var showingCosmetics = false
    @Published var settingsLayout: SettingsLayout = .right
    @Published var showChatMessages = true
    @Published var chatPaused = false
    @Published var interactiveChat = false
    @Published var blackScreen = false
    private var streaming = false
    @Published var mic = noMic
    private var micChange = noMic
    private var streamStartDate: Date?
    @Published var isLive = false
    @Published var isRecording = false
    private var currentRecording: Recording?
    @Published var recordingLength = noValue
    @Published var browserWidgetsStatus = noValue
    private var browserWidgetsStatusChanged = false
    private var subscriptions = Set<AnyCancellable>()
    @Published var uptime = noValue
    @Published var srtlaConnectionStatistics = noValue
    @Published var audioLevel: Float = defaultAudioLevel
    @Published var numberOfAudioChannels: Int = 0
    var settings = Settings()
    @Published var digitalClock = noValue
    private var selectedSceneId = UUID()
    private var twitchChat: TwitchChatMoblin!
    private var twitchPubSub: TwitchPubSub?
    private var kickPusher: KickPusher?
    private var kickViewers: KickViewers?
    private var youTubeLiveChat: YouTubeLiveChat?
    private var afreecaTvChat: AfreecaTvChat?
    private var openStreamingPlatformChat: OpenStreamingPlatformChat!
    private var obsWebSocket: ObsWebSocket?
    private var chatPostId = 0
    @Published var chatPosts: Deque<ChatPost> = []
    private var pausedChatPosts: Deque<ChatPost> = []
    @Published var pausedChatPostsCount: Int = 0
    private var newChatPosts: Deque<ChatPost> = []
    private var numberOfChatPostsPerTick = 0
    private var chatPostsRatePerSecond = 0.0
    private var chatPostsRatePerMinute = 0.0
    private var numberOfChatPostsPerMinute = 0
    @Published var chatPostsRate = String(localized: "0.0/min")
    @Published var chatPostsTotal: Int = 0
    private var watchChatPosts: Deque<WatchProtocolChatMessage> = []
    private var nextWatchChatPostId = 1
    private var chatSpeedTicks = 0
    @Published var numberOfViewers = noValue
    @Published var batteryLevel = Double(UIDevice.current.batteryLevel)
    @Published var batteryState: UIDevice.BatteryState = .full
    @Published var speedAndTotal = noValue
    @Published var thermalState = ProcessInfo.processInfo.thermalState
    var videoView = PreviewView(frame: .zero)
    private var textEffects: [UUID: TextEffect] = [:]
    private var imageEffects: [UUID: ImageEffect] = [:]
    private var videoEffects: [UUID: VideoEffect] = [:]
    private var browserEffects: [UUID: BrowserEffect] = [:]
    private var drawOnStreamEffect = DrawOnStreamEffect()
    private var lutEffect = LutEffect()
    @Published var browsers: [Browser] = []
    @Published var sceneIndex = 0
    private var isTorchOn = false
    private var isMuteOn = false
    var log: Deque<LogEntry> = []
    var remoteControlAssistantLog: Deque<LogEntry> = []
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
    @Published var showingRecordings = false
    @Published var showingCamera = false
    @Published var showingStreamSwitcher = false
    @Published var showingGrid = false
    @Published var showingObs = false
    @Published var showingRemoteControl = false
    @Published var obsScenes: [String] = []
    @Published var obsAudioVolume: String = noValue
    @Published var obsAudioDelay: Int = 0
    private var obsAudioVolumeLatest: String = ""
    @Published var obsCurrentScenePicker: String = ""
    @Published var obsCurrentScene: String = ""
    @Published var currentStreamId = UUID()
    @Published var obsStreaming = false
    @Published var obsStreamingState: ObsOutputState = .stopped
    @Published var obsFixOngoing = false
    @Published var obsScreenshot: CGImage?
    private var obsSourceFetchScreenshot = false
    private var obsSourceScreenshotIsFetching = false
    var obsRecording = false
    @Published var iconImage: String = plainIcon.id
    @Published var backZoomPresetId = UUID()
    @Published var frontZoomPresetId = UUID()
    @Published var zoomX: Float = 1.0
    @Published var hasZoom: Bool = true
    private var zoomXPinch: Float = 1.0
    private var backZoomX: Float = 0.5
    private var frontZoomX: Float = 1.0
    var cameraPosition: AVCaptureDevice.Position?
    private let motionManager = CMMotionManager()
    var database: Database {
        settings.database
    }

    @Published var showDrawOnStream: Bool = false
    @Published var showLocalOverlays: Bool = true
    @Published var drawOnStreamLines: [DrawOnStreamLine] = []
    @Published var drawOnStreamSelectedColor: Color = .pink
    @Published var drawOnStreamSelectedWidth: CGFloat = 4
    var drawOnStreamSize: CGSize = .zero

    @Published var isPresentingWizard: Bool = false
    @Published var isPresentingSetupWizard: Bool = false
    var wizardPlatform: WizardPlatform = .custom
    var wizardNetworkSetup: WizardNetworkSetup = .none
    var wizardCustomProtocol: WizardCustomProtocol = .none
    @Published var wizardName = ""
    @Published var wizardTwitchChannelName = ""
    @Published var wizardTwitchChannelId = ""
    @Published var wizardKickChannelName = ""
    @Published var wizardYouTubeApiKey = ""
    @Published var wizardYouTubeVideoId = ""
    @Published var wizardAfreecaTvChannelName = ""
    @Published var wizardAfreecsTvCStreamId = ""
    @Published var wizardObsAddress = ""
    @Published var wizardObsPort = ""
    @Published var wizardObsRemoteControlEnabled = false
    @Published var wizardObsRemoteControlUrl = ""
    @Published var wizardObsRemoteControlPassword = ""
    @Published var wizardObsRemoteControlSourceName = ""
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

    private var synthesizer = AVSpeechSynthesizer()
    private var recognizer = NLLanguageRecognizer()
    private var latestUserThatSaidSomething = ""
    private var textToSpeechRate: Float = 0.4
    private var textToSpeechVolume: Float = 0.6
    private var textToSpeechVoices: [String: String] = [:]

    @Published var remoteControlGeneral: RemoteControlStatusGeneral?
    @Published var remoteControlTopLeft: RemoteControlStatusTopLeft?
    @Published var remoteControlTopRight: RemoteControlStatusTopRight?
    @Published var remoteControlSettings: RemoteControlSettings?
    var remoteControlState = RemoteControlState()
    @Published var remoteControlScene = UUID()
    @Published var remoteControlMic = ""
    @Published var remoteControlBitrate = UUID()
    @Published var remoteControlZoom = ""

    private var remoteControlStreamer: RemoteControlStreamer?
    private var remoteControlAssistant: RemoteControlAssistant?

    var cameraDevice: AVCaptureDevice?
    var cameraZoomLevelToXScale: Float = 1.0
    var cameraZoomXMinimum: Float = 1.0
    var cameraZoomXMaximum: Float = 1.0
    var secondCameraDevice: AVCaptureDevice?
    @Published var debugLines: [String] = []
    @Published var streamingHistory = StreamingHistory()
    private var streamingHistoryStream: StreamingHistoryStream?

    var backCameras: [Camera] = []
    var frontCameras: [Camera] = []
    var externalCameras: [Camera] = []

    var recordingsStorage = RecordingsStorage()
    private var latestLowBitrateDate = Date()

    private var rtmpServer: RtmpServer?
    @Published var rtmpSpeedAndTotal = noValue

    private var gameControllers: [GCController?] = []
    @Published var gameControllersTotal = noValue

    @Published var location = noValue
    @Published var showLoadSettingsFailed = false

    @Published var remoteControlStatus = noValue

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

    @Published var myIcons: [Icon] = []
    @Published var iconsInStore: [Icon] = []
    @Published var iconsNotYetInStore = globalIconsNotYetInStore
    private var appStoreUpdateListenerTask: Task<Void, Error>?
    private var products: [String: Product] = [:]
    private var streamTotalBytes: UInt64 = 0
    private var streamTotalChatMessages: Int = 0
    var ipMonitor = IPMonitor(ipType: .ipv4)
    @Published var ipStatuses: [IPMonitor.Status] = []
    private var movieEffect = MovieEffect()
    private var grayScaleEffect = GrayScaleEffect()
    private var sepiaEffect = SepiaEffect()
    private var randomEffect = RandomEffect()
    private var tripleEffect = TripleEffect()
    private var pixellateEffect = PixellateEffect()
    private var locationManager = Location()
    private var realtimeIrl: RealtimeIrl?
    private var failedVideoEffect: String?

    func updateAdaptiveBitrateSrtIfEnabled(stream: SettingsStream) {
        switch stream.srt.adaptiveBitrate!.algorithm {
        case .fastIrl:
            var settings = adaptiveBitrateFastSettings
            settings.packetsInFlight = Int64(stream.srt.adaptiveBitrate!.fastIrlSettings!.packetsInFlight)
            media.setAdaptiveBitrateAlgorithm(settings: settings)
        case .slowIrl:
            media.setAdaptiveBitrateAlgorithm(settings: adaptiveBitrateSlowSettings)
        case .customIrl:
            let customSettings = stream.srt.adaptiveBitrate!.customSettings
            media.setAdaptiveBitrateAlgorithm(settings: AdaptiveBitrateSettings(
                packetsInFlight: Int64(customSettings.packetsInFlight),
                rttDiffHighFactor: Double(customSettings.rttDiffHighDecreaseFactor),
                rttDiffHighAllowedSpike: Double(customSettings.rttDiffHighAllowedSpike),
                rttDiffHighMinDecrease: Int64(customSettings.rttDiffHighMinimumDecrease * 1000),
                pifDiffIncreaseFactor: Int64(customSettings.pifDiffIncreaseFactor * 1000)
            ))
        }
    }

    func updateAdaptiveBitrateRtmpIfEnabled(stream _: SettingsStream) {
        var settings = adaptiveBitrateFastSettings
        settings.rttDiffHighAllowedSpike = 500
        media.setAdaptiveBitrateAlgorithm(settings: settings)
    }

    @MainActor
    private func getProductsFromAppStore() async {
        do {
            let products = try await Product.products(for: iconsProductIds)
            for product in products {
                self.products[product.id] = product
            }
            logger.info("cosmetics: Got \(products.count) product(s) from App Store")
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
        logger.info("cosmetics: Update my products from App Store")
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

    func findButton(id: UUID) -> SettingsButton? {
        return database.buttons.first(where: { button in button.id == id })
    }

    func makeToast(title: String, subTitle: String? = nil) {
        toast = AlertToast(type: .regular, title: title, subTitle: subTitle)
        showingToast = true
    }

    func makeWarningToast(title: String, subTitle: String? = nil, vibrate: Bool = false) {
        toast = AlertToast(type: .regular, title: formatWarning(title), subTitle: subTitle)
        showingToast = true
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
        if vibrate {
            UIDevice.vibrate()
        }
    }

    func scrollQuickButtonsToBottom() {
        scrollQuickButtons += 1
    }

    func updateButtonStates() {
        guard let scene = findEnabledScene(id: selectedSceneId) else {
            buttonPairs = []
            return
        }
        var states = database.globalButtons!.filter { button in
            button.enabled!
        }.map { button in
            ButtonState(isOn: button.isOn, button: button)
        }
        states += scene
            .buttons
            .filter { button in button.enabled }
            .map { button in
                let button = findButton(id: button.buttonId)!
                return ButtonState(isOn: button.isOn, button: button)
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

    func debugLog(message: String) {
        DispatchQueue.main.async {
            if self.log.count > self.database.debug!.maximumLogLines! {
                self.log.removeFirst()
            }
            self.log.append(LogEntry(id: self.logId, message: message))
            self.logId += 1
            self.remoteControlStreamer?.log(entry: message)
        }
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

    func listObsScenes() {
        obsWebSocket?.getSceneList(onSuccess: { list in
            DispatchQueue.main.async {
                self.obsCurrentScenePicker = list.current
                self.obsCurrentScene = list.current
                self.obsScenes = list.scenes
            }
        }, onError: { _ in
        })
    }

    func setObsScene(name: String) {
        obsWebSocket?.setCurrentProgramScene(name: name, onSuccess: {
            DispatchQueue.main.async {
                self.obsCurrentScene = name
            }
        }, onError: { message in
            DispatchQueue.main.async {
                self.makeErrorToast(title: String(localized: "Failed to set OBS scene to \(name)"),
                                    subTitle: message)
            }
        })
    }

    private func updateObsStatus() {
        guard isObsConnected() else {
            obsAudioVolumeLatest = noValue
            return
        }
        obsWebSocket?.getStreamStatus(onSuccess: { state in
            self.handleObsStreamStatusChanged(active: state.active, state: state.state)
        }, onError: { _ in
            self.handleObsStreamStatusChanged(active: false)
        })
        obsWebSocket?.getRecordStatus(onSuccess: { status in
            self.handleObsRecordStatusChanged(active: status.active)
        }, onError: { _ in
            self.handleObsRecordStatusChanged(active: false)
        })
        listObsScenes()
    }

    func setup() {
        ioVideoUnitIgnoreFramesAfterAttachSeconds = Double(database.debug!.cameraSwitchRemoveBlackish!)
        let WebPCoder = SDImageWebPCoder.shared
        SDImageCodersManager.shared.addCoder(WebPCoder)
        UIDevice.current.isBatteryMonitoringEnabled = true
        logger.handler = debugLog(message:)
        logger.debugEnabled = database.debug!.logLevel == .debug
        let appender = LogAppender()
        LBLogger.with("com.haishinkit.HaishinKit").appender = appender
        LBLogger.with("com.haishinkit.HaishinKit").level = .debug
        updateCameraLists()
        updateBatteryLevel()
        media.onSrtConnected = handleSrtConnected
        media.onSrtDisconnected = handleSrtDisconnected
        media.onRtmpConnected = handleRtmpConnected
        media.onRtmpDisconnected = handleRtmpDisconnected
        media.onAudioMuteChange = updateAudioLevel
        media.onVideoDeviceInUseByAnotherClient = handleVideoDeviceInUseByAnotherClient
        media.onLowFpsImage = handleLowFpsImage
        setupAudioSession()
        setMic()
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
        videoView.videoGravity = .resizeAspect
        updateDigitalClock(now: Date())
        twitchChat = TwitchChatMoblin(model: self)
        reloadStream()
        resetSelectedScene()
        setupPeriodicTimers()
        setupThermalState()
        updateButtonStates()
        scrollQuickButtonsToBottom()
        removeUnusedImages()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
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
                                               selector: #selector(
                                                   handleAudioRouteChange
                                               ),
                                               name: AVAudioSession
                                                   .routeChangeNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(
                                                   handleDidEnterBackgroundNotification
                                               ),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(
                                                   handleWillEnterForegroundNotification
                                               ),
                                               name: UIApplication
                                                   .willEnterForegroundNotification,
                                               object: nil)
        updateOrientation()
        reloadRtmpServer()
        ipMonitor.pathUpdateHandler = handleIpStatusUpdate
        ipMonitor.start()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(
                                                   handleBatteryStateDidChangeNotification
                                               ),
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
        setTextToSpeechRate(rate: database.chat.textToSpeechRate!)
        setTextToSpeechVolume(volume: database.chat.textToSpeechSayVolume!)
        setTextToSpeechVoices(voices: database.chat.textToSpeechLanguageVoices!)
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
                store()
            }
            if !database.networkInterfaceNames!.contains(where: { interface in
                interface.interfaceName == status.name
            }) {
                let interface = SettingsNetworkInterfaceName()
                interface.interfaceName = status.name
                interface.name = status.name
                database.networkInterfaceNames!.append(interface)
                store()
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
            if !pressed {
                showChatMessages.toggle()
                toggleGlobalButton(type: .chat)
                sceneUpdated(store: false)
                updateButtonStates()
            }
        case .interactiveChat:
            break
        case .scene:
            if !pressed {
                selectScene(id: button.sceneId)
            }
        }
    }

    private func updateCameraLists() {
        externalCameras = listExternalCameras()
        backCameras = listCameras(position: .back)
        frontCameras = listCameras(position: .front)
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
            makeToast(title: "Game controller \(number) connected")
        }
        updateGameControllers()
    }

    @objc func handleGameControllerDidDisconnect(notification: Notification) {
        guard let gameController = notification.object as? GCController else {
            return
        }
        if let number = gameControllerNumber(gameController: gameController) {
            makeToast(title: "Game controller \(number) disconnected")
        }
        if let index = gameControllers.firstIndex(of: gameController) {
            gameControllers[index] = nil
        }
        updateGameControllers()
    }

    @objc func handleDidEnterBackgroundNotification() {
        stopRtmpServer()
    }

    @objc func handleWillEnterForegroundNotification() {
        reloadConnections()
        reloadRtmpServer()
        newTextToSpeech()
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
            rtmpServer = RtmpServer(settings: database.rtmpServer!.clone(),
                                    onPublishStart: handleRtmpServerPublishStart,
                                    onPublishStop: handleRtmpServerPublishStop,
                                    onFrame: handleRtmpServerFrame)
            rtmpServer!.start()
        }
    }

    func handleRtmpServerPublishStart(streamKey: String) {
        DispatchQueue.main.async {
            let camera = self.getRtmpStream(streamKey: streamKey)?.camera() ?? rtmpCamera(name: "Unknown")
            self.makeToast(title: "\(camera) connected")
            guard let stream = self.getRtmpStream(streamKey: streamKey) else {
                return
            }
            self.media.addRtmpCamera(cameraId: stream.id, latency: Double(stream.latency! / 1000))
        }
    }

    func handleRtmpServerPublishStop(streamKey: String) {
        DispatchQueue.main.async {
            let camera = self.getRtmpStream(streamKey: streamKey)?.camera() ?? rtmpCamera(name: "Unknown")
            self.makeToast(title: "\(camera) disconnected")
            guard let cameraId = self.getRtmpStream(streamKey: streamKey)?.id else {
                return
            }
            self.media.removeRtmpCamera(cameraId: cameraId)
        }
    }

    func handleRtmpServerFrame(streamKey: String, sampleBuffer: CMSampleBuffer) {
        guard let cameraId = getRtmpStream(streamKey: streamKey)?.id else {
            return
        }
        media.addRtmpSampleBuffer(cameraId: cameraId, sampleBuffer: sampleBuffer)
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

    private func updateOrientation() {
        switch UIDevice.current.orientation {
        case .landscapeLeft:
            videoView.videoOrientation = .landscapeRight
        case .landscapeRight:
            videoView.videoOrientation = .landscapeLeft
        default:
            break
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
            store()
        }
        iconImage = database.iconImage
    }

    func handleSettingsUrlsDefault(settings: MoblinSettingsUrl) {
        var streamCount = 0
        for stream in settings.streams ?? [] {
            let newStream = SettingsStream(name: stream.name)
            newStream.url = stream.url
            if let video = stream.video {
                if let codec = video.codec {
                    newStream.codec = codec
                }
            }
            if let obs = stream.obs {
                newStream.obsWebSocketUrl = obs.webSocketUrl
                newStream.obsWebSocketPassword = obs.webSocketPassword
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
            let settings: MoblinSettingsUrl
            do {
                settings = try MoblinSettingsUrl.fromString(query: query)
            } catch {
                logger.error("Failed to import URL with error: \(error)")
                makeErrorToast(
                    title: String(localized: "URL import failed"),
                    subTitle: error.localizedDescription
                )
                continue
            }
            if isPresentingWizard || isPresentingSetupWizard {
                handleSettingsUrlsInWizard(settings: settings)
            } else {
                handleSettingsUrlsDefault(settings: settings)
            }
        }
    }

    private func setupPeriodicTimers() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            let now = Date()
            self.updateUptime(now: now)
            self.updateRecordingLength(now: now)
            self.updateDigitalClock(now: now)
            self.updateChatSpeed()
            self.media.updateSrtSpeed()
            self.updateSpeed(now: now)
            self.updateRtmpSpeed()
            if !self.database.show.audioBar {
                self.updateAudioLevel()
            }
            self.updateSrtlaConnectionStatistics()
            self.removeOldChatMessages(now: now)
            self.updateLocation()
            self.updateObsSourceScreenshot()
            self.updateObsAudioVolume()
            self.updateBrowserWidgetStatus()
            self.logStatus()
            self.updateFailedVideoEffects()
        })
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true, block: { _ in
            self.updateBatteryLevel()
            self.media.logStatistics()
            self.updateObsStatus()
            self.updateRemoteControlAssistantStatus()
            self.updateRemoteControlStatus()
            if self.stream.enabled {
                self.media.updateVideoStreamBitrate(bitrate: self.stream.bitrate)
            }
            self.media.logTiming()
            self.updateViewers()
        })
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { _ in
            self.updateAdaptiveBitrate()
            if self.database.show.audioBar {
                self.updateAudioLevel()
            }
            self.updateChat()
            self.trySendNextChatPostToWatch()
        })
    }

    func colorSpaceUpdated() {
        setColorSpace()
    }

    func lutEnabledUpdated() {
        if database.color!.lutEnabled {
            media.registerEffect(lutEffect)
        } else {
            media.unregisterEffect(lutEffect)
        }
    }

    func lutUpdated() {
        guard let lut = getLogLutById(id: database.color!.lut) else {
            media.unregisterEffect(lutEffect)
            return
        }
        var image: UIImage?
        switch lut.type {
        case .bundled:
            guard let path = Bundle.main.path(forResource: "LUTs.bundle/\(lut.name).png", ofType: nil) else {
                return
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
            return
        }
        do {
            try lutEffect.setLut(name: lut.name, image: image)
        } catch {
            let message = "\(error)"
            makeErrorToast(title: message)
            logger.info(message)
        }
    }

    func addLut(data: Data) {
        let lut = SettingsColorAppleLogLut(type: .disk, name: "My LUT")
        imageStorage.write(id: lut.id, data: data)
        database.color!.diskLuts!.append(lut)
        store()
    }

    func getLogLutById(id: UUID) -> SettingsColorAppleLogLut? {
        let luts = database.color!.bundledLuts + database.color!.diskLuts!
        return luts.first { $0.id == id }
    }

    private func updateAdaptiveBitrate() {
        if let lines = media.updateAdaptiveBitrate(overlay: database.debug!.srtOverlay) {
            debugLines = lines
            debugLines.append("Audio/video capture delta: \(Int(1000 * media.getCaptureDelta())) ms")
            if logger.debugEnabled && isLive {
                logger.debug(lines.joined(separator: ", "))
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
        if newValue != numberOfViewers {
            numberOfViewers = newValue
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
            sendAudioLevelToWatch()
        }
    }

    private func updateSrtlaConnectionStatistics() {
        if isStreamConnceted(), let statistics = media.srtlaConnectionStatistics() {
            srtlaConnectionStatistics = statistics
        } else if srtlaConnectionStatistics != noValue {
            srtlaConnectionStatistics = noValue
        }
    }

    func updateSrtlaPriorities() {
        media.setConnectionPriorities(connectionPriorities: stream.srt.connectionPriorities!)
    }

    func endOfChatReachedWhenPaused() {
        var numberOfPostsAppended = 0
        while numberOfPostsAppended < 5, let post = pausedChatPosts.popFirst() {
            if post.user == nil {
                if let lastPost = chatPosts.first, lastPost.user == nil {
                    continue
                }
                if pausedChatPosts.isEmpty {
                    continue
                }
            }
            chatPosts.prepend(post)
            sendChatMessageToWatch(post: post)
            numberOfChatPostsPerTick += 1
            streamTotalChatMessages += 1
            numberOfPostsAppended += 1
        }
        if numberOfPostsAppended == 0 {
            chatPaused = false
        }
    }

    func pauseChat() {
        chatPaused = true
        pausedChatPostsCount = 0
        appendChatMessage(
            user: nil,
            userColor: nil,
            segments: [],
            timestamp: "",
            timestampDate: Date(),
            isAction: false,
            isAnnouncement: false,
            isFirstMessage: false,
            isSubscriber: false
        )
    }

    private func removeOldChatMessages(now: Date) {
        if chatPaused {
            return
        }
        guard database.chat.maximumAgeEnabled! else {
            return
        }
        while let post = chatPosts.first {
            if now > post.timestampDate + Double(database.chat.maximumAge!) {
                _ = chatPosts.popFirst()
            } else {
                break
            }
        }
    }

    private func updateChat() {
        if chatPaused {
            // The red line is one post.
            pausedChatPostsCount = max(pausedChatPosts.count - 1, 0)
            return
        }
        while let post = newChatPosts.popFirst() {
            if chatPosts.count > maximumNumberOfChatMessages - 1 {
                chatPosts.removeLast()
            }
            chatPosts.prepend(post)
            sendChatMessageToWatch(post: post)
            if isTextToSpeechEnabledForMessage(post: post), let user = post.user {
                let message = post.segments.filter { $0.text != nil }.map { $0.text! }.joined(separator: " ")
                if !message.isEmpty {
                    say(user: user, message: message)
                }
            }
            numberOfChatPostsPerTick += 1
            streamTotalChatMessages += 1
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
        return true
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

    private func addVideoEffect(widget: SettingsWidget) {
        switch widget.videoEffect.type {
        case .noiseReduction:
            videoEffects[widget.id] = NoiseReductionEffect()
        default:
            break
        }
    }

    private func unregisterGlobalVideoEffects() {
        media.unregisterEffect(movieEffect)
        media.unregisterEffect(grayScaleEffect)
        media.unregisterEffect(sepiaEffect)
        media.unregisterEffect(randomEffect)
        media.unregisterEffect(tripleEffect)
        media.unregisterEffect(pixellateEffect)
        movieEffect = MovieEffect()
        grayScaleEffect = GrayScaleEffect()
        sepiaEffect = SepiaEffect()
        randomEffect = RandomEffect()
        tripleEffect = TripleEffect()
        pixellateEffect = PixellateEffect()
    }

    private func isGlobalButtonOn(type: SettingsButtonType) -> Bool {
        return database.globalButtons?.first(where: { button in
            button.type == type
        })?.isOn ?? false
    }

    private func registerGlobalVideoEffects() {
        if isGlobalButtonOn(type: .movie) {
            media.registerEffect(movieEffect)
        }
        if isGlobalButtonOn(type: .grayScale) {
            media.registerEffect(grayScaleEffect)
        }
        if isGlobalButtonOn(type: .sepia) {
            media.registerEffect(sepiaEffect)
        }
        if isGlobalButtonOn(type: .random) {
            media.registerEffect(randomEffect)
        }
        if isGlobalButtonOn(type: .triple) {
            media.registerEffect(tripleEffect)
        }
        if isGlobalButtonOn(type: .pixellate) {
            media.registerEffect(pixellateEffect)
        }
    }

    func resetSelectedScene(changeScene: Bool = true) {
        if !enabledScenes.isEmpty && changeScene {
            setSceneId(id: enabledScenes[0].id)
            sceneIndex = 0
        }
        unregisterGlobalVideoEffects()
        for videoEffect in videoEffects.values {
            media.unregisterEffect(videoEffect)
        }
        videoEffects.removeAll()
        for widget in database.widgets where widget.type == .videoEffect {
            addVideoEffect(widget: widget)
        }
        for textEffect in textEffects.values {
            media.unregisterEffect(textEffect)
        }
        textEffects.removeAll()
        for widget in database.widgets where widget.type == .time {
            textEffects[widget.id] = TextEffect(
                format: widget.text.formatString,
                fontSize: 40,
                settingName: widget.name
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
                widget: widget.browser,
                videoSize: videoSize,
                settingName: widget.name
            )
        }
        browsers = browserEffects.map { _, browser in
            Browser(browserEffect: browser)
        }
        drawOnStreamEffect.updateOverlay(
            videoSize: media.getVideoSize(),
            size: drawOnStreamSize,
            lines: drawOnStreamLines
        )
        sceneUpdated(imageEffectChanged: true, store: false)
    }

    func store() {
        settings.store()
        sendSettingsToWatch()
    }

    func networkInterfaceNamesUpdated() {
        media.setNetworkInterfaceNames(networkInterfaceNames: database.networkInterfaceNames!)
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
        currentRecording = recordingsStorage.createRecording(settings: stream.clone())
        let bitrate = Int(stream.recording!.videoBitrate)
        let keyFrameInterval = Int(stream.recording!.maxKeyFrameInterval)
        media.startRecording(
            url: currentRecording!.url(),
            videoCodec: stream.recording!.videoCodec,
            videoBitrate: bitrate != 0 ? bitrate : nil,
            keyFrameInterval: keyFrameInterval != 0 ? keyFrameInterval : nil
        )
        makeToast(title: "Recording started")
    }

    func stopRecording() {
        guard isRecording else {
            return
        }
        setIsRecording(value: false)
        media.stopRecording()
        makeToast(title: "Recording stopped")
        if let currentRecording {
            recordingsStorage.append(recording: currentRecording)
            recordingsStorage.store()
        }
        updateRecordingLength(now: Date())
        currentRecording = nil
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
        sendIsLiveToWatch()
    }

    func setIsRecording(value: Bool) {
        isRecording = value
        setGlobalButtonState(type: .record, isOn: value)
        updateButtonStates()
        sendIsRecordingToWatch()
    }

    private func setIsMuted(value: Bool) {
        setMuteOn(value: value)
    }

    private func getVoice(message: String) -> AVSpeechSynthesisVoice? {
        var language: String?
        if database.chat.textToSpeechDetectLanguagePerMessage! {
            recognizer.reset()
            recognizer.processString(message)
            language = recognizer.dominantLanguage?.rawValue
        }
        if language == nil {
            language = Locale.current.language.languageCode?.identifier
        }
        guard let language else {
            return nil
        }
        if let voiceIdentifier = textToSpeechVoices[language] {
            return AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        } else if let voice = AVSpeechSynthesisVoice.speechVoices()
            .filter({ $0.language.starts(with: language) }).first
        {
            return AVSpeechSynthesisVoice(identifier: voice.identifier)
        }
        return nil
    }

    private func say(user: String, message: String) {
        let text: String
        if user == latestUserThatSaidSomething || !database.chat.textToSpeechSayUsername! {
            text = message
        } else {
            text = String(localized: "\(user) said \(message)")
        }
        latestUserThatSaidSomething = user
        textToSpeechQueue.async {
            let utterance = AVSpeechUtterance(string: text)
            utterance.rate = self.textToSpeechRate
            utterance.pitchMultiplier = 0.8
            utterance.postUtteranceDelay = 0.05
            utterance.volume = self.textToSpeechVolume
            if let voice = self.getVoice(message: message) {
                utterance.voice = voice
            }
            self.synthesizer.speak(utterance)
        }
    }

    func setTextToSpeechRate(rate: Float) {
        textToSpeechQueue.async {
            self.textToSpeechRate = rate
        }
    }

    func setTextToSpeechVolume(volume: Float) {
        textToSpeechQueue.async {
            self.textToSpeechVolume = volume
        }
    }

    func setTextToSpeechVoices(voices: [String: String]) {
        textToSpeechQueue.async {
            self.textToSpeechVoices = voices
        }
    }

    func startStream(delayed: Bool = false) {
        logger.info("stream: Start")
        guard !streaming else {
            return
        }
        if delayed && !isLive {
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
        setIsLive(value: true)
        streaming = true
        streamTotalBytes = 0
        streamTotalChatMessages = 0
        reconnectTime = firstReconnectTime
        updateScreenAutoOff()
        startNetStream()
        streamingHistoryStream = StreamingHistoryStream(settings: stream.clone())
        streamingHistoryStream!.updateHighestThermalState(thermalState: ThermalState(from: thermalState))
        streamingHistoryStream!.updateLowestBatteryLevel(level: batteryLevel)
    }

    func stopStream() {
        setIsLive(value: false)
        updateScreenAutoOff()
        realtimeIrl?.stop()
        if !streaming {
            return
        }
        logger.info("stream: Stop")
        streamTotalBytes += UInt64(media.streamTotal())
        streaming = false
        stopNetStream()
        streamState = .disconnected
        if let streamingHistoryStream {
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
        latestLowBitrateDate = Date()
        switch stream.getProtocol() {
        case .rtmp:
            media.rtmpStartStream(url: stream.url,
                                  targetBitrate: stream.bitrate,
                                  adaptiveBitrate: stream.rtmp!.adaptiveBitrateEnabled)
            updateAdaptiveBitrateRtmpIfEnabled(stream: stream)
        case .srt:
            payloadSize = stream.srt.mpegtsPacketsPerPacket * 188
            media.srtStartStream(
                isSrtla: stream.isSrtla(),
                url: stream.url,
                reconnectTime: reconnectTime,
                targetBitrate: stream.bitrate,
                adaptiveBitrate: stream.srt.adaptiveBitrateEnabled!,
                latency: stream.srt.latency,
                overheadBandwidth: database.debug!.srtOverheadBandwidth!,
                maximumBandwidthFollowInput: database.debug!.maximumBandwidthFollowInput!,
                mpegtsPacketsPerPacket: stream.srt.mpegtsPacketsPerPacket,
                networkInterfaceNames: database.networkInterfaceNames!,
                connectionPriorities: stream.srt.connectionPriorities!
            )
            updateAdaptiveBitrateSrtIfEnabled(stream: stream)
        }
        updateSpeed(now: Date())
    }

    private func stopNetStream(reconnect: Bool = false) {
        reconnectTimer?.invalidate()
        media.rtmpStopStream()
        media.srtStopStream()
        streamStartDate = nil
        updateUptime(now: Date())
        updateSpeed(now: Date())
        updateAudioLevel()
        srtlaConnectionStatistics = noValue
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

    func reloadStream() {
        cameraPosition = nil
        stopRecording()
        stopStream()
        setNetStream()
        setStreamResolution()
        setStreamFPS()
        setColorSpace()
        setStreamCodec()
        setStreamKeyFrameInterval()
        setStreamBitrate(stream: stream)
        setAudioStreamBitrate(stream: stream)
        setAudioChannelsMap(channelsMap: [
            0: database.debug!.audioOutputToInputChannelsMap!.channel0,
            1: database.debug!.audioOutputToInputChannelsMap!.channel1,
        ])
        reloadConnections()
        resetChat()
        reloadLocation()
    }

    func reloadChats() {
        reloadTwitchChat()
        reloadKickPusher()
        reloadYouTubeLiveChat()
        reloadAfreecaTvChat()
        reloadOpenStreamingPlatformChat()
    }

    func newTextToSpeech() {
        textToSpeechQueue.async {
            self.synthesizer = AVSpeechSynthesizer()
            self.recognizer = NLLanguageRecognizer()
        }
    }

    func stopTextToSpeech() {
        textToSpeechQueue.async {
            self.synthesizer.stopSpeaking(at: .word)
        }
        newTextToSpeech()
    }

    private func reloadConnections() {
        reloadChats()
        reloadTwitchPubSub()
        reloadObsWebSocket()
        reloadRemoteControlStreamer()
        reloadRemoteControlAssistant()
        reloadKickViewers()
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
        videoView.attachStream(media.getNetStream())
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

    private func getPreset(preset: AVCaptureSession.Preset) -> AVCaptureSession.Preset {
        return preset
    }

    private func setStreamResolution() {
        switch stream.resolution {
        case .r3840x2160:
            media.setVideoSessionPreset(preset: getPreset(preset: .hd4K3840x2160))
            media.setVideoSize(size: .init(width: 3840, height: 2160))
        case .r1920x1080:
            media.setVideoSessionPreset(preset: getPreset(preset: .hd1920x1080))
            media.setVideoSize(size: .init(width: 1920, height: 1080))
        case .r1280x720:
            media.setVideoSessionPreset(preset: getPreset(preset: .hd1280x720))
            media.setVideoSize(size: .init(width: 1280, height: 720))
        case .r854x480:
            media.setVideoSessionPreset(preset: getPreset(preset: .hd1280x720))
            media.setVideoSize(size: .init(width: 854, height: 480))
        case .r640x360:
            media.setVideoSessionPreset(preset: getPreset(preset: .hd1280x720))
            media.setVideoSize(size: .init(width: 640, height: 360))
        case .r426x240:
            media.setVideoSessionPreset(preset: getPreset(preset: .hd1280x720))
            media.setVideoSize(size: .init(width: 426, height: 240))
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
                    self.setZoomX(x: x)
                }
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

    func setAudioStreamBitrate(stream: SettingsStream) {
        media.setAudioStreamBitrate(bitrate: stream.audioBitrate!)
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

    private func setStreamKeyFrameInterval() {
        media.setStreamKeyFrameInterval(seconds: stream.maxKeyFrameInterval!)
    }

    func isStreamConfigured() -> Bool {
        return stream != fallbackStream
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
        return stream.twitchEnabled! && stream.twitchChannelId != ""
    }

    func isTwitchChatConfigured() -> Bool {
        return database.chat.enabled! && stream.twitchEnabled! && stream.twitchChannelName != ""
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
        return database.chat.enabled! && stream
            .kickEnabled! && (stream.kickChatroomId != "" || stream.kickChannelName != "")
    }

    func isKickPusherConnected() -> Bool {
        return kickPusher?.isConnected() ?? false
    }

    func hasKickPusherEmotes() -> Bool {
        return kickPusher?.hasEmotes() ?? false
    }

    func isKickViewersConfigured() -> Bool {
        return stream.kickEnabled! && stream.kickChannelName != ""
    }

    func isYouTubeLiveChatConfigured() -> Bool {
        return database.chat.enabled! && stream.youTubeEnabled! && stream.youTubeApiKey! != "" && stream
            .youTubeVideoId! != ""
    }

    func isYouTubeLiveChatConnected() -> Bool {
        return youTubeLiveChat?.isConnected() ?? false
    }

    func hasYouTubeLiveChatEmotes() -> Bool {
        return youTubeLiveChat?.hasEmotes() ?? false
    }

    func isAfreecaTvChatConfigured() -> Bool {
        return database.chat.enabled! && stream.afreecaTvEnabled! && stream
            .afreecaTvChannelName! != "" && stream
            .afreecaTvStreamId! != ""
    }

    func isAfreecaTvChatConnected() -> Bool {
        return afreecaTvChat?.isConnected() ?? false
    }

    func hasAfreecaTvChatEmotes() -> Bool {
        return afreecaTvChat?.hasEmotes() ?? false
    }

    func isOpenStreamingPlatformChatConfigured() -> Bool {
        return database.chat.enabled! && stream.openStreamingPlatformEnabled! && stream
            .openStreamingPlatformUrl! != "" && stream
            .openStreamingPlatformUsername! != "" && stream
            .openStreamingPlatformPassword! != ""
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

    func isStreamConnceted() -> Bool {
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
        pausedChatPosts = []
        newChatPosts = []
        numberOfChatPostsPerTick = 0
        chatPostsRatePerSecond = 0
        chatPostsRatePerMinute = 0
        numberOfChatPostsPerMinute = 0
        stopTextToSpeech()
    }

    private func reloadTwitchChat() {
        twitchChat.stop()
        if isTwitchChatConfigured() {
            twitchChat.start(
                channelName: stream.twitchChannelName,
                channelId: stream.twitchChannelId,
                settings: stream.chat!
            )
        }
    }

    private func reloadTwitchPubSub() {
        twitchPubSub?.stop()
        if isTwitchViewersConfigured() {
            twitchPubSub = TwitchPubSub(channelId: stream.twitchChannelId)
            twitchPubSub!.start()
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
                apiKey: stream.youTubeApiKey!,
                videoId: stream.youTubeVideoId!,
                settings: stream.chat!
            )
            youTubeLiveChat!.start()
        }
    }

    private func reloadAfreecaTvChat() {
        afreecaTvChat?.stop()
        afreecaTvChat = nil
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
                username: stream.openStreamingPlatformUsername!,
                password: stream.openStreamingPlatformPassword!,
                channelId: stream.openStreamingPlatformChannelId!
            )
            openStreamingPlatformChat!.start()
        }
    }

    private func reloadObsWebSocket() {
        obsWebSocket?.stop()
        obsWebSocket?.onSceneChanged = nil
        obsWebSocket?.onStreamStatusChanged = nil
        obsWebSocket?.onRecordStatusChanged = nil
        obsWebSocket?.onAudioVolume = nil
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
            onConnected: {
                self.updateObsStatus()
            }
        )
        obsWebSocket!.onSceneChanged = handleObsSceneChanged
        obsWebSocket!.onStreamStatusChanged = handleObsStreamStatusChanged
        obsWebSocket!.onRecordStatusChanged = handleObsRecordStatusChanged
        obsWebSocket!.onAudioVolume = handleAudioVolume
        obsWebSocket!.start()
    }

    func twitchEnabledUpdated() {
        reloadTwitchPubSub()
        reloadTwitchChat()
        resetChat()
    }

    func twitchChannelNameUpdated() {
        reloadTwitchChat()
        resetChat()
    }

    func twitchChannelIdUpdated() {
        reloadTwitchPubSub()
        reloadTwitchChat()
        resetChat()
    }

    func kickEnabledUpdated() {
        reloadKickPusher()
        resetChat()
    }

    func kickChannelNameUpdated() {
        reloadKickPusher()
        reloadKickViewers()
        resetChat()
    }

    func youTubeEnabledUpdated() {
        reloadYouTubeLiveChat()
        resetChat()
    }

    func youTubeApiKeyUpdated() {
        reloadYouTubeLiveChat()
        resetChat()
    }

    func youTubeVideoIdUpdated() {
        reloadYouTubeLiveChat()
        resetChat()
    }

    func afreecaTvEnabledUpdated() {
        reloadAfreecaTvChat()
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

    func openStreamingPlatformEnabledUpdated() {
        reloadOpenStreamingPlatformChat()
        resetChat()
    }

    func openStreamingPlatformUrlUpdated() {
        reloadOpenStreamingPlatformChat()
        resetChat()
    }

    func openStreamingPlatformUsernameUpdated() {
        reloadOpenStreamingPlatformChat()
        resetChat()
    }

    func openStreamingPlatformPasswordUpdated() {
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

    func obsFixStream() {
        obsFixOngoing = true
        obsWebSocket?.getSceneItemId(
            sceneName: obsCurrentScene,
            sourceName: stream.obsSourceName!,
            onSuccess: { itemId in
                self.obsWebSocket?.setSceneItemEnabled(
                    sceneName: self.obsCurrentScene,
                    sceneItemId: itemId,
                    enabled: false,
                    onSuccess: {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            self.obsWebSocket?.setSceneItemEnabled(
                                sceneName: self.obsCurrentScene,
                                sceneItemId: itemId,
                                enabled: true,
                                onSuccess: {
                                    DispatchQueue.main.async {
                                        self.obsFixOngoing = false
                                    }
                                },
                                onError: self.obsFixStreamError
                            )
                        }
                    },
                    onError: self.obsFixStreamError
                )
            },
            onError: obsFixStreamError
        )
    }

    func obsFixStreamError(_: String) {
        DispatchQueue.main.async {
            self.obsFixOngoing = false
        }
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
                if progress != 100 || browser.browserEffect.startLoadingTime + 5 > Date() {
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
        if logger.debugEnabled && isLive {
            logger.debug("Status: Bitrate: \(speedAndTotal), Uptime: \(uptime)")
        }
    }

    private func updateFailedVideoEffects() {
        let newFailedVideoEffect = media.getFailedVideoEffect()
        if newFailedVideoEffect != failedVideoEffect {
            if let newFailedVideoEffect {
                makeErrorToast(title: "Failed to render \(newFailedVideoEffect)")
            }
            failedVideoEffect = newFailedVideoEffect
        }
    }

    func setLowFpsImage() {
        media.setLowFpsImage(enabled: isWatchReachable())
    }

    func toggleLocalOverlays() {
        showLocalOverlays.toggle()
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
        guard !stream.obsSourceName!.isEmpty else {
            return
        }
        obsWebSocket?.getSourceScreenshot(name: stream.obsSourceName!, onSuccess: { data in
            let screenshot = UIImage(data: data)?.cgImage
            DispatchQueue.main.async {
                self.obsScreenshot = screenshot
                self.obsSourceScreenshotIsFetching = false
            }
        }, onError: { message in
            logger.debug("Failed to update screenshot with error \(message)")
            DispatchQueue.main.async {
                self.obsScreenshot = nil
                self.obsSourceScreenshotIsFetching = false
            }
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

    private func handleObsSceneChanged(name: String) {
        DispatchQueue.main.async {
            self.obsCurrentScene = name
        }
    }

    private func handleObsStreamStatusChanged(active: Bool, state: ObsOutputState? = nil) {
        DispatchQueue.main.async {
            self.obsStreaming = active
            if let state {
                self.obsStreamingState = state
            } else if active {
                self.obsStreamingState = .started
            } else {
                self.obsStreamingState = .stopped
            }
        }
    }

    private func handleObsRecordStatusChanged(active: Bool) {
        DispatchQueue.main.async {
            self.obsRecording = active
        }
    }

    private func handleAudioVolume(volumes: [ObsAudioInputVolume]) {
        DispatchQueue.main.async {
            guard let volume = volumes.first(where: { volume in
                volume.name == self.stream.obsSourceName!
            }) else {
                self
                    .obsAudioVolumeLatest =
                    String(localized: "Source \(self.stream.obsSourceName!) not found")
                return
            }
            var values: [String] = []
            for volume in volume.volumes {
                if volume.isInfinite {
                    values.append(String(localized: "Muted"))
                } else {
                    values.append(String(localized: "\(formatOneDecimal(value: volume)) dB"))
                }
            }
            self.obsAudioVolumeLatest = values.joined(separator: ", ")
        }
    }

    private func appendChatPost(post: ChatPost) {
        appendChatMessage(user: post.user,
                          userColor: post.userColor,
                          segments: post.segments,
                          timestamp: post.timestamp,
                          timestampDate: post.timestampDate,
                          isAction: post.isAction,
                          isAnnouncement: post.isAnnouncement,
                          isFirstMessage: post.isFirstMessage,
                          isSubscriber: post.isSubscriber)
    }

    func appendChatMessage(
        user: String?,
        userColor: String?,
        segments: [ChatPostSegment],
        timestamp: String,
        timestampDate: Date,
        isAction: Bool,
        isAnnouncement: Bool,
        isFirstMessage: Bool,
        isSubscriber: Bool
    ) {
        if database.chat.usernamesToIgnore!.contains(where: { user == $0.value }) {
            return
        }
        let post = ChatPost(
            id: chatPostId,
            user: user,
            userColor: userColor,
            segments: segments,
            timestamp: timestamp,
            timestampDate: timestampDate,
            isAction: isAction,
            isAnnouncement: isAnnouncement,
            isFirstMessage: isFirstMessage,
            isSubscriber: isSubscriber
        )
        chatPostId += 1
        if chatPaused {
            if pausedChatPosts.count < 2 * maximumNumberOfChatMessages {
                pausedChatPosts.append(post)
            }
        } else {
            newChatPosts.append(post)
        }
    }

    func reloadChatMessages() {
        let posts = chatPosts
        chatPosts = []
        for post in posts {
            appendChatPost(post: post)
        }
    }

    func toggleBlackScreen() {
        blackScreen.toggle()
    }

    func toggleInteractiveChat() {
        interactiveChat.toggle()
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
        unregisterGlobalVideoEffects()
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
            browserEffect.stop()
        }
        media.unregisterEffect(drawOnStreamEffect)
        media.unregisterEffect(lutEffect)
    }

    private func attachSingleLayout(scene: SettingsScene) {
        switch scene.cameraPosition! {
        case .back:
            attachCamera(position: .back)
        case .front:
            attachCamera(position: .front)
        case .rtmp:
            attachRtmpCamera(cameraId: scene.rtmpCameraId!)
        case .external:
            attachExternalCamera(cameraId: scene.externalCameraId!)
        }
    }

    func listCameraPositions() -> [(String, String)] {
        return backCameras.map {
            ($0.id, "Back \($0.name)")
        } + frontCameras.map {
            ($0.id, "Front \($0.name)")
        } + externalCameras.map {
            ($0.id, $0.name)
        } + rtmpCameras().map {
            ($0, $0)
        }
    }

    func isBackCamera(cameraId: String) -> Bool {
        return backCameras.contains(where: { $0.id == cameraId })
    }

    func isFrontCamera(cameraId: String) -> Bool {
        return frontCameras.contains(where: { $0.id == cameraId })
    }

    func getCameraPositionId(scene: SettingsScene?) -> String {
        guard let scene else {
            return ""
        }
        switch scene.cameraPosition! {
        case .rtmp:
            if let stream = getRtmpStream(id: scene.rtmpCameraId!) {
                return stream.camera()
            } else {
                return ""
            }
        case .external:
            if !scene.externalCameraId!.isEmpty {
                return scene.externalCameraId!
            } else {
                return ""
            }
        case .back:
            if !scene.backCameraId!.isEmpty {
                return scene.backCameraId!
            } else {
                return ""
            }
        case .front:
            if !scene.frontCameraId!.isEmpty {
                return scene.frontCameraId!
            } else {
                return ""
            }
        }
    }

    func getCameraPositionName(scene: SettingsScene?) -> String {
        guard let scene else {
            return "Unknown"
        }
        switch scene.cameraPosition! {
        case .rtmp:
            if let stream = getRtmpStream(id: scene.rtmpCameraId!) {
                return stream.camera()
            } else {
                return "Unknown"
            }
        case .external:
            if !scene.externalCameraName!.isEmpty {
                return scene.externalCameraName!
            } else {
                return "Unknown"
            }
        case .back:
            if let camera = backCameras.first(where: { $0.id == scene.backCameraId! }) {
                return "Back \(camera.name)"
            } else {
                return "Unknown"
            }
        case .front:
            if let camera = frontCameras.first(where: { $0.id == scene.frontCameraId! }) {
                return "Front \(camera.name)"
            } else {
                return "Unknown"
            }
        }
    }

    func getExternalCameraName(cameraId: String) -> String {
        if let camera = externalCameras.first(where: { camera in
            camera.id == cameraId
        }) {
            return camera.name
        } else {
            return "Unknown"
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

    func stopAllRtmpStreams() {
        for stream in database.rtmpServer!.streams {
            media.removeRtmpCamera(cameraId: stream.id)
        }
    }

    func isRtmpStreamConnected(streamKey: String) -> Bool {
        return rtmpServer?.isStreamConnected(streamKey: streamKey) ?? false
    }

    private func findSceneWidget(scene: SettingsScene, widgetId: UUID) -> SettingsSceneWidget? {
        return scene.widgets.first(where: { $0.widgetId == widgetId })
    }

    private func sceneUpdatedOn(scene: SettingsScene) {
        attachSingleLayout(scene: scene)
        if database.color!.lutEnabled {
            media.registerEffect(lutEffect)
        }
        registerGlobalVideoEffects()
        var usedBrowserEffects: [BrowserEffect] = []
        for sceneWidget in scene.widgets.filter({ $0.enabled }) {
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
                if let videoEffect = videoEffects[widget.id] {
                    if let noiseReductionEffect = videoEffect as? NoiseReductionEffect {
                        noiseReductionEffect.noiseLevel = widget.videoEffect
                            .noiseReductionNoiseLevel
                        noiseReductionEffect.sharpness = widget.videoEffect
                            .noiseReductionSharpness
                    }
                    media.registerEffect(videoEffect)
                }
            case .browser:
                if let browserEffect = browserEffects[widget.id],
                   !usedBrowserEffects.contains(browserEffect)
                {
                    browserEffect.setSceneWidget(
                        sceneWidget: sceneWidget,
                        crops: findWidgetCrops(scene: scene, sourceWidgetId: widget.id)
                    )
                    if !browserEffect.audioOnly {
                        media.registerEffect(browserEffect)
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
                        media.registerEffect(browserEffect)
                    }
                    usedBrowserEffects.append(browserEffect)
                }
            }
        }
        if !drawOnStreamLines.isEmpty {
            media.registerEffect(drawOnStreamEffect)
        }
        for browserEffect in browserEffects.values where !usedBrowserEffects.contains(browserEffect) {
            browserEffect.setSceneWidget(sceneWidget: nil, crops: [])
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
            if let button = getEnabledButtonForWidgetControlledByScene(
                widget: widget,
                scene: scene
            ) {
                if !button.isOn {
                    continue
                }
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
    }

    private func selectScene(id: UUID) {
        if let index = enabledScenes.firstIndex(where: { scene in
            scene.id == id
        }) {
            sceneIndex = index
            setSceneId(id: id)
            sceneUpdated(scrollQuickButtons: true)
        }
    }

    func sceneUpdated(imageEffectChanged: Bool = false, store: Bool = true,
                      scrollQuickButtons: Bool = false)
    {
        if store {
            self.store()
        }
        updateButtonStates()
        if scrollQuickButtons {
            scrollQuickButtonsToBottom()
        }
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
        } else if uptime != noValue {
            uptime = noValue
        }
    }

    private func updateRecordingLength(now: Date) {
        if let currentRecording {
            let elapsed = uptimeFormatter.string(from: now.timeIntervalSince(currentRecording.startTime))!
            let size = currentRecording.url().fileSize.formatBytes()
            recordingLength = "\(elapsed) (\(size))"
        } else if recordingLength != noValue {
            recordingLength = noValue
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
        if batteryLevel < 0.05 && !isBatteryCharging() {
            makeWarningToast(title: lowBatteryMessage, vibrate: true)
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

    private func checkLowBitrate(speed: Int64, now: Date) {
        guard database.lowBitrateWarning! else {
            return
        }
        guard streamState == .connected else {
            return
        }
        if speed < 500_000 && now > latestLowBitrateDate + 15 {
            makeWarningToast(title: lowBitrateMessage, vibrate: true)
            latestLowBitrateDate = now
        }
    }

    private func updateSpeed(now: Date) {
        if isLive {
            let speed = media.streamSpeed()
            checkLowBitrate(speed: speed, now: now)
            streamingHistoryStream?.updateBitrate(bitrate: speed)
            let speedString = formatBytesPerSecond(speed: speed)
            let total = sizeFormatter.string(fromByteCount: media.streamTotal())
            speedAndTotal = String(localized: "\(speedString) (\(total))")
            sendSpeedAndTotalToWatch()
        } else if speedAndTotal != noValue {
            speedAndTotal = noValue
            sendSpeedAndTotalToWatch()
        }
    }

    private func updateRtmpSpeed() {
        let message: String
        if let rtmpServer {
            let stats = rtmpServer.updateStats()
            let numberOfClients = rtmpServer.numberOfClients()
            if rtmpServer.numberOfClients() > 0 {
                let total = stats.total.formatBytes()
                let speed = formatBytesPerSecond(speed: Int64(8 * stats.speed))
                message = String(localized: "\(speed) (\(total)) \(numberOfClients)")
            } else {
                message = String(numberOfClients)
            }
        } else {
            message = noValue
        }
        if message != rtmpSpeedAndTotal {
            rtmpSpeedAndTotal = message
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
        logger.info("Thermal state is \(thermalState.string())")
    }

    func reattachCamera() {
        detachCamera()
        attachCamera()
    }

    func detachCamera() {
        media.attachCamera(device: nil, secondDevice: nil, videoStabilizationMode: .off, videoMirrored: false)
    }

    func attachCamera() {
        let isMirrored = getVideoMirroredOnScreen()
        media.attachCamera(
            device: cameraDevice,
            secondDevice: secondCameraDevice,
            videoStabilizationMode: getVideoStabilizationMode(),
            videoMirrored: getVideoMirroredOnStream()
        ) {
            self.videoView.isMirrored = isMirrored
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
        return cameraPosition == .front && database.mirrorFrontCameraOnStream!
    }

    private func getVideoMirroredOnScreen() -> Bool {
        return cameraPosition == .front && !database.mirrorFrontCameraOnStream!
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

    private func attachCamera(
        position: AVCaptureDevice.Position,
        secondPosition: AVCaptureDevice.Position? = nil
    ) {
        guard hasCameraChanged(
            oldCameraDevice: cameraDevice,
            oldPosition: cameraPosition,
            newPosition: position
        ) else {
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
        if let secondPosition {
            secondCameraDevice = preferredCamera(position: secondPosition)
        } else {
            secondCameraDevice = nil
        }
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
        let isMirrored = getVideoMirroredOnScreen()
        media.attachCamera(
            device: cameraDevice,
            secondDevice: secondCameraDevice,
            videoStabilizationMode: getVideoStabilizationMode(),
            videoMirrored: getVideoMirroredOnStream(),
            onSuccess: {
                if let device = self.cameraDevice {
                    logger.debug("FPS: \(device.fps)")
                }
                self.videoView.isMirrored = isMirrored
                if let x = self.setCameraZoomX(x: self.zoomX) {
                    self.setZoomX(x: x)
                }
                if let device = self.cameraDevice {
                    self.setMaxAutoExposure(device: device)
                }
            }
        )
        zoomXPinch = zoomX
        hasZoom = true
    }

    private func attachRtmpCamera(cameraId: UUID) {
        cameraDevice = nil
        cameraPosition = nil
        secondCameraDevice = nil
        videoView.isMirrored = false
        hasZoom = false
        media.attachRtmpCamera(cameraId: cameraId, device: preferredCamera(position: .front))
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

    private func setMaxAutoExposure(device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            device.activeMaxExposureDuration = device.activeFormat.maxExposureDuration
            device.unlockForConfiguration()
        } catch {}
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
        switch database.videoStabilizationMode {
        case .off:
            return .off
        case .standard:
            return .standard
        case .cinematic:
            return .cinematic
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

    private func updateMute() {
        media.setMute(on: isMuteOn)
        sendIsMutedToWatch()
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
            backZoomPresetId = UUID()
        case .front:
            frontZoomPresetId = UUID()
        default:
            break
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

    private func handleVideoDeviceInUseByAnotherClient() {
        DispatchQueue.main.async {
            // self.makeErrorToast(title: "Video in use by another app")
        }
    }

    private func handleLowFpsImage(image: Data?) {
        guard let image else {
            return
        }
        DispatchQueue.main.async {
            self.sendPreviewToWatch(image: image)
        }
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
        let subTitle = String(localized: "Attempting again in \(Int(reconnectTime)) seconds.")
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
            .scheduledTimer(withTimeInterval: reconnectTime, repeats: false) { _ in
                logger.info("stream: Reconnecting")
                self.startNetStream(reconnect: true)
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
        if !database.zoom.back.contains(where: { level in
            level.id == backZoomPresetId
        }) {
            backZoomPresetId = database.zoom.back[0].id
        }
        sceneUpdated(store: true)
    }

    func frontZoomUpdated() {
        if !database.zoom.front.contains(where: { level in
            level.id == frontZoomPresetId
        }) {
            frontZoomPresetId = database.zoom.front[0].id
        }
        sceneUpdated(store: true)
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
            title: String(localized: "😢 FFFFF 😢"),
            font: .system(size: 64).bold(),
            subTitle: subTitle,
            vibrate: true
        )
    }

    func setFocusPointOfInterest(focusPoint: CGPoint) {
        guard
            let device = cameraDevice, device.isFocusPointOfInterestSupported
        else {
            logger.warning("Tap to focus not supported for this camera")
            makeErrorToast(title: String(localized: "Tap to focus not supported for this camera"))
            return
        }
        var focusPointOfInterest = focusPoint
        if getOrientation() == .landscapeRight {
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
        manualFocuses[device] = lensPosition
    }

    func getIsManualFocusEnabled() -> Bool {
        guard let device = cameraDevice else {
            return false
        }
        return manualFocusesEnabled[device] ?? false
    }

    private func setFocusAfterCameraAttach() {
        guard let device = cameraDevice else {
            return
        }
        manualFocus = manualFocuses[device] ?? 1.0
        if !getIsManualFocusEnabled() {
            setAutoFocus()
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

    func isShowingStatusChat() -> Bool {
        return database.show.chat && isChatConfigured()
    }

    func isShowingStatusViewers() -> Bool {
        return database.show.viewers && isViewersConfigured()
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
            return ""
        }
    }

    func statusViewersText() -> String {
        if isViewersConfigured() {
            return numberOfViewers
        } else {
            return ""
        }
    }

    func isShowingStatusAudioLevel() -> Bool {
        return database.show.audioLevel
    }

    func isShowingStatusRtmpServer() -> Bool {
        return database.show.rtmpSpeed! && rtmpServerEnabled()
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

    func isShowingStatusSrtla() -> Bool {
        return stream.isSrtla() && isLive
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
    func connected() {
        DispatchQueue.main.async {
            self.makeToast(title: "Remote control assistant connected")
            self.updateRemoteControlStatus()
            var state = RemoteControlState()
            if self.sceneIndex < self.enabledScenes.count {
                state.scene = self.enabledScenes[self.sceneIndex].id
            }
            state.mic = self.mic.id
            if let preset = self.getBitratePresetByBitrate(bitrate: self.stream.bitrate) {
                state.bitrate = preset.id
            }
            state.zoom = self.zoomX
            self.remoteControlStreamer?.stateChanged(state: state)
        }
    }

    func disconnected() {
        DispatchQueue.main.async {
            self.makeToast(title: "Remote control assistant disconnected")
            self.updateRemoteControlStatus()
        }
    }

    func getStatus(onComplete: @escaping (
        RemoteControlStatusGeneral,
        RemoteControlStatusTopLeft,
        RemoteControlStatusTopRight
    ) -> Void) {
        DispatchQueue.main.async {
            var general = RemoteControlStatusGeneral()
            general.batteryCharging = self.isBatteryCharging()
            general.batteryLevel = Int(100 * self.batteryLevel)
            switch self.thermalState {
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
            var topLeft = RemoteControlStatusTopLeft()
            if self.isShowingStatusStream() {
                topLeft.stream = RemoteControlStatusItem(message: self.statusStreamText())
            }
            if self.isShowingStatusCamera() {
                topLeft.camera = RemoteControlStatusItem(message: self.statusCameraText())
            }
            if self.isShowingStatusMic() {
                topLeft.mic = RemoteControlStatusItem(message: self.mic.name)
            }
            if self.isShowingStatusZoom() {
                topLeft.zoom = RemoteControlStatusItem(message: self.statusZoomText())
            }
            if self.isShowingStatusObs() {
                topLeft.obs = RemoteControlStatusItem(message: self.statusObsText())
            }
            if self.isShowingStatusChat() {
                topLeft.chat = RemoteControlStatusItem(message: self.statusChatText())
            }
            if self.isShowingStatusViewers() {
                topLeft.viewers = RemoteControlStatusItem(message: self.statusViewersText())
            }
            var topRight = RemoteControlStatusTopRight()
            if self.isShowingStatusAudioLevel() {
                let level = formatAudioLevel(level: self.audioLevel) +
                    formatAudioLevelChannels(channels: self.numberOfAudioChannels)
                topRight.audioLevel = RemoteControlStatusItem(message: level)
            }
            if self.isShowingStatusRtmpServer() {
                topRight.rtmpServer = RemoteControlStatusItem(message: self.rtmpSpeedAndTotal)
            }
            if self.isShowingStatusRemoteControl() {
                topRight.remoteControl = RemoteControlStatusItem(message: self.remoteControlStatus)
            }
            if self.isShowingStatusGameController() {
                topRight.gameController = RemoteControlStatusItem(message: self.gameControllersTotal)
            }
            if self.isShowingStatusBitrate() {
                topRight.bitrate = RemoteControlStatusItem(message: self.speedAndTotal)
            }
            if self.isShowingStatusUptime() {
                topRight.uptime = RemoteControlStatusItem(message: self.uptime)
            }
            if self.isShowingStatusLocation() {
                topRight.location = RemoteControlStatusItem(message: self.location)
            }
            if self.isShowingStatusSrtla() {
                topRight.srtla = RemoteControlStatusItem(message: self.srtlaConnectionStatistics)
            }
            if self.isShowingStatusRecording() {
                topRight.recording = RemoteControlStatusItem(message: self.recordingLength)
            }
            if self.isShowingStatusBrowserWidgets() {
                topRight.browserWidgets = RemoteControlStatusItem(message: self.browserWidgetsStatus)
            }
            onComplete(general, topLeft, topRight)
        }
    }

    func getSettings(onComplete: @escaping (RemoteControlSettings) -> Void) {
        DispatchQueue.main.async {
            let scenes = self.database.scenes.map { scene in
                RemoteControlSettingsScene(id: scene.id, name: scene.name)
            }
            let mics = self.listMics().map { mic in
                RemoteControlSettingsMic(id: mic.id, name: mic.name)
            }
            let bitratePresets = self.database.bitratePresets.map { preset in
                RemoteControlSettingsBitratePreset(id: preset.id, bitrate: preset.bitrate)
            }
            let connectionPriorities = self.stream.srt.connectionPriorities!.priorities
                .map { priority in
                    RemoteControlSettingsSrtConnectionPriority(
                        id: priority.id,
                        name: priority.name,
                        priority: priority.priority,
                        enabled: priority.enabled!
                    )
                }
            let connectionPrioritiesEnabled = self.stream.srt.connectionPriorities!.enabled
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
    }

    func setScene(id: UUID, onComplete: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.selectScene(id: id)
            onComplete()
        }
    }

    func setMic(id: String, onComplete: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.selectMicById(id: id)
            onComplete()
        }
    }

    func setBitratePreset(id: UUID, onComplete: @escaping () -> Void) {
        DispatchQueue.main.async {
            guard let preset = self.database.bitratePresets.first(where: { preset in
                preset.id == id
            }) else {
                return
            }
            self.setBitrate(bitrate: preset.bitrate)
            if self.stream.enabled {
                self.setStreamBitrate(stream: self.stream)
            }
            onComplete()
        }
    }

    func setRecord(on: Bool, onComplete: @escaping () -> Void) {
        DispatchQueue.main.async {
            if on {
                self.startRecording()
            } else {
                self.stopRecording()
            }
            self.updateButtonStates()
            onComplete()
        }
    }

    func setStream(on: Bool, onComplete: @escaping () -> Void) {
        DispatchQueue.main.async {
            if on {
                self.startStream()
            } else {
                self.stopStream()
            }
            self.updateButtonStates()
            onComplete()
        }
    }

    func setZoom(x: Float, onComplete: @escaping () -> Void) {
        DispatchQueue.main.async {
            if let x = self.setCameraZoomX(x: x, rate: self.database.zoom.speed!) {
                self.setZoomX(x: x)
            }
            onComplete()
        }
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

    func setMute(on: Bool, onComplete: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.setMuteOn(value: on)
            onComplete()
        }
    }

    func setTorch(on: Bool, onComplete: @escaping () -> Void) {
        DispatchQueue.main.async {
            if on {
                self.isTorchOn = true
            } else {
                self.isTorchOn = false
            }
            self.updateTorch()
            self.toggleGlobalButton(type: .torch)
            self.updateButtonStates()
            onComplete()
        }
    }

    func reloadBrowserWidgets(onComplete: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.reloadBrowserWidgets()
            onComplete()
        }
    }

    func setSrtConnectionPrioritiesEnabled(enabled: Bool, onComplete: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.stream.srt.connectionPriorities!.enabled = enabled
            self.store()
            self.updateSrtlaPriorities()
            onComplete()
        }
    }

    func setSrtConnectionPriority(id: UUID, priority: Int, enabled: Bool, onComplete: @escaping () -> Void) {
        DispatchQueue.main.async {
            if let entry = self.stream.srt.connectionPriorities!.priorities.first(where: { $0.id == id }) {
                entry.priority = clampConnectionPriority(value: priority)
                entry.enabled = enabled
                self.store()
                self.updateSrtlaPriorities()
            }
            onComplete()
        }
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
            return
        }
        let server = database.remoteControl!.server
        guard let url = URL(string: server.url) else {
            return
        }
        remoteControlStreamer = RemoteControlStreamer(
            clientUrl: url,
            password: database.remoteControl!.password!,
            delegate: self
        )
        remoteControlStreamer!.start()
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
        let client = database.remoteControl!.client
        remoteControlAssistant = RemoteControlAssistant(
            port: client.port,
            password: database.remoteControl!.password!,
            delegate: self
        )
        remoteControlAssistant!.start()
    }

    func isRemoteControlAssistantConnected() -> Bool {
        return remoteControlAssistant?.isConnected() ?? false
    }

    func updateRemoteControlAssistantStatus() {
        guard showingRemoteControl, remoteControlAssistant?.isConnected() == true else {
            return
        }
        remoteControlAssistant?.getStatus { general, topLeft, topRight in
            self.remoteControlGeneral = general
            self.remoteControlTopLeft = topLeft
            self.remoteControlTopRight = topRight
        }
        remoteControlAssistant?.getSettings { settings in
            self.remoteControlSettings = settings
        }
    }

    func isRemoteControlAssistantConfigured() -> Bool {
        let client = database.remoteControl!.client
        return client.enabled && client.port > 0 && !database.remoteControl!.password!.isEmpty
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

    func remoteControlAssistantReloadBrowserWidgets() {
        remoteControlAssistant?.reloadBrowserWidgets {
            DispatchQueue.main.async {
                self.makeToast(title: "Browser widgets reloaded")
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
}

extension Model: RemoteControlAssistantDelegate {
    func assistantConnected() {
        makeToast(title: "Remote control streamer connected")
        updateRemoteControlStatus()
        updateRemoteControlAssistantStatus()
    }

    func assistantDisconnected() {
        makeToast(title: "Remote control streamer disconnected")
        remoteControlTopLeft = nil
        remoteControlTopRight = nil
        updateRemoteControlStatus()
    }

    func assistantStateChanged(state: RemoteControlState) {
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
    }

    func assistantLog(entry: String) {
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

    private func sendSpeedAndTotalToWatch() {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .speedAndTotal, data: speedAndTotal)
    }

    private func sendAudioLevelToWatch() {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .audioLevel, data: audioLevel)
    }

    private func enqueueWatchChatPost(post: ChatPost) {
        guard WCSession.default.isWatchAppInstalled else {
            return
        }
        guard let user = post.user else {
            return
        }
        var userColor: WatchProtocolColor
        if let hexColor = post.userColor,
           let color = WatchProtocolColor.fromHex(value: hexColor)
        {
            userColor = color
        } else {
            let color = database.chat.usernameColor
            userColor = WatchProtocolColor(red: color.red, green: color.green, blue: color.blue)
        }
        let post = WatchProtocolChatMessage(
            id: nextWatchChatPostId,
            timestamp: post.timestamp,
            user: user,
            userColor: userColor,
            segments: post.segments
                .map { WatchProtocolChatSegment(text: $0.text, url: $0.url?.absoluteString) }
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

    private func sendSettingsToWatch() {
        guard isWatchReachable() else {
            return
        }
        do {
            let settings = try JSONEncoder().encode(database.watch)
            sendMessageToWatch(type: .settings, data: settings)
        } catch {}
    }

    private func sendIsLiveToWatch() {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .isLive, data: isLive)
    }

    private func sendIsRecordingToWatch() {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .isRecording, data: isRecording)
    }

    private func sendIsMutedToWatch() {
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
            self.trySendNextChatPostToWatch()
            self.sendSettingsToWatch()
            self.sendAudioLevelToWatch()
            self.sendIsLiveToWatch()
            self.sendIsRecordingToWatch()
            self.sendIsMutedToWatch()
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
            if value {
                self.startStream()
            } else {
                self.stopStream()
            }
        }
    }

    private func handleSetIsRecording(_ data: Any) {
        guard let value = data as? Bool else {
            return
        }
        DispatchQueue.main.async {
            if value {
                self.startRecording()
            } else {
                self.stopRecording()
            }
        }
    }

    private func handleSetIsMuted(_ data: Any) {
        guard let value = data as? Bool else {
            return
        }
        DispatchQueue.main.async {
            self.setIsMuted(value: value)
        }
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
            makeErrorToast(title: "Malformed stream URL", subTitle: "Using default")
        }
        return cleanedUrl
    }

    private func createStreamFromWizardUrl() -> String {
        var url = defaultStreamUrl
        if wizardPlatform == .custom {
            switch wizardCustomProtocol {
            case .none:
                break
            case .srt:
                if var urlComponents = URLComponents(string: wizardCustomSrtUrl.trim()) {
                    urlComponents.queryItems = [
                        URLQueryItem(name: "streamid", value: wizardCustomSrtStreamId.trim()),
                    ]
                    if let fullUrl = urlComponents.url {
                        url = fullUrl.absoluteString
                    }
                }
            case .rtmp:
                let rtmpUrl = wizardCustomRtmpUrl
                    .trim()
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                url = "\(rtmpUrl)/\(wizardCustomRtmpStreamKey.trim())"
            }
        } else {
            switch wizardNetworkSetup {
            case .none:
                break
            case .obs:
                url = "srt://\(wizardObsAddress):\(wizardObsPort)"
            case .belaboxCloudObs:
                url = wizardBelaboxUrl
            case .direct:
                let ingestUrl = wizardDirectIngest.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                url = "\(ingestUrl)/\(wizardDirectStreamKey)"
            }
        }
        return cleanWizardUrl(url: url)
    }

    func createStreamFromWizard() {
        let stream = SettingsStream(name: wizardName.trim())
        stream.twitchEnabled = false
        stream.kickEnabled = false
        stream.youTubeEnabled = false
        stream.afreecaTvEnabled = false
        stream.openStreamingPlatformEnabled = false
        stream.obsWebSocketEnabled = false
        if wizardPlatform != .custom {
            if wizardNetworkSetup != .direct {
                if wizardObsRemoteControlEnabled {
                    let url = cleanUrl(url: wizardObsRemoteControlUrl.trim())
                    if isValidWebSocketUrl(url: url) == nil {
                        stream.obsWebSocketEnabled = true
                        stream.obsWebSocketUrl = url
                        stream.obsWebSocketPassword = wizardObsRemoteControlPassword.trim()
                        stream.obsSourceName = wizardObsRemoteControlSourceName.trim()
                    }
                }
            }
        }
        switch wizardPlatform {
        case .twitch:
            stream.twitchEnabled = true
            stream.twitchChannelName = wizardTwitchChannelName.trim()
            stream.twitchChannelId = wizardTwitchChannelId.trim()
        case .kick:
            stream.kickEnabled = true
            stream.kickChannelName = wizardKickChannelName.trim()
        case .youTube:
            if !wizardYouTubeApiKey.isEmpty, !wizardYouTubeVideoId.isEmpty {
                stream.youTubeEnabled = true
                stream.youTubeApiKey = wizardYouTubeApiKey.trim()
                stream.youTubeVideoId = wizardYouTubeVideoId.trim()
            }
        case .afreecaTv:
            if !wizardAfreecaTvChannelName.isEmpty, !wizardAfreecsTvCStreamId.isEmpty {
                stream.afreecaTvEnabled = true
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
            switch wizardCustomProtocol {
            case .none:
                stream.codec = .h264avc
            case .srt:
                stream.codec = .h265hevc
            case .rtmp:
                stream.codec = .h264avc
            }
        case .obs:
            stream.codec = .h265hevc
        case .belaboxCloudObs:
            stream.codec = .h265hevc
        case .direct:
            stream.codec = .h264avc
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
        wizardKickChannelName = ""
        wizardYouTubeApiKey = ""
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

    func handleSettingsUrlsInWizard(settings: MoblinSettingsUrl) {
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
        case .direct:
            break
        }
    }
}

extension Model {
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            let bluetoothOption: AVAudioSession.CategoryOptions
            if database.debug!.bluetoothOutputOnly! {
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
        mic = newMic
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
        return mics
    }

    private func setMic() {
        var wantedOrientation: AVAudioSession.Orientation
        switch database.mic! {
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

    func selectMicById(id: String) {
        guard let mic = listMics().first(where: { mic in mic.id == id }) else {
            logger.info("Mic with id \(id) not found")
            makeErrorToast(
                title: String(localized: "Mic not found"),
                subTitle: String(localized: "Mic id \(id)")
            )
            return
        }
        if let builtInOrientation = mic.builtInOrientation {
            database.mic = builtInOrientation
            store()
        }
        selectMic(mic: mic)
    }

    private func selectMic(mic: Mic) {
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
            self.mic = mic
            remoteControlStreamer?.stateChanged(state: RemoteControlState(mic: mic.id))
        } catch {
            logger.error("Failed to select mic: \(error)")
            makeErrorToast(
                title: String(localized: "Failed to select mic"),
                subTitle: error.localizedDescription
            )
        }
    }

    private func setBuiltInMicAudioMode(dataSource: AVAudioSessionDataSourceDescription) throws {
        if false, dataSource.supportedPolarPatterns?.contains(.stereo) == true {
            try dataSource.setPreferredPolarPattern(.stereo)
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

    func isRealtimeIrlConfigured() -> Bool {
        return stream.realtimeIrlEnabled! && !stream.realtimeIrlPushKey!.isEmpty
    }

    func reloadRealtimeIrl() {
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
            lines: drawOnStreamLines
        )
        media.registerEffect(drawOnStreamEffect)
    }

    func drawOnStreamWipe() {
        drawOnStreamLines = []
        drawOnStreamEffect.updateOverlay(
            videoSize: media.getVideoSize(),
            size: drawOnStreamSize,
            lines: drawOnStreamLines
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
            lines: drawOnStreamLines
        )
        if drawOnStreamLines.isEmpty {
            media.unregisterEffect(drawOnStreamEffect)
        }
    }
}
