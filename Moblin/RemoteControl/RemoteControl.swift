import AVFoundation
import CoreLocation
import CryptoKit
import Foundation
import WeatherKit

let remoteControlApiVersion = "0.1"

class RemoteControlStartStatusFilter: Codable {
    var topRight: Bool = true
}

enum RemoteControlRequest: Codable {
    case getStatus
    case getSettings
    case setRecord(on: Bool)
    case setLive(on: Bool)
    case setPreviewStream(on: Bool)
    case setZoom(x: Float)
    case setZoomPreset(id: UUID)
    case setMute(on: Bool)
    case setStealthMode(on: Bool)
    case setTorch(on: Bool)
    case setDebugLogging(on: Bool)
    case setStream(id: UUID)
    case setScene(id: UUID)
    case setAutoSceneSwitcher(id: UUID?)
    case setBitratePreset(id: UUID)
    case setMic(id: String)
    case setTalkbackMic(id: String)
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
    case getScoreboardSports
    case setScoreboardSport(sportId: String)
    case updateScoreboard(config: RemoteControlScoreboardMatchConfig)
    case toggleScoreboardClock
    case setScoreboardDuration(minutes: Int)
    case setScoreboardClock(time: String)
    case whip(url: String, method: String, headers: [SettingsHttpHeader], body: Data)
    case setFilter(filter: RemoteControlFilter, on: Bool)
    case triggerReaction(reaction: RemoteControlReaction)
    case moveToGimbalPreset(id: UUID)
    case getGolfScoreboard
    case updateGolfScoreboard(data: RemoteControlGolfScoreboard)
}

enum RemoteControlResponse: Codable {
    case getStatus(
        general: RemoteControlStatusGeneral?,
        topLeft: RemoteControlStatusTopLeft,
        topRight: RemoteControlStatusTopRight
    )
    case getSettings(data: RemoteControlSettings)
    case getScoreboardSports(names: [String])
    case whip(status: Int, headers: [SettingsHttpHeader], body: Data)
    case getGolfScoreboard(data: RemoteControlGolfScoreboard)
}

enum RemoteControlEvent: Codable {
    case state(data: RemoteControlAssistantStreamerState)
    case log(entry: String)
    case status(general: RemoteControlStatusGeneral?,
                topLeft: RemoteControlStatusTopLeft?,
                topRight: RemoteControlStatusTopRight?)
    case scoreboard(config: RemoteControlScoreboardMatchConfig)
    case golfScoreboard(data: RemoteControlGolfScoreboard)
    case telemetry(data: TelemetryData)
}

struct TelemetryData: Codable {
    var speed: Double
    var averageSpeed: Double
    var altitude: Double
    var latitude: Double?
    var longitude: Double?
    var distance: Double
    var splitDistance: Double
    var slopePercent: Double
    var altitudeAscent: Double
    var altitudeDescent: Double
    var splitAltitudeAscent: Double
    var splitAltitudeDescent: Double
    var temperature: Double?
    var feelsLikeTemperature: Double?
    var windSpeed: Double?
    var windGust: Double?
    var country: String?
    var countryFlag: String?
    var state: String?
    var area: String?
    var city: String?
    var neighborhood: String?
    var heartRates: [String: Int?]
    var activeEnergyBurned: Int?
    var workoutDistance: Int?
    var power: Int?
    var stepCount: Int?
    var cyclingPower: Int
    var cyclingCadence: Int
}

struct RemoteControlChatMessage: Codable {
    let id: Int
    let platform: Platform
    let messageId: String?
    let displayName: String?
    let user: String?
    let userId: String?
    let userColor: RgbColor?
    let userBadges: [URL]
    let segments: [ChatPostSegment]
    let timestamp: String
    let isAction: Bool
    let isModerator: Bool
    let isSubscriber: Bool
    let isOwner: Bool
    let bits: String?
}

enum RemoteControlReaction: Codable, CaseIterable {
    case fireworks
    case balloons
    case hearts
    case confetti
    case lasers
    case rain
    case glasses
    case sparkle

