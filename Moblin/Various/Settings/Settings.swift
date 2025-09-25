import AVFoundation
import SwiftUI

let defaultStreamUrl = "srt://my_public_ip:4000"
let defaultRtmpStreamUrl = "rtmp://my_public_ip:1935/live/foobar"
let defaultQuickButtonColor = RgbColor(red: 255 / 4, green: 255 / 4, blue: 255 / 4)
let defaultStreamButtonColor = RgbColor(red: 255, green: 59, blue: 48)
let defaultSrtLatency: Int32 = 3000
let minZoomX: Float = 0.5

enum SettingsCameraId {
    case back(id: String)
    case front(id: String)
    case rtmp(id: UUID)
    case srtla(id: UUID)
    case rist(id: UUID)
    case rtsp(id: UUID)
    case mediaPlayer(id: UUID)
    case external(id: String, name: String)
    case screenCapture
    case none
    case backTripleLowEnergy
    case backDualLowEnergy
    case backWideDualLowEnergy
}

enum SettingsVideoEffectType: String, Codable, CaseIterable {
    case shape
    case grayScale
    case sepia
    case whirlpool
    case pinch
    case removeBackground
    case dewarp360

    init(from decoder: Decoder) throws {
        do {
            self = try SettingsVideoEffectType(rawValue: decoder.singleValueContainer()
                .decode(RawValue.self)) ?? .shape
        } catch {
            self = .shape
        }
    }

    func toString() -> String {
        switch self {
        case .shape:
            return String(localized: "Shape")
        case .grayScale:
            return String(localized: "Gray scale")
        case .sepia:
            return String(localized: "Sepia")
        case .whirlpool:
            return String(localized: "Whirlpool")
        case .pinch:
            return String(localized: "Pinch")
        case .removeBackground:
            return String(localized: "Remove background")
        case .dewarp360:
            return String(localized: "Dewarp 360")
        }
    }
}

private let defaultFromColor = RgbColor(red: 220, green: 235, blue: 92)
private let defaultToColor = RgbColor(red: 82, green: 180, blue: 203)

class SettingsVideoEffectRemoveBackground: Codable, ObservableObject {
    var from: RgbColor = defaultFromColor
    @Published var fromColor: Color
    var to: RgbColor = defaultToColor
    @Published var toColor: Color

    enum CodingKeys: CodingKey {
        case from,
             to
    }

    init() {
        fromColor = from.color()
        toColor = to.color()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.from, from)
        try container.encode(.to, to)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        from = container.decode(.from, RgbColor.self, defaultFromColor)
        fromColor = from.color()
        to = container.decode(.to, RgbColor.self, defaultToColor)
        toColor = to.color()
    }
}

class SettingsVideoEffectShape: Codable, ObservableObject {
    @Published var cornerRadius: Float = 0
    @Published var borderWidth: Double = 0
    var borderColor: RgbColor = .init(red: 0, green: 0, blue: 0)
    @Published var borderColorColor: Color

    enum CodingKeys: CodingKey {
        case cornerRadius,
             borderWidth,
             borderColor
    }

    init() {
        borderColorColor = borderColor.color()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.cornerRadius, cornerRadius)
        try container.encode(.borderWidth, borderWidth)
        try container.encode(.borderColor, borderColor)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cornerRadius = container.decode(.cornerRadius, Float.self, 0)
        borderWidth = container.decode(.borderWidth, Double.self, 0)
        borderColor = container.decode(.borderColor, RgbColor.self, .init(red: 0, green: 0, blue: 0))
        borderColorColor = borderColor.color()
    }

    func toSettings() -> ShapeEffectSettings {
        return .init(cornerRadius: cornerRadius,
                     borderWidth: borderWidth,
                     borderColor: CIColor(
                         red: Double(borderColor.red) / 255,
                         green: Double(borderColor.green) / 255,
                         blue: Double(borderColor.blue) / 255
                     ))
    }
}

class SettingsVideoEffectDewarp360: Codable, ObservableObject {
    @Published var pan: Float = 0
    @Published var tilt: Float = 0
    var zoom: Float = 1
    @Published var inverseFieldOfView: Float = 90

    init() {}

    enum CodingKeys: CodingKey {
        case pan,
             tilt,
             zoom
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.pan, pan)
        try container.encode(.tilt, tilt)
        try container.encode(.zoom, zoom)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pan = container.decode(.pan, Float.self, 0)
        tilt = container.decode(.tilt, Float.self, 0)
        zoom = container.decode(.zoom, Float.self, 1)
        inverseFieldOfView = 180 - zoomToFieldOfView(zoom: zoom).toDegrees()
    }

    func updateZoomFromInverseFieldOfView() {
        zoom = fieldOfViewToZoom(fieldOfView: (180 - inverseFieldOfView).toRadians())
    }

    func toSettings() -> Dewarp360EffectSettings {
        return .direct(pan: -pan.toRadians(),
                       tilt: tilt.toRadians(),
                       fieldOfView: zoomToFieldOfView(zoom: zoom))
    }
}

class SettingsVideoEffect: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var enabled: Bool = true
    @Published var type: SettingsVideoEffectType = .shape
    var removeBackground: SettingsVideoEffectRemoveBackground = .init()
    var shape: SettingsVideoEffectShape = .init()
    var dewarp360: SettingsVideoEffectDewarp360 = .init()

    enum CodingKeys: CodingKey {
        case id,
             enabled,
             type,
             removeBackground,
             shape,
             dewarp360
    }

    init() {}

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.enabled, enabled)
        try container.encode(.type, type)
        try container.encode(.removeBackground, removeBackground)
        try container.encode(.shape, shape)
        try container.encode(.dewarp360, dewarp360)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        enabled = container.decode(.enabled, Bool.self, true)
        type = container.decode(.type, SettingsVideoEffectType.self, .shape)
        removeBackground = container.decode(.removeBackground, SettingsVideoEffectRemoveBackground.self, .init())
        shape = container.decode(.shape, SettingsVideoEffectShape.self, .init())
        dewarp360 = container.decode(.dewarp360, SettingsVideoEffectDewarp360.self, .init())
    }

    func getEffect() -> VideoEffect {
        switch type {
        case .grayScale:
            return GrayScaleEffect()
        case .sepia:
            return SepiaEffect()
        case .whirlpool:
            return WhirlpoolEffect(angle: .pi / 2)
        case .pinch:
            return PinchEffect(scale: 0.5)
        case .removeBackground:
            let effect = RemoveBackgroundEffect()
            effect.setColorRange(from: removeBackground.from, to: removeBackground.to)
            return effect
        case .shape:
            let effect = ShapeEffect()
            effect.setSettings(settings: shape.toSettings())
            return effect
        case .dewarp360:
            let effect = Dewarp360Effect()
            effect.setSettings(settings: dewarp360.toSettings())
            return effect
        }
    }
}

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

    init(from decoder: Decoder) throws {
        var value = try decoder.singleValueContainer().decode(RawValue.self)
        if value == "Pause chat" {
            value = "Chat"
        }
        self = SettingsQuickButtonType(rawValue: value) ?? .unknown
    }
}

class SettingsQuickButton: Codable, Identifiable, Equatable, Hashable, ObservableObject {
    var name: String
    var id: UUID = .init()
    var type: SettingsQuickButtonType = .widget
    var systemImageNameOn: String = "mic.slash"
    var systemImageNameOff: String = "mic"
    var isOn: Bool = false
    @Published var enabled: Bool = true
    var backgroundColor: RgbColor = defaultQuickButtonColor
    @Published var color: Color = defaultQuickButtonColor.color()
    @Published var page: Int = 1

    init(name: String) {
        self.name = name
    }

    static func == (lhs: SettingsQuickButton, rhs: SettingsQuickButton) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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
        try container.encode(.systemImageNameOn, systemImageNameOn)
        try container.encode(.systemImageNameOff, systemImageNameOff)
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
        systemImageNameOn = container.decode(.systemImageNameOn, String.self, "mic.slash")
        systemImageNameOff = container.decode(.systemImageNameOff, String.self, "mic")
        isOn = container.decode(.isOn, Bool.self, false)
        enabled = container.decode(.enabled, Bool.self, true)
        backgroundColor = container.decode(.backgroundColor, RgbColor.self, defaultQuickButtonColor)
        color = backgroundColor.color()
        page = container.decode(.page, Int.self, 1)
    }
}

enum SettingsColorLutType: String, Codable {
    case bundled
    case disk
    case diskCube

    init(from decoder: Decoder) throws {
        do {
            self = try SettingsColorLutType(rawValue: decoder.singleValueContainer()
                .decode(RawValue.self)) ?? .bundled
        } catch {
            self = .bundled
        }
    }
}

class SettingsColorLut: Codable, Identifiable {
    var id: UUID = .init()
    var type: SettingsColorLutType = .bundled
    var name: String = ""
    var enabled: Bool = false

    init(type: SettingsColorLutType, name: String) {
        self.type = type
        self.name = name
    }

    enum CodingKeys: CodingKey {
        case id,
             type,
             name,
             enabled
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.type, type)
        try container.encode(.name, name)
        try container.encode(.enabled, enabled)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        type = container.decode(.type, SettingsColorLutType.self, .bundled)
        name = container.decode(.name, String.self, "")
        enabled = container.decode(.enabled, Bool.self, false)
    }

    func clone() -> SettingsColorLut {
        let new = SettingsColorLut(type: type, name: name)
        new.id = id
        new.enabled = enabled
        return new
    }
}

enum SettingsColorSpace: String, Codable, CaseIterable {
    case srgb = "Standard RGB"
    case p3D65 = "P3 D65"
    case hlgBt2020 = "HLG BT2020"
    case appleLog = "Apple Log"

    init(from decoder: Decoder) throws {
        self = try SettingsColorSpace(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .srgb
    }
}

let colorSpaces = SettingsColorSpace.allCases

private let allBundledLuts = [
    SettingsColorLut(type: .bundled, name: "Apple Log To Rec 709"),
    SettingsColorLut(type: .bundled, name: "Moblin Meme"),
]

class SettingsColor: Codable, ObservableObject {
    @Published var space: SettingsColorSpace = .srgb
    @Published var lutEnabled: Bool = true
    @Published var lut: UUID = .init()
    var bundledLuts = allBundledLuts
    @Published var diskLuts: [SettingsColorLut] = []
    @Published var diskLutsPng: [SettingsColorLut] = []
    @Published var diskLutsCube: [SettingsColorLut] = []

    init() {}

