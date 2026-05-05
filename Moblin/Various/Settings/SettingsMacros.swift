import Foundation

enum SettingsMacrosActionFunction: String, CaseIterable, Codable {
    case enableScene = "Enable scene"
    case disableScene = "Disable scene"
    case enableDisableScenes = "Enable/disable scenes"
    case scene = "Scene"
    case autoSceneSwitcher = "Auto scene switcher"
    case zoom = "Zoom"
    case gimbalPreset = "Move to gimbal preset"
    case delay = "Delay"
    case macro = "Macro"
    case djiDevices = "DJI devices"
    case startRecording = "Start recording"
    case stopRecording = "Stop recording"

    func toString() -> String {
        switch self {
        case .enableScene:
            return String(localized: "Enable scene")
        case .disableScene:
            return String(localized: "Disable scene")
        case .enableDisableScenes:
            return String(localized: "Enable/disable scenes")
        case .scene:
            return String(localized: "Scene")
        case .autoSceneSwitcher:
            return String(localized: "Auto scene switcher")
        case .zoom:
            return String(localized: "Zoom")
        case .gimbalPreset:
            return String(localized: "Move to gimbal preset")
        case .delay:
            return String(localized: "Delay")
        case .macro:
            return String(localized: "Run macro")
        case .djiDevices:
            return String(localized: "DJI devices")
        case .startRecording:
            return String(localized: "Start recording")
        case .stopRecording:
            return String(localized: "Stop recording")
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
             djiDevices
    }

    func encode(to encoder: Encoder) throws {
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
    }

    required init(from decoder: Decoder) throws {
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
    }
}

class SettingsMacrosMacro: Identifiable, Codable, ObservableObject, Named {
    static let baseName = String(localized: "My macro")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var actions: [SettingsMacrosAction] = []
    @Published var running: Bool = false
    var nextActionIndex: Int = 0
    let timer = SimpleTimer(queue: .main)
    var stack: [SettingsMacrosMacro] = []

    init() {}

    enum CodingKeys: CodingKey {
        case id,
             name,
             actions
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.actions, actions)
    }

    required init(from decoder: Decoder) throws {
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.macros, macros)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        macros = container.decode(.macros, [SettingsMacrosMacro].self, [])
    }
}
