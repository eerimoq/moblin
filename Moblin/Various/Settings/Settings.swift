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

class SettingsColorLut: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var type: SettingsColorLutType = .bundled
    @Published var name: String = ""
    @Published var enabled: Bool = false

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
    @Published var systemMonitor: Bool = false

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
        try container.encode(.cpu, systemMonitor)
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
        systemMonitor = container.decode(.cpu, Bool.self, false)
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

var videoStabilizationModes = SettingsVideoStabilizationMode.allCases.filter {
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

class SettingsNetworkInterfaceName: Codable, Identifiable {
    var id: UUID = .init()
    var interfaceName: String = ""
    var name: String = ""
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
    var navigation: SettingsNavigation = .init()

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
             rtspClient,
             navigation
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
        try container.encode(.navigation, navigation)
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
        navigation = container.decode(.navigation, SettingsNavigation.self, .init())
    }
}

private func addDefaultScenes(database: Database) {
    var scene = SettingsScene(name: String(localized: "Back"))
    scene.videoSource.cameraPosition = defaultBackCameraPosition
    scene.videoSource.backCameraId = bestBackCameraId
    database.scenes.append(scene)
    scene = SettingsScene(name: String(localized: "Front"))
    scene.videoSource.cameraPosition = .front
    scene.videoSource.frontCameraId = bestFrontCameraId
    database.scenes.append(scene)
}

private func addDefaultZoomPresets(database: Database) {
    database.zoom = .init()
    addDefaultBackZoomPresets(database: database)
    addDefaultFrontZoomPresets(database: database)
}

private func addDefaultBackZoomPresets(database: Database) {
    if let device = bestBackCameraDevice {
        let hasUltraWideCamera = hasUltraWideBackCamera
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
    let existingButton = database.quickButtons.first(where: { $0.type == button.type })
    if let existingButton {
        existingButton.name = button.name
        existingButton.imageOn = button.imageOn
        existingButton.imageOff = button.imageOff
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

private func quickButtonPageThree() -> Int {
    if #available(iOS 17, *) {
        return 3
    } else {
        return 1
    }
}

private func addMissingQuickButtonsPageOne(database: Database) {
    var button = SettingsQuickButton(name: String(localized: "Torch"),
                                     type: .torch,
                                     imageOn: "flashlight.on.fill",
                                     imageOff: "flashlight.off.fill")
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Mute"),
                                 type: .mute,
                                 imageOn: "mic.slash",
                                 imageOff: "mic")
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Stream"),
                                 type: .live,
                                 imageOn: "dot.radiowaves.left.and.right")
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Mic"),
                                 type: .mic,
                                 imageOn: "music.mic")
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Record"),
                                 type: .record,
                                 imageOn: "record.circle.fill",
                                 imageOff: "record.circle")
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Snapshot"),
                                 type: .snapshot,
                                 imageOn: "camera.aperture")
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Scene widgets"),
                                 type: .widgets,
                                 imageOn: "photo.on.rectangle.fill",
                                 imageOff: "photo.on.rectangle")
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Local overlays"),
                                 type: .localOverlays,
                                 imageOn: "square.stack.3d.up.slash.fill",
                                 imageOff: "square.stack.3d.up.slash")
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "OBS"),
                                 type: .obs,
                                 imageOn: "xserve")
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Remote"),
                                 type: .remote,
                                 imageOn: "appletvremote.gen1.fill",
                                 imageOff: "appletvremote.gen1")
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Stealth mode"),
                                 type: .blackScreen,
                                 imageOn: "sunset.fill",
                                 imageOff: "sunset")
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Lock screen"),
                                 type: .lockScreen,
                                 imageOn: "lock.fill",
                                 imageOff: "lock")
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Chat"),
                                 type: .chat,
                                 imageOn: "message.fill",
                                 imageOff: "message")
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Poll"),
                                 type: .poll,
                                 imageOn: "chart.bar.xaxis")
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Replay"),
                                 type: .replay,
                                 imageOn: "play.fill",
                                 imageOff: "play")
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Instant replay"),
                                 type: .instantReplay,
                                 imageOn: "memories")
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "DJI devices"),
                                 type: .djiDevices,
                                 imageOn: "appletvremote.gen1.fill",
                                 imageOff: "appletvremote.gen1")
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "GoPro"),
                                 type: .goPro,
                                 imageOn: "appletvremote.gen1.fill",
                                 imageOff: "appletvremote.gen1")
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Camera"),
                                 type: .image,
                                 imageOn: "camera.fill",
                                 imageOff: "camera")
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Camera preview"),
                                 type: .cameraPreview,
                                 imageOn: "camera.rotate.fill",
                                 imageOff: "camera.rotate")
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Bitrate"),
                                 type: .bitrate,
                                 imageOn: "speedometer")
    updateQuickButton(database: database, button: button)
}

private func addMissingQuickButtonsPageTwo(database: Database) {
    let page = quickButtonPageTwo()
    var button = SettingsQuickButton(name: String(localized: "Draw"),
                                     type: .draw,
                                     imageOn: "pencil.line",
                                     page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Face"),
                                 type: .face,
                                 imageOn: "theatermask.and.paintbrush.fill",
                                 imageOff: "theatermask.and.paintbrush",
                                 page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "LUTs"),
                                 type: .luts,
                                 imageOn: "camera.filters",
                                 page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Pixellate"),
                                 type: .pixellate,
                                 imageOn: "squareshape.split.2x2",
                                 page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Whirlpool"),
                                 type: .whirlpool,
                                 imageOn: "tornado",
                                 page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Pinch"),
                                 type: .pinch,
                                 imageOn: "hand.pinch.fill",
                                 imageOff: "hand.pinch",
                                 page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Movie"),
                                 type: .movie,
                                 imageOn: "film.fill",
                                 imageOff: "film",
                                 page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "4:3"),
                                 type: .fourThree,
                                 imageOn: "square.fill",
                                 imageOff: "square",
                                 page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Gray scale"),
                                 type: .grayScale,
                                 imageOn: "moon.fill",
                                 imageOff: "moon",
                                 page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Sepia"),
                                 type: .sepia,
                                 imageOn: "moonphase.waxing.crescent.inverse",
                                 imageOff: "moonphase.waning.crescent",
                                 page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Triple"),
                                 type: .triple,
                                 imageOn: "person.3.fill",
                                 imageOff: "person.3",
                                 page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Twin"),
                                 type: .twin,
                                 imageOn: "person.2.fill",
                                 imageOff: "person.2",
                                 page: page)
    updateQuickButton(database: database, button: button)
}

