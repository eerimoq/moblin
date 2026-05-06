import Foundation

class SettingsGimbalPreset: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My preset")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var x: Float = 0
    @Published var y: Float = 0
    @Published var zoomX: Float = 1

    enum CodingKeys: CodingKey {
        case id,
             name,
             x,
             y,
             zoomX
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.x, x)
        try container.encode(.y, y)
        try container.encode(.zoomX, zoomX)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, SettingsGimbalPreset.baseName)
        x = container.decode(.x, Float.self, 0.0)
        y = container.decode(.y, Float.self, 0.0)
        zoomX = container.decode(.zoomX, Float.self, 1)
    }
}

class SettingsGimbal: Codable, ObservableObject {
    static let zoomSpeedDefault: Float = 50
    @Published var zoomSpeed: Float = zoomSpeedDefault
    @Published var naturalZoom: Bool = true
    @Published var tracking: Bool = true
    @Published var functionShutter: SettingsControllerFunction = .record
    @Published var functionDataShutter: SettingsControllerFunctionData = .init()
    @Published var functionFlip: SettingsControllerFunction = .switchScene
    @Published var functionDataFlip: SettingsControllerFunctionData = .init()
    @Published var presets: [SettingsGimbalPreset] = []

    enum CodingKeys: CodingKey {
        case zoomSpeed,
             naturalZoom,
             tracking,
             functionShutter,
             shutterSceneId,
             shutterWidgetId,
             shutterGimbalPresetId,
             shutterMotion,
             shutterMacroId,
             functionFlip,
             flipSceneId,
             flipWidgetId,
             flipGimbalPresetId,
             flipMotion,
             flipMacroId,
             presets
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.zoomSpeed, zoomSpeed)
        try container.encode(.naturalZoom, naturalZoom)
        try container.encode(.tracking, tracking)
        try container.encode(.functionShutter, functionShutter)
        try container.encode(.shutterSceneId, functionDataShutter.sceneId)
        try container.encode(.shutterWidgetId, functionDataShutter.widgetId)
        try container.encode(.shutterGimbalPresetId, functionDataShutter.gimbalPresetId)
        try container.encode(.shutterMotion, functionDataFlip.gimbalMotion)
        try container.encode(.shutterMacroId, functionDataFlip.macroId)
        try container.encode(.functionFlip, functionFlip)
        try container.encode(.flipSceneId, functionDataFlip.sceneId)
        try container.encode(.flipWidgetId, functionDataFlip.widgetId)
        try container.encode(.flipGimbalPresetId, functionDataFlip.gimbalPresetId)
        try container.encode(.flipMotion, functionDataFlip.gimbalMotion)
        try container.encode(.flipMacroId, functionDataFlip.macroId)
        try container.encode(.presets, presets)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        zoomSpeed = container.decode(.zoomSpeed, Float.self, Self.zoomSpeedDefault)
        naturalZoom = container.decode(.naturalZoom, Bool.self, true)
        tracking = container.decode(.tracking, Bool.self, true)
        functionShutter = container.decode(.functionShutter, SettingsControllerFunction.self, .record)
        functionDataShutter.sceneId = container.decode(.shutterSceneId, UUID?.self, nil)
        functionDataShutter.widgetId = container.decode(.shutterWidgetId, UUID?.self, nil)
        functionDataShutter.gimbalPresetId = container.decode(.shutterGimbalPresetId, UUID?.self, nil)
        functionDataShutter.gimbalMotion = container.decode(.shutterMotion, SettingsGimbalMotion.self, .kapow)
        functionDataShutter.macroId = container.decode(.shutterMacroId, UUID?.self, nil)
        functionFlip = container.decode(.functionFlip, SettingsControllerFunction.self, .switchScene)
        functionDataFlip.sceneId = container.decode(.flipSceneId, UUID?.self, nil)
        functionDataFlip.widgetId = container.decode(.flipWidgetId, UUID?.self, nil)
        functionDataFlip.gimbalPresetId = container.decode(.flipGimbalPresetId, UUID?.self, nil)
        functionDataFlip.gimbalMotion = container.decode(.flipMotion, SettingsGimbalMotion.self, .kapow)
        functionDataFlip.macroId = container.decode(.flipMacroId, UUID?.self, nil)
        presets = container.decode(.presets, [SettingsGimbalPreset].self, [])
    }
}