    func toSettings() -> SettingsReaction {
        switch self {
        case .fireworks:
            .fireworks
        case .balloons:
            .balloons
        case .hearts:
            .hearts
        case .confetti:
            .confetti
        case .lasers:
            .lasers
        case .rain:
            .rain
        case .glasses:
            .glasses
        case .sparkle:
            .sparkle
        }
    }
}

enum RemoteControlFilter: Codable, CaseIterable {
    case pixellate
    case movie
    case grayScale
    case sepia
    case triple
    case twin
    case fourThree
    case crt
    case pinch
    case whirlpool
    case poll
    case blurFaces
    case privacy
    case beauty
    case moblinInMouth
    case cameraMan

    init?(type: SettingsQuickButtonType) {
        switch type {
        case .pixellate:
            self = .pixellate
        case .movie:
            self = .movie
        case .grayScale:
            self = .grayScale
        case .sepia:
            self = .sepia
        case .triple:
            self = .triple
        case .twin:
            self = .twin
        case .fourThree:
            self = .fourThree
        case .crt:
            self = .crt
        case .pinch:
            self = .pinch
        case .whirlpool:
            self = .whirlpool
        case .poll:
            self = .poll
        case .blurFaces:
            self = .blurFaces
        case .privacy:
            self = .privacy
        case .beauty:
            self = .beauty
        case .moblinInMouth:
            self = .moblinInMouth
        case .cameraMan:
            self = .cameraMan
        default:
            return nil
        }
    }

    func toSettings() -> SettingsQuickButtonType {
        switch self {
        case .pixellate:
            .pixellate
        case .movie:
            .movie
        case .grayScale:
            .grayScale
        case .sepia:
            .sepia
        case .triple:
            .triple
        case .twin:
            .twin
        case .fourThree:
            .fourThree
        case .crt:
            .crt
        case .pinch:
            .pinch
        case .whirlpool:
            .whirlpool
        case .poll:
            .poll
        case .blurFaces:
            .blurFaces
        case .privacy:
            .privacy
        case .beauty:
            .beauty
        case .moblinInMouth:
            .moblinInMouth
        case .cameraMan:
            .cameraMan
        }
    }

    func toString() -> String {
        switch self {
        case .pixellate:
            String(localized: "Pixellate")
        case .movie:
            String(localized: "Movie")
        case .grayScale:
            String(localized: "Gray scale")
        case .sepia:
            String(localized: "Sepia")
        case .triple:
            String(localized: "Triple")
        case .twin:
            String(localized: "Twin")
        case .fourThree:
            String(localized: "4:3")
        case .crt:
            String(localized: "CRT")
        case .pinch:
            String(localized: "Pinch")
        case .whirlpool:
            String(localized: "Whirlpool")
        case .poll:
            String(localized: "Poll")
        case .blurFaces:
            String(localized: "Blur faces")
        case .privacy:
            String(localized: "Blur background")
        case .beauty:
            String(localized: "Beauty")
        case .moblinInMouth:
            String(localized: "Moblin in mouth")
        case .cameraMan:
            String(localized: "Camera man")
        }
    }
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

struct RemoteControlRemoteSceneSettingsSceneWidgetLayout: Codable {
    let x: Double
    let y: Double
    let size: Double
    let alignment: SettingsAlignment
}

struct RemoteControlRemoteSceneSettingsSceneWidget: Codable {
    let id: UUID
    let layout: RemoteControlRemoteSceneSettingsSceneWidgetLayout

    init(widget: SettingsSceneWidget) {
        id = widget.widgetId
        layout = RemoteControlRemoteSceneSettingsSceneWidgetLayout(x: widget.layout.x,
                                                                   y: widget.layout.y,
                                                                   size: widget.layout.size,
                                                                   alignment: widget.layout.alignment)
    }

