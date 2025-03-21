import CryptoKit
import Foundation

let remoteControlApiVersion = "0.1"

enum RemoteControlRequest: Codable {
    case getStatus
    case getSettings
    case setRecord(on: Bool)
    case setStream(on: Bool)
    case setZoom(x: Float)
    case setMute(on: Bool)
    case setTorch(on: Bool)
    case setDebugLogging(on: Bool)
    case setScene(id: UUID)
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
}

struct RemoteControlChatMessage: Codable {
    var id: Int
    var platform: Platform
    var user: String?
    var userId: String?
    var userColor: RgbColor?
    var userBadges: [URL]
    var segments: [ChatPostSegment]
    var timestamp: String
    var isAction: Bool
    var isModerator: Bool
    var isSubscriber: Bool
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
        return (scenes.map { $0.toSettings() }, widgets.map { $0.toSettings() }, selectedSceneId)
    }
}

struct RemoteControlRemoteSceneSettingsScene: Codable {
    var id: UUID
    var widgets: [RemoteControlRemoteSceneSettingsSceneWidget]

    init(scene: SettingsScene) {
        id = scene.id
        widgets = scene.widgets.map { RemoteControlRemoteSceneSettingsSceneWidget(
            id: $0.widgetId,
            x: $0.x,
            y: $0.y,
            width: $0.width,
            height: $0.height
        ) }
    }

    func toSettings() -> SettingsScene {
        let scene = SettingsScene(name: "")
        scene.id = id
        for widget in widgets {
            let settingsSceneWidget = SettingsSceneWidget(widgetId: widget.id)
            settingsSceneWidget.x = widget.x
            settingsSceneWidget.y = widget.y
            settingsSceneWidget.width = widget.width
            settingsSceneWidget.height = widget.height
            scene.widgets.append(settingsSceneWidget)
        }
        return scene
    }
}

struct RemoteControlRemoteSceneSettingsSceneWidget: Codable {
    var id: UUID
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

struct RemoteControlRemoteSceneSettingsWidget: Codable {
    var id: UUID
    var enabled: Bool
    var type: RemoteControlRemoteSceneSettingsWidgetType

    init?(widget: SettingsWidget) {
        id = widget.id
        enabled = widget.enabled!
        switch widget.type {
        case .browser:
            type = .browser(data: RemoteControlRemoteSceneSettingsWidgetTypeBrowser(browser: widget.browser))
        case .image:
            return nil
        case .text:
            type = .text(data: RemoteControlRemoteSceneSettingsWidgetTypeText(text: widget.text))
        case .videoEffect:
            return nil
        case .crop:
            return nil
        case .map:
            return nil
        case .scene:
            type = .scene(data: RemoteControlRemoteSceneSettingsWidgetTypeScene(sceneId: widget.scene!.sceneId))
        case .qrCode:
            return nil
        case .alerts:
            return nil
        case .videoSource:
            return nil
        case .scoreboard:
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
        case let .scene(data):
            widget.type = .scene
            widget.scene!.sceneId = data.sceneId
        }
        return widget
    }
}

enum RemoteControlRemoteSceneSettingsWidgetType: Codable {
    case browser(data: RemoteControlRemoteSceneSettingsWidgetTypeBrowser)
    case text(data: RemoteControlRemoteSceneSettingsWidgetTypeText)
    case scene(data: RemoteControlRemoteSceneSettingsWidgetTypeScene)
}

struct RemoteControlRemoteSceneSettingsWidgetTypeBrowser: Codable {
    var url: String
    var width: Int
    var height: Int
    var audioOnly: Bool
    var scaleToFitVideo: Bool
    var fps: Float
    var styleSheet: String

    init(browser: SettingsWidgetBrowser) {
        url = browser.url
        width = browser.width
        height = browser.height
        audioOnly = browser.audioOnly!
        scaleToFitVideo = browser.scaleToFitVideo!
        fps = browser.fps!
        styleSheet = browser.styleSheet!
    }

    func toSettings() -> SettingsWidgetBrowser {
        let browser = SettingsWidgetBrowser()
        browser.url = url
        browser.width = width
        browser.height = height
        browser.audioOnly = audioOnly
        browser.scaleToFitVideo = scaleToFitVideo
        browser.fps = fps
        browser.styleSheet = styleSheet
        return browser
    }
}

struct RemoteControlRemoteSceneSettingsWidgetTypeText: Codable {
    var format: String
    var horizontalAlignment: RemoteControlRemoteSceneSettingsHorizontalAlignment
    var verticalAlignment: RemoteControlRemoteSceneSettingsVerticalAlignment

    init(text: SettingsWidgetText) {
        format = text.formatString
        horizontalAlignment = .init(alignment: text.horizontalAlignment!)
        verticalAlignment = .init(alignment: text.verticalAlignment!)
    }

    func toSettings() -> SettingsWidgetText {
        let text = SettingsWidgetText()
        text.formatString = format
        text.horizontalAlignment = horizontalAlignment.toSettings()
        text.verticalAlignment = verticalAlignment.toSettings()
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

enum RemoteControlRemoteSceneSettingsVerticalAlignment: Codable {
    case top
    case bottom

    init(alignment: SettingsVerticalAlignment) {
        switch alignment {
        case .top:
            self = .top
        case .bottom:
            self = .bottom
        }
    }

    func toSettings() -> SettingsVerticalAlignment {
        switch self {
        case .top:
            return .top
        case .bottom:
            return .bottom
        }
    }
}

struct RemoteControlRemoteSceneSettingsWidgetTypeScene: Codable {
    var sceneId: UUID
}

// periphery:ignore
struct RemoteControlRemoteSceneData: Codable {
    var widgets: [RemoteControlRemoteSceneDataWidget]
}

// periphery:ignore
struct RemoteControlRemoteSceneDataWidget: Codable {
    var id: UUID
    var type: RemoteControlRemoteSceneDataWidgetType
}

// periphery:ignore
enum RemoteControlRemoteSceneDataWidgetType: Codable {
    case text(data: RemoteControlRemoteSceneDataWidgetTypeText)
}

// periphery:ignore
struct RemoteControlRemoteSceneDataWidgetTypeText: Codable {
    var speed: String?
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
    var browserWidgets: RemoteControlStatusItem?
    var moblink: RemoteControlStatusItem?
    var djiDevices: RemoteControlStatusItem?
}

struct RemoteControlSettingsScene: Codable, Identifiable {
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
    var bitratePresets: [RemoteControlSettingsBitratePreset]
    var mics: [RemoteControlSettingsMic]
    var srt: RemoteControlSettingsSrt
}

struct RemoteControlState: Codable {
    var scene: UUID?
    var mic: String?
    var bitrate: UUID?
    var zoom: Float?
    var debugLogging: Bool?
    var streaming: Bool?
    var recording: Bool?
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