    enum CodingKeys: CodingKey {
        case space,
             lutEnabled,
             lut,
             bundledLuts,
             diskLuts,
             diskLutsPng,
             diskLutsCube
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.space, space)
        try container.encode(.lutEnabled, lutEnabled)
        try container.encode(.lut, lut)
        try container.encode(.bundledLuts, bundledLuts)
        try container.encode(.diskLuts, diskLuts)
        try container.encode(.diskLutsPng, diskLutsPng)
        try container.encode(.diskLutsCube, diskLutsCube)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        space = container.decode(.space, SettingsColorSpace.self, .srgb)
        lutEnabled = container.decode(.lutEnabled, Bool.self, true)
        lut = container.decode(.lut, UUID.self, .init())
        bundledLuts = container.decode(.bundledLuts, [SettingsColorLut].self, [])
        diskLuts = container.decode(.diskLuts, [SettingsColorLut].self, [])
        diskLutsPng = container.decode(.diskLutsPng, [SettingsColorLut].self, [])
        diskLutsCube = container.decode(.diskLutsCube, [SettingsColorLut].self, [])
    }
}

class SettingsShow: Codable, ObservableObject {
    @Published var chat: Bool = true
    @Published var viewers: Bool = true
    @Published var uptime: Bool = true
    @Published var stream: Bool = false
    @Published var speed: Bool = true
    @Published var audioLevel: Bool = true
    @Published var zoom: Bool = false
    @Published var zoomPresets: Bool = true
    @Published var microphone: Bool = false
    @Published var audioBar: Bool = true
    @Published var cameras: Bool = false
    @Published var obsStatus: Bool = true
    @Published var rtmpSpeed: Bool = true
    @Published var gameController: Bool = true
    @Published var location: Bool = true
    @Published var remoteControl: Bool = true
    @Published var browserWidgets: Bool = true
    @Published var bonding: Bool = true
    @Published var events: Bool = true
    @Published var djiDevices: Bool = true
    @Published var bondingRtts: Bool = false
    @Published var moblink: Bool = true
    @Published var catPrinter: Bool = true
    @Published var cyclingPowerDevice: Bool = true
    @Published var heartRateDevice: Bool = true
    @Published var cpu: Bool = false

    init() {}

    enum CodingKeys: CodingKey {
        case chat,
             viewers,
             uptime,
             stream,
             speed,
             audioLevel,
             zoom,
             zoomPresets,
             microphone,
             audioBar,
             cameras,
             obsStatus,
             rtmpSpeed,
             gameController,
             location,
             remoteControl,
             browserWidgets,
             bonding,
             events,
             djiDevices,
             bondingRtts,
             moblink,
             catPrinter,
             cyclingPowerDevice,
             heartRateDevice,
             cpu
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.chat, chat)
        try container.encode(.viewers, viewers)
        try container.encode(.uptime, uptime)
        try container.encode(.stream, stream)
        try container.encode(.speed, speed)
        try container.encode(.audioLevel, audioLevel)
        try container.encode(.zoom, zoom)
        try container.encode(.zoomPresets, zoomPresets)
        try container.encode(.microphone, microphone)
        try container.encode(.audioBar, audioBar)
        try container.encode(.cameras, cameras)
        try container.encode(.obsStatus, obsStatus)
        try container.encode(.rtmpSpeed, rtmpSpeed)
        try container.encode(.gameController, gameController)
        try container.encode(.location, location)
        try container.encode(.remoteControl, remoteControl)
        try container.encode(.browserWidgets, browserWidgets)
        try container.encode(.bonding, bonding)
        try container.encode(.events, events)
        try container.encode(.djiDevices, djiDevices)
        try container.encode(.bondingRtts, bondingRtts)
        try container.encode(.moblink, moblink)
        try container.encode(.catPrinter, catPrinter)
        try container.encode(.cyclingPowerDevice, cyclingPowerDevice)
        try container.encode(.heartRateDevice, heartRateDevice)
        try container.encode(.cpu, cpu)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chat = container.decode(.chat, Bool.self, true)
        viewers = container.decode(.viewers, Bool.self, true)
        uptime = container.decode(.uptime, Bool.self, true)
        stream = container.decode(.stream, Bool.self, false)
        speed = container.decode(.speed, Bool.self, true)
        audioLevel = container.decode(.audioLevel, Bool.self, true)
        zoom = container.decode(.zoom, Bool.self, false)
        zoomPresets = container.decode(.zoomPresets, Bool.self, true)
        microphone = container.decode(.microphone, Bool.self, false)
        audioBar = container.decode(.audioBar, Bool.self, true)
        cameras = container.decode(.cameras, Bool.self, false)
        obsStatus = container.decode(.obsStatus, Bool.self, true)
        rtmpSpeed = container.decode(.rtmpSpeed, Bool.self, true)
        gameController = container.decode(.gameController, Bool.self, true)
        location = container.decode(.location, Bool.self, true)
        remoteControl = container.decode(.remoteControl, Bool.self, true)
        browserWidgets = container.decode(.browserWidgets, Bool.self, true)
        bonding = container.decode(.bonding, Bool.self, true)
        events = container.decode(.events, Bool.self, true)
        djiDevices = container.decode(.djiDevices, Bool.self, true)
        bondingRtts = container.decode(.bondingRtts, Bool.self, false)
        moblink = container.decode(.moblink, Bool.self, true)
        catPrinter = container.decode(.catPrinter, Bool.self, true)
        cyclingPowerDevice = container.decode(.cyclingPowerDevice, Bool.self, true)
        heartRateDevice = container.decode(.heartRateDevice, Bool.self, true)
        cpu = container.decode(.cpu, Bool.self, false)
    }
}

class SettingsZoomPreset: Codable, Identifiable, Equatable, ObservableObject {
    var id: UUID
    @Published var name: String = ""
    @Published var x: Float = 1.0

    init(id: UUID, name: String, x: Float) {
        self.id = id
        self.name = name
        self.x = x
    }

    static func == (lhs: SettingsZoomPreset, rhs: SettingsZoomPreset) -> Bool {
        return lhs.id == rhs.id
    }

    enum CodingKeys: CodingKey {
        case id,
             name,
             x
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.x, x)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, "")
        x = container.decode(.x, Float.self, 1.0)
    }
}

class SettingsZoomSwitchTo: Codable, ObservableObject {
    @Published var level: Float = 1.0
    @Published var x: Float = 1.0
    @Published var enabled: Bool = false

    init() {}

    enum CodingKeys: CodingKey {
        case level,
             x,
             enabled
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.level, level)
        try container.encode(.x, x)
        try container.encode(.enabled, enabled)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        level = container.decode(.level, Float.self, 1.0)
        x = container.decode(.x, Float.self, 1.0)
        enabled = container.decode(.enabled, Bool.self, false)
    }
}

class SettingsZoom: Codable, ObservableObject {
    @Published var back: [SettingsZoomPreset] = []
    @Published var front: [SettingsZoomPreset] = []
    @Published var switchToBack: SettingsZoomSwitchTo = .init()
    @Published var switchToFront: SettingsZoomSwitchTo = .init()
    @Published var speed: Float = 5.0

    init() {}

    enum CodingKeys: CodingKey {
        case back,
             front,
             switchToBack,
             switchToFront,
             speed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.back, back)
        try container.encode(.front, front)
        try container.encode(.switchToBack, switchToBack)
        try container.encode(.switchToFront, switchToFront)
        try container.encode(.speed, speed)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        back = container.decode(.back, [SettingsZoomPreset].self, [])
        front = container.decode(.front, [SettingsZoomPreset].self, [])
        switchToBack = container.decode(.switchToBack, SettingsZoomSwitchTo.self, .init())
        switchToFront = container.decode(.switchToFront, SettingsZoomSwitchTo.self, .init())
        speed = container.decode(.speed, Float.self, 5.0)
    }
}

class SettingsBitratePreset: Codable, Identifiable, ObservableObject {
    var id: UUID
    @Published var bitrate: UInt32 = 5_000_000

    init(id: UUID, bitrate: UInt32) {
        self.id = id
        self.bitrate = bitrate
    }

    enum CodingKeys: CodingKey {
        case id,
             bitrate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.bitrate, bitrate)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        bitrate = container.decode(.bitrate, UInt32.self, 5_000_000)
    }
}

enum SettingsVideoStabilizationMode: String, Codable, CaseIterable {
    case off = "Off"
    case standard = "Standard"
    case cinematic = "Cinematic"
    case cinematicExtendedEnhanced = "Cinematic extended enhanced"

    init(from decoder: Decoder) throws {
        self = try SettingsVideoStabilizationMode(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .off
    }

    func toString() -> String {
        switch self {
        case .off:
            return String(localized: "Off")
        case .standard:
            return String(localized: "Standard")
        case .cinematic:
            return String(localized: "Cinematic")
        case .cinematicExtendedEnhanced:
            return String(localized: "Cinematic extended enhanced")
        }
    }
}

var videoStabilizationModes = SettingsVideoStabilizationMode.allCases
    .filter {
        if #available(iOS 18.0, *) {
            return true
        } else {
            return $0 != .cinematicExtendedEnhanced
        }
    }

class SettingsTesla: Codable {
    var vin: String = ""
    var privateKey: String = ""
    var enabled: Bool = true

    enum CodingKeys: CodingKey {
        case vin,
             privateKey,
             enabled
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.vin, vin)
        try container.encode(.privateKey, privateKey)
        try container.encode(.enabled, enabled)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vin = container.decode(.vin, String.self, "")
        privateKey = container.decode(.privateKey, String.self, "")
        enabled = container.decode(.enabled, Bool.self, true)
    }
}

enum SettingsDnsLookupStrategy: String, Codable, CaseIterable {
    case system = "System"
    case ipv4 = "IPv4"
    case ipv6 = "IPv6"
    case ipv4AndIpv6 = "IPv4 and IPv6"

    init(from decoder: Decoder) throws {
        self = try SettingsDnsLookupStrategy(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .system
    }
}

let dnsLookupStrategies = SettingsDnsLookupStrategy.allCases.map { $0.rawValue }

enum SettingsSelfieStickButtonFunction: String, Codable, CaseIterable {
    case switchScene

    init(from decoder: Decoder) throws {
        do {
            self = try SettingsSelfieStickButtonFunction(rawValue: decoder.singleValueContainer()
                .decode(RawValue.self)) ?? .switchScene
        } catch {
            self = .switchScene
        }
    }

    func toString() -> String {
        switch self {
        case .switchScene:
            return String(localized: "Switch scene")
        }
    }
}

class SettingsSelfieStick: Codable, ObservableObject {
    @Published var buttonEnabled: Bool = false
    @Published var buttonFunction: SettingsSelfieStickButtonFunction = .switchScene

    enum CodingKeys: CodingKey {
        case enabled,
             function
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, buttonEnabled)
        try container.encode(.function, buttonFunction)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        buttonEnabled = container.decode(.enabled, Bool.self, false)
        buttonFunction = container.decode(.function, SettingsSelfieStickButtonFunction.self, .switchScene)
    }
}

class SettingsMediaPlayerFile: Codable, Identifiable {
    var id: UUID = .init()
    var name: String = "My video"

    func clone() -> SettingsMediaPlayerFile {
        let new = SettingsMediaPlayerFile()
        new.id = id
        new.name = name
        return new
    }
}