    func toSettings() -> SettingsSceneWidget {
        let widget = SettingsSceneWidget(widgetId: id)
        widget.layout.x = layout.x
        widget.layout.y = layout.y
        widget.layout.size = layout.size
        widget.layout.alignment = layout.alignment
        return widget
    }
}

struct RemoteControlRemoteSceneSettingsWidget: Codable {
    let id: UUID
    let enabled: Bool
    let type: RemoteControlRemoteSceneSettingsWidgetType

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
        case .slideshow:
            return nil
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
        case .chatEmoteCombo:
            return nil
        case .wheelOfLuck:
            return nil
        case .bingoCard:
            return nil
        case .pomodoroTimer:
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
    let url: String
    let width: Int
    let height: Int
    let mode: SettingsWidgetBrowserMode
    let fps: Float
    let styleSheet: String

    init(browser: SettingsWidgetBrowser) {
        url = browser.url
        width = browser.width
        height = browser.height
        mode = browser.mode
        fps = browser.baseFps
        styleSheet = browser.styleSheet
    }

    func toSettings() -> SettingsWidgetBrowser {
        let browser = SettingsWidgetBrowser()
        browser.url = url
        browser.width = width
        browser.height = height
        browser.mode = mode
        browser.baseFps = fps
        browser.styleSheet = styleSheet
        return browser
    }
}

struct RemoteControlRemoteSceneSettingsWidgetTypeText: Codable {
    let formatString: String
    let backgroundColor: RgbColor
    let clearBackgroundColor: Bool
    let foregroundColor: RgbColor
    let clearForegroundColor: Bool
    let fontSize: Int
    let fontFamily: String?
    let fontStyle: String?
    let fontDesign: SettingsFontDesign
    let fontWeight: SettingsFontWeight
    let fontMonospacedDigits: Bool
    let horizontalAlignment: RemoteControlRemoteSceneSettingsHorizontalAlignment
    let delay: Double

    init(text: SettingsWidgetText) {
        formatString = text.formatString
        backgroundColor = text.backgroundColor
        clearBackgroundColor = text.clearBackgroundColor
        foregroundColor = text.foregroundColor
        clearForegroundColor = text.clearForegroundColor
        fontSize = text.fontSize
        fontFamily = text.fontFamily
        fontStyle = text.fontStyle
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
        text.fontFamily = fontFamily ?? ""
        text.fontStyle = fontStyle ?? ""
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
    case center

    init(alignment: SettingsHorizontalAlignment) {
        switch alignment {
        case .leading:
            self = .leading
        case .trailing:
            self = .trailing
        case .center:
            self = .center
        }
    }

    func toSettings() -> SettingsHorizontalAlignment {
        switch self {
        case .leading:
            .leading
        case .trailing:
            .trailing
        case .center:
            .center
        }
    }
}

struct RemoteControlRemoteSceneSettingsWidgetTypeMap: Codable {
    let northUp: Bool

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
    let sceneId: UUID

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
    let bitrate: String
    let bitrateAndTotal: String
    let resolution: String?
    let fps: Int?
    let date: Date
    let debugOverlayLines: [String]
    let speed: Double
    let averageSpeed: Double
    let altitude: Double
    let distance: Double
    let splitDistance: Double
    let altitudeAscent: Double
    let altitudeDescent: Double
    let splitAltitudeAscent: Double
    let splitAltitudeDescent: Double
    let slope: String
    let conditions: String?
    let temperature: Measurement<UnitTemperature>?
    let feelsLikeTemperature: Measurement<UnitTemperature>?
    let windSpeed: Measurement<UnitSpeed>?
    let windGust: Measurement<UnitSpeed>?
    let country: String?
    let countryFlag: String?
    let state: String?
    let area: String?
    let city: String?
    let neighborhood: String?
    let muted: Bool
    let heartRates: [String: Int?]
    let activeEnergyBurned: Int?
    let workoutDistance: Int?
    let power: Int?
    let stepCount: Int?
    let teslaBatteryLevel: String
    let teslaDrive: String
    let teslaMedia: String
    let cyclingPower: String
    let cyclingCadence: String
    let runningMetrics: [String: WorkoutDeviceRunningMetrics]
    let browserTitle: String
    let gForce: GForce?
    let latestSubscriber: String
    let latestFollower: String

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
        splitDistance = stats.splitDistance
        altitudeAscent = stats.altitudeAscent
        altitudeDescent = stats.altitudeDescent
        splitAltitudeAscent = stats.splitAltitudeAscent
        splitAltitudeDescent = stats.splitAltitudeDescent
        slope = stats.slope
        conditions = stats.conditions
        temperature = stats.temperature
        feelsLikeTemperature = stats.feelsLikeTemperature
        windSpeed = stats.windSpeed
        windGust = stats.windGust
        country = stats.country
        countryFlag = stats.countryFlag
        state = stats.state
        area = stats.area
        city = stats.city
        neighborhood = stats.neighborhood
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
        runningMetrics = stats.runningMetrics
        browserTitle = stats.browserTitle
        gForce = stats.gForce
        latestSubscriber = stats.latestSubscriber
        latestFollower = stats.latestFollower
    }

