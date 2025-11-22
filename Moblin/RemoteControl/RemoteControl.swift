import CoreLocation
import CryptoKit
import Foundation

let remoteControlApiVersion = "0.1"

class RemoteControlStartStatusFilter: Codable {
    var topRight: Bool = true
}

enum RemoteControlRequest: Codable {
    case getStatus
    case getSettings
    case setRecord(on: Bool)
    case setStream(on: Bool)
    case setZoom(x: Float)
    case setZoomPreset(id: UUID)
    case setMute(on: Bool)
    case setTorch(on: Bool)
    case setDebugLogging(on: Bool)
    case setScene(id: UUID)
    case setAutoSceneSwitcher(id: UUID?)
    case setBitratePreset(id: UUID)
    case setMic(id: String)
    case setSrtConnectionPriority(id: UUID, priority: Int, enabled: Bool)
    case setSrtConnectionPrioritiesEnabled(enabled: Bool)
    case reloadBrowserWidgets
    case twitchEventSubNotification(message: String)
    case startPreview
    case stopPreview
    case chatMessages(history: Bool, messages: [RemoteControlChatMessage])
    case setRemoteSceneSettings(data: RemoteControlRemoteSceneSettings)
    case setRemoteSceneData(data: RemoteControlRemoteSceneData)
    case instantReplay
    case saveReplay
    case startStatus(interval: Int, filter: RemoteControlStartStatusFilter)
    case stopStatus
}

enum RemoteControlResponse: Codable {
    case getStatus(
        general: RemoteControlStatusGeneral?,
        topLeft: RemoteControlStatusTopLeft,
        topRight: RemoteControlStatusTopRight
    )
    case getSettings(data: RemoteControlSettings)
}

enum RemoteControlEvent: Codable {
    case state(data: RemoteControlState)
    case log(entry: String)
    case mediaShareSegmentReceived(fileId: UUID)
    case status(general: RemoteControlStatusGeneral?,
                topLeft: RemoteControlStatusTopLeft?,
                topRight: RemoteControlStatusTopRight?)
}

struct RemoteControlChatMessage: Codable {
    var id: Int
    var platform: Platform
    var messageId: String?
    var displayName: String?
    var user: String?
    var userId: String?
    var userColor: RgbColor?
    var userBadges: [URL]
    var segments: [ChatPostSegment]
    var timestamp: String
    var isAction: Bool
    var isModerator: Bool
    var isSubscriber: Bool
    var isOwner: Bool
    var bits: String?
}

struct RemoteControlRemoteSceneSettings: Codable {
    var scenes: [RemoteControlRemoteSceneSettingsScene]
    var widgets: [RemoteControlRemoteSceneSettingsWidget]
    var selectedSceneId: UUID?

    init(scenes: [SettingsScene], widgets: [SettingsWidget], selectedSceneId: UUID?) {
        self.scenes = scenes.map { RemoteControlRemoteSceneSettingsScene(scene: $0) }
        self.widgets = []
        for widget in widgets {
            guard let widget = RemoteControlRemoteSceneSettingsWidget(widget: widget) else {
                continue
            }
            self.widgets.append(widget)
        }
        self.selectedSceneId = selectedSceneId
    }

    func toSettings() -> ([SettingsScene], [SettingsWidget], UUID?) {
        let scenes = scenes.map { $0.toSettings() }
        let widgets = widgets.map { $0.toSettings() }
        return (scenes, widgets, selectedSceneId)
    }
}

struct RemoteControlRemoteSceneSettingsScene: Codable {
    var id: UUID
    var widgets: [RemoteControlRemoteSceneSettingsSceneWidget]

    init(scene: SettingsScene) {
        id = scene.id
        widgets = scene.widgets.map { RemoteControlRemoteSceneSettingsSceneWidget(widget: $0) }
    }

    func toSettings() -> SettingsScene {
        let scene = SettingsScene(name: "")
        scene.id = id
        scene.widgets = widgets.map { $0.toSettings() }
        return scene
    }
}

struct RemoteControlRemoteSceneSettingsSceneWidget: Codable {
    var id: UUID
    var x: Double
    var y: Double
    var size: Double