class SettingsMediaPlayer: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My player")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var playerId: String = ""
    @Published var autoSelectMic: Bool = true
    @Published var playlist: [SettingsMediaPlayerFile] = []

    enum CodingKeys: CodingKey {
        case id,
             name,
             playerId,
             autoSelectMic,
             playlist
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.playerId, playerId)
        try container.encode(.autoSelectMic, autoSelectMic)
        try container.encode(.playlist, playlist)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        playerId = container.decode(.playerId, String.self, "")
        autoSelectMic = container.decode(.autoSelectMic, Bool.self, true)
        playlist = container.decode(.playlist, [SettingsMediaPlayerFile].self, [])
    }

    func camera() -> String {
        return mediaPlayerCamera(name: name)
    }

    func clone() -> SettingsMediaPlayer {
        let new = SettingsMediaPlayer()
        new.id = id
        new.name = name
        new.playerId = playerId
        new.autoSelectMic = autoSelectMic
        for file in playlist {
            new.playlist.append(file.clone())
        }
        return new
    }
}

class SettingsMediaPlayers: Codable, ObservableObject {
    @Published var players: [SettingsMediaPlayer] = []

    enum CodingKeys: CodingKey {
        case players
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.players, players)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        players = container.decode(.players, [SettingsMediaPlayer].self, [])
    }
}

enum SettingsReplaySpeed: String, Codable, CaseIterable {
    case oneHalf = "0.5x"
    case one = "1x"

    init(from decoder: Decoder) throws {
        self = try SettingsReplaySpeed(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .one
    }

    func toNumber() -> Double {
        switch self {
        case .oneHalf:
            return 0.5
        case .one:
            return 1.0
        }
    }
}

class SettingsReplay: Codable, ObservableObject {
    static let stop: Double = 30.0
    @Published var start: Double = 20.0
    @Published var stop: Double = SettingsReplay.stop
    @Published var speed: SettingsReplaySpeed = .one

    init() {}

    enum CodingKeys: CodingKey {
        case start,
             stop,
             speed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.start, start)
        try container.encode(.stop, stop)
        try container.encode(.speed, speed)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        start = container.decode(.start, Double.self, 20.0)
        stop = container.decode(.stop, Double.self, SettingsReplay.stop)
        speed = container.decode(.speed, SettingsReplaySpeed.self, .one)
    }
}

class SettingsCyclingPowerDevice: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My device")
    var id: UUID = .init()
    @Published var name: String = ""
    @Published var enabled: Bool = false
    @Published var bluetoothPeripheralName: String?
    @Published var bluetoothPeripheralId: UUID?

    enum CodingKeys: CodingKey {
        case id,
             name,
             enabled,
             bluetoothPeripheralName,
             bluetoothPeripheralId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.enabled, enabled)
        try container.encode(.bluetoothPeripheralName, bluetoothPeripheralName)
        try container.encode(.bluetoothPeripheralId, bluetoothPeripheralId)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        enabled = container.decode(.enabled, Bool.self, false)
        bluetoothPeripheralName = try? container.decode(String.self, forKey: .bluetoothPeripheralName)
        bluetoothPeripheralId = try? container.decode(UUID.self, forKey: .bluetoothPeripheralId)
    }
}

class SettingsCyclingPowerDevices: Codable, ObservableObject {
    @Published var devices: [SettingsCyclingPowerDevice] = []

    enum CodingKeys: CodingKey {
        case devices
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.devices, devices)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        devices = container.decode(.devices, [SettingsCyclingPowerDevice].self, [])
    }
}

class SettingsHeartRateDevice: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My device")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var enabled: Bool = false
    @Published var bluetoothPeripheralName: String?
    @Published var bluetoothPeripheralId: UUID?

    enum CodingKeys: CodingKey {
        case id,
             name,
             enabled,
             bluetoothPeripheralName,
             bluetoothPeripheralId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.enabled, enabled)
        try container.encode(.bluetoothPeripheralName, bluetoothPeripheralName)
        try container.encode(.bluetoothPeripheralId, bluetoothPeripheralId)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        enabled = container.decode(.enabled, Bool.self, false)
        bluetoothPeripheralName = try? container.decode(String.self, forKey: .bluetoothPeripheralName)
        bluetoothPeripheralId = try? container.decode(UUID.self, forKey: .bluetoothPeripheralId)
    }
}

class SettingsHeartRateDevices: Codable, ObservableObject {
    @Published var devices: [SettingsHeartRateDevice] = []

    enum CodingKeys: CodingKey {
        case devices
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.devices, devices)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        devices = container.decode(.devices, [SettingsHeartRateDevice].self, [])
    }
}

private let defaultRgbLightColor = RgbColor(red: 0, green: 255, blue: 0)

class SettingsBlackSharkCoolerDevice: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My cooler")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var enabled: Bool = false
    @Published var bluetoothPeripheralName: String?
    @Published var bluetoothPeripheralId: UUID?
    @Published var rgbLightEnabled: Bool = false
    var rgbLightColor: RgbColor = defaultRgbLightColor
    @Published var rgbLightColorColor: Color = defaultRgbLightColor.color()
    @Published var rgbLightBrightness: Double = 100.0

    enum CodingKeys: CodingKey {
        case id,
             name,
             enabled,
             bluetoothPeripheralName,
             bluetoothPeripheralId,
             rgbLightEnabled,
             rgbLightColor,
             rgbLightBrightness
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.enabled, enabled)
        try container.encode(.bluetoothPeripheralName, bluetoothPeripheralName)
        try container.encode(.bluetoothPeripheralId, bluetoothPeripheralId)
        try container.encode(.rgbLightEnabled, rgbLightEnabled)
        try container.encode(.rgbLightColor, rgbLightColor)
        try container.encode(.rgbLightBrightness, rgbLightBrightness)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        enabled = container.decode(.enabled, Bool.self, false)
        bluetoothPeripheralName = try? container.decode(String.self, forKey: .bluetoothPeripheralName)
        bluetoothPeripheralId = try? container.decode(UUID.self, forKey: .bluetoothPeripheralId)
        rgbLightEnabled = container.decode(.rgbLightEnabled, Bool.self, false)
        rgbLightColor = container.decode(.rgbLightColor, RgbColor.self, defaultRgbLightColor)
        rgbLightColorColor = rgbLightColor.color()
        rgbLightBrightness = container.decode(.rgbLightBrightness, Double.self, 100.0)
    }
}

class SettingsBlackSharkCoolerDevices: Codable, ObservableObject {
    @Published var devices: [SettingsBlackSharkCoolerDevice] = []

    enum CodingKeys: CodingKey {
        case devices
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.devices, devices)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        devices = container.decode(.devices, [SettingsBlackSharkCoolerDevice].self, [])
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

class SettingsNetworkInterfaceName: Codable, Identifiable {
    var id: UUID = .init()
    var interfaceName: String = ""
    var name: String = ""
}

enum SettingsGameControllerButtonFunction: String, Codable, CaseIterable {
    case unused = "Unused"
    case record = "Record"
    case stream = "Stream"
    case zoomIn = "Zoom in"
    case zoomOut = "Zoom out"
    case mute = "Mute"
    case torch = "Torch"
    case blackScreen = "Black screen"
    case chat = "Chat"
    case scene = "Scene"
    case instantReplay = "Instant replay"
    case pauseTts = "Pause TTS"

    init(from decoder: Decoder) throws {
        var value = try decoder.singleValueContainer().decode(RawValue.self)
        if value == "Pause chat" {
            value = "Interactive chat"
        }
        self = SettingsGameControllerButtonFunction(rawValue: value) ?? .unused
    }

    func toString() -> String {
        switch self {
        case .unused:
            return String(localized: "Unused")
        case .record:
            return String(localized: "Record")
        case .stream:
            return String(localized: "Stream")
        case .zoomIn:
            return String(localized: "Zoom in")
        case .zoomOut:
            return String(localized: "Zoom out")
        case .mute:
            return String(localized: "Mute")
        case .torch:
            return String(localized: "Torch")
        case .blackScreen:
            return String(localized: "Stealth mode")
        case .chat:
            return String(localized: "Chat")
        case .scene:
            return String(localized: "Scene")
        case .instantReplay:
            return String(localized: "Instant replay")
        case .pauseTts:
            return String(localized: "Pause TTS")
        }
    }
}

class SettingsGameControllerButton: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    var name: String = ""
    var text: String = ""
    @Published var function: SettingsGameControllerButtonFunction = .unused
    @Published var sceneId: UUID = .init()

    init() {}

    enum CodingKeys: CodingKey {
        case id,
             name,
             text,
             function,
             sceneId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.text, text)
        try container.encode(.function, function)
        try container.encode(.sceneId, sceneId)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, "")
        text = container.decode(.text, String.self, "")
        function = container.decode(.function, SettingsGameControllerButtonFunction.self, .unused)
        sceneId = container.decode(.sceneId, UUID.self, .init())
    }
}

class SettingsGameController: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var buttons: [SettingsGameControllerButton] = []

    init() {
        var button = SettingsGameControllerButton()
        button.name = "dpad.left.fill"
        button.text = String(localized: "Left")
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "dpad.right.fill"
        button.text = String(localized: "Right")
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "dpad.up.fill"
        button.text = String(localized: "Up")
        button.function = .zoomIn
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "dpad.down.fill"
        button.text = String(localized: "Down")
        button.function = .zoomOut
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "a.circle"
        button.text = "A"
        button.function = .torch
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "b.circle"
        button.text = "B"
        button.function = .mute
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "x.circle"
        button.text = "X"
        button.function = .blackScreen
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "y.circle"
        button.text = "Y"
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "circle.circle"
        button.text = String(localized: "Circle")
        button.function = .torch
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "xmark.circle"
        button.text = String(localized: "X mark")
        button.function = .mute
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "square.circle"
        button.text = String(localized: "Square")
        button.function = .blackScreen
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "triangle.circle"
        button.text = String(localized: "Triangle")
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "zl.rectangle.roundedtop"
        button.text = "ZL"
        button.function = .stream
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "l.rectangle.roundedbottom"
        button.text = "L"
        button.function = .record
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "zr.rectangle.roundedtop"
        button.text = "ZR"
        button.function = .chat
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "r.rectangle.roundedbottom"
        button.text = "R"
        button.function = .chat
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "l2.rectangle.roundedtop"
        button.text = "L2"
        button.function = .stream
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "l1.rectangle.roundedbottom"
        button.text = "L1"
        button.function = .record
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "r2.rectangle.roundedtop"
        button.text = "R2"
        button.function = .chat
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "r1.rectangle.roundedbottom"
        button.text = "R1"
        button.function = .chat
        buttons.append(button)
    }

    enum CodingKeys: CodingKey {
        case id,
             buttons
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.buttons, buttons)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        buttons = container.decode(.buttons, [SettingsGameControllerButton].self, [])
    }
}

enum SettingsKeyboardKeyFunction: String, Codable, CaseIterable {
    case unused = "Unused"
    case record = "Record"
    case stream = "Stream"
    case mute = "Mute"
    case torch = "Torch"
    case blackScreen = "Black screen"
    case scene = "Scene"
    case widget = "Widget"
    case instantReplay = "Instant replay"

