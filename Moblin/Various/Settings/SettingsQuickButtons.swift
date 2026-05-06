import Foundation
import SwiftUI

enum SettingsQuickButtonType: String, Codable, CaseIterable {
    case unknown = "Unknown"
    case torch = "Torch"
    case mute = "Mute"
    case bitrate = "Bitrate"
    case mic = "Mic"
    case chat = "Chat"
    case blackScreen = "Black screen"
    case record = "Record"
    case recordings = "Recrodings"
    case image = "Image"
    case movie = "Movie"
    case grayScale = "Gray scale"
    case sepia = "Sepia"
    case triple = "Triple"
    case twin = "Twin"
    case pixellate = "Pixellate"
    case stream = "Stream"
    case grid = "Grid"
    case cameraLevel = "Camera level"
    case obs = "OBS"
    case remote = "Remote"
    case draw = "Draw"
    case localOverlays = "Local overlays"
    case browser = "Browser"
    case cameraPreview = "Camera preview"
    case fourThree = "4:3"
    case crt = "CRT"
    case poll = "Poll"
    case snapshot = "Snapshot"
    case widgets = "Widgets"
    case luts = "LUTs"
    case workout = "Workout"
    case moderation = "Moderation"
    case predefinedMessages = "Predefined messages"
    case skipCurrentTts = "Skip current TTS"
    case streamMarker = "Stream marker"
    case reloadBrowserWidgets = "Reload browser widgets"
    case interactiveChat = "Interactive chat"
    case lockScreen = "Lock screen"
    case djiDevices = "DJI devices"
    case portrait = "Portrait"
    case goPro = "GoPro"
    case replay = "Replay"
    case connectionPriorities = "Connection priorities"
    case instantReplay = "Instant replay"
    case pinch = "Pinch"
    case whirlpool = "Whirlpool"
    case autoSceneSwitcher = "Auto scene switcher"
    case pauseTts = "Pause TTS"
    case live = "Live"
    case navigation = "Navigation"
    case blurFaces = "Blur faces"
    case blurText = "Blur text"
    case privacy = "Privacy"
    case moblinInMouth = "Moblin in mouth"
    case glasses = "Glasses"
    case sparkle = "Sparkle"
    case beauty = "Beauty filter"
    case cameraMan = "Camera man"
    case videoPreview = "Video preview"
    case interactiveBrowserWidgets = "Interactive browser widgets"
    case macros = "Macros"
    case gimbalTracking = "Gimbal tracking"

    init(from decoder: Decoder) throws {
        var value = try decoder.singleValueContainer().decode(RawValue.self)
        if value == "Pause chat" {
            value = "Chat"
        }
        self = SettingsQuickButtonType(rawValue: value) ?? .unknown
    }

    func toString() -> String {
        switch self {
        case .unknown:
            return String(localized: "Unknown")
        case .torch:
            return String(localized: "Torch")
        case .mute:
            return String(localized: "Mute")
        case .live:
            return String(localized: "Stream")
        case .mic:
            return String(localized: "Mic")
        case .record:
            return String(localized: "Record")
        case .snapshot:
            return String(localized: "Snapshot")
        case .widgets:
            return String(localized: "Scene widgets")
        case .localOverlays:
            return String(localized: "Local overlays")
        case .blackScreen:
            return String(localized: "Stealth mode")
        case .chat:
            return String(localized: "Chat")
        case .bitrate:
            return String(localized: "Bitrate")
        case .browser:
            return String(localized: "Browser")
        case .draw:
            return String(localized: "Draw")
        case .poll:
            return String(localized: "Poll")
        case .pinch:
            return String(localized: "Pinch")
        case .whirlpool:
            return String(localized: "Whirlpool")
        case .blurFaces:
            return String(localized: "Blur faces")
        case .privacy:
            return String(localized: "Blur background")
        case .blurText:
            return String(localized: "Blur text")
        case .glasses:
            return String(localized: "Glasses")
        case .sparkle:
            return String(localized: "Sparkle")
        case .movie:
            return String(localized: "Movie")
        case .fourThree:
            return String(localized: "4:3")
        case .crt:
            return String(localized: "CRT")
        case .pixellate:
            return String(localized: "Pixellate")
        case .grayScale:
            return String(localized: "Gray scale")
        case .sepia:
            return String(localized: "Sepia")
        case .triple:
            return String(localized: "Triple")
        case .twin:
            return String(localized: "Twin")
        case .moblinInMouth:
            return String(localized: "Moblin in mouth")
        case .cameraMan:
            return String(localized: "Camera man")
        case .beauty:
            return String(localized: "Beauty")
        case .luts:
            return String(localized: "LUTs")
        case .obs:
            return String(localized: "OBS")
        case .remote:
            return String(localized: "Remote")
        case .replay:
            return String(localized: "Replay")
        case .instantReplay:
            return String(localized: "Instant replay")
        case .djiDevices:
            return String(localized: "DJI devices")
        case .goPro:
            return String(localized: "GoPro")
        case .interactiveChat:
            return String(localized: "Interactive chat")
        case .autoSceneSwitcher:
            return String(localized: "Auto scene switcher")
        case .lockScreen:
            return String(localized: "Lock screen")
        case .image:
            return String(localized: "Camera")
        case .cameraPreview:
            return String(localized: "Camera preview")
        case .recordings:
            return String(localized: "Recordings")
        case .stream:
            return String(localized: "Switch stream")
        case .grid:
            return String(localized: "Grid")
        case .cameraLevel:
            return String(localized: "Camera level")
        case .workout:
            return String(localized: "Workout")
        case .skipCurrentTts:
            return String(localized: "Skip current TTS")
        case .pauseTts:
            return String(localized: "Pause TTS")
        case .moderation:
            return String(localized: "Moderation")
        case .predefinedMessages:
            return String(localized: "Predefined messages")
        case .streamMarker:
            return String(localized: "Stream marker")
        case .navigation:
            return String(localized: "Navigation")
        case .reloadBrowserWidgets:
            return String(localized: "Reload browser widgets")
        case .portrait:
            return String(localized: "Portrait")
        case .connectionPriorities:
            return String(localized: "Connection priorities")
        case .videoPreview:
            return String(localized: "Video preview")
        case .interactiveBrowserWidgets:
            return String(localized: "Interactive browser widgets")
        case .macros:
            return String(localized: "Macros")
        case .gimbalTracking:
            return String(localized: "Gimbal tracking")
        }
    }