    func toStats() -> TextEffectStats {
        TextEffectStats(timestamp: .now,
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
                        splitDistance: splitDistance,
                        altitudeAscent: altitudeAscent,
                        altitudeDescent: altitudeDescent,
                        splitAltitudeAscent: splitAltitudeAscent,
                        splitAltitudeDescent: splitAltitudeDescent,
                        slope: slope,
                        conditions: conditions,
                        temperature: temperature,
                        feelsLikeTemperature: feelsLikeTemperature,
                        windSpeed: windSpeed,
                        windGust: windGust,
                        country: country,
                        countryFlag: countryFlag,
                        state: state,
                        area: area,
                        city: city,
                        neighborhood: neighborhood,
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
                        runningMetrics: runningMetrics,
                        browserTitle: browserTitle,
                        gForce: gForce,
                        latestSubscriber: latestSubscriber,
                        latestFollower: latestFollower)
    }
}

struct RemoteControlRemoteSceneDataLocation: Codable {
    let latitude: Double
    let longitude: Double

    init(location: CLLocation) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
    }

    func toLocation() -> CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
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
            .fair
        case .yellow:
            .serious
        case .red:
            .critical
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
            .nan
        case .unknown:
            .infinity
        case let .value(value):
            value
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

struct RemoteControlSettingsStream: Codable, Identifiable {
    let id: UUID
    let name: String
}

struct RemoteControlSettingsScene: Codable, Identifiable {
    let id: UUID
    let name: String
}

struct RemoteControlSettingsAutoSceneSwitcher: Codable, Identifiable {
    let id: UUID
    let name: String
}

struct RemoteControlSettingsBitratePreset: Codable, Identifiable {
    let id: UUID
    let bitrate: UInt32
}

struct RemoteControlSettingsMic: Codable, Identifiable {
    let id: String
    let name: String
}

struct RemoteControlSettingsSrtConnectionPriority: Codable, Identifiable {
    let id: UUID
    let name: String
    var priority: Int
    var enabled: Bool
}

struct RemoteControlSettingsSrt: Codable {
    let connectionPrioritiesEnabled: Bool
    let connectionPriorities: [RemoteControlSettingsSrtConnectionPriority]
}

struct RemoteControlSettingsGimbalPreset: Codable, Identifiable {
    let id: UUID
    let name: String
}

struct RemoteControlSettings: Codable {
    var streams: [RemoteControlSettingsStream]
    var scenes: [RemoteControlSettingsScene]
    var autoSceneSwitchers: [RemoteControlSettingsAutoSceneSwitcher]?
    var bitratePresets: [RemoteControlSettingsBitratePreset]
    var mics: [RemoteControlSettingsMic]
    var srt: RemoteControlSettingsSrt
    var gimbalPresets: [RemoteControlSettingsGimbalPreset]
}

struct RemoteControlStateAutoSceneSwitcher: Codable {
    let id: UUID?
}

struct RemoteControlZoomPreset: Codable, Identifiable {
    let id: UUID
    let name: String
}

struct RemoteControlAssistantStreamerState: Codable {
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
    var previewStream: Bool?
    var muted: Bool?
    var stealthMode: Bool?
    var torchOn: Bool?
    var batteryCharging: Bool?
    var filters: [RemoteControlFilter: Bool]?
}

struct RemoteControlScoreboardControl: Codable {
    var type: String
    var label: String
    var options: [String]?
    var periodReset: Bool?
}

struct RemoteControlScoreboardTeam: Codable {
    var name: String
    var bgColor: String
    var textColor: String = "#ffffff"
    var possession: Bool
    var primaryScore: String = "0"
    var secondaryScore: String = ""
    var secondaryScoreLabel: String? = ""
    var secondaryScore1: String?
    var secondaryScore2: String?
    var secondaryScore3: String?
    var secondaryScore4: String?
    var secondaryScore5: String?
    var stat1: String = ""
    var stat1Label: String = ""
    var stat2: String = ""
    var stat2Label: String = ""
    var stat3: String = ""
    var stat3Label: String = ""
    var stat4: String = ""
    var stat4Label: String = ""
}

struct RemoteControlScoreboardGlobalStats: Codable {
    var title: String
    var timer: String
    var timerDirection: String
    var duration: Int?
    var period: String
    var periodLabel: String
    var infoBoxText: String = ""
    var primaryScoreResetOnPeriod: Bool
    var changePossessionOnScore: Bool
    var scoringMode: String?
    var showTitle: Bool?
    var showStats: Bool?
    var showMoreStats: Bool?
    var showClock: Bool?