    init(from decoder: Decoder) throws {
        self = try SettingsKeyboardKeyFunction(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .unused
    }

    func toString() -> String {
        switch self {
        case .unused:
            return String(localized: "Unused")
        case .record:
            return String(localized: "Record")
        case .stream:
            return String(localized: "Stream")
        case .mute:
            return String(localized: "Mute")
        case .torch:
            return String(localized: "Torch")
        case .blackScreen:
            return String(localized: "Stealth mode")
        case .scene:
            return String(localized: "Scene")
        case .widget:
            return String(localized: "Widget")
        case .instantReplay:
            return String(localized: "Instant replay")
        }
    }
}

class SettingsKeyboardKey: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var key: String = ""
    @Published var function: SettingsKeyboardKeyFunction = .unused
    @Published var sceneId: UUID = .init()
    @Published var widgetId: UUID = .init()

    init() {}

    enum CodingKeys: CodingKey {
        case id,
             key,
             function,
             sceneId,
             widgetId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.key, key)
        try container.encode(.function, function)
        try container.encode(.sceneId, sceneId)
        try container.encode(.widgetId, widgetId)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        key = container.decode(.key, String.self, "")
        function = container.decode(.function, SettingsKeyboardKeyFunction.self, .unused)
        sceneId = container.decode(.sceneId, UUID.self, .init())
        widgetId = container.decode(.widgetId, UUID.self, .init())
    }
}

class SettingsKeyboard: Codable, ObservableObject {
    @Published var keys: [SettingsKeyboardKey] = []

    init() {}

    enum CodingKeys: CodingKey {
        case keys
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.keys, keys)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keys = container.decode(.keys, [SettingsKeyboardKey].self, [])
    }
}

class SettingsRemoteControlAssistant: Codable, ObservableObject, Identifiable, Named {
    static let baseName = String(localized: "Streamer name")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var enabled: Bool = true
    @Published var port: UInt16 = 2345
    var relay: SettingsRemoteControlServerRelay = .init()

    enum CodingKeys: CodingKey {
        case id,
             name,
             enabled,
             port,
             relay
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.enabled, enabled)
        try container.encode(.port, port)
        try container.encode(.relay, relay)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        enabled = container.decode(.enabled, Bool.self, true)
        port = container.decode(.port, UInt16.self, 2345)
        relay = container.decode(.relay, SettingsRemoteControlServerRelay.self, .init())
    }
}

class SettingsRemoteControlStreamer: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var url: String = ""
    @Published var previewFps: Float = 1.0

    enum CodingKeys: CodingKey {
        case enabled,
             url,
             previewFps
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.url, url)
        try container.encode(.previewFps, previewFps)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        url = container.decode(.url, String.self, "")
        previewFps = container.decode(.previewFps, Float.self, 1.0)
    }
}

class SettingsRemoteControlServerRelay: Codable, ObservableObject {
    @Published var enabled: Bool = true
    @Published var baseUrl: String = "wss://moblin.mys-lang.org/moblin-remote-control-relay"
    @Published var bridgeId: String = UUID().uuidString.lowercased()

    enum CodingKeys: CodingKey {
        case enabled,
             baseUrl,
             bridgeId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.baseUrl, baseUrl)
        try container.encode(.bridgeId, bridgeId)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        baseUrl = container.decode(.baseUrl, String.self, "wss://moblin.mys-lang.org/moblin-remote-control-relay")
        bridgeId = container.decode(.bridgeId, String.self, UUID().uuidString.lowercased())
    }
}

class SettingsRemoteControl: Codable, ObservableObject {
    var assistant: SettingsRemoteControlAssistant = .init()
    var streamer: SettingsRemoteControlStreamer = .init()
    var password: String = randomGoodPassword()
    @Published var streamers: [SettingsRemoteControlAssistant] = []
    @Published var selectedStreamer: UUID?
    var hasMigratedAssistant: Bool = true

    enum CodingKeys: CodingKey {
        case client,
             server,
             password,
             streamers,
             selectedStreamer,
             hasMigratedAssistant
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.client, assistant)
        try container.encode(.server, streamer)
        try container.encode(.password, password)
        try container.encode(.streamers, streamers)
        try container.encode(.selectedStreamer, selectedStreamer)
        try container.encode(.hasMigratedAssistant, hasMigratedAssistant)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        assistant = container.decode(.client, SettingsRemoteControlAssistant.self, .init())
        streamer = container.decode(.server, SettingsRemoteControlStreamer.self, .init())
        password = container.decode(.password, String.self, randomGoodPassword())
        streamers = container.decode(.streamers, [SettingsRemoteControlAssistant].self, [])
        selectedStreamer = container.decode(.selectedStreamer, UUID?.self, nil)
        hasMigratedAssistant = container.decode(.hasMigratedAssistant, Bool.self, false)
        if !hasMigratedAssistant {
            let streamer = SettingsRemoteControlAssistant()
            streamer.name = "Streamer"
            streamer.enabled = assistant.enabled
            streamer.port = assistant.port
            streamer.relay.enabled = assistant.relay.enabled
            streamer.relay.baseUrl = assistant.relay.baseUrl
            streamer.relay.bridgeId = assistant.relay.bridgeId
            streamers.append(streamer)
            selectedStreamer = streamer.id
            hasMigratedAssistant = true
        }
    }

    func getSelectedStreamerName() -> String? {
        return streamers.first(where: { $0.id == selectedStreamer })?.name
    }
}

class SettingsMoblinkStreamer: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var port: UInt16 = 7777

    enum CodingKeys: CodingKey {
        case enabled,
             port
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.port, port)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        port = container.decode(.port, UInt16.self, 7777)
    }
}

class SettingsMoblinkRelay: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var name: String = randomName()
    @Published var url: String = ""
    @Published var manual: Bool = false

    enum CodingKeys: CodingKey {
        case enabled,
             name,
             url,
             manual
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.name, name)
        try container.encode(.url, url)
        try container.encode(.manual, manual)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        name = container.decode(.name, String.self, randomName())
        url = container.decode(.url, String.self, "")
        manual = container.decode(.manual, Bool.self, false)
    }
}

class SettingsMoblink: Codable {
    var streamer: SettingsMoblinkStreamer = .init()
    var relay: SettingsMoblinkRelay = .init()
    var password = "1234"

    enum CodingKeys: CodingKey {
        case server,
             client,
             password
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.server, streamer)
        try container.encode(.client, relay)
        try container.encode(.password, password)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streamer = container.decode(.server, SettingsMoblinkStreamer.self, .init())
        relay = container.decode(.client, SettingsMoblinkRelay.self, .init())
        password = container.decode(.password, String.self, "1234")
    }
}

enum SettingsExternalDisplayContent: String, Codable, CaseIterable {
    case stream = "Stream"
    case cleanStream = "Clean stream"
    case chat = "Chat"
    case mirror = "Mirror"

    init(from decoder: Decoder) throws {
        self = try SettingsExternalDisplayContent(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .stream
    }

    func toString() -> String {
        switch self {
        case .stream:
            return String(localized: "Stream")
        case .cleanStream:
            return String(localized: "Clean stream")
        case .chat:
            return String(localized: "Chat")
        case .mirror:
            return String(localized: "Mirror")
        }
    }
}

class WebBrowserBookmarkSettings: Identifiable, Codable, ObservableObject {
    var id: UUID = .init()
    @Published var url: String = "https://google.com"

    enum CodingKeys: CodingKey {
        case url
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.url, url)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = container.decode(.url, String.self, "https://google.com")
    }
}

class WebBrowserSettings: Codable, ObservableObject {
    @Published var home: String = "https://google.com"
    @Published var bookmarks: [WebBrowserBookmarkSettings] = []

    enum CodingKeys: CodingKey {
        case home,
             bookmarks
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.home, home)
        try container.encode(.bookmarks, bookmarks)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        home = container.decode(.home, String.self, "https://google.com")
        bookmarks = container.decode(.bookmarks, [WebBrowserBookmarkSettings].self, [])
    }
}

class DeepLinkCreatorStreamVideo: Codable, ObservableObject {
    @Published var resolution: SettingsStreamResolution = .r1920x1080
    @Published var fps: Int = 30
    @Published var bitrate: UInt32 = 5_000_000
    @Published var codec: SettingsStreamCodec = .h265hevc
    @Published var bFrames: Bool = false
    @Published var maxKeyFrameInterval: Int32 = 2

    enum CodingKeys: CodingKey {
        case resolution,
             fps,
             bitrate,
             codec,
             bFrames,
             maxKeyFrameInterval
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.resolution, resolution)
        try container.encode(.fps, fps)
        try container.encode(.bitrate, bitrate)
        try container.encode(.codec, codec)
        try container.encode(.bFrames, bFrames)
        try container.encode(.maxKeyFrameInterval, maxKeyFrameInterval)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resolution = container.decode(.resolution, SettingsStreamResolution.self, .r1920x1080)
        fps = container.decode(.fps, Int.self, 30)
        bitrate = container.decode(.bitrate, UInt32.self, 5_000_000)
        codec = container.decode(.codec, SettingsStreamCodec.self, .h265hevc)
        bFrames = container.decode(.bFrames, Bool.self, false)
        maxKeyFrameInterval = container.decode(.maxKeyFrameInterval, Int32.self, 2)
    }
}

class DeepLinkCreatorStreamAudio: Codable, ObservableObject {
    @Published var bitrate: Int = 128_000
    @Published var bitrateFloat: Float = 128

    enum CodingKeys: CodingKey {
        case bitrate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.bitrate, bitrate)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bitrate = container.decode(.bitrate, Int.self, 128_000)
        bitrateFloat = Float(bitrate / 1000)
    }
}

class DeepLinkCreatorStreamSrt: Codable, ObservableObject {
    @Published var latency: Int32 = defaultSrtLatency
    @Published var adaptiveBitrateEnabled: Bool = true
    @Published var dnsLookupStrategy: SettingsDnsLookupStrategy = .system

    enum CodingKeys: CodingKey {
        case latency,
             adaptiveBitrateEnabled,
             dnsLookupStrategy
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.latency, latency)
        try container.encode(.adaptiveBitrateEnabled, adaptiveBitrateEnabled)
        try container.encode(.dnsLookupStrategy, dnsLookupStrategy)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        latency = container.decode(.latency, Int32.self, defaultSrtLatency)
        adaptiveBitrateEnabled = container.decode(.adaptiveBitrateEnabled, Bool.self, true)
        dnsLookupStrategy = container.decode(.dnsLookupStrategy, SettingsDnsLookupStrategy.self, .system)
    }
}

class DeepLinkCreatorStreamObs: Codable, ObservableObject {
    @Published var webSocketUrl: String = ""
    @Published var webSocketPassword: String = ""