    init(widget: SettingsSceneWidget) {
        id = widget.widgetId
        x = widget.layout.x
        y = widget.layout.y
        size = widget.layout.size
    }

    func toSettings() -> SettingsSceneWidget {
        let widget = SettingsSceneWidget(widgetId: id)
        widget.layout.x = x
        widget.layout.y = y
        widget.layout.size = size
        return widget
    }
}

struct RemoteControlRemoteSceneSettingsWidget: Codable {
    var id: UUID
    var enabled: Bool
    var type: RemoteControlRemoteSceneSettingsWidgetType

    init?(widget: SettingsWidget) {
        id = widget.id
        enabled = widget.enabled
        switch widget.type {
        case .browser:
            type = .browser(data: RemoteControlRemoteSceneSettingsWidgetTypeBrowser(browser: widget.browser))
        case .image:
            return nil
        case .text:
            type = .text(data: RemoteControlRemoteSceneSettingsWidgetTypeText(text: widget.text))
        case .crop:
            return nil
        case .map:
            type = .map(data: RemoteControlRemoteSceneSettingsWidgetTypeMap(map: widget.map))
        case .scene:
            type = .scene(data: RemoteControlRemoteSceneSettingsWidgetTypeScene(scene: widget.scene))
        case .qrCode:
            return nil
        case .alerts:
            return nil
        case .videoSource:
            return nil
        case .scoreboard:
            return nil
        case .vTuber:
            return nil
        case .pngTuber:
            return nil
        case .snapshot:
            return nil
        case .chat:
            return nil
        }
    }

    func toSettings() -> SettingsWidget {
        let widget = SettingsWidget(name: "")
        widget.id = id
        widget.enabled = enabled
        switch type {
        case let .browser(data):
            widget.type = .browser
            widget.browser = data.toSettings()
        case let .text(data):
            widget.type = .text
            widget.text = data.toSettings()
        case let .map(data):
            widget.type = .map
            widget.map = data.toSettings()
        case let .scene(data):
            widget.type = .scene
            widget.scene = data.toSettings()
        }
        return widget
    }
}

enum RemoteControlRemoteSceneSettingsWidgetType: Codable {
    case browser(data: RemoteControlRemoteSceneSettingsWidgetTypeBrowser)
    case text(data: RemoteControlRemoteSceneSettingsWidgetTypeText)
    case map(data: RemoteControlRemoteSceneSettingsWidgetTypeMap)
    case scene(data: RemoteControlRemoteSceneSettingsWidgetTypeScene)
}

struct RemoteControlRemoteSceneSettingsWidgetTypeBrowser: Codable {
    var url: String
    var width: Int
    var height: Int
    var audioOnly: Bool
    var fps: Float
    var styleSheet: String

    init(browser: SettingsWidgetBrowser) {
        url = browser.url
        width = browser.width
        height = browser.height
        audioOnly = browser.audioOnly
        fps = browser.fps
        styleSheet = browser.styleSheet
    }

    func toSettings() -> SettingsWidgetBrowser {
        let browser = SettingsWidgetBrowser()
        browser.url = url
        browser.width = width
        browser.height = height
        browser.audioOnly = audioOnly
        browser.fps = fps
        browser.styleSheet = styleSheet
        return browser
    }
}

struct RemoteControlRemoteSceneSettingsWidgetTypeText: Codable {
    var formatString: String
    var backgroundColor: RgbColor
    var clearBackgroundColor: Bool
    var foregroundColor: RgbColor
    var clearForegroundColor: Bool
    var fontSize: Int
    var fontDesign: SettingsFontDesign
    var fontWeight: SettingsFontWeight
    var fontMonospacedDigits: Bool
    var horizontalAlignment: RemoteControlRemoteSceneSettingsHorizontalAlignment
    var delay: Double

    init(text: SettingsWidgetText) {
        formatString = text.formatString
        backgroundColor = text.backgroundColor
        clearBackgroundColor = text.clearBackgroundColor
        foregroundColor = text.foregroundColor
        clearForegroundColor = text.clearForegroundColor
        fontSize = text.fontSize
        fontDesign = text.fontDesign
        fontWeight = text.fontWeight
        fontMonospacedDigits = text.fontMonospacedDigits
        horizontalAlignment = .init(alignment: text.horizontalAlignment)
        delay = text.delay
    }