    func minutesAndSeconds() -> (Int, Int) {
        clockAsMinutesAndSeconds(clock: timer)
    }
}

struct RemoteControlScoreboardMatchConfig: Codable {
    var sportId: String
    var layout: String
    var team1: RemoteControlScoreboardTeam
    var team2: RemoteControlScoreboardTeam
    var global: RemoteControlScoreboardGlobalStats
    var controls: [String: RemoteControlScoreboardControl]

    func periodFull() -> String {
        switch sportId {
        case "football":
            return ""
        default:
            break
        }
        return "\(global.periodLabel) \(global.period)".trim()
    }

    func infoBoxStats(showClock: Bool) -> [String] {
        if showClock {
            [global.timer, periodFull(), global.infoBoxText].filter { !$0.isEmpty }
        } else {
            [periodFull(), global.infoBoxText].filter { !$0.isEmpty }
        }
    }
}

struct RemoteControlGolfPlayer: Codable {
    let name: String
    let scores: [Int]
    let color: RgbColor
}

struct RemoteControlGolfScoreboard: Codable {
    let title: String
    let numberOfHoles: Int
    let pars: [Int]
    let currentHole: Int
    let players: [RemoteControlGolfPlayer]
    let playerColors: Bool

    enum CodingKeys: CodingKey {
        case title
        case numberOfHoles
        case pars
        case currentHole
        case players
        case playerColors
    }

    init(title: String,
         numberOfHoles: Int,
         pars: [Int], currentHole: Int,
         players: [RemoteControlGolfPlayer],
         playerColors: Bool)
    {
        self.title = title
        self.numberOfHoles = numberOfHoles
        self.pars = pars
        self.currentHole = currentHole
        self.players = players
        self.playerColors = playerColors
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        numberOfHoles = try container.decode(Int.self, forKey: .numberOfHoles)
        pars = try container.decode([Int].self, forKey: .pars)
        currentHole = try container.decode(Int.self, forKey: .currentHole)
        players = try container.decode([RemoteControlGolfPlayer].self, forKey: .players)
        playerColors = try container.decode(Bool.self, forKey: .playerColors)
    }
}

struct RemoteControlAuthentication: Codable {
    let challenge: String
    let salt: String
}

enum RemoteControlResult: Codable {
    case ok
    case wrongPassword
    case unknownRequest
    case notIdentified
    case alreadyIdentified
    case error
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
    case identify(streamerId: String?, authentication: String)
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
        try? AES.GCM.seal(data, using: key).combined
    }

    func decrypt(data: Data) -> Data? {
        guard let sealedBox = try? AES.GCM.SealedBox(combined: data) else {
            return nil
        }
        return try? AES.GCM.open(sealedBox, using: key)
    }
}