private func addMissingQuickButtonsPageThree(database: Database) {
    let page = quickButtonPageThree()
    var button = SettingsQuickButton(name: String(localized: "Interactive chat"),
                                     type: .interactiveChat,
                                     imageOn: "arrow.up.message.fill",
                                     imageOff: "arrow.up.message",
                                     isOn: true,
                                     page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Auto scene switcher"),
                                 type: .autoSceneSwitcher,
                                 imageOn: "autostartstop",
                                 page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Recordings"),
                                 type: .recordings,
                                 imageOn: "photo.on.rectangle.angled.fill",
                                 imageOff: "photo.on.rectangle.angled",
                                 page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Switch stream"),
                                 type: .stream,
                                 imageOn: "arrow.left.arrow.right",
                                 page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Grid"),
                                 type: .grid,
                                 imageOn: "grid",
                                 page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Camera level"),
                                 type: .cameraLevel,
                                 imageOn: "level.fill",
                                 imageOff: "level",
                                 page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Browser"),
                                 type: .browser,
                                 imageOn: "globe",
                                 page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Workout"),
                                 type: .workout,
                                 imageOn: "figure.run",
                                 page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Skip current TTS"),
                                 type: .skipCurrentTts,
                                 imageOn: "waveform.slash",
                                 page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Pause TTS"),
                                 type: .pauseTts,
                                 imageOn: "waveform.badge.xmark",
                                 page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Ads"),
                                 type: .ads,
                                 imageOn: "cup.and.saucer.fill",
                                 imageOff: "cup.and.saucer",
                                 page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Stream marker"),
                                 type: .streamMarker,
                                 imageOn: "bookmark.fill",
                                 imageOff: "bookmark",
                                 page: page)
    updateQuickButton(database: database, button: button)
    if #available(iOS 26, *) {
        button = SettingsQuickButton(name: String(localized: "Navigation"),
                                     type: .navigation,
                                     imageOn: "arrow.trianglehead.turn.up.right.circle",
                                     page: page)
        updateQuickButton(database: database, button: button)
    }
    button = SettingsQuickButton(name: String(localized: "Reload browser widgets"),
                                 type: .reloadBrowserWidgets,
                                 imageOn: "arrow.clockwise",
                                 page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Portrait"),
                                 type: .portrait,
                                 imageOn: "rectangle.portrait.rotate",
                                 page: page)
    updateQuickButton(database: database, button: button)
    button = SettingsQuickButton(name: String(localized: "Connection priorities"),
                                 type: .connectionPriorities,
                                 imageOn: "phone.connection.fill",
                                 imageOff: "phone.connection",
                                 page: page)
    updateQuickButton(database: database, button: button)
}

private func addMissingQuickButtons(database: Database) {
    addMissingQuickButtonsPageOne(database: database)
    addMissingQuickButtonsPageTwo(database: database)
    addMissingQuickButtonsPageThree(database: database)
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
        let buttonExists = quickButtons.buttons.contains(where: { quickButton.type == $0.type })
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
        if let existingSound = database.alertsMediaGallery.bundledSounds.first(where: { $0.name == sound.name }) {
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
                    sceneWidget.layout.alignment = .bottomRight
                    sceneWidget.layout.x = 100 - sceneWidget.layout.x
                    sceneWidget.layout.updateXString()
                    sceneWidget.layout.y = 100 - sceneWidget.layout.y
                    sceneWidget.layout.updateYString()
                } else if widget.text.verticalAlignment == .top, widget.text.horizontalAlignment == .trailing {
                    sceneWidget.layout.alignment = .topRight
                    sceneWidget.layout.x = 100 - sceneWidget.layout.x
                    sceneWidget.layout.updateXString()
                } else if widget.text.verticalAlignment == .bottom, widget.text.horizontalAlignment == .leading {
                    sceneWidget.layout.alignment = .bottomLeft
                    sceneWidget.layout.y = 100 - sceneWidget.layout.y
                    sceneWidget.layout.updateYString()
                }
            }
        }
        for scene in realDatabase.scenes {
            for sceneWidget in scene.widgets where !sceneWidget.migrated2 {
                sceneWidget.migrated2 = true
                store()
                guard let widget = realDatabase.widgets.first(where: { $0.id == sceneWidget.widgetId }) else {
                    continue
                }
                guard widget.type == .browser else {
                    continue
                }
                guard let stream = database.streams.first(where: { $0.enabled }) else {
                    continue
                }
                let resolution = stream.resolution.dimensions(portrait: stream.portrait)
                let width = (100 * Double(widget.browser.width) / Double(resolution.width)).clamped(to: 1 ... 100)
                let height = (100 * Double(widget.browser.height) / Double(resolution.height)).clamped(to: 1 ... 100)
                sceneWidget.layout.size = max(width, height)
                sceneWidget.layout.updateSizeString()
            }
        }
    }
}