    enum CodingKeys: CodingKey {
        case webSocketUrl,
             webSocketPassword
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.webSocketUrl, webSocketUrl)
        try container.encode(.webSocketPassword, webSocketPassword)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        webSocketUrl = container.decode(.webSocketUrl, String.self, "")
        webSocketPassword = container.decode(.webSocketPassword, String.self, "")
    }
}

class DeepLinkCreatorStreamTwitch: Codable, ObservableObject {
    @Published var channelName: String = ""
    @Published var channelId: String = ""

    enum CodingKeys: CodingKey {
        case channelName,
             channelId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.channelName, channelName)
        try container.encode(.channelId, channelId)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        channelName = container.decode(.channelName, String.self, "")
        channelId = container.decode(.channelId, String.self, "")
    }
}

class DeepLinkCreatorStreamKick: Codable, ObservableObject {
    @Published var channelName: String = ""

    enum CodingKeys: CodingKey {
        case channelName
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.channelName, channelName)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        channelName = container.decode(.channelName, String.self, "")
    }
}

class DeepLinkCreatorStream: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My stream")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var url: String = defaultStreamUrl
    @Published var selected: Bool = false
    @Published var video: DeepLinkCreatorStreamVideo = .init()
    @Published var audio: DeepLinkCreatorStreamAudio = .init()
    @Published var srt: DeepLinkCreatorStreamSrt = .init()
    @Published var obs: DeepLinkCreatorStreamObs = .init()
    @Published var twitch: DeepLinkCreatorStreamTwitch = .init()
    @Published var kick: DeepLinkCreatorStreamKick = .init()

    enum CodingKeys: CodingKey {
        case id,
             name,
             url,
             selected,
             video,
             audio,
             srt,
             obs,
             twitch,
             kick
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.url, url)
        try container.encode(.selected, selected)
        try container.encode(.video, video)
        try container.encode(.audio, audio)
        try container.encode(.srt, srt)
        try container.encode(.obs, obs)
        try container.encode(.twitch, twitch)
        try container.encode(.kick, kick)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        url = container.decode(.url, String.self, defaultStreamUrl)
        selected = container.decode(.selected, Bool.self, false)
        video = container.decode(.video, DeepLinkCreatorStreamVideo.self, .init())
        audio = container.decode(.audio, DeepLinkCreatorStreamAudio.self, .init())
        srt = container.decode(.srt, DeepLinkCreatorStreamSrt.self, .init())
        obs = container.decode(.obs, DeepLinkCreatorStreamObs.self, .init())
        twitch = container.decode(.twitch, DeepLinkCreatorStreamTwitch.self, .init())
        kick = container.decode(.kick, DeepLinkCreatorStreamKick.self, .init())
    }
}

class DeepLinkCreatorQuickButton: Codable, Identifiable, ObservableObject {
    @Published var id: UUID = .init()
    @Published var type: SettingsQuickButtonType = .unknown
    @Published var enabled: Bool = false

    enum CodingKeys: CodingKey {
        case id,
             type,
             enabled
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.type, type)
        try container.encode(.enabled, enabled)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        type = container.decode(.type, SettingsQuickButtonType.self, .unknown)
        enabled = container.decode(.enabled, Bool.self, false)
    }
}

class DeepLinkCreatorQuickButtons: Codable, ObservableObject {
    @Published var twoColumns: Bool = true
    @Published var showName: Bool = true
    @Published var enableScroll: Bool = true
    @Published var buttons: [DeepLinkCreatorQuickButton] = []

    enum CodingKeys: CodingKey {
        case twoColumns,
             showName,
             enableScroll,
             buttons
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.twoColumns, twoColumns)
        try container.encode(.showName, showName)
        try container.encode(.enableScroll, enableScroll)
        try container.encode(.buttons, buttons)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        twoColumns = container.decode(.twoColumns, Bool.self, true)
        showName = container.decode(.showName, Bool.self, true)
        enableScroll = container.decode(.enableScroll, Bool.self, true)
        buttons = container.decode(.buttons, [DeepLinkCreatorQuickButton].self, [])
    }
}

class DeepLinkCreatorWebBrowser: Codable, ObservableObject {
    @Published var home: String = ""

    enum CodingKeys: CodingKey {
        case home
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.home, home)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        home = container.decode(.home, String.self, "")
    }
}

class DeepLinkCreator: Codable, ObservableObject {
    @Published var streams: [DeepLinkCreatorStream] = []
    @Published var quickButtonsEnabled: Bool = false
    @Published var quickButtons: DeepLinkCreatorQuickButtons = .init()
    @Published var webBrowserEnabled: Bool = false
    @Published var webBrowser: DeepLinkCreatorWebBrowser = .init()

    enum CodingKeys: CodingKey {
        case streams,
             quickButtonsEnabled,
             quickButtons,
             webBrowserEnabled,
             webBrowser
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.streams, streams)
        try container.encode(.quickButtonsEnabled, quickButtonsEnabled)
        try container.encode(.quickButtons, quickButtons)
        try container.encode(.webBrowserEnabled, webBrowserEnabled)
        try container.encode(.webBrowser, webBrowser)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streams = container.decode(.streams, [DeepLinkCreatorStream].self, [])
        quickButtonsEnabled = container.decode(.quickButtonsEnabled, Bool.self, false)
        quickButtons = container.decode(.quickButtons, DeepLinkCreatorQuickButtons.self, .init())
        webBrowserEnabled = container.decode(.webBrowserEnabled, Bool.self, false)
        webBrowser = container.decode(.webBrowser, DeepLinkCreatorWebBrowser.self, .init())
    }
}

class SettingsAlertsMediaGalleryItem: Codable, Identifiable {
    var id: UUID = .init()
    var name: String = ""

    init(name: String) {
        self.name = name
    }
}

private let allBundledAlertsMediaGalleryImages = [
    SettingsAlertsMediaGalleryItem(name: "Moblin pixels"),
    SettingsAlertsMediaGalleryItem(name: "Moblin party"),
    SettingsAlertsMediaGalleryItem(name: "Moblin trillionaire"),
    SettingsAlertsMediaGalleryItem(name: "White star"),
    SettingsAlertsMediaGalleryItem(name: "Angry"),
    SettingsAlertsMediaGalleryItem(name: "Sunglasses"),
    SettingsAlertsMediaGalleryItem(name: "Salty"),
    SettingsAlertsMediaGalleryItem(name: "-100"),
]

private let allBundledAlertsMediaGallerySounds = [
    SettingsAlertsMediaGalleryItem(name: "Notification 2"),
    SettingsAlertsMediaGalleryItem(name: "Boing"),
    SettingsAlertsMediaGalleryItem(name: "Cash register"),
    SettingsAlertsMediaGalleryItem(name: "Dingaling"),
    SettingsAlertsMediaGalleryItem(name: "Level up"),
    SettingsAlertsMediaGalleryItem(name: "Notification"),
    SettingsAlertsMediaGalleryItem(name: "SFX magic"),
    SettingsAlertsMediaGalleryItem(name: "Whoosh"),
    SettingsAlertsMediaGalleryItem(name: "Coin dropping"),
    SettingsAlertsMediaGalleryItem(name: "Fart"),
    SettingsAlertsMediaGalleryItem(name: "Fart 2"),
    SettingsAlertsMediaGalleryItem(name: "Bad chili fart"),
    SettingsAlertsMediaGalleryItem(name: "Perfect fart"),
    SettingsAlertsMediaGalleryItem(name: "Silence"),
]

class SettingsAlertsMediaGallery: Codable {
    var bundledImages = allBundledAlertsMediaGalleryImages
    var customImages: [SettingsAlertsMediaGalleryItem] = []
    var bundledSounds = allBundledAlertsMediaGallerySounds
    var customSounds: [SettingsAlertsMediaGalleryItem] = []
}

class SettingsDisconnectProtection: Codable, ObservableObject {
    @Published var liveSceneId: UUID?
    @Published var fallbackSceneId: UUID?

    enum CodingKeys: CodingKey {
        case liveSceneId,
             fallbackSceneId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.liveSceneId, liveSceneId)
        try container.encode(.fallbackSceneId, fallbackSceneId)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        liveSceneId = container.decode(.liveSceneId, UUID?.self, .init())
        fallbackSceneId = container.decode(.fallbackSceneId, UUID?.self, .init())
    }
}

class Database: Codable, ObservableObject {
    @Published var streams: [SettingsStream] = []
    @Published var scenes: [SettingsScene] = []
    @Published var widgets: [SettingsWidget] = []
    var show: SettingsShow = .init()
    var zoom: SettingsZoom = .init()
    @Published var tapToFocus: Bool = false
    @Published var bitratePresets: [SettingsBitratePreset] = []
    var iconImage: String = plainIcon.image()
    var videoStabilizationMode: SettingsVideoStabilizationMode = .off
    var chat: SettingsChat = .init()
    var mic: SettingsMic = getDefaultMic()
    var mics: SettingsMics = .init()
    var debug: SettingsDebug = .init()
    var quickButtonsGeneral: SettingsQuickButtons = .init()
    @Published var quickButtons: [SettingsQuickButton] = []
    var rtmpServer: SettingsRtmpServer = .init()
    @Published var networkInterfaceNames: [SettingsNetworkInterfaceName] = []
    @Published var lowBitrateWarning: Bool = true
    @Published var vibrate: Bool = false
    @Published var gameControllers: [SettingsGameController] = [.init()]
    var remoteControl: SettingsRemoteControl = .init()
    @Published var startStopRecordingConfirmations: Bool = true
    var color: SettingsColor = .init()
    @Published var mirrorFrontCameraOnStream: Bool = true
    var streamButtonColor: RgbColor = defaultStreamButtonColor
    @Published var streamButtonColorColor: Color = defaultStreamButtonColor.color()
    var location: SettingsLocation = .init()
    var watch: WatchSettings = .init()
    var audio: AudioSettings = .init()
    var webBrowser: WebBrowserSettings = .init()
    var deepLinkCreator: DeepLinkCreator = .init()
    var srtlaServer: SettingsSrtlaServer = .init()
    var mediaPlayers: SettingsMediaPlayers = .init()
    @Published var showAllSettings: Bool = false
    @Published var portrait: Bool = false
    var djiDevices: SettingsDjiDevices = .init()
    var alertsMediaGallery: SettingsAlertsMediaGallery = .init()
    var catPrinters: SettingsCatPrinters = .init()
    @Published var verboseStatuses: Bool = false
    @Published var scoreboardPlayers: [SettingsWidgetScoreboardPlayer] = .init()
    var keyboard: SettingsKeyboard = .init()
    var tesla: SettingsTesla = .init()
    var srtlaRelay: SettingsMoblink = .init()
    @Published var pixellateStrength: Float = 0.3
    var moblink: SettingsMoblink = .init()
    @Published var sceneSwitchTransition: SettingsSceneSwitchTransition = .blur
    @Published var forceSceneSwitchTransition: Bool = false
    @Published var cameraControlsEnabled: Bool = false
    @Published var externalDisplayContent: SettingsExternalDisplayContent = .stream
    var cyclingPowerDevices: SettingsCyclingPowerDevices = .init()
    var heartRateDevices: SettingsHeartRateDevices = .init()
    var blackSharkCoolerDevices: SettingsBlackSharkCoolerDevices = .init()
    var remoteSceneId: UUID?
    @Published var sceneNumericInput: Bool = false
    var goPro: SettingsGoPro = .init()
    var replay: SettingsReplay = .init()
    var portraitVideoOffsetFromTop: Double = 0.0
    var autoSceneSwitchers: SettingsAutoSceneSwitchers = .init()
    @Published var fixedHorizon: Bool = false
    @Published var whirlpoolAngle: Float = .pi / 2
    @Published var pinchScale: Float = 0.5
    var selfieStick: SettingsSelfieStick = .init()
    @Published var bigButtons: Bool = false
    var ristServer: SettingsRistServer = .init()
    var disconnectProtection: SettingsDisconnectProtection = .init()
    var rtspClient: SettingsRtspClient = .init()

