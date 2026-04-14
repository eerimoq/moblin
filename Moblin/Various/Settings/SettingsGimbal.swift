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
    @Published var functionShutter: SettingsControllerFunction = .record
    @Published var shutterSceneId: UUID?
    @Published var shutterWidgetId: UUID?
    @Published var shutterGimbalPresetId: UUID?
    @Published var functionFlip: SettingsControllerFunction = .switchScene
    @Published var flipSceneId: UUID?
    @Published var flipWidgetId: UUID?
    @Published var flipGimbalPresetId: UUID?
    @Published var presets: [SettingsGimbalPreset] = []
    @Published var motion: SettingsGimbalMotion = .kapow

    enum CodingKeys: CodingKey {
        case zoomSpeed,
             naturalZoom,
             functionShutter,
             shutterSceneId,
             shutterWidgetId,
             shutterGimbalPresetId,
             functionFlip,
             flipSceneId,
             flipWidgetId,
             flipGimbalPresetId,
             presets,
             motion
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.zoomSpeed, zoomSpeed)
        try container.encode(.naturalZoom, naturalZoom)
        try container.encode(.functionShutter, functionShutter)
        try container.encode(.shutterSceneId, shutterSceneId)
        try container.encode(.shutterWidgetId, shutterWidgetId)
        try container.encode(.shutterGimbalPresetId, shutterGimbalPresetId)
        try container.encode(.functionFlip, functionFlip)
        try container.encode(.flipSceneId, flipSceneId)
        try container.encode(.flipWidgetId, flipWidgetId)
        try container.encode(.flipGimbalPresetId, flipGimbalPresetId)
        try container.encode(.presets, presets)
        try container.encode(.motion, motion)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        zoomSpeed = container.decode(.zoomSpeed, Float.self, Self.zoomSpeedDefault)
        naturalZoom = container.decode(.naturalZoom, Bool.self, true)
        functionShutter = container.decode(.functionShutter, SettingsControllerFunction.self, .record)
        shutterSceneId = container.decode(.shutterSceneId, UUID?.self, nil)
        shutterWidgetId = container.decode(.shutterWidgetId, UUID?.self, nil)
        shutterGimbalPresetId = container.decode(.shutterGimbalPresetId, UUID?.self, nil)
        functionFlip = container.decode(.functionFlip, SettingsControllerFunction.self, .switchScene)
        flipSceneId = container.decode(.flipSceneId, UUID?.self, nil)
        flipWidgetId = container.decode(.flipWidgetId, UUID?.self, nil)
        flipGimbalPresetId = container.decode(.flipGimbalPresetId, UUID?.self, nil)
        presets = container.decode(.presets, [SettingsGimbalPreset].self, [])
        motion = container.decode(.motion, SettingsGimbalMotion.self, .kapow)
    }
}