    func toSettings() -> SettingsWidgetText {
        let text = SettingsWidgetText()
        text.formatString = formatString
        text.backgroundColor = backgroundColor
        text.clearBackgroundColor = clearBackgroundColor
        text.foregroundColor = foregroundColor
        text.clearForegroundColor = clearForegroundColor
        text.fontSize = fontSize
        text.fontDesign = fontDesign
        text.fontWeight = fontWeight
        text.fontMonospacedDigits = fontMonospacedDigits
        text.horizontalAlignment = horizontalAlignment.toSettings()
        text.delay = delay
        return text
    }
}

enum RemoteControlRemoteSceneSettingsHorizontalAlignment: Codable {
    case leading
    case trailing

    init(alignment: SettingsHorizontalAlignment) {
        switch alignment {
        case .leading:
            self = .leading
        case .trailing:
            self = .trailing
        }
    }

    func toSettings() -> SettingsHorizontalAlignment {
        switch self {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        }
    }
}

struct RemoteControlRemoteSceneSettingsWidgetTypeMap: Codable {
    var northUp: Bool

    init(map: SettingsWidgetMap) {
        northUp = map.northUp
    }

    func toSettings() -> SettingsWidgetMap {
        let map = SettingsWidgetMap()
        map.northUp = northUp
        return map
    }
}

struct RemoteControlRemoteSceneSettingsWidgetTypeScene: Codable {
    var sceneId: UUID

    init(scene: SettingsWidgetScene) {
        sceneId = scene.sceneId
    }

    func toSettings() -> SettingsWidgetScene {
        let scene = SettingsWidgetScene()
        scene.sceneId = sceneId
        return scene
    }
}

struct RemoteControlRemoteSceneData: Codable {
    var textStats: RemoteControlRemoteSceneDataTextStats?
    var location: RemoteControlRemoteSceneDataLocation?
}

struct RemoteControlRemoteSceneDataTextStats: Codable {
    var bitrate: String
    var bitrateAndTotal: String
    var resolution: String?
    var fps: Int?
    var date: Date
    var debugOverlayLines: [String]
    var speed: String
    var averageSpeed: String
    var altitude: String
    var distance: String
    var slope: String
    var conditions: String?
    var temperature: Measurement<UnitTemperature>?
    var country: String?
    var countryFlag: String?
    var state: String?
    var city: String?
    var muted: Bool
    var heartRates: [String: Int?]
    var activeEnergyBurned: Int?
    var workoutDistance: Int?
    var power: Int?
    var stepCount: Int?
    var teslaBatteryLevel: String
    var teslaDrive: String
    var teslaMedia: String
    var cyclingPower: String
    var cyclingCadence: String
    var browserTitle: String
    var gForce: GForce?

    init(stats: TextEffectStats) {
        bitrate = stats.bitrate
        bitrateAndTotal = stats.bitrateAndTotal
        resolution = stats.resolution
        fps = stats.fps
        date = stats.date
        debugOverlayLines = stats.debugOverlayLines
        speed = stats.speed
        averageSpeed = stats.averageSpeed
        altitude = stats.altitude
        distance = stats.distance
        slope = stats.slope
        conditions = stats.conditions
        temperature = stats.temperature
        country = stats.country
        countryFlag = stats.countryFlag
        state = stats.state
        city = stats.city
        muted = stats.muted
        heartRates = stats.heartRates
        activeEnergyBurned = stats.activeEnergyBurned
        workoutDistance = stats.workoutDistance
        power = stats.power
        stepCount = stats.stepCount
        teslaBatteryLevel = stats.teslaBatteryLevel
        teslaDrive = stats.teslaDrive
        teslaMedia = stats.teslaMedia
        cyclingPower = stats.cyclingPower
        cyclingCadence = stats.cyclingCadence
        browserTitle = stats.browserTitle
    }