    static func fromString(settings: String) throws -> Database {
        let database = try JSONDecoder().decode(
            Database.self,
            from: settings.data(using: .utf8)!
        )
        if database.zoom.back.isEmpty {
            addDefaultBackZoomPresets(database: database)
        }
        if database.zoom.front.isEmpty {
            addDefaultFrontZoomPresets(database: database)
        }
        if database.bitratePresets.isEmpty {
            addDefaultBitratePresets(database: database)
        }
        addMissingQuickButtons(database: database)
        for button in database.quickButtons where button.type != .interactiveChat && button.type != .cameraPreview {
            button.isOn = false
        }
        addMissingDeepLinkQuickButtons(database: database)
        addMissingBundledLuts(database: database)
        addMissingGoPro(database: database)
        return database
    }

    func toString() throws -> String {
        return try String.fromUtf8(data: JSONEncoder().encode(self))
    }

    enum CodingKeys: CodingKey {
        case streams,
             scenes,
             widgets,
             show,
             zoom,
             tapToFocus,
             bitratePresets,
             iconImage,
             videoStabilizationMode,
             chat,
             batteryPercentage,
             mic,
             mics,
             debug,
             quickButtons,
             globalButtons,
             rtmpServer,
             networkInterfaceNames,
             lowBitrateWarning,
             vibrate,
             gameControllers,
             remoteControl,
             startStopRecordingConfirmations,
             color,
             mirrorFrontCameraOnStream,
             streamButtonColor,
             location,
             watch,
             audio,
             webBrowser,
             deepLinkCreator,
             srtlaServer,
             mediaPlayers,
             showAllSettings,
             portrait,
             djiDevices,
             alertsMediaGallery,
             catPrinters,
             verboseStatuses,
             scoreboardPlayers,
             keyboard,
             tesla,
             srtlaRelay,
             pixellateStrength,
             moblink,
             sceneSwitchTransition,
             forceSceneSwitchTransition,
             cameraControlsEnabled,
             externalDisplayContent,
             cyclingPowerDevices,
             heartRateDevices,
             phoneCoolerDevices,
             remoteSceneId,
             sceneNumericInput,
             goPro,
             replay,
             portraitVideoOffsetFromTop,
             autoSceneSwitchers,
             fixedHorizon,
             whirlpoolAngle,
             pinchScale,
             selfieStick,
             bigButtons,
             ristServer,
             disconnectProtection,
             rtspClient
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.streams, streams)
        try container.encode(.scenes, scenes)
        try container.encode(.widgets, widgets)
        try container.encode(.show, show)
        try container.encode(.zoom, zoom)
        try container.encode(.tapToFocus, tapToFocus)
        try container.encode(.bitratePresets, bitratePresets)
        try container.encode(.iconImage, iconImage)
        try container.encode(.videoStabilizationMode, videoStabilizationMode)
        try container.encode(.chat, chat)
        try container.encode(.mic, mic)
        try container.encode(.mics, mics)
        try container.encode(.debug, debug)
        try container.encode(.quickButtons, quickButtonsGeneral)
        try container.encode(.globalButtons, quickButtons)
        try container.encode(.rtmpServer, rtmpServer)
        try container.encode(.networkInterfaceNames, networkInterfaceNames)
        try container.encode(.lowBitrateWarning, lowBitrateWarning)
        try container.encode(.vibrate, vibrate)
        try container.encode(.gameControllers, gameControllers)
        try container.encode(.remoteControl, remoteControl)
        try container.encode(.startStopRecordingConfirmations, startStopRecordingConfirmations)
        try container.encode(.color, color)
        try container.encode(.mirrorFrontCameraOnStream, mirrorFrontCameraOnStream)
        try container.encode(.streamButtonColor, streamButtonColor)
        try container.encode(.location, location)
        try container.encode(.watch, watch)
        try container.encode(.audio, audio)
        try container.encode(.webBrowser, webBrowser)
        try container.encode(.deepLinkCreator, deepLinkCreator)
        try container.encode(.srtlaServer, srtlaServer)
        try container.encode(.mediaPlayers, mediaPlayers)
        try container.encode(.showAllSettings, showAllSettings)
        try container.encode(.portrait, portrait)
        try container.encode(.djiDevices, djiDevices)
        try container.encode(.alertsMediaGallery, alertsMediaGallery)
        try container.encode(.catPrinters, catPrinters)
        try container.encode(.verboseStatuses, verboseStatuses)
        try container.encode(.scoreboardPlayers, scoreboardPlayers)
        try container.encode(.keyboard, keyboard)
        try container.encode(.tesla, tesla)
        try container.encode(.srtlaRelay, srtlaRelay)
        try container.encode(.pixellateStrength, pixellateStrength)
        try container.encode(.moblink, moblink)
        try container.encode(.sceneSwitchTransition, sceneSwitchTransition)
        try container.encode(.forceSceneSwitchTransition, forceSceneSwitchTransition)
        try container.encode(.cameraControlsEnabled, cameraControlsEnabled)
        try container.encode(.externalDisplayContent, externalDisplayContent)
        try container.encode(.cyclingPowerDevices, cyclingPowerDevices)
        try container.encode(.heartRateDevices, heartRateDevices)
        try container.encode(.phoneCoolerDevices, blackSharkCoolerDevices)
        try container.encode(.remoteSceneId, remoteSceneId)
        try container.encode(.sceneNumericInput, sceneNumericInput)
        try container.encode(.goPro, goPro)
        try container.encode(.replay, replay)
        try container.encode(.portraitVideoOffsetFromTop, portraitVideoOffsetFromTop)
        try container.encode(.autoSceneSwitchers, autoSceneSwitchers)
        try container.encode(.fixedHorizon, fixedHorizon)
        try container.encode(.whirlpoolAngle, whirlpoolAngle)
        try container.encode(.pinchScale, pinchScale)
        try container.encode(.selfieStick, selfieStick)
        try container.encode(.bigButtons, bigButtons)
        try container.encode(.ristServer, ristServer)
        try container.encode(.disconnectProtection, disconnectProtection)
        try container.encode(.rtspClient, rtspClient)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streams = container.decode(.streams, [SettingsStream].self, [])
        scenes = container.decode(.scenes, [SettingsScene].self, [])
        widgets = container.decode(.widgets, [SettingsWidget].self, [])
        show = container.decode(.show, SettingsShow.self, .init())
        zoom = container.decode(.zoom, SettingsZoom.self, .init())
        tapToFocus = container.decode(.tapToFocus, Bool.self, false)
        bitratePresets = container.decode(.bitratePresets, [SettingsBitratePreset].self, [])
        iconImage = container.decode(.iconImage, String.self, plainIcon.image())
        videoStabilizationMode = container.decode(.videoStabilizationMode, SettingsVideoStabilizationMode.self, .off)
        chat = container.decode(.chat, SettingsChat.self, .init())
        mic = container.decode(.mic, SettingsMic.self, getDefaultMic())
        mics = container.decode(.mics, SettingsMics.self, .init())
        debug = container.decode(.debug, SettingsDebug.self, .init())
        quickButtonsGeneral = container.decode(.quickButtons, SettingsQuickButtons.self, .init())
        quickButtons = container.decode(.globalButtons, [SettingsQuickButton].self, [])
        rtmpServer = container.decode(.rtmpServer, SettingsRtmpServer.self, .init())
        networkInterfaceNames = container.decode(.networkInterfaceNames, [SettingsNetworkInterfaceName].self, [])
        lowBitrateWarning = container.decode(.lowBitrateWarning, Bool.self, true)
        vibrate = container.decode(.vibrate, Bool.self, false)
        gameControllers = container.decode(.gameControllers, [SettingsGameController].self, [.init()])
        remoteControl = container.decode(.remoteControl, SettingsRemoteControl.self, .init())
        startStopRecordingConfirmations = container.decode(.startStopRecordingConfirmations, Bool.self, true)
        color = container.decode(.color, SettingsColor.self, .init())
        mirrorFrontCameraOnStream = container.decode(.mirrorFrontCameraOnStream, Bool.self, true)
        streamButtonColor = container.decode(.streamButtonColor, RgbColor.self, defaultStreamButtonColor)
        streamButtonColorColor = streamButtonColor.color()
        location = container.decode(.location, SettingsLocation.self, .init())
        watch = container.decode(.watch, WatchSettings.self, .init())
        audio = container.decode(.audio, AudioSettings.self, .init())
        webBrowser = container.decode(.webBrowser, WebBrowserSettings.self, .init())
        deepLinkCreator = container.decode(.deepLinkCreator, DeepLinkCreator.self, .init())
        srtlaServer = container.decode(.srtlaServer, SettingsSrtlaServer.self, .init())
        mediaPlayers = container.decode(.mediaPlayers, SettingsMediaPlayers.self, .init())
        showAllSettings = container.decode(.showAllSettings, Bool.self, false)
        portrait = container.decode(.portrait, Bool.self, false)
        djiDevices = container.decode(.djiDevices, SettingsDjiDevices.self, .init())
        alertsMediaGallery = container.decode(.alertsMediaGallery, SettingsAlertsMediaGallery.self, .init())
        catPrinters = container.decode(.catPrinters, SettingsCatPrinters.self, .init())
        verboseStatuses = container.decode(.verboseStatuses, Bool.self, false)
        scoreboardPlayers = container.decode(.scoreboardPlayers, [SettingsWidgetScoreboardPlayer].self, .init())
        keyboard = container.decode(.keyboard, SettingsKeyboard.self, .init())
        tesla = container.decode(.tesla, SettingsTesla.self, .init())
        srtlaRelay = container.decode(.srtlaRelay, SettingsMoblink.self, .init())
        pixellateStrength = container.decode(.pixellateStrength, Float.self, 0.3)
        moblink = container.decode(.moblink, SettingsMoblink.self, srtlaRelay)
        sceneSwitchTransition = container.decode(.sceneSwitchTransition, SettingsSceneSwitchTransition.self, .blur)
        forceSceneSwitchTransition = container.decode(.forceSceneSwitchTransition, Bool.self, false)
        cameraControlsEnabled = container.decode(.cameraControlsEnabled, Bool.self, false)
        externalDisplayContent = container.decode(.externalDisplayContent, SettingsExternalDisplayContent.self, .stream)
        cyclingPowerDevices = container.decode(.cyclingPowerDevices, SettingsCyclingPowerDevices.self, .init())
        heartRateDevices = container.decode(.heartRateDevices, SettingsHeartRateDevices.self, .init())
        blackSharkCoolerDevices = container.decode(.phoneCoolerDevices, SettingsBlackSharkCoolerDevices.self, .init())
        remoteSceneId = try? container.decode(UUID?.self, forKey: .remoteSceneId)
        sceneNumericInput = container.decode(.sceneNumericInput, Bool.self, false)
        goPro = container.decode(.goPro, SettingsGoPro.self, .init())
        replay = container.decode(.replay, SettingsReplay.self, .init())
        portraitVideoOffsetFromTop = container.decode(.portraitVideoOffsetFromTop, Double.self, 0.0)
        autoSceneSwitchers = container.decode(.autoSceneSwitchers, SettingsAutoSceneSwitchers.self, .init())
        fixedHorizon = container.decode(.fixedHorizon, Bool.self, false)
        whirlpoolAngle = container.decode(.whirlpoolAngle, Float.self, .pi / 2)
        pinchScale = container.decode(.pinchScale, Float.self, 0.5)
        selfieStick = container.decode(.selfieStick, SettingsSelfieStick.self, .init())
        bigButtons = container.decode(.bigButtons, Bool.self, false)
        ristServer = container.decode(.ristServer, SettingsRistServer.self, .init())
        disconnectProtection = container.decode(.disconnectProtection, SettingsDisconnectProtection.self, .init())
        rtspClient = container.decode(.rtspClient, SettingsRtspClient.self, .init())
    }
}

