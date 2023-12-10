import AlertToast
import Collections
import Combine
import CoreMotion
import HaishinKit
import Logboard
import Network
import PhotosUI
import SDWebImageSwiftUI
import SDWebImageWebPCoder
import SRTHaishinKit
import StoreKit
import SwiftUI
import TwitchChat
import VideoToolbox

private let noValue = ""
private let maximumNumberOfChatMessages = 50
private let secondsSuffix = String(localized: "/sec")

struct Camera {
    var type: SettingsCameraType
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

private let productsIds = [
    "AppIconKing",
    "AppIconQueen",
    "AppIconGoblin",
    "AppIconGoblina",
    "AppIconMillionaire",
    "AppIconBillionaire",
    "AppIconTrillionaire",
]

private let globalIconsNotYetInStore = [
    Icon(name: "Looking", id: "AppIconLooking", price: ""),
    Icon(name: "Heart", id: "AppIconHeart", price: ""),
    Icon(name: "Basque", id: "AppIconBasque", price: ""),
    Icon(name: "Tetris", id: "AppIconTetris", price: ""),
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

struct ChatPost: Identifiable, Hashable {
    static func == (lhs: ChatPost, rhs: ChatPost) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var id: Int
    var user: String?
    var userColor: String?
    var segments: [ChatPostSegment]
    var timestamp: String
    var timestampDate: Date
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

    @Published var bias: Float = 0.0
    @Published var showingSettings = false
    @Published var settingsLayout: SettingsLayout = .right
    @Published var showChatMessages = true
    @Published var chatPaused = false
    @Published var audioGenerator = "Off"
    @Published var squareWaveGeneratorAmplitude = 200.0
    @Published var squareWaveGeneratorInterval = 60.0
    @Published var blackScreen = false
    private var streaming = false
    @Published var mic = noMic
    private var micChange = noMic
    private var streamStartDate: Date?
    @Published var isLive = false
    private var subscriptions = Set<AnyCancellable>()
    @Published var uptime = noValue
    @Published var srtlaConnectionStatistics = noValue
    @Published var audioLevel: Float = -160.0
    var settings = Settings()
    @Published var digitalClock = noValue
    var selectedSceneId = UUID()
    private var twitchChat: TwitchChatMoblin!
    private var twitchPubSub: TwitchPubSub?
    private var kickPusher: KickPusher?
    private var youTubeLiveChat: YouTubeLiveChat?
    private var afreecaTvChat: AfreecaTvChat?
    private var obsWebSocket: ObsWebSocket?
    private var chatPostId = 0
    @Published var chatPosts: Deque<ChatPost> = []
    private var pausedChatPosts: Deque<ChatPost> = []
    private var newChatPosts: Deque<ChatPost> = []
    private var numberOfChatPostsPerTick = 0
    private var chatPostsRatePerSecond = 0.0
    private var chatPostsRatePerMinute = 0.0
    private var numberOfChatPostsPerMinute = 0
    @Published var chatPostsRate = String(localized: "0.0/min")
    @Published var chatPostsTotal: Int = 0
    private var chatSpeedTicks = 0
    @Published var numberOfViewers = noValue
    var numberOfViewersUpdateDate = Date()
    @Published var batteryLevel = Double(UIDevice.current.batteryLevel)
    @Published var speedAndTotal = noValue
    @Published var thermalState = ProcessInfo.processInfo.thermalState
    var videoView = PiPHKView(frame: .zero)
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
    @Published var showingObsScene = false
    @Published var obsScenes: [String] = []
    @Published var obsCurrentScene: String = ""
    @Published var obsCurrentSceneStatus: String = ""
    var obsStreaming = false
    var obsRecording = false
    @Published var iconImage: String = plainIcon.id
    @Published var manualFocusPoint: CGPoint?
    @Published var backZoomPresetId = UUID()
    @Published var frontZoomPresetId = UUID()
    @Published var zoomX: Float = 1.0
    var zoomXPinch: Float = 1.0
    private var backZoomX: Float = 0.5
    private var frontZoomX: Float = 1.0
    var cameraPosition: AVCaptureDevice.Position?
    var secondCameraPosition: AVCaptureDevice.Position?
    private let motionManager = CMMotionManager()
    private var manualFocusAttitude: CMAttitude?
    var database: Database {
        settings.database
    }

    var cameraDevice: AVCaptureDevice?
    var cameraZoomLevelToXScale: Float = 1.0
    var cameraZoomXMinimum: Float = 1.0
    var cameraZoomXMaximum: Float = 1.0
    var secondCameraDevice: AVCaptureDevice?
    @Published var srtDebugLines: [String] = []

    var backCameras: [Camera] = []
    var frontCameras: [Camera] = []

    init() {
        settings.load()
    }

    var stream: SettingsStream {
        for stream in database.streams where stream.enabled {
            return stream
        }
        return SettingsStream(name: "")
    }

    private let networkPathMonitor = NWPathMonitor()

    var enabledScenes: [SettingsScene] {
        database.scenes.filter { scene in scene.enabled }
    }

    @Published var myIcons: [Icon] = []
    @Published var iconsInStore: [Icon] = []
    @Published var iconsNotYetInStore = globalIconsNotYetInStore
    private var appStoreUpdateListenerTask: Task<Void, Error>?
    private var products: [String: Product] = [:]

    func setAdaptiveBitratePacketsInFlight(value: Int32) {
        adaptiveBitratePacketsInFlightLimit = value
    }

    func getAdaptiveBitratePacketsInFlight() -> Int32 {
        return adaptiveBitratePacketsInFlightLimit
    }

    @MainActor
    private func getProductsFromAppStore() async {
        do {
            let products = try await Product.products(for: productsIds)
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
        var myIconsIds: [String] = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = checkVerified(result: result) else {
                logger.info("cosmetics: Verification failed for my product")
                continue
            }
            myIconsIds.append(transaction.productID)
        }
        var myIcons = globalMyIcons
        var iconsInStore: [Icon] = []
        for productId in productsIds {
            guard let product = products[productId] else {
                logger.info("cosmetics: Product \(productId) not found")
                continue
            }
            if myIconsIds.contains(productId) {
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

    func purchaseIcon(id: String) async throws {
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

    func setAudioGenerator(generator: String) {
        switch generator {
        case "Off":
            audioGeneratorMode = .off
        case "Square wave":
            audioGeneratorMode = .squareWave
        default:
            logger.error("Bad audio generator \(generator)")
        }
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

    func formatLog() -> String {
        var data = "Version: \(version())\n"
        data += "Debug: \(logger.debugEnabled)\n\n"
        data += log.map { e in e.message }.joined(separator: "\n")
        return data
    }

    func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                options: [.mixWithOthers, .allowBluetooth]
            )
            try session.setActive(true)
        } catch {
            logger.error("app: Session error \(error)")
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
        }
        let session = AVAudioSession.sharedInstance()
        for inputPort in session.availableInputs ?? [] {
            if inputPort.portType != .builtInMic {
                continue
            }
            if let dataSources = inputPort.dataSources, !dataSources.isEmpty {
                for dataSource in dataSources
                    where dataSource.orientation == wantedOrientation
                {
                    do {
                        try inputPort.setPreferredDataSource(dataSource)
                    } catch {
                        logger
                            .error(
                                "Failed to set bottom mic as preferred with error \(error)"
                            )
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
                        try session.setInputDataSource(dataSource)
                    }
                }
            }
            self.mic = mic
        } catch {
            logger.error("Failed to select mic: \(error)")
            makeErrorToast(
                title: String(localized: "Failed to select mic"),
                subTitle: error.localizedDescription
            )
        }
    }

    func isObsConfigured() -> Bool {
        return stream.obsWebSocketUrl != "" && stream.obsWebSocketPassword != ""
    }

    func isObsConnected() -> Bool {
        return obsWebSocket?.isConnected() ?? false
    }

    func listObsScenes() {
        obsCurrentScene = ""
        obsScenes = []
        obsWebSocket?.getSceneList(onSuccess: { list in
            DispatchQueue.main.async {
                self.obsCurrentScene = list.current
                self.obsScenes = list.scenes
            }
        }, onError: {
            DispatchQueue.main.async {
                self.makeErrorToast(title: String(localized: "Failed to fetch OBS scenes"))
            }
        })
    }

    func setObsScene(name: String) {
        obsWebSocket?.setCurrentProgramScene(name: name, onSuccess: {
            DispatchQueue.main.async {
                self.makeToast(title: String(localized: "OBS scene set to \(name)"))
                self.obsCurrentSceneStatus = name
            }
        }, onError: {
            DispatchQueue.main.async {
                self.makeErrorToast(title: String(localized: "Failed to set OBS scene to \(name)"))
            }
        })
    }

    private func updateObsStatus() {
        guard isObsConnected() else {
            return
        }
        obsWebSocket?.getSceneList(onSuccess: { list in
            DispatchQueue.main.async {
                self.obsCurrentSceneStatus = list.current
            }
        }, onError: {
            DispatchQueue.main.async {
                self.obsCurrentSceneStatus = "Unknown"
            }
        })
        obsWebSocket?.getStreamStatus(onSuccess: { status in
            DispatchQueue.main.async {
                self.obsStreaming = status.active
            }
        }, onError: {
            DispatchQueue.main.async {
                self.obsStreaming = false
            }
        })
        obsWebSocket?.getRecordStatus(onSuccess: { status in
            DispatchQueue.main.async {
                self.obsRecording = status.active
            }
        }, onError: {
            DispatchQueue.main.async {
                self.obsRecording = false
            }
        })
    }

    func setup() {
        let WebPCoder = SDImageWebPCoder.shared
        SDImageCodersManager.shared.addCoder(WebPCoder)
        UIDevice.current.isBatteryMonitoringEnabled = true
        backCameras = listCameras(position: .back)
        if !backCameras.contains(where: { $0.type == database.backCameraType! }) {
            database.backCameraType = backCameras.first?.type ?? .dual
            store()
        }
        frontCameras = listCameras(position: .front)
        if !frontCameras.contains(where: { $0.type == database.frontCameraType! }) {
            database.frontCameraType = frontCameras.first?.type ?? .dual
            store()
        }
        updateBatteryLevel()
        media.onSrtConnected = handleSrtConnected
        media.onSrtDisconnected = handleSrtDisconnected
        media.onRtmpConnected = handleRtmpConnected
        media.onRtmpDisconnected = handleRtmpDisconnected
        media.onAudioMuteChange = updateAudioLevel
        media.onVideoDeviceInUseByAnotherClient = handleVideoDeviceInUseByAnotherClient
        setupAudioSession()
        setMic()
        if let cameraDevice = preferredCamera(position: .back) {
            (cameraZoomXMinimum, cameraZoomXMaximum) = cameraDevice
                .getUIZoomRange(hasUltraWideCamera: hasUltraWideCamera())
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
        if database.maximumScreenFpsEnabled {
            videoView.fps = Double(database.maximumScreenFps)
        }
        logger.handler = debugLog(message:)
        logger.debugEnabled = database.debug!.logLevel == .debug
        let appender = LogAppender()
        LBLogger.with("com.haishinkit.HaishinKit").appender = appender
        LBLogger.with("com.haishinkit.SRTHaishinKit").appender = appender
        LBLogger.with("com.haishinkit.HaishinKit").level = .debug
        LBLogger.with("com.haishinkit.SRTHaishinKit").level = .debug
        updateDigitalClock(now: Date())
        twitchChat = TwitchChatMoblin(model: self)
        reloadStream()
        resetSelectedScene()
        setupPeriodicTimers()
        setupThermalState()
        updateButtonStates()
        removeUnusedImages()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        networkPathMonitor.pathUpdateHandler = handleNetworkPathUpdate(path:)
        networkPathMonitor.start(queue: DispatchQueue.main)
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
                                                   handleWillEnterForegroundNotification
                                               ),
                                               name: UIApplication
                                                   .willEnterForegroundNotification,
                                               object: nil)
        updateOrientation()
    }

    @objc func handleWillEnterForegroundNotification() {
        reloadConnections()
    }

    private func listCameras(position: AVCaptureDevice.Position) -> [Camera] {
        let deviceDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInTripleCamera,
                .builtInDualCamera,
                .builtInDualWideCamera,
                .builtInUltraWideCamera,
                .builtInWideAngleCamera,
                .builtInTelephotoCamera,
            ],
            mediaType: .video,
            position: position
        )
        return deviceDiscovery.devices.map { device in
            switch device.deviceType {
            case .builtInTripleCamera:
                return Camera(type: .triple, name: device.localizedName)
            case .builtInDualCamera:
                return Camera(type: .dual, name: device.localizedName)
            case .builtInDualWideCamera:
                return Camera(type: .dualWide, name: device.localizedName)
            case .builtInUltraWideCamera:
                return Camera(type: .ultraWide, name: device.localizedName)
            case .builtInWideAngleCamera:
                return Camera(type: .wide, name: device.localizedName)
            case .builtInTelephotoCamera:
                return Camera(type: .telephoto, name: device.localizedName)
            default:
                fatalError("Bad camera")
            }
        }
    }

    deinit {
        appStoreUpdateListenerTask?.cancel()
    }

    private func handleNetworkPathUpdate(path: NWPath) {
        logger
            .debug("Network: \(path.debugDescription), All: \(path.availableInterfaces)")
    }

    private func updateOrientation() {
        switch UIDevice.current.orientation {
        case .landscapeLeft:
            if videoView.videoOrientation != .landscapeRight {
                videoView.videoOrientation = .landscapeRight
            }
        case .landscapeRight:
            if videoView.videoOrientation != .landscapeLeft {
                videoView.videoOrientation = .landscapeLeft
            }
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
                let query = try MoblinSettingsUrl.fromString(query: query)
                var streamCount = 0
                for stream in query.streams ?? [] {
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
            } catch {
                logger.error("Failed to import URL with error: \(error)")
                makeErrorToast(
                    title: String(localized: "URL import failed"),
                    subTitle: error.localizedDescription
                )
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
            if !self.database.show.audioBar {
                self.updateAudioLevel()
            }
            self.updateSrtlaConnectionStatistics()
            self.removeOldChatMessages(now: now)
        })
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true, block: { _ in
            self.updateBatteryLevel()
            self.media.logStatistics()
            self.media.logAudioStatistics()
            self.updateObsStatus()
        })
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { _ in
            self.updateSrtDebugLines()
            if self.database.show.audioBar {
                self.updateAudioLevel()
            }
            self.updateChat()
        })
        takeBrowserSnapshots()
    }

    private func updateSrtDebugLines() {
        if let lines = media.getSrtStats(overlay: database.debug!.srtOverlay) {
            srtDebugLines = lines
        } else if !srtDebugLines.isEmpty {
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
        if newAudioLevel == audioLevel {
            return
        }
        if abs(audioLevel - newAudioLevel) > 5 || newAudioLevel
            .isNaN || newAudioLevel == .infinity || audioLevel.isNaN || audioLevel == .infinity
        {
            audioLevel = newAudioLevel
        }
    }

    private func updateSrtlaConnectionStatistics() {
        if isStreamConnceted(), let statistics = media.srtlaConnectionStatistics() {
            srtlaConnectionStatistics = statistics
        } else if srtlaConnectionStatistics != noValue {
            srtlaConnectionStatistics = noValue
        }
    }

    private func removeOldChatMessages(now: Date) {
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
            return
        }
        while let post = newChatPosts.popFirst() {
            if chatPosts.count > maximumNumberOfChatMessages - 1 {
                chatPosts.removeFirst()
            }
            chatPosts.append(post)
            numberOfChatPostsPerTick += 1
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
            break
        case .random:
            videoEffects[widget.id] = RandomEffect()
        case .triple:
            videoEffects[widget.id] = TripleEffect()
        case .noiseReduction:
            videoEffects[widget.id] = NoiseReductionEffect()
        }
    }

    func resetSelectedScene(changeScene: Bool = true) {
        if !enabledScenes.isEmpty && changeScene {
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
                fontSize: 40
            )
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
                for sceneWidget in scene.widgets
                    where sceneWidget.widgetId == widget.id
                {
                    let videoSize = media.getVideoSize()
                    browserEffects[sceneWidget.id] = BrowserEffect(
                        url: URL(string: widget.browser.url)!,
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

    func setMaximumScreenFps(fps: Int) {
        database.maximumScreenFps = fps
        store()
        videoView.fps = Double(fps)
    }

    func setMaximumScreenFpsEnabled(value: Bool) {
        database.maximumScreenFpsEnabled = value
        store()
        if value {
            videoView.fps = Double(database.maximumScreenFps)
        } else {
            videoView.fps = nil
        }
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
            payloadSize = stream.srt.mpegtsPacketsPerPacket * 188
            media.srtStartStream(
                isSrtla: stream.isSrtla(),
                url: stream.url,
                reconnectTime: reconnectTime,
                targetBitrate: stream.bitrate,
                adaptiveBitrate: stream.adaptiveBitrate,
                latency: stream.srt.latency,
                overheadBandwidth: database.debug!.srtOverheadBandwidth!,
                mpegtsPacketsPerPacket: stream.srt.mpegtsPacketsPerPacket
            )
        }
        updateSpeed()
    }

    private func stopNetStream() {
        reconnectTimer?.invalidate()
        media.rtmpStopStream()
        media.srtStopStream()
        streamStartDate = nil
        updateUptime(now: Date())
        updateSpeed()
        updateAudioLevel()
        srtlaConnectionStatistics = noValue
        makeStreamEndedToast()
    }

    func reloadStream() {
        cameraPosition = nil
        stopStream()
        setNetStream()
        setStreamResolution()
        setStreamFPS()
        setStreamCodec()
        setStreamKeyFrameInterval()
        setStreamBitrate(stream: stream)
        reloadConnections()
        resetChat()
    }

    private func reloadConnections() {
        reloadTwitchChat()
        reloadTwitchPubSub()
        reloadKickPusher()
        reloadYouTubeLiveChat()
        reloadAfreecaTvChat()
        reloadObsWebSocket()
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
    }

    private func showPreset(preset: SettingsZoomPreset) -> Bool {
        let x = preset.x!
        return x >= cameraZoomXMinimum && x <= cameraZoomXMaximum
    }

    func backZoomPresets() -> [SettingsZoomPreset] {
        return database.zoom.back.filter { showPreset(preset: $0) }
    }

    private func getPreset(preset: AVCaptureSession.Preset) -> AVCaptureSession.Preset {
        if logger.debugEnabled && stream.captureSessionPresetEnabled {
            switch stream.captureSessionPreset {
            case .high:
                return .high
            case .medium:
                return .medium
            case .low:
                return .low
            case .hd1280x720:
                return .hd1280x720
            case .hd1920x1080:
                return .hd1920x1080
            case .hd4K3840x2160:
                return .hd4K3840x2160
            case .vga640x480:
                return .vga640x480
            case .iFrame960x540:
                return .iFrame960x540
            case .iFrame1280x720:
                return .iFrame1280x720
            case .cif352x288:
                return .cif352x288
            }
        } else {
            return preset
        }
    }

    private func setStreamResolution() {
        switch stream.resolution {
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

    func setStreamBitrate(stream: SettingsStream) {
        media.setVideoStreamBitrate(bitrate: stream.bitrate)
    }

    private func setStreamCodec() {
        switch stream.codec {
        case .h264avc:
            media.setVideoProfile(profile: kVTProfileLevel_H264_High_AutoLevel)
        case .h265hevc:
            media.setVideoProfile(profile: kVTProfileLevel_HEVC_Main_AutoLevel)
        }
    }

    private func setStreamKeyFrameInterval() {
        media.setStreamKeyFrameInterval(seconds: stream.maxKeyFrameInterval!)
    }

    func isChatConfigured() -> Bool {
        return isTwitchChatConfigured() || isKickPusherConfigured() ||
            isYouTubeLiveChatConfigured() || isAfreecaTvChatConfigured()
    }

    func isViewersConfigured() -> Bool {
        return stream.twitchChannelId != ""
    }

    func isTwitchChatConfigured() -> Bool {
        return stream.twitchChannelName != ""
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
        return stream.kickChatroomId != ""
    }

    func isKickPusherConnected() -> Bool {
        return kickPusher?.isConnected() ?? false
    }

    func hasKickPusherEmotes() -> Bool {
        return kickPusher?.hasEmotes() ?? false
    }

    func isYouTubeLiveChatConfigured() -> Bool {
        return stream.youTubeApiKey! != "" && stream.youTubeVideoId! != ""
    }

    func isYouTubeLiveChatConnected() -> Bool {
        return youTubeLiveChat?.isConnected() ?? false
    }

    func hasYouTubeLiveChatEmotes() -> Bool {
        return youTubeLiveChat?.hasEmotes() ?? false
    }

    func isAfreecaTvChatConfigured() -> Bool {
        return stream.afreecaTvChannelName! != "" && stream.afreecaTvStreamId! != ""
    }

    func isAfreecaTvChatConnected() -> Bool {
        return afreecaTvChat?.isConnected() ?? false
    }

    func hasAfreecaTvChatEmotes() -> Bool {
        return afreecaTvChat?.hasEmotes() ?? false
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
        return true
    }

    func hasChatEmotes() -> Bool {
        return hasTwitchChatEmotes() || hasKickPusherEmotes() ||
            hasYouTubeLiveChatEmotes() || hasAfreecaTvChatEmotes()
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
    }

    private func reloadTwitchChat() {
        twitchChat.stop()
        if isTwitchChatConfigured() {
            twitchChat.start(
                channelName: stream.twitchChannelName,
                channelId: stream.twitchChannelId
            )
        } else {
            logger.info("Twitch channel name not configured. No Twitch chat.")
        }
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
        if isKickPusherConfigured() {
            kickPusher = KickPusher(model: self, channelId: stream.kickChatroomId)
            kickPusher!.start()
        } else {
            logger.info("Kick chatroom id not configured. No Kick chat.")
        }
    }

    private func reloadYouTubeLiveChat() {
        youTubeLiveChat?.stop()
        youTubeLiveChat = nil
        if isYouTubeLiveChatConfigured() {
            youTubeLiveChat = YouTubeLiveChat(
                model: self,
                apiKey: stream.youTubeApiKey!,
                videoId: stream.youTubeVideoId!
            )
            youTubeLiveChat!.start()
        } else {
            logger.info("YouTube chat id not configured. No YouTube chat.")
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
        } else {
            logger.info("AfreecaTV chat id not configured. No AfreecaTV chat.")
        }
    }

    private func reloadObsWebSocket() {
        obsWebSocket?.stop()
        obsWebSocket?.onSceneChanged = nil
        obsWebSocket?.onStreamStatusChanged = nil
        obsWebSocket?.onRecordStatusChanged = nil
        obsWebSocket = nil
        guard isObsConfigured() else {
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
        obsWebSocket!.onSceneChanged = { name in
            DispatchQueue.main.async {
                self.obsCurrentSceneStatus = name
            }
        }
        obsWebSocket!.onStreamStatusChanged = { active in
            DispatchQueue.main.async {
                self.obsStreaming = active
            }
        }
        obsWebSocket!.onRecordStatusChanged = { active in
            DispatchQueue.main.async {
                self.obsRecording = active
            }
        }
        obsWebSocket!.start()
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

    func kickChatroomIdUpdated() {
        reloadKickPusher()
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

    func afreecaTvChannelNameUpdated() {
        reloadAfreecaTvChat()
        resetChat()
    }

    func afreecaTvStreamIdUpdated() {
        reloadAfreecaTvChat()
        resetChat()
    }

    func obsWebSocketUrlUpdated() {
        reloadObsWebSocket()
    }

    func obsWebSocketPasswordUpdated() {
        reloadObsWebSocket()
    }

    private func appendChatPost(post: ChatPost) {
        appendChatMessage(user: post.user,
                          userColor: post.userColor,
                          segments: post.segments,
                          timestamp: post.timestamp,
                          timestampDate: post.timestampDate)
    }

    func appendChatMessage(
        user: String?,
        userColor: String?,
        segments: [ChatPostSegment],
        timestamp: String,
        timestampDate: Date
    ) {
        let post = ChatPost(
            id: chatPostId,
            user: user,
            userColor: userColor,
            segments: segments,
            timestamp: timestamp,
            timestampDate: timestampDate
        )
        chatPostId += 1
        if chatPaused {
            if pausedChatPosts.count > maximumNumberOfChatMessages - 1 {
                pausedChatPosts.removeFirst()
            }
            pausedChatPosts.append(post)
        } else {
            if newChatPosts.count > maximumNumberOfChatMessages - 1 {
                newChatPosts.removeFirst()
            }
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

    func toggleChatPaused() {
        chatPaused.toggle()
        if chatPaused {
            return
        }
        chatPosts = chatPosts.filter { post in
            post.user != nil
        }
        if !chatPosts.isEmpty {
            appendChatPost(post: chatPosts.popLast()!)
        }
        if !pausedChatPosts.isEmpty {
            appendChatMessage(
                user: nil,
                userColor: nil,
                segments: [],
                timestamp: "",
                timestampDate: Date()
            )
        }
        for post in pausedChatPosts {
            appendChatPost(post: post)
        }
        pausedChatPosts = []
        updateChat()
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

    private func attachSingleLayout(scene: SettingsScene) {
        switch scene.cameraPosition! {
        case .back:
            attachCamera(position: .back)
        case .front:
            attachCamera(position: .front)
        }
    }

    private func attachPipLayout(scene: SettingsScene) {
        switch scene.cameraPosition! {
        case .back:
            attachCamera(position: .back, secondPosition: .front)
        case .front:
            attachCamera(position: .front, secondPosition: .back)
        }
    }

    private func sceneUpdatedOn(scene: SettingsScene) {
        switch scene.cameraLayout! {
        case .single:
            attachSingleLayout(scene: scene)
        case .pip:
            attachPipLayout(scene: scene)
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
                            .noiseReductionNoiseLevel
                        noiseReductionEffect.sharpness = widget.videoEffect
                            .noiseReductionSharpness
                    } else if videoEffect is RandomEffect {
                        videoEffect = RandomEffect()
                        videoEffects[widget.id] = videoEffect
                    }
                    media.registerEffect(videoEffect)
                }
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
        } else if uptime != noValue {
            uptime = noValue
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

    private func updateSpeed() {
        if isLive {
            let speed = formatBytesPerSecond(speed: media.streamSpeed())
            let total = sizeFormatter.string(fromByteCount: media.streamTotal())
            speedAndTotal = String(localized: "\(speed) (\(total))")
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

    func reattachCamera() {
        media.attachCamera(device: nil, secondDevice: nil, videoStabilizationMode: .off)
        media.attachCamera(
            device: cameraDevice,
            secondDevice: secondCameraDevice,
            videoStabilizationMode: getVideoStabilizationMode()
        )
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
        ) || hasCameraChanged(
            oldCameraDevice: secondCameraDevice,
            oldPosition: secondCameraPosition,
            newPosition: secondPosition
        ) else {
            return
        }
        setAutoFocus()
        cameraDevice = preferredCamera(position: position)
        cameraZoomLevelToXScale = cameraDevice?
            .getZoomFactorScale(hasUltraWideCamera: hasUltraWideCamera()) ?? 1.0
        (cameraZoomXMinimum, cameraZoomXMaximum) = cameraDevice?
            .getUIZoomRange(hasUltraWideCamera: hasUltraWideCamera()) ?? (
                1.0,
                1.0
            )
        if let secondPosition {
            secondCameraDevice = preferredCamera(position: secondPosition)
        } else {
            secondCameraDevice = nil
        }
        var isMirrored = false
        cameraPosition = position
        if let secondPosition {
            secondCameraPosition = secondPosition
        } else {
            secondCameraPosition = nil
        }
        switch position {
        case .back:
            if database.zoom.switchToBack.enabled {
                clearZoomId()
                backZoomX = database.zoom.switchToBack.x!
            }
            zoomX = backZoomX
            isMirrored = false
        case .front:
            if database.zoom.switchToFront.enabled {
                clearZoomId()
                frontZoomX = database.zoom.switchToFront.x!
            }
            zoomX = frontZoomX
            isMirrored = true
        default:
            break
        }
        media.attachCamera(
            device: cameraDevice,
            secondDevice: secondCameraDevice,
            videoStabilizationMode: getVideoStabilizationMode(),
            onSuccess: {
                self.videoView.isMirrored = isMirrored
                if let x = self.setCameraZoomX(x: self.zoomX) {
                    self.zoomX = x
                }
                if let device = self.cameraDevice {
                    self.setMaxAutoExposure(device: device)
                }
            }
        )
        zoomXPinch = zoomX
    }

    private func setCameraZoomX(x: Float, rate: Float? = nil) -> Float? {
        let level = media.setCameraZoomLevel(level: x / cameraZoomLevelToXScale, rate: rate)
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

    private func rtmpStartStream() {
        media.rtmpStartStream(url: stream.url)
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
        if setPinch {
            zoomXPinch = zoomX
        }
    }

    func changeZoomX(amount: Float) {
        clearZoomId()
        if let x = setCameraZoomX(x: zoomXPinch * amount) {
            setZoomX(x: x, setPinch: false)
        }
    }

    func commitZoomX(amount: Float) {
        clearZoomId()
        if let x = setCameraZoomX(x: zoomXPinch * amount) {
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

    private func makeGoingLiveToast() {
        makeToast(title: String(localized: "😎 Going live at \(stream.name) 😎"))
    }

    private func makeYouAreLiveToast() {
        makeToast(title: String(localized: "🎉 You are LIVE at \(stream.name) 🎉"))
    }

    private func makeStreamEndedToast() {
        makeToast(title: String(localized: "🤟 Stream ended 🤟"))
    }

    private func makeFffffToast(reason: String) {
        makeErrorToast(
            title: String(localized: "😢 FFFFF 😢"),
            font: .system(size: 64).bold(),
            subTitle: reason
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
            // device.exposurePointOfInterest = focusPoint
            // device.exposureMode = .autoExpose
            device.unlockForConfiguration()
            manualFocusPoint = focusPoint
            startMotionDetection()
        } catch let error as NSError {
            logger.error("while locking device for focusPointOfInterest: \(error)")
        }
    }

    func setAutoFocus() {
        if manualFocusPoint == nil {
            return
        }
        stopMotionDetection()
        guard
            let device = cameraDevice, device.isFocusPointOfInterestSupported
        else {
            logger.warning("Tap to focus not supported for this camera")
            makeErrorToast(title: String(localized: "Tap to focus not supported for this camera"))
            return
        }
        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            device.focusMode = .continuousAutoFocus
            // device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
            // device.exposureMode = .continuousAutoExposure
            device.unlockForConfiguration()
            manualFocusPoint = nil
        } catch let error as NSError {
            logger.error("while locking device for focusPointOfInterest: \(error)")
        }
    }

    private func startMotionDetection() {
        motionManager.stopDeviceMotionUpdates()
        manualFocusAttitude = nil
        motionManager.deviceMotionUpdateInterval = 0.2
        motionManager.startDeviceMotionUpdates(to: OperationQueue.main) { data, _ in
            guard let data else {
                return
            }
            let attitude = data.attitude
            if self.manualFocusAttitude == nil {
                self.manualFocusAttitude = attitude
            }
            if diffAngles(attitude.pitch, self.manualFocusAttitude!.pitch) > 10 {
                self.setAutoFocus()
            } else if diffAngles(attitude.roll, self.manualFocusAttitude!.roll) > 10 {
                self.setAutoFocus()
            } else if diffAngles(attitude.yaw, self.manualFocusAttitude!.yaw) > 10 {
                self.setAutoFocus()
            }
        }
    }

    private func stopMotionDetection() {
        motionManager.stopDeviceMotionUpdates()
    }

    func preferredCamera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        var cameraType: SettingsCameraType
        if position == .back {
            cameraType = database.backCameraType!
        } else {
            cameraType = database.frontCameraType!
        }
        var deviceType: AVCaptureDevice.DeviceType
        switch cameraType {
        case .triple:
            deviceType = .builtInTripleCamera
        case .dual:
            deviceType = .builtInDualCamera
        case .dualWide:
            deviceType = .builtInDualWideCamera
        case .ultraWide:
            deviceType = .builtInUltraWideCamera
        case .wide:
            deviceType = .builtInWideAngleCamera
        case .telephoto:
            deviceType = .builtInTelephotoCamera
        }
        if let device = AVCaptureDevice.default(deviceType, for: .video, position: position) {
            return device
        }
        logger.error("No camera")
        return nil
    }

    private func hasUltraWideCamera() -> Bool {
        return AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil
    }

    private func factorToX(position: AVCaptureDevice.Position, factor: Float) -> Float {
        if position == .back && hasUltraWideCamera() {
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
}