    func toStats() -> TextEffectStats {
        return TextEffectStats(timestamp: .now,
                               bitrate: bitrate,
                               bitrateAndTotal: bitrateAndTotal,
                               resolution: resolution,
                               fps: fps,
                               date: date,
                               debugOverlayLines: debugOverlayLines,
                               speed: speed,
                               averageSpeed: averageSpeed,
                               altitude: altitude,
                               distance: distance,
                               slope: slope,
                               conditions: conditions,
                               temperature: temperature,
                               country: country,
                               countryFlag: countryFlag,
                               state: state,
                               city: city,
                               muted: muted,
                               heartRates: heartRates,
                               activeEnergyBurned: activeEnergyBurned,
                               workoutDistance: workoutDistance,
                               power: power,
                               stepCount: stepCount,
                               teslaBatteryLevel: teslaBatteryLevel,
                               teslaDrive: teslaDrive,
                               teslaMedia: teslaMedia,
                               cyclingPower: cyclingPower,
                               cyclingCadence: cyclingCadence,
                               browserTitle: browserTitle,
                               gForce: gForce)
    }
}

struct RemoteControlRemoteSceneDataLocation: Codable {
    var latitude: Double
    var longitude: Double

    init(location: CLLocation) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
    }

    func toLocation() -> CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
}

struct RemoteControlStatusItem: Codable {
    var message: String
    var ok: Bool = true
}

enum RemoteControlStatusGeneralFlame: String, Codable {
    case white = "White"
    case yellow = "Yellow"
    case red = "Red"

    func toThermalState() -> ProcessInfo.ThermalState {
        switch self {
        case .white:
            return .fair
        case .yellow:
            return .serious
        case .red:
            return .critical
        }
    }
}

enum RemoteControlStatusTopRightAudioLevel: Codable {
    case muted
    case unknown
    case value(Float)

    func toFloat() -> Float {
        switch self {
        case .muted:
            return .nan
        case .unknown:
            return .infinity
        case let .value(value):
            return value
        }
    }
}

struct RemoteControlStatusTopRightAudioInfo: Codable {
    var audioLevel: RemoteControlStatusTopRightAudioLevel
    var numberOfAudioChannels: Int
}

struct RemoteControlStatusGeneral: Codable {
    var batteryCharging: Bool?
    var batteryLevel: Int?
    var flame: RemoteControlStatusGeneralFlame?
    var wiFiSsid: String?
    var isLive: Bool?
    var isRecording: Bool?
    var isMuted: Bool?
}

struct RemoteControlStatusTopLeft: Codable {
    var stream: RemoteControlStatusItem?
    var camera: RemoteControlStatusItem?
    var mic: RemoteControlStatusItem?
    var zoom: RemoteControlStatusItem?
    var obs: RemoteControlStatusItem?
    var events: RemoteControlStatusItem?
    var chat: RemoteControlStatusItem?
    var viewers: RemoteControlStatusItem?
}

struct RemoteControlStatusTopRight: Codable {
    var audioInfo: RemoteControlStatusTopRightAudioInfo?
    var audioLevel: RemoteControlStatusItem?
    var rtmpServer: RemoteControlStatusItem?
    var remoteControl: RemoteControlStatusItem?
    var gameController: RemoteControlStatusItem?
    var bitrate: RemoteControlStatusItem?
    var uptime: RemoteControlStatusItem?
    var location: RemoteControlStatusItem?
    var srtla: RemoteControlStatusItem?
    var srtlaRtts: RemoteControlStatusItem?
    var recording: RemoteControlStatusItem?
    var replay: RemoteControlStatusItem?
    var browserWidgets: RemoteControlStatusItem?
    var moblink: RemoteControlStatusItem?
    var djiDevices: RemoteControlStatusItem?
    var systemMonitor: RemoteControlStatusItem?
}

struct RemoteControlSettingsScene: Codable, Identifiable {
    var id: UUID
    var name: String
}

struct RemoteControlSettingsAutoSceneSwitcher: Codable, Identifiable {
    var id: UUID
    var name: String
}

struct RemoteControlSettingsBitratePreset: Codable, Identifiable {
    var id: UUID
    var bitrate: UInt32
}

struct RemoteControlSettingsMic: Codable, Identifiable {
    var id: String
    var name: String
}