private func addDefaultScenes(database: Database) {
    var scene = SettingsScene(name: String(localized: "Back"))
    scene.cameraPosition = getDefaultBackCameraPosition()
    scene.backCameraId = getBestBackCameraId()
    database.scenes.append(scene)

    scene = SettingsScene(name: String(localized: "Front"))
    scene.cameraPosition = .front
    scene.frontCameraId = getBestFrontCameraId()
    database.scenes.append(scene)
}

private func addDefaultZoomPresets(database: Database) {
    database.zoom = .init()
    addDefaultBackZoomPresets(database: database)
    addDefaultFrontZoomPresets(database: database)
}

private func addDefaultBackZoomPresets(database: Database) {
    if let device = getBestBackCameraDevice() {
        let hasUltraWideCamera = hasUltraWideBackCamera()
        let scale = device.getZoomFactorScale(hasUltraWideCamera: hasUltraWideCamera)
        var xs: [Float] = []
        if hasUltraWideCamera {
            xs.append(0.5)
        } else {
            xs.append(1.0)
        }
        for factor in device.virtualDeviceSwitchOverVideoZoomFactors {
            let x = (Float(truncating: factor) * scale).rounded()
            if let prevX = xs.last {
                if (x / prevX) >= 4 {
                    xs.append(2 * prevX)
                }
            }
            xs.append(x)
        }
        xs.append(2 * xs.last!)
        database.zoom.back = []
        for x in xs {
            let nameX = x < 1 ? formatOneDecimal(x) : String(Int(x))
            database.zoom.back.append(SettingsZoomPreset(
                id: UUID(),
                name: "\(nameX)x",
                x: x
            ))
        }
    } else {
        database.zoom.back = [
            SettingsZoomPreset(id: UUID(), name: "0.5x", x: 0.5),
            SettingsZoomPreset(id: UUID(), name: "1x", x: 1.0),
            SettingsZoomPreset(id: UUID(), name: "2x", x: 2.0),
            SettingsZoomPreset(id: UUID(), name: "4x", x: 4.0),
            SettingsZoomPreset(id: UUID(), name: "8x", x: 8.0),
        ]
    }
}

private func addDefaultFrontZoomPresets(database: Database) {
    database.zoom.front = [
        SettingsZoomPreset(id: UUID(), name: "0.5x", x: 0.5),
        SettingsZoomPreset(id: UUID(), name: "1x", x: 1.0),
        SettingsZoomPreset(id: UUID(), name: "2x", x: 2.0),
        SettingsZoomPreset(id: UUID(), name: "4x", x: 4.0),
        SettingsZoomPreset(id: UUID(), name: "8x", x: 8.0),
    ]
}

private func addDefaultBitratePresets(database: Database) {
    database.bitratePresets = [
        SettingsBitratePreset(id: UUID(), bitrate: 15_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 12_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 9_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 7_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 6_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 5_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 4_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 3_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 2_000_000),
        SettingsBitratePreset(id: UUID(), bitrate: 1_000_000),
    ]
}

private func updateQuickButton(database: Database, button: SettingsQuickButton) {
    let existingButton = database.quickButtons.first(where: { globalButton in
        globalButton.type == button.type
    })
    if let existingButton {
        existingButton.name = button.name
        existingButton.systemImageNameOn = button.systemImageNameOn
        existingButton.systemImageNameOff = button.systemImageNameOff
    } else {
        database.quickButtons.append(button)
    }
}

private func quickButtonPageTwo() -> Int {
    if #available(iOS 17, *) {
        return 2
    } else {
        return 1
    }
}

private func addMissingQuickButtons(database: Database) {
    var button = SettingsQuickButton(name: String(localized: "Torch"))
    button.id = UUID()
    button.type = .torch
    button.systemImageNameOn = "flashlight.on.fill"
    button.systemImageNameOff = "flashlight.off.fill"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Mute"))
    button.id = UUID()
    button.type = .mute
    button.systemImageNameOn = "mic.slash"
    button.systemImageNameOff = "mic"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Bitrate"))
    button.id = UUID()
    button.type = .bitrate
    button.systemImageNameOn = "speedometer"
    button.systemImageNameOff = "speedometer"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Mic"))
    button.id = UUID()
    button.type = .mic
    button.systemImageNameOn = "music.mic"
    button.systemImageNameOff = "music.mic"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Chat"))
    button.id = UUID()
    button.type = .chat
    button.systemImageNameOn = "message.fill"
    button.systemImageNameOff = "message"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Interactive chat"))
    button.id = UUID()
    button.isOn = true
    button.type = .interactiveChat
    button.systemImageNameOn = "arrow.up.message.fill"
    button.systemImageNameOff = "arrow.up.message"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Stealth mode"))
    button.id = UUID()
    button.type = .blackScreen
    button.systemImageNameOn = "sunset.fill"
    button.systemImageNameOff = "sunset"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Lock screen"))
    button.id = UUID()
    button.type = .lockScreen
    button.systemImageNameOn = "lock.fill"
    button.systemImageNameOff = "lock"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Record"))
    button.id = UUID()
    button.type = .record
    button.systemImageNameOn = "record.circle.fill"
    button.systemImageNameOff = "record.circle"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Stream"))
    button.id = UUID()
    button.type = .stream
    button.systemImageNameOn = "dot.radiowaves.left.and.right"
    button.systemImageNameOff = "dot.radiowaves.left.and.right"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Recordings"))
    button.id = UUID()
    button.type = .recordings
    button.systemImageNameOn = "photo.on.rectangle.angled.fill"
    button.systemImageNameOff = "photo.on.rectangle.angled"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Snapshot"))
    button.id = UUID()
    button.type = .snapshot
    button.systemImageNameOn = "camera.aperture"
    button.systemImageNameOff = "camera.aperture"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Replay"))
    button.id = UUID()
    button.type = .replay
    button.systemImageNameOn = "play.fill"
    button.systemImageNameOff = "play"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Instant replay"))
    button.id = UUID()
    button.type = .instantReplay
    button.systemImageNameOn = "memories"
    button.systemImageNameOff = "memories"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "OBS"))
    button.id = UUID()
    button.type = .obs
    button.systemImageNameOn = "xserve"
    button.systemImageNameOff = "xserve"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Remote"))
    button.id = UUID()
    button.type = .remote
    button.systemImageNameOn = "appletvremote.gen1.fill"
    button.systemImageNameOff = "appletvremote.gen1"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Scene widgets"))
    button.id = UUID()
    button.type = .widgets
    button.systemImageNameOn = "photo.on.rectangle.fill"
    button.systemImageNameOff = "photo.on.rectangle"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Auto scene switcher"))
    button.id = UUID()
    button.type = .autoSceneSwitcher
    button.systemImageNameOn = "autostartstop"
    button.systemImageNameOff = "autostartstop"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Draw"))
    button.id = UUID()
    button.type = .draw
    button.systemImageNameOn = "pencil.line"
    button.systemImageNameOff = "pencil.line"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Camera"))
    button.id = UUID()
    button.type = .image
    button.systemImageNameOn = "camera.fill"
    button.systemImageNameOff = "camera"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Browser"))
    button.id = UUID()
    button.type = .browser
    button.systemImageNameOn = "globe"
    button.systemImageNameOff = "globe"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Grid"))
    button.id = UUID()
    button.type = .grid
    button.systemImageNameOn = "grid"
    button.systemImageNameOff = "grid"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Camera level"))
    button.id = UUID()
    button.type = .cameraLevel
    button.systemImageNameOn = "level.fill"
    button.systemImageNameOff = "level"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Face"))
    button.id = UUID()
    button.type = .face
    button.systemImageNameOn = "theatermask.and.paintbrush.fill"
    button.systemImageNameOff = "theatermask.and.paintbrush"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Movie"))
    button.id = UUID()
    button.type = .movie
    button.page = quickButtonPageTwo()
    button.systemImageNameOn = "film.fill"
    button.systemImageNameOff = "film"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "4:3"))
    button.id = UUID()
    button.type = .fourThree
    button.page = quickButtonPageTwo()
    button.systemImageNameOn = "square.fill"
    button.systemImageNameOff = "square"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Gray scale"))
    button.id = UUID()
    button.type = .grayScale
    button.page = quickButtonPageTwo()
    button.systemImageNameOn = "moon.fill"
    button.systemImageNameOff = "moon"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Sepia"))
    button.id = UUID()
    button.type = .sepia
    button.page = quickButtonPageTwo()
    button.systemImageNameOn = "moonphase.waxing.crescent.inverse"
    button.systemImageNameOff = "moonphase.waning.crescent"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Triple"))
    button.id = UUID()
    button.type = .triple
    button.page = quickButtonPageTwo()
    button.systemImageNameOn = "person.3.fill"
    button.systemImageNameOff = "person.3"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Twin"))
    button.id = UUID()
    button.type = .twin
    button.page = quickButtonPageTwo()
    button.systemImageNameOn = "person.2.fill"
    button.systemImageNameOff = "person.2"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Pixellate"))
    button.id = UUID()
    button.type = .pixellate
    button.systemImageNameOn = "squareshape.split.2x2"
    button.systemImageNameOff = "squareshape.split.2x2"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Whirlpool"))
    button.id = UUID()
    button.type = .whirlpool
    button.page = quickButtonPageTwo()
    button.systemImageNameOn = "tornado"
    button.systemImageNameOff = "tornado"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Pinch"))
    button.id = UUID()
    button.type = .pinch
    button.page = quickButtonPageTwo()
    button.systemImageNameOn = "hand.pinch.fill"
    button.systemImageNameOff = "hand.pinch"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Local overlays"))
    button.id = UUID()
    button.type = .localOverlays
    button.systemImageNameOn = "square.stack.3d.up.slash.fill"
    button.systemImageNameOff = "square.stack.3d.up.slash"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Poll"))
    button.id = UUID()
    button.type = .poll
    button.systemImageNameOn = "chart.bar.xaxis"
    button.systemImageNameOff = "chart.bar.xaxis"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "LUTs"))
    button.id = UUID()
    button.type = .luts
    button.systemImageNameOn = "camera.filters"
    button.systemImageNameOff = "camera.filters"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Workout"))
    button.id = UUID()
    button.type = .workout
    button.systemImageNameOn = "figure.run"
    button.systemImageNameOff = "figure.run"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Skip current TTS"))
    button.id = UUID()
    button.type = .skipCurrentTts
    button.systemImageNameOn = "waveform.slash"
    button.systemImageNameOff = "waveform.slash"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Pause TTS"))
    button.id = UUID()
    button.type = .pauseTts
    button.systemImageNameOn = "waveform.badge.xmark"
    button.systemImageNameOff = "waveform.badge.xmark"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Ads"))
    button.id = UUID()
    button.type = .ads
    button.systemImageNameOn = "cup.and.saucer.fill"
    button.systemImageNameOff = "cup.and.saucer"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Stream marker"))
    button.id = UUID()
    button.type = .streamMarker
    button.systemImageNameOn = "bookmark.fill"
    button.systemImageNameOff = "bookmark"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Reload browser widgets"))
    button.id = UUID()
    button.type = .reloadBrowserWidgets
    button.systemImageNameOn = "arrow.clockwise"
    button.systemImageNameOff = "arrow.clockwise"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "DJI devices"))
    button.id = UUID()
    button.type = .djiDevices
    button.systemImageNameOn = "appletvremote.gen1.fill"
    button.systemImageNameOff = "appletvremote.gen1"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "GoPro"))
    button.id = UUID()
    button.type = .goPro
    button.systemImageNameOn = "appletvremote.gen1.fill"
    button.systemImageNameOff = "appletvremote.gen1"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Camera preview"))
    button.id = UUID()
    button.type = .cameraPreview
    button.systemImageNameOn = "camera.rotate.fill"
    button.systemImageNameOff = "camera.rotate"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Portrait"))
    button.id = UUID()
    button.type = .portrait
    button.systemImageNameOn = "rectangle.portrait.rotate"
    button.systemImageNameOff = "rectangle.portrait.rotate"
    updateQuickButton(database: database, button: button)

    button = SettingsQuickButton(name: String(localized: "Connection priorities"))
    button.id = UUID()
    button.type = .connectionPriorities
    button.systemImageNameOn = "phone.connection.fill"
    button.systemImageNameOff = "phone.connection"
    updateQuickButton(database: database, button: button)

    database.quickButtons = database.quickButtons.filter { button in
        if button.type == .unknown {
            return false
        }
        if button.type == .workout, !isPhone() {
            return false
        }
        if button.type == .portrait, isMac() {
            return false
        }
        return true
    }
}

