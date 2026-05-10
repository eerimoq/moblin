import AVFoundation
import Foundation

enum SettingsReaction: Codable, CaseIterable {
    case fireworks
    case balloons
    case hearts
    case confetti
    case lasers
    case rain
    case glasses
    case sparkle

    @available(iOS 17, *)
    init?(value: String?) {
        switch value {
        case "fireworks":
            self = .fireworks
        case "balloons":
            self = .balloons
        case "hearts":
            self = .hearts
        case "confetti":
            self = .confetti
        case "lasers":
            self = .lasers
        case "rain":
            self = .rain
        case "glasses":
            self = .glasses
        case "sparkle":
            self = .sparkle
        default:
            return nil
        }
    }

    @available(iOS 17, *)
    func toSystem() -> AVCaptureReactionType? {
        switch self {
        case .fireworks:
            .fireworks
        case .balloons:
            .balloons
        case .hearts:
            .heart
        case .confetti:
            .confetti
        case .lasers:
            .lasers
        case .rain:
            .rain
        default:
            nil
        }
    }

    func toString() -> String {
        switch self {
        case .fireworks:
            String(localized: "Fireworks")
        case .balloons:
            String(localized: "Balloons")
        case .hearts:
            String(localized: "Hearts")
        case .confetti:
            String(localized: "Confetti")
        case .lasers:
            String(localized: "Lasers")
        case .rain:
            String(localized: "Rain")
        case .glasses:
            String(localized: "Glasses")
        case .sparkle:
            String(localized: "Sparkle")
        }
    }
}

enum SettingsMacrosActionFunction: String, CaseIterable, Codable {
    case scene = "Scene"
    case zoom = "Zoom"
    case filters = "Filters"
    case reaction = "Reaction"
    case enableDisableScenes = "Enable/disable scenes"
    case record = "Record"
    case snapshot = "Snapshot"
    case mute = "Mute"
    case torch = "Torch"
    case autoSceneSwitcher = "Auto scene switcher"
    case djiDevices = "DJI devices"
    case gimbalPreset = "Move to gimbal preset"
    case delay = "Delay"
    case macro = "Macro"

    func toString() -> String {
        switch self {
        case .scene:
            String(localized: "Scene")
        case .zoom:
            String(localized: "Zoom")
        case .filters:
            String(localized: "Filters")
        case .reaction:
            String(localized: "Reaction")
        case .enableDisableScenes:
            String(localized: "Scenes")
        case .record:
            String(localized: "Record")
        case .snapshot:
            String(localized: "Snapshot")
        case .mute:
            String(localized: "Mute")
        case .torch:
            String(localized: "Torch")
        case .autoSceneSwitcher:
            String(localized: "Auto scene switcher")
        case .djiDevices:
            String(localized: "DJI devices")
        case .gimbalPreset:
            String(localized: "Move to gimbal preset")
        case .delay:
            String(localized: "Delay")
        case .macro:
            String(localized: "Run macro")
        }
    }
}

class SettingsMacrosAction: Identifiable, Codable, ObservableObject {
    var id: UUID = .init()
    @Published var function: SettingsMacrosActionFunction?
    @Published var sceneId: UUID?
    @Published var sceneIds: Set<UUID> = []
    @Published var autoSceneSwitcherId: UUID?
    @Published var zoomX: Float = 1
    @Published var gimbalPresetId: UUID?
    @Published var delay: Double = 3
    @Published var macroId: UUID?
    @Published var djiDevices: Set<UUID> = []
    @Published var filters: Set<SettingsQuickButtonType> = []
    @Published var record: Bool = true
    @Published var mute: Bool = true
    @Published var torch: Bool = true
    @Published var reaction: SettingsReaction = .fireworks

    init() {}

    enum CodingKeys: CodingKey {
        case id,
             function,
             sceneId,
             sceneIds,
             autoSceneSwitcherId,
             zoomX,
             gimbalPresetId,
             delay,
             macroId,
             djiDevices,
             filters,
             record,
             mute,
             torch,
             reaction
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.function, function)
        try container.encode(.sceneId, sceneId)
        try container.encode(.sceneIds, sceneIds)
        try container.encode(.autoSceneSwitcherId, autoSceneSwitcherId)
        try container.encode(.zoomX, zoomX)
        try container.encode(.gimbalPresetId, gimbalPresetId)
        try container.encode(.delay, delay)
        try container.encode(.macroId, macroId)
        try container.encode(.djiDevices, djiDevices)
        try container.encode(.filters, filters)
        try container.encode(.record, record)
        try container.encode(.mute, mute)
        try container.encode(.torch, torch)
        try container.encode(.reaction, reaction)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        function = container.decode(.function, SettingsMacrosActionFunction?.self, nil)
        sceneId = container.decode(.sceneId, UUID?.self, nil)
        sceneIds = container.decode(.sceneIds, Set<UUID>.self, [])
        autoSceneSwitcherId = container.decode(.autoSceneSwitcherId, UUID?.self, nil)
        zoomX = container.decode(.zoomX, Float.self, 1)
        gimbalPresetId = container.decode(.gimbalPresetId, UUID?.self, nil)
        delay = container.decode(.delay, Double.self, 3)
        macroId = container.decode(.macroId, UUID?.self, nil)
        djiDevices = container.decode(.djiDevices, Set<UUID>.self, [])
        filters = container.decode(.filters, Set<SettingsQuickButtonType>.self, [])
        record = container.decode(.record, Bool.self, true)
        mute = container.decode(.mute, Bool.self, true)
        torch = container.decode(.torch, Bool.self, true)
        reaction = container.decode(.reaction, SettingsReaction.self, .fireworks)
    }
}

class SettingsMacrosMacro: Identifiable, Codable, ObservableObject, Named {
    static let baseName = String(localized: "My macro")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var actions: [SettingsMacrosAction] = []
    @Published var running: Bool = false
    @Published var finished: Bool = false
    var nextActionIndex: Int = 0
    let delayTimer = SimpleTimer(queue: .main)
    let finishedTimer = SimpleTimer(queue: .main)
    var stack: [SettingsMacrosMacro] = []

    init() {}

    enum CodingKeys: CodingKey {
        case id,
             name,
             actions
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.actions, actions)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        actions = container.decode(.actions, [SettingsMacrosAction].self, [])
    }

    func copy() -> SettingsMacrosMacro {
        let new = SettingsMacrosMacro()
        new.id = id
        new.name = name
        new.actions = actions
        return new
    }
}

class SettingsMacros: Codable, ObservableObject {
    @Published var macros: [SettingsMacrosMacro] = []

    init() {}

    enum CodingKeys: CodingKey {
        case macros
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.macros, macros)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        macros = container.decode(.macros, [SettingsMacrosMacro].self, [])
    }
}