struct RemoteControlSettingsSrtConnectionPriority: Codable, Identifiable {
    var id: UUID
    var name: String
    var priority: Int
    var enabled: Bool
}

struct RemoteControlSettingsSrt: Codable {
    var connectionPrioritiesEnabled: Bool
    var connectionPriorities: [RemoteControlSettingsSrtConnectionPriority]
}

struct RemoteControlSettings: Codable {
    var scenes: [RemoteControlSettingsScene]
    var autoSceneSwitchers: [RemoteControlSettingsAutoSceneSwitcher]?
    var bitratePresets: [RemoteControlSettingsBitratePreset]
    var mics: [RemoteControlSettingsMic]
    var srt: RemoteControlSettingsSrt
}

struct RemoteControlStateAutoSceneSwitcher: Codable {
    var id: UUID?
}

struct RemoteControlZoomPreset: Codable, Identifiable {
    var id: UUID
    var name: String
}

struct RemoteControlState: Codable {
    var scene: UUID?
    var autoSceneSwitcher: RemoteControlStateAutoSceneSwitcher?
    var mic: String?
    var bitrate: UUID?
    var zoom: Float?
    var zoomPresets: [RemoteControlZoomPreset]?
    var zoomPreset: UUID?
    var debugLogging: Bool?
    var streaming: Bool?
    var recording: Bool?
    var muted: Bool?
    var torchOn: Bool?
    var batteryCharging: Bool?
}

struct RemoteControlAuthentication: Codable {
    var challenge: String
    var salt: String
}

enum RemoteControlResult: Codable {
    case ok
    case wrongPassword
    case unknownRequest
    case notIdentified
    case alreadyIdentified
}

enum RemoteControlMessageToStreamer: Codable {
    case hello(apiVersion: String, authentication: RemoteControlAuthentication)
    case identified(result: RemoteControlResult)
    case request(id: Int, data: RemoteControlRequest)
    case pong

    func toJson() -> String? {
        do {
            return try String(bytes: JSONEncoder().encode(self), encoding: .utf8)
        } catch {
            return nil
        }
    }

    static func fromJson(data: String) throws -> RemoteControlMessageToStreamer {
        guard let data = data.data(using: .utf8) else {
            throw "Not a UTF-8 string"
        }
        return try JSONDecoder().decode(RemoteControlMessageToStreamer.self, from: data)
    }
}

enum RemoteControlMessageToAssistant: Codable {
    case identify(authentication: String)
    case response(id: Int, result: RemoteControlResult, data: RemoteControlResponse?)
    case event(data: RemoteControlEvent)
    case preview(preview: Data)
    case twitchStart(channelName: String?, channelId: String, accessToken: String)
    case ping

    func toJson() throws -> String {
        guard let encoded = try String(bytes: JSONEncoder().encode(self), encoding: .utf8) else {
            throw "Encode failed"
        }
        return encoded
    }

    static func fromJson(data: String) throws -> RemoteControlMessageToAssistant {
        guard let data = data.data(using: .utf8) else {
            throw "Not a UTF-8 string"
        }
        return try JSONDecoder().decode(RemoteControlMessageToAssistant.self, from: data)
    }
}

func remoteControlHashPassword(challenge: String, salt: String, password: String) -> String {
    var concatenated = "\(password)\(salt)"
    var hash = Data(SHA256.hash(data: Data(concatenated.utf8)))
    concatenated = "\(hash.base64EncodedString())\(challenge)"
    hash = Data(SHA256.hash(data: Data(concatenated.utf8)))
    return hash.base64EncodedString()
}

class RemoteControlEncryption {
    private let key: SymmetricKey

    init(password: String) {
        key = SymmetricKey(data: Data(SHA256.hash(data: password.utf8Data)))
    }

    func encrypt(data: Data) -> Data? {
        return try? AES.GCM.seal(data, using: key).combined
    }

    func decrypt(data: Data) -> Data? {
        guard let sealedBox = try? AES.GCM.SealedBox(combined: data) else {
            return nil
        }
        return try? AES.GCM.open(sealedBox, using: key)
    }
}