private func addMissingDeepLinkQuickButtons(database: Database) {
    let quickButtons = database.deepLinkCreator.quickButtons
    for quickButton in database.quickButtons where quickButton.type != .lut {
        let button = DeepLinkCreatorQuickButton()
        let buttonExists = quickButtons.buttons.contains(where: { button in
            quickButton.type == button.type
        })
        if !buttonExists {
            button.type = quickButton.type
            quickButtons.buttons.append(button)
        }
    }
    quickButtons.buttons = quickButtons.buttons.filter { button in
        button.type != .unknown
    }
}

private func addMissingBundledLuts(database: Database) {
    var bundledLuts: [SettingsColorLut] = []
    for lut in allBundledLuts {
        if let existingLut = database.color.bundledLuts.first(where: { $0.name == lut.name }) {
            bundledLuts.append(existingLut)
        } else {
            bundledLuts.append(lut)
        }
    }
    database.color.bundledLuts = bundledLuts
}

private func addMissingGoPro(database: Database) {
    let goPro = database.goPro
    if goPro.launchLiveStream.isEmpty {
        goPro.launchLiveStream = [.init()]
        goPro.selectedLaunchLiveStream = goPro.launchLiveStream.first?.id
    }
}

private func updateBundledAlertsMediaGallery(database: Database) {
    var bundledImages: [SettingsAlertsMediaGalleryItem] = []
    for image in allBundledAlertsMediaGalleryImages {
        if let existingImage = database.alertsMediaGallery.bundledImages
            .first(where: { $0.name == image.name })
        {
            bundledImages.append(existingImage)
        } else {
            bundledImages.append(image)
        }
    }
    database.alertsMediaGallery.bundledImages = bundledImages
    var bundledSounds: [SettingsAlertsMediaGalleryItem] = []
    for sound in allBundledAlertsMediaGallerySounds {
        if let existingSound = database.alertsMediaGallery.bundledSounds
            .first(where: { $0.name == sound.name })
        {
            bundledSounds.append(existingSound)
        } else {
            bundledSounds.append(sound)
        }
    }
    database.alertsMediaGallery.bundledSounds = bundledSounds
}

private func addScenesToGameController(database: Database) {
    var button = database.gameControllers[0].buttons[0]
    button.function = .scene
    button.sceneId = database.scenes[0].id
    button = database.gameControllers[0].buttons[1]
    button.function = .scene
    button.sceneId = database.scenes[1].id
}

func getDefaultMic() -> SettingsMic {
    if isMac() {
        return .bottom
    }
    let session = AVAudioSession.sharedInstance()
    for inputPort in session.availableInputs ?? [] {
        if inputPort.portType != .builtInMic {
            continue
        }
        if let dataSources = inputPort.dataSources, !dataSources.isEmpty {
            for dataSource in dataSources {
                if dataSource.orientation == .bottom {
                    return .bottom
                } else if dataSource.orientation == .top {
                    return .top
                }
            }
        }
    }
    return .bottom
}

private func createDefault() -> Database {
    let database = Database()
    addDefaultScenes(database: database)
    addDefaultZoomPresets(database: database)
    addDefaultBitratePresets(database: database)
    addMissingQuickButtons(database: database)
    addMissingDeepLinkQuickButtons(database: database)
    addScenesToGameController(database: database)
    addMissingBundledLuts(database: database)
    return database
}

final class Settings {
    private var realDatabase = Database()
    var database: Database {
        realDatabase
    }

    @AppStorage("settings") var storage = ""

    func load() -> Bool {
        do {
            try tryLoadAndMigrate(settings: storage)
            return true
        } catch {
            logger.info("settings: Failed to load with error \(error). Using default.")
            realDatabase = createDefault()
            return storage.isEmpty
        }
    }

    private func tryLoadAndMigrate(settings: String) throws {
        realDatabase = try Database.fromString(settings: settings)
        addSensitiveData(database: realDatabase)
        migrateFromOlderVersions()
    }

    func store() {
        do {
            let database = extractSensitiveData(fromDatabase: realDatabase)
            storage = try realDatabase.toString()
            insertSensitiveData(toDatabase: realDatabase, fromDatabase: database)
        } catch {
            logger.error("settings: Failed to store.")
        }
    }

    func reset() {
        realDatabase = createDefault()
        store()
    }

    func importFromClipboard() -> String? {
        guard let settings = UIPasteboard.general.string else {
            return String(localized: "Empty clipboard")
        }
        do {
            try tryLoadAndMigrate(settings: settings)
        } catch {
            return String(localized: "Malformed settings")
        }
        store()
        return nil
    }

    func exportToClipboard() {
        store()
        UIPasteboard.general.string = storage
    }

    private func addSensitiveData(database: Database) {
        for stream in database.streams {
            if let accessToken = loadTwitchAccessTokenFromKeychain(streamId: stream.id) {
                stream.twitchAccessToken = accessToken
            }
        }
    }

    private func extractSensitiveData(fromDatabase: Database) -> Database {
        let toDatabase = Database()
        for fromStream in fromDatabase.streams {
            let toStream = SettingsStream(name: "")
            toStream.twitchAccessToken = fromStream.twitchAccessToken
            fromStream.twitchAccessToken = ""
            toDatabase.streams.append(toStream)
        }
        return toDatabase
    }

    private func insertSensitiveData(toDatabase: Database, fromDatabase: Database) {
        for (index, fromStream) in fromDatabase.streams.enumerated() where index < toDatabase.streams.count {
            toDatabase.streams[index].twitchAccessToken = fromStream.twitchAccessToken
        }
    }

    private func migrateFromOlderVersions() {
        updateBundledAlertsMediaGallery(database: realDatabase)
        let newButtons = realDatabase.quickButtons.filter { $0.type != .lut }
        if realDatabase.quickButtons.count != newButtons.count {
            realDatabase.quickButtons = newButtons
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource.cropX > 1.0 {
            widget.videoSource.cropX = 0.0
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource.cropY > 1.0 {
            widget.videoSource.cropY = 0.0
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource.cropWidth > 1.0 {
            widget.videoSource.cropWidth = 1.0
            store()
        }
        for widget in realDatabase.widgets where widget.videoSource.cropHeight > 1.0 {
            widget.videoSource.cropHeight = 1.0
            store()
        }
        for scene in realDatabase.scenes {
            for sceneWidget in scene.widgets where !sceneWidget.migrated {
                sceneWidget.migrated = true
                store()
                guard let widget = realDatabase.widgets.first(where: { $0.id == sceneWidget.widgetId }) else {
                    continue
                }
                guard widget.type == .text else {
                    continue
                }
                if widget.text.verticalAlignment == .bottom, widget.text.horizontalAlignment == .trailing {
                    sceneWidget.alignment = .bottomRight
                    sceneWidget.x = 100 - sceneWidget.x
                    sceneWidget.xString = String(sceneWidget.x)
                    sceneWidget.y = 100 - sceneWidget.y
                    sceneWidget.yString = String(sceneWidget.y)
                } else if widget.text.verticalAlignment == .top, widget.text.horizontalAlignment == .trailing {
                    sceneWidget.alignment = .topRight
                    sceneWidget.x = 100 - sceneWidget.x
                    sceneWidget.xString = String(sceneWidget.x)
                } else if widget.text.verticalAlignment == .bottom, widget.text.horizontalAlignment == .leading {
                    sceneWidget.alignment = .bottomLeft
                    sceneWidget.y = 100 - sceneWidget.y
                    sceneWidget.yString = String(sceneWidget.y)
                }
            }
        }
    }
}