    static func filters() -> [SettingsQuickButtonType] {
        return [
            .movie,
            .fourThree,
            .crt,
            .grayScale,
            .sepia,
            .triple,
            .twin,
            .pixellate,
            .whirlpool,
            .pinch,
            .blurFaces,
            .privacy,
            .moblinInMouth,
            .beauty,
            .cameraMan,
            .poll,
        ]
    }
}

class SettingsQuickButton: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    var name: String
    var type: SettingsQuickButtonType
    var imageOn: String
    var imageOff: String
    var isOn: Bool
    @Published var enabled: Bool = true
    var backgroundColor: RgbColor = defaultQuickButtonColor
    @Published var color: Color = defaultQuickButtonColor.color()
    @Published var page: Int

    init(type: SettingsQuickButtonType,
         imageOn: String,
         imageOff: String? = nil,
         isOn: Bool = false,
         page: Int = 1)
    {
        name = type.toString()
        self.type = type
        self.imageOn = imageOn
        self.imageOff = imageOff ?? imageOn
        self.isOn = isOn
        self.page = page
    }

    enum CodingKeys: CodingKey {
        case name,
             id,
             type,
             imageType,
             systemImageNameOn,
             systemImageNameOff,
             isOn,
             enabled,
             backgroundColor,
             page
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.name, name)
        try container.encode(.id, id)
        try container.encode(.type, type)
        try container.encode(.systemImageNameOn, imageOn)
        try container.encode(.systemImageNameOff, imageOff)
        try container.encode(.isOn, isOn)
        try container.encode(.enabled, enabled)
        try container.encode(.backgroundColor, backgroundColor)
        try container.encode(.page, page)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decode(.name, String.self, "")
        id = container.decode(.id, UUID.self, .init())
        type = container.decode(.type, SettingsQuickButtonType.self, .unknown)
        imageOn = container.decode(.systemImageNameOn, String.self, "")
        imageOff = container.decode(.systemImageNameOff, String.self, "")
        isOn = container.decode(.isOn, Bool.self, false)
        enabled = container.decode(.enabled, Bool.self, true)
        backgroundColor = container.decode(.backgroundColor, RgbColor.self, defaultQuickButtonColor)
        color = backgroundColor.color()
        page = container.decode(.page, Int.self, 1)
    }
}

class SettingsQuickButtons: Codable, ObservableObject {
    @Published var twoColumns: Bool = true
    @Published var bigButtons: Bool = false
    @Published var showName: Bool = true
    @Published var enableScroll: Bool = true
    @Published var stealthModeShowChat: Bool = false
    @Published var stealthModeShowStatus: Bool = false

    enum CodingKeys: CodingKey {
        case twoColumns,
             bigButtons,
             showName,
             enableScroll,
             blackScreenShowChat,
             blackScreenShowStatus
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.twoColumns, twoColumns)
        try container.encode(.bigButtons, bigButtons)
        try container.encode(.showName, showName)
        try container.encode(.enableScroll, enableScroll)
        try container.encode(.blackScreenShowChat, stealthModeShowChat)
        try container.encode(.blackScreenShowStatus, stealthModeShowStatus)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        twoColumns = container.decode(.twoColumns, Bool.self, true)
        bigButtons = container.decode(.bigButtons, Bool.self, false)
        showName = container.decode(.showName, Bool.self, true)
        enableScroll = container.decode(.enableScroll, Bool.self, true)
        stealthModeShowChat = container.decode(.blackScreenShowChat, Bool.self, false)
        stealthModeShowStatus = container.decode(.blackScreenShowStatus, Bool.self, false)
    }
}
