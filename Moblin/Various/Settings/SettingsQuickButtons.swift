import Foundation
import SwiftUI

enum SettingsQuickButtonType: String, Codable, CaseIterable {
    case unknown = "Unknown"
    case torch = "Torch"
    case mute = "Mute"
    case bitrate = "Bitrate"
    case widget = "Widget"
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
    case lut = "LUT"
    case cameraPreview = "Camera preview"
    case face = "Face"
    case fourThree = "4:3"
    case poll = "Poll"
    case snapshot = "Snapshot"
    case widgets = "Widgets"
    case luts = "LUTs"
    case workout = "Workout"
    case ads = "Ads"
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

    init(from decoder: Decoder) throws {
        var value = try decoder.singleValueContainer().decode(RawValue.self)
        if value == "Pause chat" {
            value = "Chat"
        }
        self = SettingsQuickButtonType(rawValue: value) ?? .unknown
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

    init(name: String,
         type: SettingsQuickButtonType,
         imageOn: String,
         imageOff: String? = nil,
         isOn: Bool = false,
         page: Int = 1)
    {
        self.name = name
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
        type = container.decode(.type, SettingsQuickButtonType.self, .widget)
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
    @Published var blackScreenShowChat: Bool = false

    enum CodingKeys: CodingKey {
        case twoColumns,
             bigButtons,
             showName,
             enableScroll,
             blackScreenShowChat
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.twoColumns, twoColumns)
        try container.encode(.bigButtons, bigButtons)
        try container.encode(.showName, showName)
        try container.encode(.enableScroll, enableScroll)
        try container.encode(.blackScreenShowChat, blackScreenShowChat)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        twoColumns = container.decode(.twoColumns, Bool.self, true)
        bigButtons = container.decode(.bigButtons, Bool.self, false)
        showName = container.decode(.showName, Bool.self, true)
        enableScroll = container.decode(.enableScroll, Bool.self, true)
        blackScreenShowChat = container.decode(.blackScreenShowChat, Bool.self, false)
    }
}
